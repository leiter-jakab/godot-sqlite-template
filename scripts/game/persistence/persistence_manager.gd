extends RefCounted

class_name PersistenceManager

const DATABASE_DIRECTORY := "user://"
const DATABASE_EXTENSION := ".db"
const TEMPLATE_DATABASE_PATH := "res://data/database/game_template.db"

const DATABASE_NAME_EMPTY_ERROR := "Database name cannot be empty."
const DATABASE_FAILED_CLOSE_ERROR := "Failed to close SQLite database '%s': %s"

var _database_cache: Dictionary = {}


func create_database_from_template(db_name: String, template_path: String = TEMPLATE_DATABASE_PATH) -> SQLite:
    var resolved_db_name := _normalize_database_name(db_name)
    if resolved_db_name.is_empty():
        push_error(DATABASE_NAME_EMPTY_ERROR)
        return null

    var db_path := _build_database_path(resolved_db_name)
    if _database_cache.has(resolved_db_name) or FileAccess.file_exists(db_path):
        push_error("Database already exists at %s." % db_path)
        return null

    var temporary_path := db_path + ".tmp"
    if not _write_template_copy(template_path, temporary_path):
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


func replace_database_from_template(db_name: String, template_path: String = TEMPLATE_DATABASE_PATH) -> SQLite:
    var resolved_db_name := _normalize_database_name(db_name)
    if resolved_db_name.is_empty():
        push_error(DATABASE_NAME_EMPTY_ERROR)
        return null

    var matching_db_names := _find_existing_database_names(resolved_db_name)
    if matching_db_names.size() > 1:
        push_error(
            "Database name '%s' is ambiguous; matches: %s."
            % [resolved_db_name, ", ".join(matching_db_names)]
        )
        return null
    if matching_db_names.is_empty():
        push_error("Database does not exist for overwrite: %s." % resolved_db_name)
        return null
    var existing_db_name := matching_db_names[0]

    var db_path := _build_database_path(existing_db_name)
    var operation_id := str(Time.get_ticks_usec())
    var temporary_path := "%s.%s.tmp" % [db_path, operation_id]
    var backup_path := "%s.%s.bak" % [db_path, operation_id]
    if not _write_template_copy(template_path, temporary_path):
        return null

    if not _validate_database_file(temporary_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
        return null

    if _database_cache.has(existing_db_name):
        var cached_database: SQLite = _database_cache[existing_db_name]
        if cached_database != null and not cached_database.close_db():
            DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
            push_error(DATABASE_FAILED_CLOSE_ERROR % [existing_db_name, cached_database.error_message])
            return null
        _database_cache.erase(existing_db_name)

    var absolute_db_path := ProjectSettings.globalize_path(db_path)
    var absolute_temporary_path := ProjectSettings.globalize_path(temporary_path)
    var absolute_backup_path := ProjectSettings.globalize_path(backup_path)
    if DirAccess.rename_absolute(absolute_db_path, absolute_backup_path) != OK:
        DirAccess.remove_absolute(absolute_temporary_path)
        push_error("Failed to stage existing database for overwrite at %s." % db_path)
        return null

    if DirAccess.rename_absolute(absolute_temporary_path, absolute_db_path) != OK:
        var restore_error := DirAccess.rename_absolute(absolute_backup_path, absolute_db_path)
        DirAccess.remove_absolute(absolute_temporary_path)
        if restore_error != OK:
            push_error("Failed to restore existing database after overwrite failed at %s." % db_path)
        else:
            push_error("Failed to install replacement database at %s." % db_path)
        return null

    var database := _open_database(existing_db_name, db_path)
    if database == null:
        DirAccess.remove_absolute(absolute_db_path)
        if DirAccess.rename_absolute(absolute_backup_path, absolute_db_path) != OK:
            push_error("Failed to restore existing database after replacement could not be opened at %s." % db_path)
        return null

    if DirAccess.remove_absolute(absolute_backup_path) != OK:
        push_error("Failed to remove overwritten database backup at %s." % backup_path)
    print("Replaced SQLite database from template at %s" % ProjectSettings.globalize_path(db_path))
    return database


func delete_database(db_name: String) -> bool:
    var resolved_db_name := _normalize_database_name(db_name)
    if resolved_db_name.is_empty():
        push_error(DATABASE_NAME_EMPTY_ERROR)
        return false

    var cached_database: SQLite = _database_cache.get(resolved_db_name)
    if cached_database != null and not cached_database.close_db():
        push_error(DATABASE_FAILED_CLOSE_ERROR % [resolved_db_name, cached_database.error_message])
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
        push_error(DATABASE_NAME_EMPTY_ERROR)
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
        if not entry.ends_with(DATABASE_EXTENSION):
            continue
        database_names.append(entry.trim_suffix(DATABASE_EXTENSION))

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


func _find_existing_database_names(db_name: String) -> Array[String]:
    var matches: Array[String] = []
    for existing_db_name in get_existing_databases():
        if existing_db_name == db_name:
            return [existing_db_name]
        if existing_db_name.to_lower() == db_name.to_lower():
            matches.append(existing_db_name)

    return matches


func _write_template_copy(template_path: String, destination_path: String) -> bool:
    if not FileAccess.file_exists(template_path):
        push_error("Template database does not exist at %s." % template_path)
        return false
    var template_bytes := FileAccess.get_file_as_bytes(template_path)
    if template_bytes.is_empty():
        push_error("Template database is empty or could not be read at %s." % template_path)
        return false

    var temporary_file := FileAccess.open(destination_path, FileAccess.WRITE)
    if temporary_file == null:
        push_error("Unable to create database copy at %s: %s" % [destination_path, FileAccess.get_open_error()])
        return false
    temporary_file.store_buffer(template_bytes)
    temporary_file.flush()
    var write_error := temporary_file.get_error()
    temporary_file.close()
    if write_error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(destination_path))
        push_error("Failed to write database copy at %s." % destination_path)
        return false
    return true


func _validate_database_file(db_path: String) -> bool:
    var database := SQLite.new()
    database.path = db_path
    if not database.open_db():
        push_error("Failed to validate SQLite database at %s: %s" % [db_path, database.error_message])
        return false

    database.foreign_keys = true
    if not database.query("PRAGMA foreign_keys = ON;"):
        push_error("Failed to validate SQLite foreign keys: %s" % database.error_message)
        database.close_db()
        return false

    if not database.close_db():
        push_error("Failed to close staged SQLite database at %s: %s" % [db_path, database.error_message])
        return false
    return true


func _build_database_path(db_name: String) -> String:
    var normalized_name := _normalize_database_name(db_name)
    if normalized_name.is_empty():
        return ""
    return DATABASE_DIRECTORY + normalized_name + DATABASE_EXTENSION


func _normalize_database_name(db_name: String) -> String:
    var normalized := db_name.strip_edges()
    if normalized.is_empty():
        return ""
    if normalized.ends_with(DATABASE_EXTENSION):
        normalized = normalized.trim_suffix(DATABASE_EXTENSION)
    return normalized
