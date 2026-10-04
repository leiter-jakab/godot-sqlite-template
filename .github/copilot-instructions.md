# Copilot instructions for this repository

## Project purpose

This repository is a Godot 4 template for building games that need SQLite-backed persistence. It is intentionally structured around a schema-driven workflow rather than ad hoc SQL scattered through gameplay code.

The important pieces are:

- `scripts/game/main.gd` is the app entry point and orchestrates the state machine.
- `scripts/game/states/` contains the gameplay lifecycle states.
- `scripts/game/persistence/persistence_manager.gd` manages SQLite database creation, schema application, and seed loading.
- `scripts/game/game_manager.gd` exposes save-game creation and retrieval helpers.
- `data/schema/<name>/schema.json` is the canonical persistence contract; optional fragments live under that schema directory.
- `tools/generate_data_classes.py` creates typed persistence classes and the repository layer.

## Working rules

- Treat `addons/godot-sqlite/` and `addons/gut/` as vendored third-party dependencies; do not ask contributors to fetch them separately while they remain in the repository.
- When updating a vendored addon, preserve its upstream license and notice files and record the upstream source/version or commit in the change description.
- Treat `data/schema/<name>/schema.json` as the schema contract consumed by runtime and code generation.
- Optional fragments live in `data/schema/<name>/fragments/`; when present, merge them into `schema.json` with `python tools/merge_schema_fragments.py` before generating persistence code.
- Without fragments, edit `schema.json` directly. With fragments, treat `schema.json` as generated output.
- After changing the schema, regenerate persistence code with `python tools/generate_data_classes.py`.
- Use the generator validation command before finishing work: `python tools/generate_data_classes.py --check --check-seeds`.
- Do not hand-edit files under `scripts/game/persistence/data_generated/`; they are generated artifacts.
- Keep gameplay code using the generated repository API rather than writing custom database logic in state or UI scripts.
- Follow the existing Godot state pattern instead of creating a different flow control model.

## Project conventions

- Follow the applicable `.editorconfig` settings for all code you create, modify, or generate.
- Prefer small, explicit Godot scripts with typed properties and clear naming.
- Preserve the current folder structure: scenes in `scenes/`, game logic and tests in `scripts/game/` and `scripts/test/`, data contracts in `data/`, and generator tools and their tests in `tools/` and `tools/test/`.
- When adding a new runtime feature, keep the UI, state changes, and persistence responsibilities separated.
- Seed files in `data/seed/` should stay valid for the schema and should reflect realistic default data for new games.

## Verification before completion

- On Windows, locate and invoke `Godot_v4.7.2-stable_win64_console.exe` for Godot engine commands instead of assuming `godot` is on `PATH`.

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
2. Update `data/schema/game/schema.json`, or its fragments if using fragment mode, when the data model changes.
3. If schema fragments are used, merge them with `python tools/merge_schema_fragments.py`.
4. Regenerate the typed data classes.
5. Update seed data if required.
6. Wire the repository into the gameplay logic.
7. Run the project-specific validation command.
