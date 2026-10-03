## Addons

- [godot-sqlite](https://github.com/2shady4u/godot-sqlite) is vendored in `addons/godot-sqlite/` and provides the runtime SQLite extension.
- [GUT](https://github.com/bitwes/Gut) is vendored in `addons/gut/` and provides the project's test framework; it is not used by runtime persistence code.

Both addons are included in the repository; no separate download is needed. Preserve their upstream license and notice files when updating them.

## Persistence architecture

This template uses a schema-first persistence pipeline:

1. The canonical database contract lives in `data/schema/game.json`.
2. `tools/generate_data_classes.py` validates that schema and emits typed GDScript models.
3. A generated `DataRepository` exposes table-specific queries such as `get_example_by_id()` and `get_all_examples()`.
4. `PersistenceManager` opens the SQLite database, applies the schema, and loads seed data.
5. `GameManager` exposes save-game creation and retrieval for the game runtime.

This design keeps data access predictable and avoids hand-writing repetitive database access code for every table.

## Project structure relevant to persistence

```text
.
├── data/
│   ├── schema/game.json            # Source-of-truth schema contract
│   └── seed/                      # Seed JSON loaded into new databases
├── src/
│   ├── game_manager.gd            # Save-game helper API
│   ├── persistence/
│   │   ├── persistence_manager.gd  # Database creation, schema application, seed loading
│   │   └── data_generated/        # Generated classes and repository
│   └── states/                    # State-driven gameplay flow
├── tools/
│   └── generate_data_classes.py   # Schema validator and code generator
└── project.godot
```

## Schema source of truth

`data/schema/game.json` defines every table, field, and primary-key metadata. Each field has a `data_type` and may flag `primary_key`, `not_null`, and foreign-key metadata. The generator enforces a simple schema contract so the repo stays consistent.

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

After changing the schema, regenerate the typed files and repository with:

```sh
python tools/generate_data_classes.py
```

Check generated classes and seed files against the schema with:

```sh
python tools/generate_data_classes.py --check --check-seeds
```

Generated output is written to `src/persistence/data_generated/`; the directory is created automatically if it is missing. Do not edit generated files directly.

## Seed data

Seed files live under `data/seed/` and are loaded by `PersistenceManager` when a new database is initialized. They must match the shape defined by the schema. If you change table names or fields, update the corresponding seed JSON and validate it with the generator check.

## Repository usage

`DataRepository` takes the `SQLite` handle returned by `GameManager` and provides typed lookups for each table. Example:

```gdscript
var database := game_manager.start_new_game("save_01")
var repository := DataRepository.new(database)
var example := repository.get_example_by_id("example_01")
var examples := repository.get_all_examples()
```

## Agent and contributor guidance

- Update `data/schema/game.json` before touching generated persistence files.
- Prefer regenerating typed classes instead of patching generated output by hand.
- When adding or changing tables, also review matching seed JSON files for validity.
- Keep repository usage aligned with the generated API names rather than inventing bespoke SQL queries in gameplay code.
- Run the schema validation command before finalizing persistence changes.
