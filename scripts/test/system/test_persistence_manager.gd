extends GutTest


func test_create_database_from_template_requires_existing_template() -> void:
    var manager := PersistenceManager.new()
    var database_name := "gut_missing_template_test"
    var missing_template_path := "res://data/database/missing_template_for_test.db"
    assert_null(manager.create_database_from_template(database_name, missing_template_path))
    assert_push_error("Template database does not exist at %s." % missing_template_path)
    assert_false(FileAccess.file_exists(ProjectSettings.globalize_path("user://%s.db" % database_name)))


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
    var repository := DataRepository.new(database)
    var summaries: Array[Example2SummaryData] = repository.get_all_example2_summary()
    assert_eq(summaries.size(), 2)
    var summary := repository.get_example2_summary_by_id(1)
    assert_not_null(summary)
    if summary != null:
        assert_eq(summary.example1_name, "Alpha")
    assert_true(database.query("PRAGMA foreign_key_list(example2);"))
    assert_eq(database.query_result.size(), 1)
    assert_true(database.query("PRAGMA foreign_keys;"))
    assert_eq(database.query_result[0]["foreign_keys"], 1)
    assert_eq(database.path, ProjectSettings.globalize_path("user://%s.db" % database_name))

    assert_true(database.close_db())
    manager._database_cache.erase(database_name)
    var reopened_database := manager.get_database_handle(database_name)
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


func test_replace_database_from_template_resets_save_and_matches_case_insensitively() -> void:
    var manager := PersistenceManager.new()
    var database_name := "gut_overwrite_case_test"
    var database := manager.create_database_from_template(database_name)

    assert_not_null(database)
    if database == null:
        return

    var repository := DataRepository.new(database)
    var stale_record := Example1Data.new()
    stale_record.name = "Stale data"
    stale_record.date = 123
    assert_true(repository.insert_example1(stale_record))

    var replacement := manager.replace_database_from_template("GUT_OVERWRITE_CASE_TEST.db")

    assert_not_null(replacement)
    if replacement == null:
        return
    assert_true(database != replacement)
    assert_eq(replacement.path, ProjectSettings.globalize_path("user://%s.db" % database_name))
    assert_eq(manager._database_cache[database_name], replacement)
    assert_true(replacement.query("SELECT name FROM example1 ORDER BY id;"))
    assert_eq(replacement.query_result.size(), 2)
    assert_true(replacement.query("SELECT id FROM example1 WHERE name = 'Stale data';"))
    assert_eq(replacement.query_result.size(), 0)
    assert_true(manager.delete_database(database_name))


func _create_case_variant_pair(manager: PersistenceManager, upper: String, lower: String) -> Array:
    manager.delete_database(upper)
    manager.delete_database(lower)
    var upper_db := manager.create_database_from_template(upper)
    var lower_db := manager.create_database_from_template(lower)
    if upper_db == null or lower_db == null:
        return []
    return [upper_db, lower_db]


func test_replace_database_from_template_prefers_exact_case_and_evicts_only_that_entry() -> void:
    var manager := PersistenceManager.new()
    var pair := _create_case_variant_pair(manager, "Gut_Case_Pair", "gut_case_pair")
    if pair.is_empty():
        # Case-insensitive filesystem: the second create is rejected.
        assert_push_error("Database already exists")
        manager.delete_database("Gut_Case_Pair")
        pending("Filesystem is case-insensitive")
        return

    var replacement := manager.replace_database_from_template("gut_case_pair")

    assert_not_null(replacement)
    assert_eq(manager._database_cache["gut_case_pair"], replacement)
    assert_eq(manager._database_cache["Gut_Case_Pair"], pair[0])
    assert_true(pair[0].query("SELECT COUNT(*) AS row_count FROM example1;"))
    manager.delete_database("Gut_Case_Pair")
    manager.delete_database("gut_case_pair")


