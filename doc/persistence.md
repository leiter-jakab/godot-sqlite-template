## Addons

- [godot-sqlite](https://github.com/2shady4u/godot-sqlite) is vendored in `addons/godot-sqlite/` and provides the runtime SQLite extension.
- [GUT](https://github.com/bitwes/Gut) is vendored in `addons/gut/` and provides the project's test framework; it is not used by runtime persistence code.

Both addons are included in the repository; no separate download is needed. Preserve their upstream license and notice files when updating them.

## Persistence architecture

This template uses a schema-first persistence pipeline:

1. The canonical database contract lives in `data/schema/game/schema.json`.
2. `tools/generate_data_classes.py` validates that schema and emits typed GDScript models.
3. A generated `DataRepository` exposes table-specific queries such as `get_example_by_id()` and `get_all_examples()`.
4. `PersistenceManager` opens the SQLite database, applies the schema, and loads seed data.
5. `GameManager` exposes save-game creation and retrieval for the game runtime.

This design keeps data access predictable and avoids hand-writing repetitive database access code for every table.

## Project structure relevant to persistence

```text
.
├── data/
│   ├── schema/
│   │   └── game/
│   │       ├── schema.json         # Schema contract consumed by runtime and generator
│   │       └── fragments/          # Optional source fragments for schema generation
│   └── seed/                      # Seed JSON loaded into new databases
├── scripts/
│   ├── game/
│   │   ├── game_manager.gd            # Save-game helper API
│   │   ├── persistence/
│   │   │   ├── persistence_manager.gd  # Database creation, schema application, seed loading
│   │   │   └── data_generated/        # Generated classes and repository
│   │   └── states/                    # State-driven gameplay flow
│   └── test/                          # GUT tests for game scripts
├── tools/
│   ├── test/                     # Python tests for the tool scripts
│   └── generate_data_classes.py   # Schema validator and code generator
└── project.godot
```

## Schema source of truth

`data/schema/<schema-name>/schema.json` defines every table, field, and primary-key metadata. Each field has a `data_type` and may flag `primary_key`, `not_null`, and foreign-key metadata. The generator enforces a simple schema contract so the repo stays consistent.

Fragmented schemas are optional. When `data/schema/<schema-name>/fragments/` contains JSON files, `tools/merge_schema_fragments.py` combines their `tables` objects into that schema directory's `schema.json`. Fragments are processed in filename order and each table must be defined in exactly one fragment. In fragment mode, `schema.json` is generated output; without fragments, it can be edited directly. The persistence manager always reads only `schema.json`.

Example structure:

```json
{
  "tables": {
    "example1": {
      "id": {
        "data_type": "text",
        "primary_key": true
      },
      "name": {
        "data_type": "text",
        "not_null": true
      }
    }
  }
}
```

## Regenerating persistence code

When using schema fragments, merge them first:

```sh
python tools/merge_schema_fragments.py
```

The merge command is optional when editing `schema.json` directly. For another schema directory, pass `--schema-dir data/schema/<name>`. After changing the schema, regenerate the typed files and repository with:

```sh
python tools/generate_data_classes.py
```

Check generated classes and seed files against the schema with:

```sh
python tools/generate_data_classes.py --check --check-seeds
```

Generated persistence code is written to `scripts/game/persistence/data_generated/`; the directory is created automatically if it is missing. In fragment mode, `data/schema/<schema-name>/schema.json` is also generated and should not be edited directly. Do not edit generated persistence code by hand.

## Seed data

Seed files live in directories under `data/seed/`, with each seed identifier represented by its path segments. For example, the `game_test` identifier resolves to `data/seed/game/test/`. Each directory can contain multiple JSON fragments named with a numeric prefix and underscore, such as `01_examples.json`; fragments load in ascending numeric order. Leading zeros are ignored when ordering, so prefixes `01` and `1` have the same value and cannot both appear in one seed directory.

Every JSON fragment must begin with a numeric prefix followed by `_`, contain a top-level object, and match the schema. The generator recursively validates nested seed directories and rejects flat JSON files directly under `data/seed/`, malformed prefixes, and duplicate numeric prefixes. Run `python tools/generate_data_classes.py --check --check-seeds` after changing seed data.

## Repository usage

`DataRepository` takes the `SQLite` handle returned by `GameManager` and provides typed lookups for each table. Example:

```gdscript
var database := game_manager.start_new_game("save_01")
var repository := DataRepository.new(database)
var example := repository.get_example_by_id("example_01")
var examples := repository.get_all_examples()
```

## Agent and contributor guidance

- Update `data/schema/game/schema.json`, or the optional files under `data/schema/game/fragments/`, before regenerating persistence files.
- When fragments are used, run `python tools/merge_schema_fragments.py` before `python tools/generate_data_classes.py`.
- Prefer regenerating typed classes instead of patching generated output by hand.
- When adding or changing tables, also review matching seed JSON files for validity.
- Keep repository usage aligned with the generated API names rather than inventing bespoke SQL queries in gameplay code.
- Run the schema validation command before finalizing persistence changes.
