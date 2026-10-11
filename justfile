test: test-tools test-gut

test-tools:
    python -m unittest discover -s tools/test

test-gut:
    "$GODOT_BIN" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gdir=res://scripts/test -ginclude_subdirs=true -gexit

merge-schema:
    python tools/merge_schema_fragments.py

build-template-db: check-schema
    python tools/build_seed_database.py

check-schema: merge-schema
    python tools/generate_data_classes.py --check --check-seeds
