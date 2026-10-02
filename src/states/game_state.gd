extends RefCounted

class_name GameState

var owner: Main


func _init(root: Main) -> void:
    owner = root


func enter() -> void:
    pass


func exit() -> void:
    pass


func process(_delta: float) -> void:
    pass


func unhandled_input(_event: InputEvent) -> void:
    pass


func request_gameplay_transition() -> void:
    owner.transition_to_gameplay()


func request_main_menu_transition() -> void:
    owner.transition_to_main_menu()


func request_paused_gameplay_transition() -> void:
    owner.transition_to_paused_gameplay()


func request_transition(next_state: GameState) -> void:
    owner.change_state(next_state)
