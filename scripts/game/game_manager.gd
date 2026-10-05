extends RefCounted

class_name GameManager

const GAME_SCHEMA_NAME := "game"

var _persistence_manager: PersistenceManager


func start_new_game(game_name: String = "game") -> SQLite:
    var db_name := _normalize_game_name(game_name)
    if db_name.is_empty():
        push_error("Game name cannot be empty.")
        return null

    return _persistence_manager.create_database_from_template(db_name)


func load_existing_game(game_name: String) -> SQLite:
    var db_name := _normalize_game_name(game_name)
    if db_name.is_empty():
        push_error("Game name cannot be empty.")
        return null

    return _persistence_manager.get_database_handle(GAME_SCHEMA_NAME, db_name)


func delete_game(game_name: String) -> bool:
    var db_name := _normalize_game_name(game_name)
    if db_name.is_empty():
        push_error("Game name cannot be empty.")
        return false

    return _persistence_manager.delete_database(db_name)


func get_existing_game_names() -> Array[String]:
    var game_names: Array[String] = []
    for database_name in _persistence_manager.get_existing_databases():
        if not database_name.is_empty():
            game_names.append(database_name)
    return game_names


func _init(manager: PersistenceManager) -> void:
    if manager == null:
        push_error("PersistenceManager instance cannot be null.")
        return
    _persistence_manager = manager


func _normalize_game_name(game_name: String) -> String:
    var normalized := game_name.strip_edges()
    if normalized.is_empty():
        return ""
    if normalized.ends_with(".db"):
        normalized = normalized.trim_suffix(".db")
    return normalized
