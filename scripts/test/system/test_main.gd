extends GutTest


class GameManagerStub:
    extends GameManager

    var existing_names: Array[String] = []
    var requested_new_game_name := ""
    var requested_overwrite_game_name := ""
    var requested_load_game_name := ""
    var requested_delete_game_name := ""
    var overwrite_game_result: SQLite
    var delete_result := false

    func _init() -> void:
        super(PersistenceManager.new())

    func get_existing_game_names() -> Array[String]:
        return existing_names

    func start_new_game(game_name: String = "game") -> SQLite:
        requested_new_game_name = game_name
        return null

    func overwrite_game(game_name: String) -> SQLite:
        requested_overwrite_game_name = game_name
        return overwrite_game_result

    func load_existing_game(game_name: String) -> SQLite:
        requested_load_game_name = game_name
        return null

    func delete_game(game_name: String) -> bool:
        requested_delete_game_name = game_name
        if delete_result:
            existing_names.erase(game_name)
        return delete_result


func test_main_menu_delete_confirmation_routes_without_loading() -> void:
    var main := Main.new()
    var game_manager := GameManagerStub.new()
    game_manager.existing_names = ["slot_1", "slot_2"]
    game_manager.delete_result = true
    main._game_manager = game_manager

    var ui := load("res://scenes/ui/ui_main.tscn").instantiate() as UiMain
    add_child(ui)
    var state := MainMenuState.new(main, ui)
    state.enter()

    var loaded_game_names: Array[String] = []
    ui.existing_game_selected.connect(func(game_name: String) -> void: loaded_game_names.append(game_name))

    var delete_button := ui.game_list.get_child(0).get_child(1) as Button
    delete_button.emit_signal("pressed")
    ui.delete_confirmation_dialog.get_cancel_button().emit_signal("pressed")
    assert_eq(game_manager.requested_delete_game_name, "")
    assert_eq(ui.saved_games, ["slot_1", "slot_2"])

    delete_button.emit_signal("pressed")
    ui.delete_confirmation_dialog.emit_signal("confirmed")
    assert_eq(game_manager.requested_delete_game_name, "slot_1")
    assert_eq(ui.saved_games, ["slot_2"])
    assert_eq(loaded_game_names, [])

    state.exit()
    ui.free()
    main.free()


func test_main_menu_new_game_confirmation_routes_only_after_confirm() -> void:
    var main := Main.new()
    var game_manager := GameManagerStub.new()
    game_manager.existing_names = ["slot_1"]
    game_manager.overwrite_game_result = SQLite.new()
    main._game_manager = game_manager

    var ui := load("res://scenes/ui/ui_main.tscn").instantiate() as UiMain
    add_child(ui)
    var state := MainMenuState.new(main, ui)
    state.enter()

    ui.name_field.text = " SLOT_1.db "
    ui.new_game_button.emit_signal("pressed")
    assert_eq(ui.overwrite_confirmation_dialog.dialog_text, "A game named 'SLOT_1.db' already exists. Overwrite it with a new game?")
    assert_eq(game_manager.requested_new_game_name, "")
    assert_eq(game_manager.requested_overwrite_game_name, "")

    ui.overwrite_confirmation_dialog.get_cancel_button().emit_signal("pressed")
    assert_eq(ui.pending_overwrite_game_name, "")
    assert_eq(game_manager.requested_overwrite_game_name, "")

    ui.name_field.text = "sLoT_1"
    ui.new_game_button.emit_signal("pressed")
    ui.overwrite_confirmation_dialog.emit_signal("confirmed")
    assert_eq(game_manager.requested_overwrite_game_name, "sLoT_1")
    assert_true(main._current_state is GameplayState)

    ui.free()
    main.free()


func test_main_scene_transitions_and_ui_visibility() -> void:
    var main := load("res://scenes/main.tscn").instantiate() as Main
    add_child(main)

    assert_true(main._current_state is MainMenuState)
    assert_true(main._ui_main.visible)
    assert_false(main._ui_gameplay_paused.visible)

    main.transition_to_gameplay()
    assert_true(main._current_state is GameplayState)
    assert_false(main._ui_main.visible)
    assert_false(main._ui_gameplay_paused.visible)

    main.transition_to_paused_gameplay()
    assert_true(main._current_state is GameplayPausedState)
    assert_true(main._ui_gameplay_paused.visible)

    main.transition_to_gameplay()
    assert_true(main._current_state is GameplayState)
    assert_false(main._ui_gameplay_paused.visible)

    main.transition_to_main_menu()
    assert_true(main._current_state is MainMenuState)
    assert_true(main._ui_main.visible)
    assert_false(main._ui_gameplay_paused.visible)

    main.free()