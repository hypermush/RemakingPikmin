extends Node

var debug: bool = OS.has_feature("debug")

@onready var panel: Panel = Panel.new()
@onready var canvas_layer: CanvasLayer = CanvasLayer.new()
@onready var rich_text_label: RichTextLabel = RichTextLabel.new()
# @onready var theme: Theme = load("res://SurvivalScape.theme") # Your custom theme file

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if debug:
		if OS.get_name() == "Android" or OS.get_name() == "iOS":
			pass
		else:
			canvas_layer.layer = 128
			panel.size = Vector2(360, 120)
			# panel.theme = theme
			panel.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
			panel.self_modulate = Color(1, 1, 1, 0.69)

			rich_text_label.text = ""
			# rich_text_label.theme = theme
			rich_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			rich_text_label.scroll_following = true
			panel.add_child(rich_text_label)

			canvas_layer.add_child(panel)
			add_child(canvas_layer)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		if panel.visible:
			panel.visible = false
		else:
			panel.visible = true


func print(message: String) -> void:
	if debug:
		if rich_text_label:
			rich_text_label.append_text(message + "\n")			

	print(message)
