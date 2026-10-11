extends Control

class_name UiMain

const DELETE_GAME_DIALOG_TEXT := "Delete saved game '%s'? This cannot be undone."
const OVERWRITE_GAME_DIALOG_TEXT := "A game named '%s' already exists. Overwrite it with a new game?"
const OVERWRITE_GAME_BUTTON_TEXT := "Overwrite"

signal existing_game_selected(game_name: String)
signal new_game_requested(game_name: String)
signal overwrite_game_requested(game_name: String)
signal delete_game_requested(game_name: String)
signal close_game_requested()

@onready var game_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/GameList
@onready var name_field: LineEdit = $MarginContainer/VBoxContainer/NameField
@onready var new_game_button: Button = $MarginContainer/VBoxContainer/NewGameButton
@onready var close_game_button: Button = $MarginContainer/VBoxContainer/CloseGameButton
@onready var delete_confirmation_dialog: ConfirmationDialog = $DeleteGameConfirmationDialog
@onready var overwrite_confirmation_dialog: ConfirmationDialog = $OverwriteGameConfirmationDialog

var saved_games: Array[String] = []
var selected_game_name: String = ""
var pending_delete_game_name: String = ""
var pending_overwrite_game_name: String = ""


func initialize(existing_games: Array[String]) -> void:
    saved_games = existing_games.duplicate()
    selected_game_name = ""
    populate_game_list()


func populate_game_list() -> void:
    for child in game_list.get_children():
        child.queue_free()

    for game_name in saved_games:
        var row := HBoxContainer.new()
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        var game_button := Button.new()
        game_button.text = game_name
        game_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        game_button.pressed.connect(_on_game_selected.bind(game_name))

        var delete_button := Button.new()
        delete_button.text = "Delete"
        delete_button.tooltip_text = "Delete this saved game"
        delete_button.pressed.connect(_on_delete_game_pressed.bind(game_name))

        row.add_child(game_button)
        row.add_child(delete_button)
        game_list.add_child(row)

    if saved_games.size() > 0:
        selected_game_name = saved_games[0]


func _ready() -> void:
    new_game_button.pressed.connect(_on_new_game_pressed)
    close_game_button.pressed.connect(_on_close_game_pressed)
    delete_confirmation_dialog.confirmed.connect(_on_delete_game_confirmed)
    delete_confirmation_dialog.canceled.connect(_on_delete_game_canceled)
    overwrite_confirmation_dialog.confirmed.connect(_on_overwrite_game_confirmed)
    overwrite_confirmation_dialog.canceled.connect(_on_overwrite_game_canceled)


func _on_game_selected(game_name: String) -> void:
    selected_game_name = game_name
    existing_game_selected.emit(game_name)


func _on_delete_game_pressed(game_name: String) -> void:
    pending_delete_game_name = game_name
    delete_confirmation_dialog.dialog_text = DELETE_GAME_DIALOG_TEXT % game_name
    delete_confirmation_dialog.popup_centered()


func _on_delete_game_confirmed() -> void:
    var game_name := pending_delete_game_name
    pending_delete_game_name = ""
    if not game_name.is_empty():
        delete_game_requested.emit(game_name)


func _on_delete_game_canceled() -> void:
    pending_delete_game_name = ""


func _on_overwrite_game_confirmed() -> void:
    var game_name := pending_overwrite_game_name
    pending_overwrite_game_name = ""
    if not game_name.is_empty():
        overwrite_game_requested.emit(game_name)


func _on_overwrite_game_canceled() -> void:
    pending_overwrite_game_name = ""


func _on_new_game_pressed() -> void:
    var game_name := name_field.text.strip_edges()
    if game_name.is_empty():
        print("Game name cannot be empty.")
        return

    selected_game_name = game_name
    if _has_saved_game(game_name):
        pending_overwrite_game_name = game_name
        overwrite_confirmation_dialog.dialog_text = OVERWRITE_GAME_DIALOG_TEXT % game_name
        overwrite_confirmation_dialog.get_ok_button().text = OVERWRITE_GAME_BUTTON_TEXT
        overwrite_confirmation_dialog.popup_centered()
        name_field.clear()
        return

    new_game_requested.emit(game_name)
    name_field.clear()


func _has_saved_game(game_name: String) -> bool:
    var normalized_name := _normalize_game_name(game_name).to_lower()
    for saved_game_name in saved_games:
        if _normalize_game_name(saved_game_name).to_lower() == normalized_name:
            return true
    return false


func _normalize_game_name(game_name: String) -> String:
    var normalized_name := game_name.strip_edges()
    if normalized_name.ends_with(".db"):
        normalized_name = normalized_name.trim_suffix(".db")
    return normalized_name


func _on_close_game_pressed() -> void:
    close_game_requested.emit()
