#!/usr/bin/env python3
"""Generate persistence data classes from the declarative game schema."""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
from pathlib import Path
from typing import Any, Dict


REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "scripts" / "game" / "persistence" / "data_generated"
SCHEMA_PATH = REPO_ROOT / "data" / "schema" / "game" / "schema.json"
SEED_DIR = REPO_ROOT / "data" / "seed"
EDITORCONFIG_PATH = REPO_ROOT / ".editorconfig"
IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
TABLE_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")
RESERVED_MEMBERS = {"table_name", "from_row", "to_row", "get_by_id", "get_all"}
FIELD_TYPES = {
    "text": ("String", '""', "str"),
    "integer": ("int", "0", "int"),
    "real": ("float", "0.0", "float"),
    "boolean": ("bool", "false", "bool"),
}


def load_editorconfig_settings(path: Path) -> Dict[str, str]:
    settings = {
        "charset": "utf-8",
        "end_of_line": "lf",
        "indent_style": "space",
        "indent_size": "4",
    }
    try:
        relative_path = path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError:
        relative_path = path.name

    active_section_matches = True
    for raw_line in EDITORCONFIG_PATH.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("[") and line.endswith("]"):
            pattern = line[1:-1]
            target = relative_path if "/" in pattern else path.name
            active_section_matches = fnmatch.fnmatchcase(target, pattern)
            continue
        if active_section_matches and "=" in line:
            key, value = (part.strip().lower() for part in line.split("=", 1))
            if key != "root":
                settings[key] = value

    return settings


