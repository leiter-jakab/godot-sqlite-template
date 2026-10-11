# Download or verify the pinned just and Godot binaries.
init:
    @echo "Project dependencies are ready."

# Run the complete verification pass for Python tooling and Godot tests.
test: test-tools test-godot load-project-headless

# Run Python unit tests for the schema and generator tooling.
test-tools:
    python -m unittest discover -s tools/test

# Run the complete Godot test suite through its tiers.
test-godot: test-godot-unit test-godot-integration test-godot-system

# Generate the GD Script data classes from the schema.json.
generate-data-classes: validate-persistence
    python tools/generate_data_classes.py

# Run the Godot unit tests.
test-godot-unit:
    "$GODOT_BIN" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gdir=res://scripts/test/unit -ginclude_subdirs=false -gexit

# Run the Godot integration tests.
test-godot-integration:
    "$GODOT_BIN" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gdir=res://scripts/test/integration -ginclude_subdirs=false -gexit

# Run the Godot system tests.
test-godot-system: build-template-database
    "$GODOT_BIN" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gdir=res://scripts/test/system -ginclude_subdirs=false -gexit

# Load the project in headless editor mode to confirm it boots cleanly.
load-project-headless: generate-data-classes
    "$GODOT_BIN" --headless --editor --path . --quit

# Launch the Godot editor for interactive development.
start-editor: load-project-headless
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

# Remove any genarated files.
clean:
    rm data/database/*.db
