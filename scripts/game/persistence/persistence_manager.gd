extends RefCounted

class_name PersistenceManager

const SCHEMA_DIRECTORY := "res://data/schema/"
const SEED_DIRECTORY := "res://data/seed/"
const DATABASE_DIRECTORY := "user://"
const TEMPLATE_DATABASE_PATH := "res://data/database/game_template.db"

var _database_cache: Dictionary = {}


func initialize_database(schema_name: String, db_name: String = "") -> SQLite:
    var resolved_db_name := _normalize_database_name(db_name if not db_name.is_empty() else schema_name)
    if resolved_db_name.is_empty():
        push_error("Database name cannot be empty.")
        return null

    if _database_cache.has(resolved_db_name):
        return _database_cache[resolved_db_name]

    var db_path := _build_database_path(resolved_db_name)
    var schema_path := _build_schema_path(schema_name)
    var database := _open_database(resolved_db_name, db_path)
    if database == null:
        return null

    if not _apply_schema(database, schema_path):
        push_error("Failed to initialize schema for %s from %s." % [resolved_db_name, schema_path])
        database.close_db()
        _database_cache.erase(resolved_db_name)
        return null

    print("SQLite database initialized at %s" % ProjectSettings.globalize_path(db_path))
    return database


func create_database_from_template(db_name: String, template_path: String = TEMPLATE_DATABASE_PATH) -> SQLite:
    var resolved_db_name := _normalize_database_name(db_name)
    if resolved_db_name.is_empty():
        push_error("Database name cannot be empty.")
        return null

    var db_path := _build_database_path(resolved_db_name)
    if _database_cache.has(resolved_db_name) or FileAccess.file_exists(db_path):
        push_error("Database already exists at %s." % db_path)
        return null

    if not FileAccess.file_exists(template_path):
        push_error("Template database does not exist at %s." % template_path)
        return null
    var template_bytes := FileAccess.get_file_as_bytes(template_path)
    if template_bytes.is_empty():
        push_error("Template database is empty or could not be read at %s." % template_path)
        return null

    var temporary_path := db_path + ".tmp"
    var temporary_file := FileAccess.open(temporary_path, FileAccess.WRITE)
    if temporary_file == null:
        push_error("Unable to create database copy at %s: %s" % [temporary_path, FileAccess.get_open_error()])
        return null
    temporary_file.store_buffer(template_bytes)
    temporary_file.flush()
    var write_error := temporary_file.get_error()
    temporary_file.close()
    if write_error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
        push_error("Failed to write database copy at %s." % temporary_path)
        return null

    var rename_error := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(db_path)
    )
    if rename_error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
        push_error("Failed to move database copy into place at %s." % db_path)
        return null

    var database := _open_database(resolved_db_name, db_path)
    if database == null:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(db_path))
        return null

    print("Created SQLite database from template at %s" % ProjectSettings.globalize_path(db_path))
    return database


func delete_database(db_name: String) -> bool:
    var resolved_db_name := _normalize_database_name(db_name)
    if resolved_db_name.is_empty():
        push_error("Database name cannot be empty.")
        return false

    var cached_database: SQLite = _database_cache.get(resolved_db_name)
    if cached_database != null and not cached_database.close_db():
        push_error("Failed to close SQLite database '%s': %s" % [resolved_db_name, cached_database.error_message])
        return false
    if cached_database != null:
        _database_cache.erase(resolved_db_name)

    var db_path := _build_database_path(resolved_db_name)
    if not FileAccess.file_exists(db_path):
        return true

    var absolute_path := ProjectSettings.globalize_path(db_path)
    if DirAccess.remove_absolute(absolute_path) != OK:
        push_error("Failed to delete SQLite database at %s." % db_path)
        return false

    return true


func get_database_handle(schema_name: String, db_name: String = "") -> SQLite:
    var resolved_db_name := _normalize_database_name(db_name if not db_name.is_empty() else schema_name)
    if resolved_db_name.is_empty():
        push_error("Database name cannot be empty.")
        return null

    if _database_cache.has(resolved_db_name):
        return _database_cache[resolved_db_name]

    var db_path := _build_database_path(resolved_db_name)
    if not FileAccess.file_exists(db_path):
        push_error("Database does not exist at %s." % db_path)
        return null
    return _open_database(resolved_db_name, db_path)


func get_existing_databases() -> Array[String]:
    var database_names: Array[String] = []
    var directory := DirAccess.open(DATABASE_DIRECTORY)
    if directory == null:
        push_error("Unable to open SQLite database directory at %s." % DATABASE_DIRECTORY)
        return database_names

    var entries := directory.get_files()
    for entry in entries:
        if not entry.ends_with(".db"):
            continue
        database_names.append(entry.trim_suffix(".db"))

    return database_names


