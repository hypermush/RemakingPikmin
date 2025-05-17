extends RigidBody3D

signal reached_destination(payload: Dictionary)
# examples
# {"weight": weight} for onions

@export var weight: int = 1  # How many Pikmin are needed
@export var value: int = 5 # how many Pikmin are made from this
var lift := 0 # this is how many are carrying 
@export var carry_point_scene: PackedScene  # Drag a debug sphere or marker here
@export var carry_radius: float = 1.0  # Distance from center to place points
@export var carry_destination: Node3D
var _carry_buffer := 0.3
var _complete := false
@onready var collision_shape: CollisionShape3D = %CarryableCollision

@export var mesh_holder: Node3D # potential to swap visuals

@onready var carry_parent := $CarryPoints

var carry_points := []  # Will hold references to the spawned carry point nodes

@onready var nav_agent := $NavigationAgent3D
const MOVE_SPEED := 2.0  # Tune for how fast the object moves
#var _moving := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weight <= 0:
		Log.print("Warning: Carryable item has no weight.")
		return
	if not carry_destination:
		Log.print("No carry destination set, using Global")
		carry_destination = GlobalRefs.onion
		Log.print("carry dest set to: " + str(carry_destination))
		
	# this group is what pikmin look for
	add_to_group("carryable")
	
	# Determine carry radius dynamically from the shape
	if collision_shape.shape is CylinderShape3D:
		var cylinder_shape := collision_shape.shape as CylinderShape3D
		carry_radius += _carry_buffer  # Add a small buffer
		#Log.print("Carry radius set to: " + str(carry_radius))
	else:
		Log.print("Warning: Collision shape is not a cylinder. Using default radius.")
	
	generate_carry_points()
	
	# connect to destination for signalling
	connect("reached_destination", Callable(carry_destination, "_on_carryable_reached_destination"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if _complete:
		#Log.print("Reached destination?")
		var current_pikmin
		for point in carry_points:
			current_pikmin = point.assigned_pikmin
			if current_pikmin:
				current_pikmin.detach_from_carryable()
			if current_pikmin.player and current_pikmin.player.has_method("add_pikmin_to_idle"):
				current_pikmin.player.add_pikmin_to_idle(current_pikmin)
		# trigger event at destination
		emit_signal("reached_destination", {"value": value})
		#Log.print("Signal emitted?")
		# this actually deletes the item instantly, we'd want an animation or something later
		queue_free()
	
func _physics_process(_delta):
	if not _complete:
		if lift >= weight and carry_destination:
			if nav_agent.get_target_position() != carry_destination.global_transform.origin:
				nav_agent.set_target_position(carry_destination.global_transform.origin)

			if not nav_agent.is_navigation_finished():
				var next_position = nav_agent.get_next_path_position()
				var direction = (next_position - global_transform.origin).normalized()
				linear_velocity = direction * MOVE_SPEED
			else:
				linear_velocity = Vector3.ZERO
				# nav finished
				_complete = true
		else:
			linear_velocity = Vector3.ZERO

func generate_carry_points():
	carry_points.clear()
	#Log.print("Generating carry points for radius: " + str(carry_radius)) 
	for i in range(weight):
		var angle = (TAU / weight) * i  # Evenly spaced in a circle
		var x = cos(angle) * carry_radius
		var z = sin(angle) * carry_radius
		var point_pos = Vector3(x, 0, z)  # Local position now

		var point = carry_point_scene.instantiate()
		point.position = point_pos  # Local position is correct here
		carry_parent.add_child(point)
		carry_points.append(point)
		
# Return the first unclaimed carry point and claim it
func get_available_carry_point(pikmin: Node3D) -> Node3D:
	if lift < weight:
		#Log.print("Attempting to find carry point...")
		for point in carry_points:
			if point.claim(pikmin):
				#Log.print("point claimed!")
				# lift now calculated when pikmin reaches position
				#lift += 1
				return point
	Log.print("We have enough lift")
	return null

func release_carry_point(point: Node3D):
	if point:
		#Log.print("Releasing carry point: " + str(point.name))
		point.claimed = false
		point.assigned_pikmin = null
		lift -= 1
