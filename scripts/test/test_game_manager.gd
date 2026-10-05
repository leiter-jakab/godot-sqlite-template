extends GutTest


class PersistenceManagerStub:
    extends "res://scripts/game/persistence/persistence_manager.gd"

    var template_copy_count := 0
    var copied_database_name := ""
    var copied_template_path := ""
    var database_result: SQLite
    var handle_lookup_count := 0
    var looked_up_schema := ""
    var looked_up_database_name := ""
    var handle_result: SQLite
    var delete_count := 0
    var deleted_database_name := ""
    var delete_result := false

    func create_database_from_template(db_name: String, template_path: String = TEMPLATE_DATABASE_PATH) -> SQLite:
        template_copy_count += 1
        copied_database_name = db_name
        copied_template_path = template_path
        return database_result

    func get_database_handle(schema_name: String, db_name: String = "") -> SQLite:
        handle_lookup_count += 1
        looked_up_schema = schema_name
        looked_up_database_name = db_name
        return handle_result

    func delete_database(db_name: String) -> bool:
        delete_count += 1
        deleted_database_name = db_name
        return delete_result


var _persistence_manager: PersistenceManagerStub
var _game_manager: GameManager
var _database: SQLite


func before_each() -> void:
    _database = SQLite.new()
    _persistence_manager = PersistenceManagerStub.new()
    _persistence_manager.database_result = _database
    _persistence_manager.handle_result = _database
    _game_manager = GameManager.new(_persistence_manager)


func test_start_new_game_normalizes_name_and_copies_template() -> void:
    var result := _game_manager.start_new_game(" slot_1.db ")

    assert_eq(result, _database)
    assert_eq(_persistence_manager.copied_database_name, "slot_1")
    assert_eq(_persistence_manager.copied_template_path, PersistenceManager.TEMPLATE_DATABASE_PATH)
    assert_eq(_persistence_manager.template_copy_count, 1)


func test_start_new_game_returns_null_when_template_copy_fails() -> void:
    _persistence_manager.database_result = null

    var result := _game_manager.start_new_game("slot_1")

    assert_null(result)
    assert_eq(_persistence_manager.template_copy_count, 1)


func test_load_existing_game_normalizes_name() -> void:
    var result := _game_manager.load_existing_game(" slot_1.db ")

    assert_eq(result, _database)
    assert_eq(_persistence_manager.looked_up_schema, "game")
    assert_eq(_persistence_manager.looked_up_database_name, "slot_1")
    assert_eq(_persistence_manager.handle_lookup_count, 1)


func test_load_existing_game_rejects_blank_name() -> void:
    var result := _game_manager.load_existing_game("  ")
    var test_errors = gut.error_tracker.get_current_test_errors()
    if not test_errors.is_empty():
        test_errors.back().handled = true

    assert_null(result)
    assert_eq(_persistence_manager.handle_lookup_count, 0)


func test_delete_game_normalizes_name_and_returns_persistence_result() -> void:
    _persistence_manager.delete_result = true

    var result: bool = _game_manager.delete_game(" slot_1.db ")

    assert_true(result)
    assert_eq(_persistence_manager.deleted_database_name, "slot_1")
    assert_eq(_persistence_manager.delete_count, 1)


func test_delete_game_rejects_blank_name() -> void:
    var result: bool = _game_manager.delete_game("  ")
    var test_errors = gut.error_tracker.get_current_test_errors()
    if not test_errors.is_empty():
        test_errors.back().handled = true

    assert_false(result)
    assert_eq(_persistence_manager.delete_count, 0)