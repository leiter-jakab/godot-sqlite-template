extends GutTest


class PersistenceManagerStub:
	extends "res://src/persistence/persistence_manager.gd"

	var initialize_count := 0
	var initialized_schema := ""
	var initialized_database_name := ""
	var database_result: SQLite
	var seed_load_count := 0
	var seeded_database: SQLite
	var loaded_seed_name := ""
	var seed_result := true
	var handle_lookup_count := 0
	var looked_up_schema := ""
	var looked_up_database_name := ""
	var handle_result: SQLite

	func initialize_database(schema_name: String, db_name: String = "") -> SQLite:
		initialize_count += 1
		initialized_schema = schema_name
		initialized_database_name = db_name
		return database_result

	func load_seed(database: SQLite, seed_name: String) -> bool:
		seed_load_count += 1
		seeded_database = database
		loaded_seed_name = seed_name
		return seed_result

	func get_database_handle(schema_name: String, db_name: String = "") -> SQLite:
		handle_lookup_count += 1
		looked_up_schema = schema_name
		looked_up_database_name = db_name
		return handle_result


var _persistence_manager: PersistenceManagerStub
var _game_manager: GameManager
var _database: SQLite


func before_each() -> void:
	_database = SQLite.new()
	_persistence_manager = PersistenceManagerStub.new()
	_persistence_manager.database_result = _database
	_persistence_manager.handle_result = _database
	_game_manager = GameManager.new(_persistence_manager)


func test_start_new_game_normalizes_name_and_loads_seed() -> void:
	var result := _game_manager.start_new_game(" slot_1.db ")

	assert_eq(result, _database)
	assert_eq(_persistence_manager.initialized_schema, "game")
	assert_eq(_persistence_manager.initialized_database_name, "slot_1")
	assert_eq(_persistence_manager.seeded_database, _database)
	assert_eq(_persistence_manager.loaded_seed_name, "game_test")
	assert_eq(_persistence_manager.initialize_count, 1)
	assert_eq(_persistence_manager.seed_load_count, 1)


func test_start_new_game_returns_null_when_initialization_fails() -> void:
	_persistence_manager.database_result = null

	var result := _game_manager.start_new_game("slot_1")

	assert_null(result)
	assert_eq(_persistence_manager.initialize_count, 1)
	assert_eq(_persistence_manager.seed_load_count, 0)


func test_start_new_game_returns_database_when_seed_loading_fails() -> void:
	_persistence_manager.seed_result = false

	var result := _game_manager.start_new_game("slot_1")

	assert_eq(result, _database)
	assert_eq(_persistence_manager.seed_load_count, 1)


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