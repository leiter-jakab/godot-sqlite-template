extends Control

class_name UiMain

signal existing_game_selected(game_name: String)
signal new_game_requested(game_name: String)
signal close_game_requested()

@onready var game_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/GameList
@onready var name_field: LineEdit = $MarginContainer/VBoxContainer/NameField
@onready var new_game_button: Button = $MarginContainer/VBoxContainer/NewGameButton
@onready var close_game_button: Button = $MarginContainer/VBoxContainer/CloseGameButton

var saved_games: Array[String] = []
var selected_game_name: String = ""


func _ready() -> void:
    new_game_button.pressed.connect(_on_new_game_pressed)
    close_game_button.pressed.connect(_on_close_game_pressed)


func initialize(existing_games: Array[String]) -> void:
    saved_games = existing_games.duplicate()
    selected_game_name = ""
    populate_game_list()
func populate_game_list() -> void:
    for child in game_list.get_children():
        child.queue_free()

    for game_name in saved_games:
        var button := Button.new()
        button.text = game_name
        button.pressed.connect(_on_game_selected.bind(game_name))
        game_list.add_child(button)

    if saved_games.size() > 0:
        selected_game_name = saved_games[0]


func _on_game_selected(game_name: String) -> void:
    selected_game_name = game_name
    existing_game_selected.emit(game_name)


func _on_new_game_pressed() -> void:
    var game_name := name_field.text.strip_edges()
    if game_name.is_empty():
        print("Game name cannot be empty.")
        return

    selected_game_name = game_name
    new_game_requested.emit(game_name)
    name_field.clear()


func _on_close_game_pressed() -> void:
    close_game_requested.emit()
