extends RefCounted

class_name PersistenceManager

const DATABASE_DIRECTORY := "user://"
const TEMPLATE_DATABASE_PATH := "res://data/database/game_template.db"

var _database_cache: Dictionary = {}


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


func get_database_handle(db_name: String) -> SQLite:
    var resolved_db_name := _normalize_database_name(db_name)
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


func _normalize_database_name(db_name: String) -> String:
    var normalized := db_name.strip_edges()
    if normalized.is_empty():
        return ""
    if normalized.ends_with(".db"):
        normalized = normalized.trim_suffix(".db")
    return normalized
