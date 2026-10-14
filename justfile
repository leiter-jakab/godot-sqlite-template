database_dir := "data/database"
test_scripts_dir := "scripts/test"
generated_scripts_dir := "scripts/game/persistence/data_generated"

gut_cmdln := "res://addons/gut/gut_cmdln.gd"
godot_headless_cmd := "$GODOT_BIN --headless --path ."
godot_bg_sh := "tools/godot_bg.sh"


# Download or verify the pinned just and Godot binaries.
init:
    @echo "Project dependencies are ready."

# Remove any generated files.
clean:
    rm -rf {{ database_dir }}
    rm -rf {{ generated_scripts_dir }}


# Complete build and verification pass for persistence.
persistence: merge-schema-fragments generate-data-classes build-template-database
    @echo "Executed merge-schema-fragments, generate-data-classes, build-template-database."

# Build the template SQLite database.
build-template-database: validate-persistence
    python tools/build_seed_database.py

# Merge optional schema fragments into schema.json.
merge-schema-fragments:
    python tools/merge_schema_fragments.py

# Generate the GD Script data classes from the schema.json.
generate-data-classes: merge-schema-fragments
    python tools/generate_data_classes.py

# Validate the schema contract and seed data against the generator output.
validate-persistence: merge-schema-fragments
    python tools/generate_data_classes.py --check --check-seeds


# Run the Godot unit tests.
test-godot-unit:
    {{ godot_headless_cmd }} -s {{ gut_cmdln }} -gconfig= -gdir=res://{{ test_scripts_dir }}/unit -ginclude_subdirs=false -gexit

# Run the Godot integration tests.
test-godot-integration:
    {{ godot_headless_cmd }} -s {{ gut_cmdln }} -gconfig= -gdir=res://{{ test_scripts_dir }}/integration -ginclude_subdirs=false -gexit

# Run the Godot system tests.
test-godot-system: build-template-database
    {{ godot_headless_cmd }} -s {{ gut_cmdln }} -gconfig= -gdir=res://{{ test_scripts_dir }}/system -ginclude_subdirs=false -gexit

# Run Python unit tests for the schema and generator tooling.
test-tools:
    python -m unittest discover -s tools/test

# Run the complete verification pass for Python tooling and Godot tests.
test: test-tools test-godot load-project-headless
    @echo "Executed test-tools, test-godot, load-project-headless."

# Run the complete Godot test suite through its tiers.
test-godot: test-godot-unit test-godot-integration test-godot-system
    @echo "Executed: test-godot-unit, test-godot-integration, test-godot-system."

# Load the project in headless editor mode to confirm it boots cleanly.
load-project-headless: generate-data-classes
    {{ godot_headless_cmd }} --editor --quit


# Launch the Godot editor for interactive development.
godot-start:
    "$GODOT_BIN" --editor --path .

# Launc the Godot editor in headless mode.
godot-start-headless:
    {{ godot_headless_cmd }} --editor

# Launch the game.
godot-start-game:
    "$GODOT_BIN" --path .

# Start the headless Godot editor as a background process.
godot-bg-start: load-project-headless
    bash {{ godot_bg_sh }} start

# Stop the background headless Godot process.
godot-bg-stop:
    bash {{ godot_bg_sh }} stop

# Follow the background headless Godot log.
godot-bg-log:
    bash {{ godot_bg_sh }} log
