test:
    python -m unittest discover -s tools/test

merge-schema:
    python tools/merge_schema_fragments.py

build-template-db: check-schema
    python tools/build_seed_database.py

check-schema: merge-schema
    python tools/generate_data_classes.py --check --check-seeds
