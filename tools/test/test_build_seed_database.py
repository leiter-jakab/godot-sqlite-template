import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.build_seed_database import build_database
from tools.generate_data_classes import validate_schema


REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_SCRIPT = REPO_ROOT / "tools" / "build_seed_database.py"


SCHEMA = {
    "tables": {
        "parent": {
            "id": {"data_type": "text", "primary_key": True},
            "name": {"data_type": "text", "not_null": True},
        },
        "child": {
            "id": {"data_type": "integer", "primary_key": True},
            "parent_id": {
                "data_type": "text",
                "not_null": True,
                "foreign_key": {"table": "parent", "field": "id"},
            },
        },
    }
}
SEED_DATA = {
    "parent": [{"id": "parent_1", "name": "Parent"}],
    "child": [{"id": 1, "parent_id": "parent_1"}],
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
            self.assertEqual(connection.execute("SELECT parent_id FROM child").fetchall(), [("parent_1",)])
            self.assertEqual(connection.execute("PRAGMA foreign_key_check").fetchall(), [])
            self.assertEqual(connection.execute("PRAGMA integrity_check").fetchone(), ("ok",))
        finally:
            connection.close()

    def test_default_seed_directory_builds_all_fragments(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILD_SCRIPT), "--output", str(self.output_path)],
            check=False,
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        connection = sqlite3.connect(self.output_path)
        try:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM example1").fetchone(), (2,))
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM example2").fetchone(), (2,))
        finally:
            connection.close()

    def test_invalid_foreign_key_does_not_replace_existing_output(self) -> None:
        self.output_path.parent.mkdir(parents=True)
        self.output_path.write_bytes(b"existing database artifact")
        invalid_seed = {"parent": [], "child": [{"id": 1, "parent_id": "missing"}]}

        with self.assertRaises(sqlite3.IntegrityError):
            build_database(self.tables, invalid_seed, self.output_path)

        self.assertEqual(self.output_path.read_bytes(), b"existing database artifact")

    def test_rejects_values_that_do_not_match_declared_types(self) -> None:
        invalid_seed = {"parent": [{"id": 1, "name": "Parent"}], "child": []}

        with self.assertRaisesRegex(ValueError, "expected text"):
            build_database(self.tables, invalid_seed, self.output_path)
        self.assertFalse(self.output_path.exists())


if __name__ == "__main__":
    unittest.main()