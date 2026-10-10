## Addons

- [godot-sqlite](https://github.com/2shady4u/godot-sqlite) is vendored in `addons/godot-sqlite/` and provides the runtime SQLite extension.
- [GUT](https://github.com/bitwes/Gut) is vendored in `addons/gut/` and provides the project's test framework; it is not used by runtime persistence code.

Both addons are included in the repository; no separate download is needed. Preserve their upstream license and notice files when updating them.

## Persistence architecture

This template uses a schema-first persistence pipeline:

1. The canonical database contract lives in `data/schema/game/schema.json`.
2. `tools/generate_data_classes.py` validates that schema and emits typed GDScript models.
3. A generated `DataRepository` exposes table-specific queries such as `get_example_by_id()` and `get_all_example()`; list method names preserve the exact table name.
4. `tools/build_seed_database.py` creates a populated SQLite template from the schema and seed JSON before export.
5. `PersistenceManager` copies that template into the writable user-data directory for new saves and opens existing saves.
6. `GameManager` exposes save-game creation and retrieval for the game runtime.

This design keeps data access predictable and avoids hand-writing repetitive database access code for every table.

## Project structure relevant to persistence

```text
.
├── data/
│   ├── schema/game.json            # Source-of-truth schema contract
│   ├── seed/                      # Seed JSON used to build the template database
│   └── database/                  # Generated SQLite template included in game exports
├── src/
│   ├── game_manager.gd            # Save-game helper API
│   ├── persistence/
│   │   ├── persistence_manager.gd  # Database creation, schema application, seed loading
│   │   └── data_generated/        # Generated classes and repository
│   └── states/                    # State-driven gameplay flow
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

Seed JSON is source data for the prebuilt database, not loaded by the runtime. Files must match the schema. If you change table names, fields, or seed rows, update the inputs and rebuild the template.

## Building the database template

The standard-library `sqlite3` module builds the SQLite template at `data/database/game_template.db`, validates seed shape and value types, applies schema constraints, inserts seed rows transactionally, and checks database integrity and foreign keys. No extra Python package is required.

Run this command after changing the schema or seed data and before exporting the game:

```sh
python tools/build_seed_database.py
```

By default, the builder loads numbered seed fragments from `data/seed/game/test/`. Use `--seed-dir` to select another fragment directory, or `--seed-file` to use one JSON file instead; `--seed-file` takes precedence if both are supplied. Use `--schema` or `--output` to override the schema or output path. New saves copy the packaged template to `user://<save-name>.db`; existing saves open that copy without recreating tables or inserting seed data. Keep foreign-key enforcement enabled on each runtime database connection.

The `.db` is a non-resource file. Add `data/database/*.db` to the **Filters to export non-resource files** setting in each Godot export preset, then verify the template is present in the exported game. This repository does not define platform-specific export presets.

## Repository usage

`DataRepository` takes the `SQLite` handle returned by `GameManager` and provides typed lookups for each table. Example:

```gdscript
var database := game_manager.start_new_game("save_01")
var repository := DataRepository.new(database)
var example := repository.get_example1_by_id("example_01")
var examples := repository.get_all_example1()
if example != null:
  example.name = "Updated name"
  var updated := repository.update_example1(example)
  var deleted := repository.delete_example1_by_id(example.id)
```

Generated repositories also provide `update_<table>(data)` and `delete_<table>_by_id(id)` methods. Update uses the data object's primary key to find the row and replaces every non-primary-key field; nullable fields set to `null` clear their stored values. Both methods return `true` when at least one row was affected, and `false` when no row matched or the database operation failed.

## Agent and contributor guidance

- Update `data/schema/game/schema.json`, or the optional files under `data/schema/game/fragments/`, before regenerating persistence files.
- When fragments are used, run `python tools/merge_schema_fragments.py` before `python tools/generate_data_classes.py`.
- Prefer regenerating typed classes instead of patching generated output by hand.
- When adding or changing tables, also review matching seed JSON files for validity.
- Keep repository usage aligned with the generated API names rather than inventing bespoke SQL queries in gameplay code.
- Run the schema validation command before finalizing persistence changes.
