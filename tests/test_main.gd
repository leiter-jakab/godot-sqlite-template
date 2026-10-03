extends GutTest


class GameManagerStub:
    extends GameManager

    var existing_names: Array[String] = []
    var new_game_result: SQLite
    var loaded_game_result: SQLite
    var requested_new_game_name := ""
    var requested_load_game_name := ""
    var requested_delete_game_name := ""
    var delete_result := false

    func _init() -> void:
        super(PersistenceManager.new())

    func get_existing_game_names() -> Array[String]:
        return existing_names

    func start_new_game(game_name: String = "game") -> SQLite:
        requested_new_game_name = game_name
        return new_game_result

    func load_existing_game(game_name: String) -> SQLite:
        requested_load_game_name = game_name
        return loaded_game_result

    func delete_game(game_name: String) -> bool:
        requested_delete_game_name = game_name
        if delete_result:
            existing_names.erase(game_name)
        return delete_result


class RecordingGameState:
    extends GameState

    var enter_count := 0
    var exit_count := 0
    var process_count := 0
    var input_count := 0
    var last_delta := 0.0
    var last_event: InputEvent

    func _init(main: Main) -> void:
        super(main)

    func enter() -> void:
        enter_count += 1

    func exit() -> void:
        exit_count += 1

    func process(delta: float) -> void:
        process_count += 1
        last_delta = delta

    func unhandled_input(event: InputEvent) -> void:
        input_count += 1
        last_event = event


func test_manager_facade_delegates_and_maps_results() -> void:
    var main := Main.new()
    var game_manager := GameManagerStub.new()
    var database := SQLite.new()
    game_manager.existing_names = ["slot_1", "slot_2"]
    game_manager.new_game_result = database
    game_manager.loaded_game_result = database
    main._game_manager = game_manager

    assert_eq(main.get_existing_game_names(), ["slot_1", "slot_2"])
    assert_true(main.start_new_game("new_slot"))
    assert_eq(game_manager.requested_new_game_name, "new_slot")
    assert_true(main.load_existing_game("saved_slot"))
    assert_eq(game_manager.requested_load_game_name, "saved_slot")
    game_manager.delete_result = true
    assert_true(main.delete_game("deleted_slot"))
    assert_eq(game_manager.requested_delete_game_name, "deleted_slot")

    game_manager.new_game_result = null
    game_manager.loaded_game_result = null
    assert_false(main.start_new_game("failed_slot"))
    assert_false(main.load_existing_game("missing_slot"))
    game_manager.delete_result = false
    assert_false(main.delete_game("failed_delete"))
    assert_eq(game_manager.requested_delete_game_name, "failed_delete")

    main.free()


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


func test_state_replacement_and_dispatch() -> void:
    var main := Main.new()
    var first_state := RecordingGameState.new(main)
    var current_state := RecordingGameState.new(main)
    main._change_state(first_state)
    main._change_state(current_state)

    assert_eq(first_state.enter_count, 1)
    assert_eq(first_state.exit_count, 1)
    assert_eq(current_state.enter_count, 1)

    main._change_state(null)
    main._process(0.25)
    var event := InputEventKey.new()
    main._unhandled_input(event)

    assert_eq(main._current_state, current_state)
    assert_eq(current_state.process_count, 1)
    assert_eq(current_state.last_delta, 0.25)
    assert_eq(current_state.input_count, 1)
    assert_eq(current_state.last_event, event)
    assert_eq(first_state.process_count, 0)
    assert_eq(first_state.input_count, 0)

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