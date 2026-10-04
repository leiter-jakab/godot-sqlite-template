extends GameState

class_name MainMenuState

var ui: UiMain


func enter() -> void:
    print("State: main menu")
    if ui == null:
        return

    ui.visible = true
    ui.set_process(true)

    ui.new_game_requested.connect(_on_new_game_requested)
    ui.existing_game_selected.connect(_on_existing_game_selected)
    ui.delete_game_requested.connect(_on_delete_game_requested)
    ui.close_game_requested.connect(_on_close_game_requested)

    ui.initialize(owner.get_existing_game_names())


func exit() -> void:
    if ui == null:
        return

    ui.new_game_requested.disconnect(_on_new_game_requested)
    ui.existing_game_selected.disconnect(_on_existing_game_selected)
    ui.delete_game_requested.disconnect(_on_delete_game_requested)
    ui.close_game_requested.disconnect(_on_close_game_requested)

    ui.visible = false
    ui.set_process(false)


func unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        request_gameplay_transition()


func _init(root: Main, ui_instance: UiMain = null) -> void:
    super(root)
    ui = ui_instance


func _on_new_game_requested(game_name: String) -> void:
    print("Create new game: %s" % game_name)
    if owner.start_new_game(game_name):
        request_gameplay_transition()


func _on_existing_game_selected(game_name: String) -> void:
    print("Load existing game: %s" % game_name)
    if owner.load_existing_game(game_name):
        request_gameplay_transition()


func _on_delete_game_requested(game_name: String) -> void:
    print("Delete saved game: %s" % game_name)
    if owner.delete_game(game_name):
        ui.initialize(owner.get_existing_game_names())


func _on_close_game_requested() -> void:
    print("Close game requested")
    owner.quit_game()