def format_generated_gdscript(
    lines: list[str], indent_unit: str, line_ending: str
) -> str:
    formatted_lines = []
    for line in lines:
        indent_size = len(line) - len(line.lstrip(" "))
        if indent_size % 4:
            raise ValueError("Generated GDScript indentation must use four-space levels internally.")
        formatted_lines.append(indent_unit * (indent_size // 4) + line[indent_size:])
    return line_ending.join(formatted_lines)


def output_format(settings: Dict[str, str]) -> tuple[str, str, str]:
    charset = settings.get("charset", "utf-8")
    encodings = {
        "utf-8": "utf-8",
        "utf-8-bom": "utf-8-sig",
        "latin1": "latin-1",
        "utf-16be": "utf-16-be",
        "utf-16le": "utf-16-le",
    }
    if charset not in encodings:
        raise ValueError(f"Unsupported .editorconfig charset for generated GDScript: {charset}")

    line_endings = {"lf": "\n", "cr": "\r", "crlf": "\r\n"}
    end_of_line = settings.get("end_of_line", "lf")
    if end_of_line not in line_endings:
        raise ValueError(f"Unsupported .editorconfig end_of_line: {end_of_line}")

    indent_style = settings.get("indent_style", "space")
    if indent_style == "tab":
        indent_unit = "\t"
    elif indent_style == "space":
        indent_size = settings.get("indent_size", "4")
        if indent_size == "tab":
            indent_size = settings.get("tab_width", "4")
        try:
            indent_unit = " " * int(indent_size)
        except ValueError as exc:
            raise ValueError(f"Invalid .editorconfig indent_size: {indent_size}") from exc
        if not indent_unit:
            raise ValueError(".editorconfig indent_size must be greater than zero.")
    else:
        raise ValueError(f"Unsupported .editorconfig indent_style: {indent_style}")

    return encodings[charset], line_endings[end_of_line], indent_unit


def load_json_file(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc


def validate_schema(schema: Any) -> Dict[str, Dict[str, Dict[str, Any]]]:
    if not isinstance(schema, dict) or not isinstance(schema.get("tables"), dict):
        raise ValueError("Schema must contain a 'tables' object.")

    tables = schema["tables"]
    class_names: set[str] = set()
    for table_name, fields in tables.items():
        if not isinstance(table_name, str) or not TABLE_PATTERN.fullmatch(table_name):
            raise ValueError(f"Invalid table name: {table_name!r}")
        if not isinstance(fields, dict) or not fields:
            raise ValueError(f"Table '{table_name}' must contain a non-empty fields object.")

        class_name = to_class_name(table_name)
        if class_name in class_names:
            raise ValueError(f"Multiple tables generate the class name '{class_name}'.")
        class_names.add(class_name)

        primary_keys = []

        for field_name, field in fields.items():
            if not isinstance(field_name, str) or not IDENTIFIER_PATTERN.fullmatch(field_name):
                raise ValueError(f"Invalid field name in table '{table_name}': {field_name!r}")
            if field_name in RESERVED_MEMBERS:
                raise ValueError(f"Field '{field_name}' in table '{table_name}' conflicts with the Data API.")
            if not isinstance(field, dict):
                raise ValueError(f"Field '{table_name}.{field_name}' must be an object.")
            if field.get("primary_key", False):
                primary_keys.append(field_name)
            data_type = field.get("data_type")
            if not isinstance(data_type, str) or data_type.lower() not in FIELD_TYPES:
                supported_types = ", ".join(sorted(FIELD_TYPES))
                raise ValueError(
                    f"Unsupported data_type for '{table_name}.{field_name}': {data_type!r}. "
                    f"Supported types: {supported_types}."
                )
        if len(primary_keys) != 1:
            raise ValueError(f"Table '{table_name}' must define exactly one primary key for repository lookups.")

    return tables


def to_class_name(table_name: str) -> str:
    parts = [part for part in re.split(r"[^A-Za-z0-9]+", table_name) if part]
    return "".join(part[0].upper() + part[1:] for part in parts) + "Data"


def render_data_class(
    table_name: str,
    fields: Dict[str, Dict[str, Any]],
    indent_unit: str = "    ",
    line_ending: str = "\n",
) -> str:
    class_name = to_class_name(table_name)
    lines = ["extends RefCounted", "", f"class_name {class_name}", ""]

    for field_name, field in fields.items():
        gdscript_type, default_value, _ = FIELD_TYPES[field["data_type"].lower()]
        is_nullable = not field.get("not_null", False) and not field.get("primary_key", False)
        property_type = "Variant" if is_nullable else gdscript_type
        property_default = "null" if is_nullable else default_value
        lines.append(f"var {field_name}: {property_type} = {property_default}")

    lines.extend(
        [
            "",
            "",
            "static func table_name() -> String:",
            f'    return "{table_name}"',
            "",
            "",
            f"static func from_row(row: Dictionary) -> {class_name}:",
            f"    var data := {class_name}.new()",
        ]
    )

    for field_name, field in fields.items():
        _, default_value, converter = FIELD_TYPES[field["data_type"].lower()]
        is_nullable = not field.get("not_null", False) and not field.get("primary_key", False)
        if is_nullable:
            assignment = f'row.get("{field_name}", null)'
        else:
            assignment = f'{converter}(row.get("{field_name}", {default_value}))'
        lines.append(f"    data.{field_name} = {assignment}")

    lines.extend(["    return data", "", "", "func to_row() -> Dictionary:", "    return {"])
    for field_name in fields:
        lines.append(f'        "{field_name}": {field_name},')
    lines.extend(["    }", ""])
    return format_generated_gdscript(lines, indent_unit, line_ending)


def generated_classes(
    tables: Dict[str, Dict[str, Dict[str, Any]]],
    output_dir: Path,
    indent_unit: str = "    ",
    line_ending: str = "\n",
) -> Dict[Path, str]:
    return {
        output_dir / f"{table_name}_data.gd": render_data_class(
            table_name, fields, indent_unit, line_ending
        )
        for table_name, fields in tables.items()
    }


def pluralize_table_name(table_name: str) -> str:
    if table_name.endswith("y") and len(table_name) > 1 and table_name[-2] not in "aeiou":
        return table_name[:-1] + "ies"
    if table_name.endswith(("s", "x", "z", "ch", "sh")):
        return table_name + "es"
    return table_name + "s"


def render_repository(
    tables: Dict[str, Dict[str, Dict[str, Any]]],
    indent_unit: str = "    ",
    line_ending: str = "\n",
) -> str:
    lines = [
        "extends RefCounted",
        "",
        "class_name DataRepository",
        "",
        "var _database: SQLite",
        "",
        "",
        "func _init(database: SQLite) -> void:",
        '    if database == null:',
        '        push_error("Database handle cannot be null.")',
        "        return",
        "    _database = database",
    ]

    for table_name, fields in tables.items():
        class_name = to_class_name(table_name)
        primary_key = next(name for name, field in fields.items() if field.get("primary_key", False))
        primary_key_type = FIELD_TYPES[fields[primary_key]["data_type"].lower()][0]
        lines.extend(
            [
                "",
                "",
                f"func get_{table_name}_by_id(id: {primary_key_type}) -> {class_name}:",
                "    if _database == null:",
                '        push_error("Cannot query without a database handle.")',
                "        return null",
                f'    var query := "SELECT * FROM {table_name} WHERE {primary_key} = ?;"',
                "    if not _database.query_with_bindings(query, [id]):",
                f'        push_error("Failed to retrieve {table_name} row: %s" % _database.error_message)',
                "        return null",
                "    var rows: Array = _database.query_result",
                "    if rows.is_empty():",
                "        return null",
                f"    return {class_name}.from_row(rows[0])",
                "",
                "",
                f"func get_all_{pluralize_table_name(table_name)}() -> Array[{class_name}]:",
                f"    var items: Array[{class_name}] = []",
                "    if _database == null:",
                '        push_error("Cannot query without a database handle.")',
                "        return items",
                f'    var query := "SELECT * FROM {table_name};"',
                "    if not _database.query(query):",
                f'        push_error("Failed to retrieve {table_name} rows: %s" % _database.error_message)',
                "        return items",
                "    for row in _database.query_result:",
                f"        items.append({class_name}.from_row(row))",
                "    return items",
            ]
        )

    lines.append("")
    return format_generated_gdscript(lines, indent_unit, line_ending)


def validate_seed_against_schema(
    tables: Dict[str, Dict[str, Dict[str, Any]]], seed_data: Any, seed_path: Path | None = None
) -> None:
    if not isinstance(seed_data, dict):
        raise ValueError(f"Seed file {seed_path or ''} must contain a JSON object at the top level.")

    invalid_collection_names = sorted(key for key in seed_data if key not in tables)
    if invalid_collection_names:
        location = f" for {seed_path}" if seed_path else ""
        raise ValueError(f"Seed collection names are not in the schema{location}: {', '.join(invalid_collection_names)}")

    for collection_name, rows in seed_data.items():
        if not isinstance(rows, list):
            raise ValueError(f"Seed collection '{collection_name}' must be an array of objects.")
        expected_fields = tables[collection_name]
        for row_index, row in enumerate(rows):
            if not isinstance(row, dict):
                raise ValueError(f"Seed collection '{collection_name}' entry {row_index} must be an object.")
            unexpected_fields = sorted(field for field in row if field not in expected_fields)
            if unexpected_fields:
                raise ValueError(
                    f"Seed collection '{collection_name}' row {row_index} contains unknown fields: "
                    f"{', '.join(unexpected_fields)}"
                )


def validate_seed_files(tables: Dict[str, Dict[str, Dict[str, Any]]], seed_dir: Path) -> None:
    if not seed_dir.exists():
        return
    for seed_path in sorted(seed_dir.glob("*.json")):
        validate_seed_against_schema(tables, load_json_file(seed_path), seed_path)


def check_generated_files(
    expected: Dict[Path, str], output_dir: Path, encoding: str
) -> bool:
    valid = True
    for path, expected_content in expected.items():
        if not path.exists() or path.read_bytes() != expected_content.encode(encoding):
            print(f"Generated data class is missing or out of date: {path}")
            valid = False

    expected_paths = set(expected)
    for path in sorted(output_dir.glob("*_data.gd")):
        if path not in expected_paths:
            print(f"Stale generated data class: {path}")
            valid = False
    return valid


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate persistence data classes and repository from the game schema JSON.")
    parser.add_argument("--schema", type=Path, default=SCHEMA_PATH, help="Input schema JSON path.")
    parser.add_argument("--output-dir", type=Path, default=DATA_DIR, help="Generated GDScript output directory.")
    parser.add_argument("--check", action="store_true", help="Fail if generated classes are missing or out of date.")
    parser.add_argument("--check-seeds", action="store_true", help="Validate every seed file against the schema.")
    parser.add_argument("--seed-file", type=Path, help="Validate one seed file against the schema.")
    args = parser.parse_args()

    try:
        schema = load_json_file(args.schema)
        tables = validate_schema(schema)
        if args.seed_file:
            validate_seed_against_schema(tables, load_json_file(args.seed_file), args.seed_file)
            print(f"Seed file is valid for schema contract: {args.seed_file}")
            return 0
        if args.check_seeds:
            validate_seed_files(tables, SEED_DIR)
            print("Seed files match the schema contract.")

        settings = load_editorconfig_settings(args.output_dir / "data_repository.gd")
        encoding, line_ending, indent_unit = output_format(settings)
        expected = generated_classes(tables, args.output_dir, indent_unit, line_ending)
        expected[args.output_dir / "data_repository.gd"] = render_repository(
            tables, indent_unit, line_ending
        )
        if args.check:
            if not check_generated_files(expected, args.output_dir, encoding):
                return 1
            print(f"Generated data classes and repository are up to date in {args.output_dir}.")
            return 0

        args.output_dir.mkdir(parents=True, exist_ok=True)
        for path, content in expected.items():
            with path.open("w", encoding=encoding, newline="") as generated_file:
                generated_file.write(content)
            print(f"Wrote {path}")
    except (OSError, ValueError) as exc:
        print(f"Generation failed: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())