func load_seed(database: SQLite, seed_name: String) -> bool:
    if database == null:
        push_error("Database handle cannot be null.")
        return false

    var seed_directory_path := _build_seed_path(seed_name)
    var seed_paths := _get_ordered_seed_paths(seed_directory_path)
    if seed_paths.is_empty():
        push_error("No seed JSON fragments found in %s." % seed_directory_path)
        return false

    for seed_path in seed_paths:
        var file := FileAccess.open(seed_path, FileAccess.READ)
        if file == null:
            push_error("Unable to open seed file at %s: %s" % [seed_path, FileAccess.get_open_error()])
            return false
        var raw_text := file.get_as_text()
        file.close()

        var parsed = JSON.parse_string(raw_text)
        if typeof(parsed) != TYPE_DICTIONARY:
            push_error("Seed file must contain a JSON object at %s" % seed_path)
            return false

        for collection_key in parsed.keys():
            var rows: Array = parsed[collection_key]
            if typeof(rows) != TYPE_ARRAY:
                continue
            for row in rows:
                if typeof(row) != TYPE_DICTIONARY:
                    continue
                if not database.insert_row(collection_key, row):
                    push_error("Failed to insert seed row into %s: %s" % [collection_key, database.error_message])
                    return false

    print("Loaded seed data from %s" % seed_directory_path)
    return true


func _get_ordered_seed_paths(seed_directory_path: String) -> Array[String]:
    var seed_paths: Array[String] = []
    var directory := DirAccess.open(seed_directory_path)
    if directory == null:
        push_error("Unable to open seed directory at %s." % seed_directory_path)
        return seed_paths

    var prefix_regex := RegEx.new()
    prefix_regex.compile("^(\\d+)_")
    var filenames_by_number: Dictionary = {}
    for filename in directory.get_files():
        if not filename.ends_with(".json"):
            continue
        var prefix_match := prefix_regex.search(filename)
        if prefix_match == null:
            push_error("Seed fragment filename must start with a numeric prefix followed by '_': %s" % filename)
            return []
        var fragment_number := prefix_match.get_string(1).to_int()
        if filenames_by_number.has(fragment_number):
            push_error(
                "Duplicate seed fragment number %d in %s: %s and %s" % [
                    fragment_number,
                    seed_directory_path,
                    filenames_by_number[fragment_number],
                    filename,
                ]
            )
            return []
        filenames_by_number[fragment_number] = filename

    var fragment_numbers: Array[int] = []
    for fragment_number in filenames_by_number.keys():
        fragment_numbers.append(fragment_number)
    fragment_numbers.sort()
    for fragment_number in fragment_numbers:
        seed_paths.append(seed_directory_path.path_join(filenames_by_number[fragment_number]))
    return seed_paths


func _apply_schema(database: SQLite, schema_path: String) -> bool:
    var file := FileAccess.open(schema_path, FileAccess.READ)
    if file == null:
        push_error("Unable to open schema file at %s: %s" % [schema_path, FileAccess.get_open_error()])
        return false

    var raw_text := file.get_as_text()
    file.close()

    var parsed = JSON.parse_string(raw_text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Schema file must contain a JSON object at %s" % schema_path)
        return false

    var tables: Dictionary = parsed.get("tables", parsed)
    for table_name in tables.keys():
        if not database.create_table(table_name, tables[table_name]):
            push_error("Failed to create table '%s': %s" % [table_name, database.error_message])
            return false

    return true


func _open_database(db_name: String, db_path: String) -> SQLite:
    var database := SQLite.new()
    database.path = db_path
    if not database.open_db():
        push_error("Failed to open SQLite database at %s: %s" % [db_path, database.error_message])
        return null

    database.foreign_keys = true
    if not database.query("PRAGMA foreign_keys = ON;"):
        push_error("Failed to enable foreign key enforcement: %s" % database.error_message)
        database.close_db()
        return null

    _database_cache[db_name] = database
    return database


func _build_database_path(db_name: String) -> String:
    var normalized_name := _normalize_database_name(db_name)
    if normalized_name.is_empty():
        return ""
    return DATABASE_DIRECTORY + normalized_name + ".db"


func _build_schema_path(schema_name: String) -> String:
    var normalized_name := schema_name.strip_edges()
    if normalized_name.is_empty():
        return ""
    if normalized_name.ends_with(".json"):
        normalized_name = normalized_name.trim_suffix(".json")
    return SCHEMA_DIRECTORY + normalized_name + "/schema.json"


func _build_seed_path(seed_name: String) -> String:
    var normalized_name := seed_name.strip_edges()
    if normalized_name.is_empty():
        return ""
    if normalized_name.ends_with(".json"):
        normalized_name = normalized_name.trim_suffix(".json")
    return SEED_DIRECTORY + normalized_name.replace("_", "/") + "/"


func _normalize_database_name(db_name: String) -> String:
    var normalized := db_name.strip_edges()
    if normalized.is_empty():
        return ""
    if normalized.ends_with(".db"):
        normalized = normalized.trim_suffix(".db")
    return normalized
