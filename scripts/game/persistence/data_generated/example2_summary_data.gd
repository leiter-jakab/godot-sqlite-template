extends RefCounted

class_name Example2SummaryData

var id: int = 0
var example1_name: String = ""
var value: Variant = null


static func view_name() -> String:
    return "example2_summary"


static func from_row(row: Dictionary) -> Example2SummaryData:
    var data := Example2SummaryData.new()
    data.id = int(row.get("id", 0))
    data.example1_name = str(row.get("example1_name", ""))
    data.value = row.get("value", null)
    return data


func to_row() -> Dictionary:
    return {
        "id": id,
        "example1_name": example1_name,
        "value": value,
    }
