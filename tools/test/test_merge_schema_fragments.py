import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
MERGE_TOOL = REPO_ROOT / "tools" / "merge_schema_fragments.py"


class MergeSchemaFragmentsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.schema_directory = Path(self.temporary_directory.name) / "schema"
        self.fragments_directory = self.schema_directory / "fragments"
        self.fragments_directory.mkdir(parents=True)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def run_merge(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(MERGE_TOOL), "--schema-dir", str(self.schema_directory)],
            check=False,
            capture_output=True,
            text=True,
        )

    def write_fragment(self, filename: str, table_name: str) -> None:
        fragment = {"tables": {table_name: {"id": {"data_type": "text"}}}}
        (self.fragments_directory / filename).write_text(
            json.dumps(fragment), encoding="utf-8"
        )

    def test_merges_fragments_in_sorted_filename_order(self) -> None:
        self.write_fragment("z_last.json", "last")
        self.write_fragment("a_first.json", "first")

        result = self.run_merge()

        self.assertEqual(result.returncode, 0, result.stderr)
        merged = json.loads((self.schema_directory / "schema.json").read_text(encoding="utf-8"))
        self.assertEqual(list(merged["tables"]), ["first", "last"])

    def test_no_fragments_leaves_existing_schema_unchanged(self) -> None:
        schema_path = self.schema_directory / "schema.json"
        schema_path.write_text('{"tables": {"kept": {}}}\n', encoding="utf-8")

        result = self.run_merge()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(schema_path.read_text(encoding="utf-8"), '{"tables": {"kept": {}}}\n')

    def test_missing_fragments_directory_leaves_schema_unchanged(self) -> None:
        self.fragments_directory.rmdir()
        schema_path = self.schema_directory / "schema.json"
        schema_path.write_text('{"tables": {"kept": {}}}\n', encoding="utf-8")

        result = self.run_merge()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(schema_path.read_text(encoding="utf-8"), '{"tables": {"kept": {}}}\n')

    def test_malformed_json_fails_without_overwriting_schema(self) -> None:
        (self.fragments_directory / "invalid.json").write_text("{", encoding="utf-8")
        schema_path = self.schema_directory / "schema.json"
        schema_path.write_text("original\n", encoding="utf-8")

        result = self.run_merge()

        self.assertEqual(result.returncode, 1)
        self.assertIn("Invalid JSON", result.stdout)
        self.assertEqual(schema_path.read_text(encoding="utf-8"), "original\n")

    def test_duplicate_tables_fail_without_overwriting_schema(self) -> None:
        self.write_fragment("one.json", "shared")
        self.write_fragment("two.json", "shared")
        schema_path = self.schema_directory / "schema.json"
        schema_path.write_text("original\n", encoding="utf-8")

        result = self.run_merge()

        self.assertEqual(result.returncode, 1)
        self.assertIn("Duplicate table 'shared'", result.stdout)
        self.assertEqual(schema_path.read_text(encoding="utf-8"), "original\n")

    def test_invalid_fragment_fails_without_overwriting_schema(self) -> None:
        (self.fragments_directory / "invalid.json").write_text("[]", encoding="utf-8")
        schema_path = self.schema_directory / "schema.json"
        schema_path.write_text("original\n", encoding="utf-8")

        result = self.run_merge()

        self.assertEqual(result.returncode, 1)
        self.assertIn("must contain a 'tables' object", result.stdout)
        self.assertEqual(schema_path.read_text(encoding="utf-8"), "original\n")


if __name__ == "__main__":
    unittest.main()