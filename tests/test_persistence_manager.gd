extends GutTest


func test_create_database_from_template_and_reopen_existing_save() -> void:
    var manager := PersistenceManager.new()
    var database_name := "gut_template_copy_test"
    var database := manager.create_database_from_template(database_name)

    assert_not_null(database)
    if database == null:
        return

    assert_true(database.query("SELECT name FROM example1 ORDER BY id;"))
    assert_eq(database.query_result.size(), 2)
    assert_true(database.query("SELECT example1 FROM example2 ORDER BY id;"))
    assert_eq(database.query_result.size(), 2)
    assert_true(database.query("PRAGMA foreign_key_list(example2);"))
    assert_eq(database.query_result.size(), 1)
    assert_true(database.query("PRAGMA foreign_keys;"))
    assert_eq(database.query_result[0]["foreign_keys"], 1)
    assert_eq(database.path, ProjectSettings.globalize_path("user://%s.db" % database_name))

    assert_true(database.close_db())
    manager._database_cache.erase(database_name)
    var reopened_database := manager.get_database_handle("game", database_name)
    assert_not_null(reopened_database)
    if reopened_database != null:
        assert_true(reopened_database.query("SELECT COUNT(*) AS row_count FROM example2;"))
        assert_eq(reopened_database.query_result[0]["row_count"], 2)
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