func test_replace_database_from_template_rejects_ambiguous_case_only_match() -> void:
    var manager := PersistenceManager.new()
    var pair := _create_case_variant_pair(manager, "Gut_Case_Amb", "gut_case_amb")
    if pair.is_empty():
        assert_push_error("Database already exists")
        manager.delete_database("Gut_Case_Amb")
        pending("Filesystem is case-insensitive")
        return

    assert_null(manager.replace_database_from_template("GUT_CASE_AMB"))
    assert_push_error("is ambiguous")
    assert_eq(manager._database_cache["Gut_Case_Amb"], pair[0])
    assert_eq(manager._database_cache["gut_case_amb"], pair[1])
    manager.delete_database("Gut_Case_Amb")
    manager.delete_database("gut_case_amb")


func test_replace_database_from_template_preserves_save_when_template_is_missing() -> void:
    var manager := PersistenceManager.new()
    var database_name := "gut_overwrite_failure_test"
    var database := manager.create_database_from_template(database_name)

    assert_not_null(database)
    if database == null:
        return

    var missing_template_path := "res://data/database/missing_overwrite_template_for_test.db"
    assert_null(manager.replace_database_from_template(database_name, missing_template_path))
    assert_push_error("Template database does not exist at %s." % missing_template_path)
    assert_eq(manager.get_database_handle(database_name), database)
    assert_true(database.query("SELECT COUNT(*) AS row_count FROM example1;"))
    assert_eq(database.query_result[0]["row_count"], 2)
    assert_true(manager.delete_database(database_name))


func test_data_repository_inserts_and_manages_generated_ids() -> void:
    var manager := PersistenceManager.new()
    var database_name := "gut_repository_crud_test"
    manager.delete_database(database_name)
    var database := manager.create_database_from_template(database_name)

    assert_not_null(database)
    if database == null:
        return

    var repository := DataRepository.new(database)
    var parent := Example1Data.new()
    parent.name = "Before"
    parent.date = 123
    assert_true(repository.insert_example1(parent))
    assert_true(parent.id > 0)

    var inserted_parent := repository.get_example1_by_id(parent.id)
    assert_not_null(inserted_parent)
    if inserted_parent == null:
        return
    assert_eq(inserted_parent.name, "Before")
    assert_eq(inserted_parent.date, 123)

    parent.name = "Must not replace existing row"
    assert_false(repository.insert_example1(parent))
    assert_push_error("Cannot insert example1 with an assigned ID")
    var unchanged_parent := repository.get_example1_by_id(parent.id)
    assert_eq(unchanged_parent.name, "Before")

    parent.name = "After"
    parent.date = null
    assert_true(repository.update_example1(parent))
    var updated_parent := repository.get_example1_by_id(parent.id)
    assert_eq(updated_parent.name, "After")
    assert_null(updated_parent.date)

    var parent_copy := Example1Data.new()
    parent_copy.name = parent.name
    parent_copy.date = parent.date
    assert_true(repository.insert_example1(parent_copy))
    assert_true(parent_copy.id > 0)
    assert_true(parent_copy.id != parent.id)

    var child := Example2Data.new()
    child.example1 = parent.id
    child.value = 4.5
    assert_true(repository.insert_example2(child))
    assert_true(child.id > 0)

    var inserted_child := repository.get_example2_by_id(child.id)
    assert_not_null(inserted_child)
    if inserted_child == null:
        return
    assert_eq(inserted_child.example1, parent.id)
    assert_eq(inserted_child.value, 4.5)

    inserted_child.value = null
    assert_true(repository.update_example2(inserted_child))
    var updated_child := repository.get_example2_by_id(child.id)
    assert_null(updated_child.value)
    assert_true(repository.delete_example2_by_id(child.id))
    assert_false(repository.delete_example2_by_id(child.id))

    assert_true(repository.delete_example1_by_id(parent_copy.id))
    assert_true(repository.delete_example1_by_id(parent.id))
    assert_false(repository.delete_example1_by_id(parent.id))

    var missing_parent := Example1Data.new()
    missing_parent.id = 999
    assert_false(repository.update_example1(missing_parent))
    assert_true(manager.delete_database(database_name))