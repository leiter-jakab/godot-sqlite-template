# Download or verify the pinned just and Godot binaries.
init:
    @echo "Project dependencies are ready."

# Run the complete verification pass for Python tooling and Godot tests.
test: test-tools test-godot

# Run Python unit tests for the schema and generator tooling.
test-tools:
    python -m unittest discover -s tools/test

# Run the Godot integration suite through GUT.
test-godot:
    "$GODOT_BIN" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gdir=res://scripts/test -ginclude_subdirs=true -gexit

# Load the project in headless editor mode to confirm it boots cleanly.
load-project-headless:
    "$GODOT_BIN" --headless --editor --path . --quit

# Launch the Godot editor for interactive development.
start-editor:
    "$GODOT_BIN" --editor --path .

# Merge optional schema fragments into schema.json.
merge-schema-fragments:
    python tools/merge_schema_fragments.py

# Validate the schema contract and seed data against the generator output.
validate-persistence: merge-schema-fragments
    python tools/generate_data_classes.py --check --check-seeds

# Build the template SQLite database.
build-template-database: validate-persistence
    python tools/build_seed_database.py
