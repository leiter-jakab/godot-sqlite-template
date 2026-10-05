import json
import tempfile
import unittest
from pathlib import Path

from tools.generate_data_classes import _ordered_seed_fragments, validate_seed_files


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


if __name__ == "__main__":
    unittest.main()