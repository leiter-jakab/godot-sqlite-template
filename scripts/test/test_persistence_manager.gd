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


func test_load_seed_loads_numbered_fragments_in_order() -> void:
    var manager := PersistenceManager.new()
    var database_name := "gut_seed_fragments_test"
    var database := manager.initialize_database("game", database_name)

    assert_not_null(database)
    if database == null:
        return

    assert_eq(manager._build_seed_path("game_test"), "res://data/seed/game/test/")
    assert_true(manager.load_seed(database, "game_test"))
    assert_true(database.query("SELECT example2.id FROM example2 INNER JOIN example1 ON example1.id = example2.example1;"))
    assert_eq(database.query_result.size(), 2)
    assert_true(manager.delete_database(database_name))


func test_seed_fragment_paths_use_numeric_prefix_order() -> void:
    var directory_path := "user://gut_seed_numeric_order_test"
    var absolute_directory_path := ProjectSettings.globalize_path(directory_path)
    assert_eq(DirAccess.make_dir_recursive_absolute(absolute_directory_path), OK)

    for filename in ["10_last.json", "02_middle.json", "001_first.json"]:
        var file := FileAccess.open(directory_path.path_join(filename), FileAccess.WRITE)
        assert_not_null(file)
        if file != null:
            file.close()

    var manager := PersistenceManager.new()
    var paths := manager._get_ordered_seed_paths(directory_path)
    var ordered_filenames: Array[String] = []
    for path in paths:
        ordered_filenames.append(path.get_file())
    assert_eq(ordered_filenames, ["001_first.json", "02_middle.json", "10_last.json"])

    var directory := DirAccess.open(directory_path)
    if directory != null:
        for filename in directory.get_files():
            directory.remove(filename)
    assert_eq(DirAccess.remove_absolute(absolute_directory_path), OK)


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


func test_data_repository_updates_and_deletes_rows_by_id() -> void:
    var manager := PersistenceManager.new()
    var database_name := "gut_repository_crud_test"
    manager.delete_database(database_name)
    var database := manager.initialize_database("game", database_name)

    assert_not_null(database)
    if database == null:
        return

    assert_true(database.insert_row("example1", {"id": "crud_parent", "name": "Before", "date": 123}))
    assert_true(database.insert_row("example2", {"id": 73, "example1": "crud_parent", "value": 4.5}))

    var repository := DataRepository.new(database)
    var parent := repository.get_example1_by_id("crud_parent")
    assert_not_null(parent)
    if parent != null:
        parent.name = "After"
        parent.date = null
        assert_true(repository.update_example1(parent))
        var updated_parent := repository.get_example1_by_id("crud_parent")
        assert_eq(updated_parent.name, "After")
        assert_null(updated_parent.date)

    var child := repository.get_example2_by_id(73)
    assert_not_null(child)
    if child != null:
        child.value = null
        assert_true(repository.update_example2(child))
        var updated_child := repository.get_example2_by_id(73)
        assert_null(updated_child.value)
        assert_true(repository.delete_example2_by_id(73))
        assert_false(repository.delete_example2_by_id(73))

    assert_true(repository.delete_example1_by_id("crud_parent"))
    assert_false(repository.delete_example1_by_id("crud_parent"))
    var missing_parent := Example1Data.new()
    missing_parent.id = "missing_parent"
    assert_false(repository.update_example1(missing_parent))
    assert_true(manager.delete_database(database_name))
