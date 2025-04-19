extends Node3D

# Destination tyle
enum DestinationType {
	SHIP,
	ONION,
}

@onready var dropoff_point: Node3D = $DropoffPoint
@export var destination_type: DestinationType
@export var seed_scene: PackedScene
@export var player: Node3D
@export var pikmin_scene: PackedScene
@onready var seed_launch_point := $"../../DevOnion/SeedLaunchPoint"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not destination_type:
		Log.print("Destination is missing type!")
	if destination_type == DestinationType.ONION and not seed_scene:
		Log.print("Onion is missing seed reference!")
	if destination_type == DestinationType.ONION and not player:
		Log.print("Onion is missing player reference!")
	if destination_type == DestinationType.ONION and not pikmin_scene:
		Log.print("Onion is missing pikmin reference!")
	#connect("reached_destination", Callable(self, "_on_carryable_reached_destination"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func get_dropoff_position():
	return dropoff_point.global_transform.origin
	
func _on_carryable_reached_destination(payload: Dictionary):
	#Log.print("Final call of destination reached!")
	if destination_type == DestinationType.ONION:
		if payload.has("value"):
			_spawn_pikmin_seeds(payload["value"])
			
func _spawn_pikmin_seeds(count: int):
	for i in count:
		var seed = seed_scene.instantiate()
		seed.player = player
		seed.pikmin_scene = pikmin_scene
		get_tree().current_scene.add_child(seed)

		# Position at the top of the onion
		seed.global_transform.origin = seed_launch_point.global_transform.origin

		# Ensure the physics frame has started
		await get_tree().physics_frame

		# Randomized launch force
		var angle = randf_range(0, TAU)
		var direction = Vector3(cos(angle), 1.0, sin(angle)).normalized()
		var force = direction * 8.0

		# Confirm the node is a RigidBody3D before applying
		if seed is RigidBody3D:
			seed.apply_impulse(force)
