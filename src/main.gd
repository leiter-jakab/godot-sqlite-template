extends Node

class_name Main

@export var main_menu_scene: PackedScene
@export var game_paused_scene: PackedScene

var _game_manager: GameManager
var _persistence_manager: PersistenceManager

var _current_state: GameState

var _ui_main: UiMain
var _ui_gameplay_paused: UiGameplayPaused


func _ready() -> void:
    _persistence_manager = PersistenceManager.new()
    _game_manager = GameManager.new(_persistence_manager)

    _ui_main = _instantiate_scene(main_menu_scene, "MainMenu")
    _ui_gameplay_paused = _instantiate_scene(game_paused_scene, "GameplayPaused")
    if _ui_main == null or _ui_gameplay_paused == null:
        _fail_init("Required UI scenes failed to initialize.")
        return

    _ui_main.visible = false
    _ui_gameplay_paused.visible = false
    add_child(_ui_main)
    add_child(_ui_gameplay_paused)

    _change_state(MainMenuState.new(self, _ui_main))


func _instantiate_scene(scene: PackedScene, label: String) -> Node:
    if scene == null:
        push_error("%s scene is not assigned." % label)
        return null

    var instance = scene.instantiate()
    if instance == null:
        push_error("Failed to instantiate %s scene." % label)
        return null

    if not instance is Control:
        push_error("%s scene must be a Control-based scene." % label)
        return null

    return instance


func _fail_init(message: String) -> void:
    push_error(message)
    assert(false, message)
    if get_tree() != null:
        get_tree().quit(1)


func _process(delta: float) -> void:
    if _current_state != null:
        _current_state.process(delta)


func _unhandled_input(event: InputEvent) -> void:
    if _current_state != null:
        _current_state.unhandled_input(event)


func _change_state(new_state: GameState) -> void:
    if new_state == null:
        return

    if _current_state != null:
        _current_state.exit()

    _current_state = new_state
    _current_state.enter()


func transition_to_gameplay() -> void:
    _change_state(GameplayState.new(self))


func transition_to_main_menu() -> void:
    _change_state(MainMenuState.new(self, _ui_main))


func transition_to_paused_gameplay() -> void:
    _change_state(GameplayPausedState.new(self, _ui_gameplay_paused))


func quit_game() -> void:
    if get_tree() != null:
        get_tree().quit()
