# Copilot instructions for this repository

## Project purpose

This repository is a Godot 4 template for building games that need SQLite-backed persistence. It is intentionally structured around a schema-driven workflow rather than ad hoc SQL scattered through gameplay code.

The important pieces are:

- `src/main.gd` is the app entry point and orchestrates the state machine.
- `src/states/` contains the gameplay lifecycle states.
- `src/persistence/persistence_manager.gd` manages SQLite database creation, schema application, and seed loading.
- `src/game_manager.gd` exposes save-game creation and retrieval helpers.
- `data/schema/game.json` is the canonical persistence contract.
- `tools/generate_data_classes.py` creates typed persistence classes and the repository layer.

## Working rules

- Treat `data/schema/game.json` as the source of truth for database structure.
- After changing the schema, regenerate persistence code with `python tools/generate_data_classes.py`.
- Use the generator validation command before finishing work: `python tools/generate_data_classes.py --check --check-seeds`.
- Do not hand-edit files under `src/persistence/data_generated/`; they are generated artifacts.
- Keep gameplay code using the generated repository API rather than writing custom database logic in state or UI scripts.
- Follow the existing Godot state pattern instead of creating a different flow control model.

## Project conventions

- Prefer small, explicit Godot scripts with typed properties and clear naming.
- Preserve the current folder structure: scenes in `scenes/`, runtime logic in `src/`, data contracts in `data/`, and generator tools in `tools/`.
- When adding a new runtime feature, keep the UI, state changes, and persistence responsibilities separated.
- Seed files in `data/seed/` should stay valid for the schema and should reflect realistic default data for new games.

## Verification before completion

For persistence-related changes, validate the schema and seed data with:

```sh
python tools/generate_data_classes.py --check --check-seeds
```

If a change affects gameplay flow, confirm the state transitions still make sense in the existing `MainMenuState` / `GameplayState` / `GameplayPausedState` model.

## Do not do

- Do not patch generated persistence files by hand.
- Do not bypass the schema-driven workflow for database changes.
- Do not add broad, unrelated refactors while fixing a specific persistence or gameplay issue.
- Do not drift away from the repository’s simple state-machine architecture.

## Helpful default approach

When implementing a new feature:

1. Check the schema and persistence contract before writing the runtime code.
2. Update `data/schema/game.json` if the data model changes.
3. Regenerate the typed data classes.
4. Update seed data if required.
5. Wire the repository into the gameplay logic.
6. Run the project-specific validation command.
