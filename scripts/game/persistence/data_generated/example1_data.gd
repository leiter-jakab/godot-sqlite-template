extends RefCounted

class_name Example1Data

var id: String = ""
var name: String = ""
var date: Variant = null


static func table_name() -> String:
    return "example1"


static func from_row(row: Dictionary) -> Example1Data:
    var data := Example1Data.new()
    data.id = str(row.get("id", ""))
    data.name = str(row.get("name", ""))
    data.date = row.get("date", null)
    return data


func to_row() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "date": date,
    }
