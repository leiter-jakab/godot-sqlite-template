#!/usr/bin/env python3
"""Build the packaged SQLite template database from schema and seed JSON."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import tempfile
from pathlib import Path
from typing import Any, Dict

if __package__:
    from .generate_data_classes import (
        REPO_ROOT,
        SCHEMA_PATH,
        SEED_DIR,
        _seed_fragment_number,
        load_json_file,
        validate_schema,
        validate_seed_against_schema,
    )
else:
    from generate_data_classes import (
        REPO_ROOT,
        SCHEMA_PATH,
        SEED_DIR,
        _seed_fragment_number,
        load_json_file,
        validate_schema,
        validate_seed_against_schema,
    )


TEMPLATE_DATABASE_PATH = REPO_ROOT / "data" / "database" / "game_template.db"
SQLITE_TYPES = {
    "text": "TEXT",
    "integer": "INTEGER",
    "real": "REAL",
    "boolean": "INTEGER",
}


def _quote_identifier(identifier: str) -> str:
    return '"' + identifier.replace('"', '""') + '"'


def _create_tables(
    connection: sqlite3.Connection,
    tables: Dict[str, Dict[str, Dict[str, Any]]],
) -> None:
    for table_name, fields in tables.items():
        definitions = []
        for field_name, field in fields.items():
            data_type = field["data_type"].lower()
            definition = [_quote_identifier(field_name), SQLITE_TYPES[data_type]]
            if field.get("not_null"):
                definition.append("NOT NULL")
            if field.get("primary_key"):
                definition.append("PRIMARY KEY")

            foreign_key = field.get("foreign_key")
            if foreign_key is not None:
                if not isinstance(foreign_key, dict):
                    raise ValueError(f"Foreign key for '{table_name}.{field_name}' must be an object.")
                referenced_table = foreign_key.get("table")
                referenced_field = foreign_key.get("field")
                if referenced_table not in tables or referenced_field not in tables[referenced_table]:
                    raise ValueError(f"Foreign key for '{table_name}.{field_name}' references an unknown field.")
                definition.append(
                    "REFERENCES %s (%s)"
                    % (_quote_identifier(referenced_table), _quote_identifier(referenced_field))
                )
            definitions.append(" ".join(definition))

        sql = "CREATE TABLE %s (%s);" % (_quote_identifier(table_name), ", ".join(definitions))
        connection.execute(sql)


def _validate_row_values(
    table_name: str,
    fields: Dict[str, Dict[str, Any]],
    row: Dict[str, Any],
    row_index: int,
) -> None:
    for field_name, value in row.items():
        if value is None:
            continue
        data_type = fields[field_name]["data_type"].lower()
        is_valid = {
            "text": lambda item: isinstance(item, str),
            "integer": lambda item: isinstance(item, int) and not isinstance(item, bool),
            "real": lambda item: isinstance(item, (int, float)) and not isinstance(item, bool),
            "boolean": lambda item: isinstance(item, bool),
        }[data_type](value)
        if not is_valid:
            raise ValueError(
                f"Seed row {row_index} in '{table_name}' has an invalid value for '{field_name}' "
                f"(expected {data_type})."
            )


def _insert_seed_data(
    connection: sqlite3.Connection,
    tables: Dict[str, Dict[str, Dict[str, Any]]],
    seed_data: Dict[str, Any],
) -> None:
    for table_name, fields in tables.items():
        rows = seed_data.get(table_name, [])
        for row_index, row in enumerate(rows):
            _validate_row_values(table_name, fields, row, row_index)
            columns = [field_name for field_name in fields if field_name in row]
            if not columns:
                connection.execute("INSERT INTO %s DEFAULT VALUES" % _quote_identifier(table_name))
                continue
            column_sql = ", ".join(_quote_identifier(field_name) for field_name in columns)
            placeholders = ", ".join("?" for _ in columns)
            values = [row[field_name] for field_name in columns]
            for index, field_name in enumerate(columns):
                if fields[field_name]["data_type"].lower() == "boolean" and values[index] is not None:
                    values[index] = int(values[index])
            connection.execute(
                "INSERT INTO %s (%s) VALUES (%s)"
                % (_quote_identifier(table_name), column_sql, placeholders),
                values,
            )


def _load_seed_directory(
    tables: Dict[str, Dict[str, Dict[str, Any]]], seed_dir: Path
) -> Dict[str, Any]:
    numbered_fragments = [
        (_seed_fragment_number(seed_path), seed_path)
        for seed_path in seed_dir.glob("*.json")
        if seed_path.is_file()
    ]
    numbered_fragments.sort(key=lambda item: (item[0], item[1].name))

    seed_data: Dict[str, Any] = {}
    seen_numbers: Dict[int, Path] = {}
    for fragment_number, seed_path in numbered_fragments:
        if fragment_number in seen_numbers:
            raise ValueError(
                f"Duplicate seed fragment number {fragment_number} in {seed_dir}: "
                f"{seen_numbers[fragment_number].name} and {seed_path.name}"
            )
        seen_numbers[fragment_number] = seed_path

        fragment_data = load_json_file(seed_path)
        validate_seed_against_schema(tables, fragment_data, seed_path)
        for collection_name, rows in fragment_data.items():
            seed_data.setdefault(collection_name, []).extend(rows)

    if not numbered_fragments:
        raise ValueError(f"No seed JSON fragments found in {seed_dir}.")
    return seed_data


def build_database(
    tables: Dict[str, Dict[str, Dict[str, Any]]], seed_data: Any, output_path: Path
) -> None:
    validate_seed_against_schema(tables, seed_data)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f"{output_path.name}.", suffix=".tmp", dir=output_path.parent
    )
    os.close(temporary_descriptor)
    temporary_path = Path(temporary_name)

    try:
        connection = sqlite3.connect(temporary_path)
        try:
            connection.execute("PRAGMA foreign_keys = ON;")
            with connection:
                _create_tables(connection, tables)
                connection.execute("PRAGMA defer_foreign_keys = ON;")
                _insert_seed_data(connection, tables, seed_data)
                foreign_key_errors = connection.execute("PRAGMA foreign_key_check;").fetchall()
                if foreign_key_errors:
                    raise ValueError(f"Generated database has foreign-key violations: {foreign_key_errors}")
                integrity_result = connection.execute("PRAGMA integrity_check;").fetchone()
                if integrity_result != ("ok",):
                    raise ValueError(f"Generated database integrity check failed: {integrity_result}")
        finally:
            connection.close()
        os.replace(temporary_path, output_path)
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the packaged SQLite template database from schema and seed JSON.")
    parser.add_argument("--schema", type=Path, default=SCHEMA_PATH, help="Input schema JSON path.")
    parser.add_argument(
        "--seed-file",
        type=Path,
        help="Single input seed JSON path (overrides --seed-dir).",
    )
    parser.add_argument(
        "--seed-dir",
        type=Path,
        default=SEED_DIR / "game" / "test",
        help="Directory of numbered seed JSON fragments.",
    )
    parser.add_argument("--output", type=Path, default=TEMPLATE_DATABASE_PATH, help="Output SQLite database path.")
    args = parser.parse_args()

    try:
        tables = validate_schema(load_json_file(args.schema))
        seed_data = (
            load_json_file(args.seed_file)
            if args.seed_file is not None
            else _load_seed_directory(tables, args.seed_dir)
        )
        build_database(tables, seed_data, args.output)
    except (OSError, sqlite3.Error, ValueError) as exc:
        print(f"Database build failed: {exc}")
        return 1

    print(f"Built SQLite template database: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())