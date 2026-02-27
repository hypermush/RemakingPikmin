extends Node

signal day_progress_updated(progress: float)

@export var day_duration: float = 360.0
var time_remaining: float
var _active: bool = false
var _ending: bool = false

func _ready() -> void:
	time_remaining = day_duration

func _process(delta: float) -> void:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return

	var in_level = current_scene.scene_file_path.ends_with("level.tscn")

	if not in_level:
		# Reset timer when leaving the level so the next day starts fresh
		if _active:
			time_remaining = day_duration
			_active = false
			_ending = false
		return

	# We are in the level scene
	if not _active:
		_active = true

	if _ending:
		return

	time_remaining -= delta
	time_remaining = maxf(time_remaining, 0.0)

	var progress = 1.0 - (time_remaining / day_duration)
	emit_signal("day_progress_updated", progress)

	if time_remaining <= 0.0:
		_ending = true
		_end_day()

func _end_day() -> void:
	for pikmin in get_tree().get_nodes_in_group("Pikmin"):
		pikmin.queue_free()
	GlobalRefs.day_number += 1
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
