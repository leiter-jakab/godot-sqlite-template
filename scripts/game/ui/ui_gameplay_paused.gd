extends Control

class_name UiGameplayPaused

signal resume_requested
signal quit_requested

@onready var resume_button: Button = $CenterContainer/VBoxContainer/Resume
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Quit


func _ready() -> void:
    resume_button.pressed.connect(_on_resume_pressed)
    quit_button.pressed.connect(_on_quit_pressed)


func _on_resume_pressed() -> void:
    resume_requested.emit()


func _on_quit_pressed() -> void:
    quit_requested.emit()
