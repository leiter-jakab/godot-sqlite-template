#!/usr/bin/env python3
"""Merge optional schema fragments into one schema.json contract."""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA_DIRECTORY = REPO_ROOT / "data" / "schema" / "game"


def load_fragment(path: Path) -> dict[str, Any]:
    try:
        fragment = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc

    if not isinstance(fragment, dict) or not isinstance(fragment.get("tables"), dict):
        raise ValueError(f"Schema fragment {path} must contain a 'tables' object.")
    return fragment


def merge_fragments(schema_directory: Path) -> Path | None:
    if not schema_directory.is_dir():
        raise ValueError(f"Schema directory does not exist: {schema_directory}")

    fragments_directory = schema_directory / "fragments"
    fragments = sorted(fragments_directory.glob("*.json")) if fragments_directory.is_dir() else []
    if not fragments:
        return None

    tables: dict[str, Any] = {}
    for fragment_path in fragments:
        fragment_tables = load_fragment(fragment_path)["tables"]
        for table_name, table_fields in fragment_tables.items():
            if table_name in tables:
                raise ValueError(
                    f"Duplicate table '{table_name}' in schema fragment {fragment_path}."
                )
            tables[table_name] = table_fields

    output_path = schema_directory / "schema.json"
    output_text = json.dumps({"tables": tables}, indent=2) + "\n"
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="\n",
            dir=schema_directory,
            prefix="schema.",
            suffix=".tmp",
            delete=False,
        ) as temporary_file:
            temporary_path = Path(temporary_file.name)
            temporary_file.write(output_text)
        temporary_path.replace(output_path)
    finally:
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink()

    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Merge data/schema/<name>/fragments/*.json into schema.json."
    )
    parser.add_argument(
        "--schema-dir",
        type=Path,
        default=DEFAULT_SCHEMA_DIRECTORY,
        help="Schema directory containing an optional fragments/ subdirectory.",
    )
    args = parser.parse_args()

    try:
        output_path = merge_fragments(args.schema_dir)
        if output_path is None:
            print(f"No schema fragments found in {args.schema_dir}; schema.json is unchanged.")
            return 0
        print(f"Merged schema fragments into {output_path}.")
    except (OSError, ValueError) as exc:
        print(f"Schema merge failed: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())