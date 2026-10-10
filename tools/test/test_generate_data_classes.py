import json
import tempfile
import unittest
from pathlib import Path

from tools.generate_data_classes import (
    _ordered_seed_fragments,
    generated_classes,
    render_repository,
    validate_seed_files,
    validate_schema,
    validate_views,
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
        seed_path.write_text(json.dumps({"example1": [{"id": 1}]}), encoding="utf-8")
        tables = {"example1": {"id": {"data_type": "integer"}}}

        validate_seed_files(tables, self.seed_directory)


class GenerateDataClassesRepositoryTests(unittest.TestCase):
    def test_renders_get_all_method_with_exact_table_name(self) -> None:
        tables = {"category": {"id": {"data_type": "integer", "primary_key": True}}}

        repository = render_repository(tables)

        self.assertIn("func get_all_category() -> Array[CategoryData]:", repository)
        self.assertNotIn("func get_all_categories()", repository)

    def test_renders_insert_update_and_delete_for_integer_primary_keys(self) -> None:
        tables = {
            "example1": {
                "id": {"data_type": "integer", "primary_key": True},
                "name": {"data_type": "text", "not_null": True},
                "date": {"data_type": "integer"},
            },
            "example2": {
                "id": {"data_type": "integer", "primary_key": True},
                "example1": {"data_type": "integer", "not_null": True},
                "value": {"data_type": "real"},
            },
        }

        repository = render_repository(tables)

        self.assertIn("func insert_example1(data: Example1Data) -> bool:", repository)
        self.assertIn(
            'var query := "INSERT INTO example1 (name, date) VALUES (?, ?);"',
            repository,
        )
        self.assertIn(
            "var inserted_id := _execute_insert(query, [data.name, data.date])",
            repository,
        )
        self.assertIn("data.id = inserted_id", repository)
        self.assertIn("if data.id != 0:", repository)
        self.assertIn("func insert_example2(data: Example2Data) -> bool:", repository)
        self.assertIn(
            'var query := "INSERT INTO example2 (example1, value) VALUES (?, ?);"',
            repository,
        )
        self.assertIn("SELECT last_insert_rowid() AS inserted_id;", repository)
        self.assertIn("func update_example1(data: Example1Data) -> bool:", repository)
        self.assertIn(
            'var query := "UPDATE example1 SET name = ?, date = ? WHERE id = ?;"',
            repository,
        )
        self.assertIn(
            "return _execute_write(query, [data.name, data.date, data.id])",
            repository,
        )
        self.assertIn("func delete_example1_by_id(id: int) -> bool:", repository)
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

    def test_rejects_non_integer_primary_keys(self) -> None:
        schema = {
            "tables": {
                "example": {
                    "id": {"data_type": "text", "primary_key": True},
                },
            },
        }

        with self.assertRaisesRegex(ValueError, "must use the integer data_type"):
            validate_schema(schema)

    def test_write_helper_returns_false_when_no_rows_were_affected(self) -> None:
        repository = render_repository(
            {"example": {"id": {"data_type": "integer", "primary_key": True}}}
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

    def test_generates_typed_read_only_view_methods(self) -> None:
        schema = {
            "tables": {
                "entry": {"id": {"data_type": "integer", "primary_key": True}},
            },
            "views": {
                "entry_summary": {
                    "query": "SELECT id, name FROM entry",
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

        repository = render_repository(tables, views=views)
        classes = generated_classes(tables, Path("generated"), views=views)

        self.assertIn("func get_all_entry_summary() -> Array[EntrySummaryData]:", repository)
        self.assertIn("func get_entry_summary_by_id(id: int) -> EntrySummaryData:", repository)
        self.assertIn(
            'var query := "SELECT * FROM entry_summary WHERE id = ?;"',
            repository,
        )
        self.assertIn("query_with_bindings(query, [id])", repository)
        self.assertNotIn("func insert_entry_summary", repository)
        self.assertNotIn("func update_entry_summary", repository)
        self.assertNotIn("func delete_entry_summary", repository)
        self.assertIn("class_name EntrySummaryData", classes[Path("generated/entry_summary_data.gd")])
        self.assertIn("static func view_name() -> String:", classes[Path("generated/entry_summary_data.gd")])

    def test_rejects_nullable_view_lookup_columns(self) -> None:
        schema = {
            "tables": {"entry": {"id": {"data_type": "integer", "primary_key": True}}},
            "views": {
                "entry_summary": {
                    "query": "SELECT id FROM entry",
                    "columns": {"id": {"data_type": "integer"}},
                    "lookups": {"id": ["id"]},
                },
            },
        }

        with self.assertRaisesRegex(ValueError, "must be declared not_null"):
            validate_schema(schema)


if __name__ == "__main__":
    unittest.main()