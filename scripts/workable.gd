class_name Workable
extends StaticBody3D

@export var max_health: int = 10
var current_health: int
var is_destroyed := false

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	current_health -= amount
	if current_health < 1:
		destroy()

func destroy() -> void:
	is_destroyed = true
	# Notify assigned pikmin
	for pikmin in get_tree().get_nodes_in_group("Pikmin"):
		if pikmin.assigned_target == self:
			pikmin.assigned_target = null
			pikmin.current_state = pikmin.State.IDLE
	# subclasses handle the rest
