extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var options_button: Button = $VBoxContainer/OptionsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	print("Start")
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func _on_options_button_pressed() -> void:
	print("Options")

func _on_exit_button_pressed() -> void:
	print("Exit")
	get_tree().quit()
