extends GameState

class_name GameplayState


func enter() -> void:
    print("State: gameplay")


func unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        request_paused_gameplay_transition()
