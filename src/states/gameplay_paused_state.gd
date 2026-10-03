extends GameState

class_name GameplayPausedState

var ui: UiGameplayPaused


func enter() -> void:
    print("State: gameplay paused")
    if ui == null:
        return

    ui.visible = true
    ui.set_process(true)
    ui.resume_requested.connect(_on_resume_requested)
    ui.quit_requested.connect(_on_quit_requested)


func exit() -> void:
    if ui == null:
        return

    ui.resume_requested.disconnect(_on_resume_requested)
    ui.quit_requested.disconnect(_on_quit_requested)
    ui.visible = false
    ui.set_process(false)


func unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
        request_gameplay_transition()


func _init(root: Main, ui_instance: UiGameplayPaused = null) -> void:
    super(root)
    ui = ui_instance


func _on_resume_requested() -> void:
    request_gameplay_transition()


func _on_quit_requested() -> void:
    request_main_menu_transition()
