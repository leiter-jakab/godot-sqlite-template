import json
import tempfile
import unittest
from pathlib import Path

from tools.generate_data_classes import (
    _ordered_seed_fragments,
    render_repository,
    validate_seed_files,
)


class GenerateDataClassesSeedTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.seed_directory = Path(self.temporary_directory.name) / "seed"
        self.seed_directory.mkdir()

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_orders_nested_fragments_by_numeric_prefix(self) -> None:
        seed_directory = self.seed_directory / "game" / "test"
        seed_directory.mkdir(parents=True)
        for filename in ("10_last.json", "02_middle.json", "001_first.json"):
            (seed_directory / filename).write_text("{}", encoding="utf-8")

        ordered = _ordered_seed_fragments(self.seed_directory)

        self.assertEqual(
            [path.name for path in ordered],
            ["001_first.json", "02_middle.json", "10_last.json"],
        )

    def test_rejects_fragment_without_numeric_prefix(self) -> None:
        seed_directory = self.seed_directory / "game" / "test"
        seed_directory.mkdir(parents=True)
        (seed_directory / "first.json").write_text("{}", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "numeric prefix"):
            _ordered_seed_fragments(self.seed_directory)

    def test_rejects_duplicate_numeric_prefixes(self) -> None:
        seed_directory = self.seed_directory / "game" / "test"
        seed_directory.mkdir(parents=True)
        for filename in ("01_first.json", "1_duplicate.json"):
            (seed_directory / filename).write_text("{}", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "Duplicate seed fragment number 1"):
            _ordered_seed_fragments(self.seed_directory)

    def test_rejects_seed_json_outside_identifier_directory(self) -> None:
        (self.seed_directory / "01_flat.json").write_text("{}", encoding="utf-8")

        with self.assertRaisesRegex(ValueError, "inside a seed directory"):
            _ordered_seed_fragments(self.seed_directory)

    def test_validates_nested_seed_fragments(self) -> None:
        seed_directory = self.seed_directory / "game" / "test"
        seed_directory.mkdir(parents=True)
        seed_path = seed_directory / "01_examples.json"
        seed_path.write_text(json.dumps({"example1": [{"id": "example"}]}), encoding="utf-8")
        tables = {"example1": {"id": {"data_type": "text"}}}

        validate_seed_files(tables, self.seed_directory)


class GenerateDataClassesRepositoryTests(unittest.TestCase):
    def test_renders_get_all_method_with_exact_table_name(self) -> None:
        tables = {"category": {"id": {"data_type": "integer", "primary_key": True}}}

        repository = render_repository(tables)

        self.assertIn("func get_all_category() -> Array[CategoryData]:", repository)
        self.assertNotIn("func get_all_categories()", repository)

    def test_renders_update_and_delete_for_text_and_integer_primary_keys(self) -> None:
        tables = {
            "example1": {
                "id": {"data_type": "text", "primary_key": True},
                "name": {"data_type": "text", "not_null": True},
                "date": {"data_type": "integer"},
            },
            "example2": {
                "id": {"data_type": "integer", "primary_key": True},
                "example1": {"data_type": "text", "not_null": True},
                "value": {"data_type": "real"},
            },
        }

        repository = render_repository(tables)

        self.assertIn("func update_example1(data: Example1Data) -> bool:", repository)
        self.assertIn(
            'var query := "UPDATE example1 SET name = ?, date = ? WHERE id = ?;"',
            repository,
        )
        self.assertIn(
            "return _execute_write(query, [data.name, data.date, data.id])",
            repository,
        )
        self.assertIn("func delete_example1_by_id(id: String) -> bool:", repository)
        self.assertIn(
            'var query := "DELETE FROM example1 WHERE id = ?;"',
            repository,
        )
        self.assertIn("func update_example2(data: Example2Data) -> bool:", repository)
        self.assertIn(
            'var query := "UPDATE example2 SET example1 = ?, value = ? WHERE id = ?;"',
            repository,
        )
        self.assertIn(
            "return _execute_write(query, [data.example1, data.value, data.id])",
            repository,
        )
        self.assertIn("func delete_example2_by_id(id: int) -> bool:", repository)
        self.assertNotIn("SET id = ?", repository)

    def test_write_helper_returns_false_when_no_rows_were_affected(self) -> None:
        repository = render_repository(
            {"example": {"id": {"data_type": "text", "primary_key": True}}}
        )

        self.assertIn(
            'if not _database.query("SELECT changes() AS affected_rows;"):',
            repository,
        )
        self.assertIn(
            'return not rows.is_empty() and int(rows[0].get("affected_rows", 0)) > 0',
            repository,
        )
        self.assertIn(
            "func update_example(data: ExampleData) -> bool:\n    return false",
            repository,
        )


if __name__ == "__main__":
    unittest.main()