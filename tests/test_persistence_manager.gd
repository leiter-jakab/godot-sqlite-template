extends GutTest


func test_initialize_database_loads_schema_from_named_directory() -> void:
    var manager := PersistenceManager.new()
    var database_name := "gut_schema_directory_test"
    var database := manager.initialize_database("game", database_name)

    assert_not_null(database)
    if database == null:
        return

    assert_true(database.query("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'example1';"))
    assert_eq(database.query_result.size(), 1)
    assert_true(manager.delete_database(database_name))


func test_delete_database_closes_cached_handle_before_removing_file() -> void:
    var database_name := "gut_cached_delete_test"
    var database_path := "user://%s.db" % database_name
    var database := SQLite.new()
    database.path = database_path
    assert_true(database.open_db())

    var manager := PersistenceManager.new()
    manager._database_cache[database_name] = database

    assert_true(manager.delete_database(database_name))
    assert_false(FileAccess.file_exists(database_path))
    assert_false(manager._database_cache.has(database_name))