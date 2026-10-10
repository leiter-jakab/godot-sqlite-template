extends RefCounted

class_name DataRepository

var _database: SQLite


func _init(database: SQLite) -> void:
    if database == null:
        push_error("Database handle cannot be null.")
        return
    _database = database


func _execute_write(query: String, bindings: Array) -> bool:
    if _database == null:
        push_error("Cannot query without a database handle.")
        return false
    if not _database.query_with_bindings(query, bindings):
        push_error("Failed to execute database write: %s" % _database.error_message)
        return false
    if not _database.query("SELECT changes() AS affected_rows;"):
        push_error("Failed to check affected database rows: %s" % _database.error_message)
        return false
    var rows: Array = _database.query_result
    return not rows.is_empty() and int(rows[0].get("affected_rows", 0)) > 0


func _execute_insert(query: String, bindings: Array) -> int:
    if _database == null:
        push_error("Cannot query without a database handle.")
        return 0
    if not _database.query_with_bindings(query, bindings):
        push_error("Failed to execute database insert: %s" % _database.error_message)
        return 0
    if not _database.query("SELECT last_insert_rowid() AS inserted_id;"):
        push_error("Failed to retrieve inserted database ID: %s" % _database.error_message)
        return 0
    var rows: Array = _database.query_result
    if rows.is_empty():
        push_error("Failed to retrieve inserted database ID.")
        return 0
    return int(rows[0].get("inserted_id", 0))


func get_example1_by_id(id: int) -> Example1Data:
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


func get_all_example1() -> Array[Example1Data]:
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


func insert_example1(data: Example1Data) -> bool:
    if data.id != 0:
        push_error("Cannot insert example1 with an assigned ID; reset it to 0 first.")
        return false
    var query := "INSERT INTO example1 (name, date) VALUES (?, ?);"
    var inserted_id := _execute_insert(query, [data.name, data.date])
    if inserted_id <= 0:
        return false
    data.id = inserted_id
    return true


func update_example1(data: Example1Data) -> bool:
    var query := "UPDATE example1 SET name = ?, date = ? WHERE id = ?;"
    return _execute_write(query, [data.name, data.date, data.id])


func delete_example1_by_id(id: int) -> bool:
    var query := "DELETE FROM example1 WHERE id = ?;"
    return _execute_write(query, [id])


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


func get_all_example2() -> Array[Example2Data]:
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


func insert_example2(data: Example2Data) -> bool:
    if data.id != 0:
        push_error("Cannot insert example2 with an assigned ID; reset it to 0 first.")
        return false
    var query := "INSERT INTO example2 (example1, value) VALUES (?, ?);"
    var inserted_id := _execute_insert(query, [data.example1, data.value])
    if inserted_id <= 0:
        return false
    data.id = inserted_id
    return true


func update_example2(data: Example2Data) -> bool:
    var query := "UPDATE example2 SET example1 = ?, value = ? WHERE id = ?;"
    return _execute_write(query, [data.example1, data.value, data.id])


func delete_example2_by_id(id: int) -> bool:
    var query := "DELETE FROM example2 WHERE id = ?;"
    return _execute_write(query, [id])


func get_all_example2_summary() -> Array[Example2SummaryData]:
    var items: Array[Example2SummaryData] = []
    if _database == null:
        push_error("Cannot query without a database handle.")
        return items
    var query := "SELECT * FROM example2_summary;"
    if not _database.query(query):
        push_error("Failed to retrieve example2_summary rows: %s" % _database.error_message)
        return items
    for row in _database.query_result:
        items.append(Example2SummaryData.from_row(row))
    return items


func get_example2_summary_by_id(id: int) -> Example2SummaryData:
    if _database == null:
        push_error("Cannot query without a database handle.")
        return null
    var query := "SELECT * FROM example2_summary WHERE id = ?;"
    if not _database.query_with_bindings(query, [id]):
        push_error("Failed to retrieve example2_summary row: %s" % _database.error_message)
        return null
    var rows: Array = _database.query_result
    if rows.is_empty():
        return null
    return Example2SummaryData.from_row(rows[0])
