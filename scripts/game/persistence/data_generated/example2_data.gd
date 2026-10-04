extends RefCounted

class_name Example2Data

var id: int = 0
var example1: String = ""
var value: Variant = null


static func table_name() -> String:
    return "example2"


static func from_row(row: Dictionary) -> Example2Data:
    var data := Example2Data.new()
    data.id = int(row.get("id", 0))
    data.example1 = str(row.get("example1", ""))
    data.value = row.get("value", null)
    return data


func to_row() -> Dictionary:
    return {
        "id": id,
        "example1": example1,
        "value": value,
    }
