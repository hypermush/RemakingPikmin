class_name Enemy
extends CharacterBody3D

@export var max_health: int = 5
var current_health: int
var is_destroyed: bool = false
var kill_cooldown: float = 2.0
var _last_kill_time: float = 0.0
var move_speed: float = 2.0
var wander_radius: float = 8.0
var _spawn_position: Vector3

@export var drop_carryable: PackedScene
@export var drop_nectar: PackedScene

var _navigation_agent: NavigationAgent3D
var _combat_area: Area3D

func _ready() -> void:
	current_health = max_health
	_spawn_position = global_position
	add_to_group("enemy")

	_navigation_agent = $NavigationAgent3D
	_combat_area = $CombatArea
	_combat_area.body_entered.connect(_on_combat_body_entered)

	# Defer so the navigation mesh is ready before we request a path
	call_deferred("_pick_new_wander_target")

func _physics_process(_delta: float) -> void:
	if is_destroyed:
		return

	if _navigation_agent.is_navigation_finished():
		_pick_new_wander_target()
		return

	var next_pos = _navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

func _pick_new_wander_target() -> void:
	var angle = randf() * TAU
	var radius = randf() * wander_radius
	var target = _spawn_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
	_navigation_agent.set_target_position(target)

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	is_destroyed = true

	# Notify any Pikmin attacking this enemy to stop
	for pikmin in get_tree().get_nodes_in_group("Pikmin"):
		if pikmin.assigned_target == self:
			pikmin.assigned_target = null
			pikmin.current_state = pikmin.State.IDLE

	# Drop items at death position
	var scene_root = get_tree().current_scene
	if drop_carryable:
		var c = drop_carryable.instantiate()
		scene_root.add_child(c)
		c.global_position = global_position

	if drop_nectar:
		var n = drop_nectar.instantiate()
		scene_root.add_child(n)
		n.global_position = global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))

	queue_free()

func _on_combat_body_entered(body: Node3D) -> void:
	if is_destroyed:
		return
	if body.is_in_group("Pikmin"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - _last_kill_time >= kill_cooldown:
			_last_kill_time = now
			body.take_damage(99)
