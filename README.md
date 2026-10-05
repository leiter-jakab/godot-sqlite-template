# Godot SQLite Template

This repository is a Godot 4 starter template for games that need SQLite-backed persistence without scattering database logic through gameplay code. The project keeps the app flow, UI, and persistence responsibilities separated so it is easy to extend with a schema-first data model.

## Dependencies

The required Godot addons are included under `addons/`, so a fresh clone does not need a separate addon download:

- [godot-sqlite](https://github.com/2shady4u/godot-sqlite) provides the SQLite extension used by the runtime.
- [GUT](https://github.com/bitwes/Gut) provides the test framework and is enabled in `project.godot`.

Keep the upstream license and notice files when updating either addon.

## Project structure

```text
.
├── addons/
│   ├── godot-sqlite/         # SQLite Godot extension and runtime support
│   └── gut/                  # GUT test framework
├── data/
│   ├── schema/                # Canonical database schema files
│   └── seed/                  # Numbered JSON fragments grouped by seed identifier
├── doc/                       # Project documentation
├── scenes/                     # Godot scenes and UI layouts
├── scripts/
│   ├── game/
│   │   ├── main.gd            # App bootstrap and state orchestration
│   │   ├── game_manager.gd    # Save-game helpers and database entry points
│   │   ├── actors/            # Actor logic
│   │   ├── items/             # Item logic
│   │   ├── levels/            # Level/gameplay logic
│   │   ├── persistence/       # SQLite manager and generated persistence layer
│   │   ├── states/            # Gameplay lifecycle state machine
│   │   └── ui/                # UI scripts and screens
│   └── test/                  # GUT tests for game scripts
├── tools/
│   ├── test/                      # Python tests for the tool scripts
│   ├── generate_data_classes.py # Schema-to-GDScript generator
│   └── merge_schema_fragments.py # Optional schema fragment merger
├── project.godot              # Godot project configuration
├── README.md
├── .github/
│   └── copilot-instructions.md
└── doc/
```

## How the project is organized

- `data/schema/<name>/schema.json` is the database design consumed by runtime; optional fragments can be merged into it.
- `tools/generate_data_classes.py` converts that schema into typed persistence classes and repository helpers.
- `scripts/test/` contains GUT tests for game code, while `tools/test/` contains Python tests for the tooling.
- `scripts/game/persistence/` contains the runtime SQLite manager and generated data access layer.
- `scripts/game/states/` contains the game flow states such as menu, gameplay, and paused gameplay.
- `scenes/` contains the Godot scene files that define UI and gameplay layout.
- `scripts/game/main.gd` wires the application together and swaps states via the main state machine.

## Runtime flow

The template follows a simple high-level flow:

1. `Main` boots the app and creates the game manager and persistence layer.
2. The app loads UI scenes and enters the initial state.
3. `GameManager` and `PersistenceManager` create or open SQLite databases.
4. State scripts control transitions between menu, gameplay, and pause flows.
5. Generated data classes and repository functions provide typed access to save data.

## Conventions

- Keep persistence changes schema-driven rather than hand-writing ad hoc SQL in gameplay code.
- Treat generated files under `scripts/game/persistence/data_generated/` as build artifacts.
- Prefer small, explicit state and script responsibilities over mixing UI, logic, and database code.
- Use the existing game-state pattern instead of introducing a different flow model.

For the schema contract, generator workflow, repository usage, and validation commands, see [doc/persistence.md](doc/persistence.md).
