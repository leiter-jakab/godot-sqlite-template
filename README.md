# Godot SQLite Template

This repository is a Godot 4 starter template for games that need SQLite-backed persistence without scattering database logic through gameplay code. The project keeps the app flow, UI, and persistence responsibilities separated so it is easy to extend with a schema-first data model.

## Dependency

This template requires the [godot-sqlite addon](https://github.com/2shady4u/godot-sqlite). Make sure it is installed at `res://addons/godot-sqlite/`; the project enables its plugin through `project.godot`.

## Project structure

```text
.
├── addons/
│   └── godot-sqlite/         # SQLite Godot extension and runtime support
├── data/
│   ├── schema/                # Canonical database schema files
│   └── seed/                  # Default or test JSON seed data
├── doc/                       # Project documentation
├── scenes/                     # Godot scenes and UI layouts
├── src/
│   ├── main.gd                # App bootstrap and state orchestration
│   ├── game_manager.gd       # Save-game helpers and database entry points
│   ├── actors/                # Actor logic
│   ├── items/                 # Item logic
│   ├── levels/                # Level/gameplay logic
│   ├── persistence/           # SQLite manager and generated persistence layer
│   ├── states/                # Gameplay lifecycle state machine
│   └── ui/                    # UI scripts and screens
├── tools/
│   └── generate_data_classes.py # Schema-to-GDScript generator
├── project.godot              # Godot project configuration
├── README.md
├── .github/
│   └── copilot-instructions.md
└── doc/
```

## How the project is organized

- `data/schema/` is the source of truth for the database design.
- `tools/generate_data_classes.py` converts that schema into typed persistence classes and repository helpers.
- `src/persistence/` contains the runtime SQLite manager and generated data access layer.
- `src/states/` contains the game flow states such as menu, gameplay, and paused gameplay.
- `scenes/` contains the Godot scene files that define UI and gameplay layout.
- `src/main.gd` wires the application together and swaps states via the main state machine.

## Runtime flow

The template follows a simple high-level flow:

1. `Main` boots the app and creates the game manager and persistence layer.
2. The app loads UI scenes and enters the initial state.
3. `GameManager` and `PersistenceManager` create or open SQLite databases.
4. State scripts control transitions between menu, gameplay, and pause flows.
5. Generated data classes and repository functions provide typed access to save data.

## Conventions

- Keep persistence changes schema-driven rather than hand-writing ad hoc SQL in gameplay code.
- Treat generated files under `src/persistence/data_generated/` as build artifacts.
- Prefer small, explicit state and script responsibilities over mixing UI, logic, and database code.
- Use the existing game-state pattern instead of introducing a different flow model.

For the schema contract, generator workflow, repository usage, and validation commands, see [doc/persistence.md](doc/persistence.md).
