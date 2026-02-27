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

var launch_radius = 6.0
var launch_height = 4.0
var launch_time = 1.5  # seconds

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if destination_type == DestinationType.SHIP:
		GlobalRefs.ship = self
		return

	if destination_type != DestinationType.ONION:
		return

	# Onion-specific setup
	if not seed_scene:
		Log.print("Onion is missing seed reference!")
	if not player:
		Log.print("Onion is missing player reference!")
	if not pikmin_scene:
		Log.print("Onion is missing pikmin reference!")

	GlobalRefs.onion = self
		
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
	elif destination_type == DestinationType.SHIP:
		var value = payload.get("value", 0)
		GlobalRefs.treasure_count += value
		GlobalRefs.emit_signal("treasure_count_changed", GlobalRefs.treasure_count)
			
func _spawn_pikmin_seeds(count: int):
	for i in count:
		var new_seed = seed_scene.instantiate()
		new_seed.player = player
		new_seed.pikmin_scene = pikmin_scene
		get_tree().current_scene.add_child(new_seed)

		var start_pos = seed_launch_point.global_transform.origin
		
		# Get where the seed will *land* horizontally
		var angle = randf_range(0, TAU)
		var horizontal_offset = Vector3(cos(angle), 0, sin(angle)) * launch_radius
		var ground_y = 0  # Adjust this if your level's ground isn't perfectly flat at Y=0
		var end_pos = start_pos + horizontal_offset
		end_pos.y = ground_y

		new_seed.global_transform.origin = start_pos
		new_seed.start_trail()

		var tween = create_tween()
		
		# Tween progress from 0 → 1, calling the helper function
		tween.tween_method(
			func(progress: float) -> void:
				_update_seed_motion(new_seed, start_pos, end_pos, progress, launch_height),
			0.0,
			1.0,
			launch_time
		).set_trans(Tween.TRANS_LINEAR)
		# ✨ Add a short delay before next seed
		await get_tree().create_timer(0.05).timeout  # 0.1 seconds = adjust as needed
		
func _update_seed_motion(pik_seed: Node3D, start_pos: Vector3, end_pos: Vector3, progress: float, peak_height: float) -> void:
	var new_pos = start_pos.lerp(end_pos, progress)
	
	# Parabolic height
	var base_y = lerp(start_pos.y, end_pos.y, progress)
	var arc_offset = peak_height * 4.0 * progress * (1.0 - progress)
	new_pos.y = base_y + arc_offset
	
	# Update seed position
	pik_seed.global_transform.origin = new_pos
	
	# --- Rotation logic ---
	var horizontal_dir = (end_pos - start_pos)
	horizontal_dir.y = 0
	horizontal_dir = horizontal_dir.normalized()
	
	# Calculate tilt based on progress
	var tilt_angle = lerp(-160.0, 0.0, progress)  # -90 degrees = stem straight down, 10 degrees up at end
	
	var current_basis = Basis()
	current_basis = current_basis.rotated(Vector3.UP, atan2(horizontal_dir.x, horizontal_dir.z))  # Face outward
	current_basis = current_basis.rotated(current_basis.x, deg_to_rad(tilt_angle))  # Tilt around the sideways axis
	
	var current_transform = pik_seed.global_transform
	current_transform.basis = current_basis
	pik_seed.global_transform = current_transform
