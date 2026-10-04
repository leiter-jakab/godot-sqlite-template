extends RefCounted

class_name DataRepository

var _database: SQLite


func _init(database: SQLite) -> void:
    if database == null:
        push_error("Database handle cannot be null.")
        return
    _database = database


func get_example1_by_id(id: String) -> Example1Data:
    if _database == null:
        push_error("Cannot query without a database handle.")
        return null
    var query := "SELECT * FROM example1 WHERE id = ?;"
    if not _database.query_with_bindings(query, [id]):
        push_error("Failed to retrieve example1 row: %s" % _database.error_message)
        return null
    var rows: Array = _database.query_result
    if rows.is_empty():
        return null
    return Example1Data.from_row(rows[0])


func get_all_example1s() -> Array[Example1Data]:
    var items: Array[Example1Data] = []
    if _database == null:
        push_error("Cannot query without a database handle.")
        return items
    var query := "SELECT * FROM example1;"
    if not _database.query(query):
        push_error("Failed to retrieve example1 rows: %s" % _database.error_message)
        return items
    for row in _database.query_result:
        items.append(Example1Data.from_row(row))
    return items


func get_example2_by_id(id: int) -> Example2Data:
    if _database == null:
        push_error("Cannot query without a database handle.")
        return null
    var query := "SELECT * FROM example2 WHERE id = ?;"
    if not _database.query_with_bindings(query, [id]):
        push_error("Failed to retrieve example2 row: %s" % _database.error_message)
        return null
    var rows: Array = _database.query_result
    if rows.is_empty():
        return null
    return Example2Data.from_row(rows[0])


func get_all_example2s() -> Array[Example2Data]:
    var items: Array[Example2Data] = []
    if _database == null:
        push_error("Cannot query without a database handle.")
        return items
    var query := "SELECT * FROM example2;"
    if not _database.query(query):
        push_error("Failed to retrieve example2 rows: %s" % _database.error_message)
        return items
    for row in _database.query_result:
        items.append(Example2Data.from_row(row))
    return items
