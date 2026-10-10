import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.build_seed_database import build_database
from tools.generate_data_classes import validate_schema, validate_views


REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_SCRIPT = REPO_ROOT / "tools" / "build_seed_database.py"


SCHEMA = {
    "tables": {
        "parent": {
            "id": {"data_type": "integer", "primary_key": True},
            "name": {"data_type": "text", "not_null": True},
        },
        "child": {
            "id": {"data_type": "integer", "primary_key": True},
            "parent_id": {
                "data_type": "integer",
                "not_null": True,
                "foreign_key": {"table": "parent", "field": "id"},
            },
        },
    }
}
SEED_DATA = {
    "parent": [{"id": 10, "name": "Parent"}],
    "child": [{"id": 1, "parent_id": 10}],
}


class BuildSeedDatabaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.output_path = Path(self.temporary_directory.name) / "nested" / "template.db"
        self.tables = validate_schema(SCHEMA)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_builds_schema_and_seed_rows_with_integrity(self) -> None:
        build_database(self.tables, SEED_DATA, self.output_path)

        connection = sqlite3.connect(self.output_path)
        try:
            self.assertEqual(connection.execute("SELECT name FROM parent").fetchall(), [("Parent",)])
            self.assertEqual(connection.execute("SELECT parent_id FROM child").fetchall(), [(10,)])
            self.assertEqual(connection.execute("PRAGMA foreign_key_check").fetchall(), [])
            self.assertEqual(connection.execute("PRAGMA integrity_check").fetchone(), ("ok",))
        finally:
            connection.close()

    def test_builds_when_referenced_table_follows_child(self) -> None:
        reversed_tables = validate_schema(
            {"tables": {"child": SCHEMA["tables"]["child"], "parent": SCHEMA["tables"]["parent"]}}
        )

        build_database(reversed_tables, SEED_DATA, self.output_path)

        connection = sqlite3.connect(self.output_path)
        try:
            self.assertEqual(connection.execute("SELECT parent_id FROM child").fetchall(), [(10,)])
            self.assertEqual(connection.execute("PRAGMA foreign_key_check").fetchall(), [])
        finally:
            connection.close()

    def test_builds_views_after_seed_data(self) -> None:
        schema = {
            **SCHEMA,
            "views": {
                "child_summary": {
                    "query": "SELECT child.id, parent.name FROM child JOIN parent ON parent.id = child.parent_id",
                    "columns": {
                        "id": {"data_type": "integer", "not_null": True},
                        "name": {"data_type": "text", "not_null": True},
                    },
                    "lookups": {"id": ["id"]},
                },
            },
        }
        tables = validate_schema(schema)
        views = validate_views(schema, tables)

        build_database(tables, SEED_DATA, self.output_path, views)

        connection = sqlite3.connect(self.output_path)
        try:
            self.assertEqual(
                connection.execute("SELECT id, name FROM child_summary").fetchall(),
                [(1, "Parent")],
            )
        finally:
            connection.close()

    def test_cli_builds_from_schema_and_all_seed_fragments(self) -> None:
        temporary_directory = Path(self.temporary_directory.name)
        schema_path = temporary_directory / "schema.json"
        seed_directory = temporary_directory / "seed"
        seed_directory.mkdir()
        schema_path.write_text(
            json.dumps(
                {
                    "tables": {
                        "entry": {
                            "id": {"data_type": "integer", "primary_key": True},
                            "value": {"data_type": "text", "not_null": True},
                        }
                    }
                }
            ),
            encoding="utf-8",
        )
        (seed_directory / "02_second.json").write_text(
            json.dumps({"entry": [{"id": 2, "value": "second"}]}),
            encoding="utf-8",
        )
        (seed_directory / "01_first.json").write_text(
            json.dumps({"entry": [{"id": 1, "value": "first"}]}),
            encoding="utf-8",
        )

        result = subprocess.run(
            [
                sys.executable,
                str(BUILD_SCRIPT),
                "--schema",
                str(schema_path),
                "--seed-dir",
                str(seed_directory),
                "--output",
                str(self.output_path),
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        connection = sqlite3.connect(self.output_path)
        try:
            self.assertEqual(
                connection.execute("SELECT value FROM entry ORDER BY id").fetchall(),
                [("first",), ("second",)],
            )
        finally:
            connection.close()

    def test_invalid_foreign_key_does_not_replace_existing_output(self) -> None:
        self.output_path.parent.mkdir(parents=True)
        self.output_path.write_bytes(b"existing database artifact")
        invalid_seed = {"parent": [], "child": [{"id": 1, "parent_id": 999}]}

        with self.assertRaisesRegex(ValueError, "foreign-key violations"):
            build_database(self.tables, invalid_seed, self.output_path)

        self.assertEqual(self.output_path.read_bytes(), b"existing database artifact")

    def test_rejects_values_that_do_not_match_declared_types(self) -> None:
        invalid_seed = {"parent": [{"id": 1, "name": 42}], "child": []}

        with self.assertRaisesRegex(ValueError, "expected text"):
            build_database(self.tables, invalid_seed, self.output_path)
        self.assertFalse(self.output_path.exists())


if __name__ == "__main__":
    unittest.main()