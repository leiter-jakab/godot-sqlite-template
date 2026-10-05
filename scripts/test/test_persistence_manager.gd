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