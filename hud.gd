extends Control

# need a reference to the player
# add in inspector for now
@export var player: CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.connect("update_hud_values", Callable(self, "_on_value_updated"))
	Log.print("connected signal?")

func _on_value_updated(new_value):
	$BottomRightContainer/SquadPanel/SquadCount.text = str(new_value)
	Log.print("HUD update? " + str(new_value))
