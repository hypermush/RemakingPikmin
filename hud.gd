extends Control

# need a reference to the player
# add in inspector for now
@export var player: CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.connect("update_hud_values", Callable(self, "_on_value_updated"))
	DayTimer.connect("day_progress_updated", Callable(self, "_on_day_progress_updated"))
	GlobalRefs.connect("treasure_count_changed", Callable(self, "_on_treasure_count_changed"))
	Log.print("connected signal?")

func _on_value_updated(new_value):
	$BottomRightContainer/SquadPanel/SquadCount.text = str(new_value)
	Log.print("HUD update? " + str(new_value))

func _on_day_progress_updated(progress: float) -> void:
	$TopContainer/DayProgress.value = progress * 100.0
	$DayCounter/DayNumber.text = str(GlobalRefs.day_number)

func _on_treasure_count_changed(count: int) -> void:
	$BottomRightContainer/TotalPanel/TotalCount.text = str(count)
