# Pikmin Code
extends CharacterBody3D

var gravity = 9.8
var throw_upward_speed = 10
var throw_forward_speed = 10

# Pikmin states
enum State {
	FOLLOWING,
	WAITING,
	IDLE,
	GATHERING,
	THROWN
}

# Public references
@onready var _navigation_agent: NavigationAgent3D = $NavigationAgent3D
@export var player: Node3D  # The player (for reference)
@export var gathering_zone_size: Vector2 = Vector2(3, 2)  # Width and depth of the gathering zone
@export var reposition_threshold: float = 2.0  # If Pikmin is too far from its spot, pick a new one

# Minimum distance from the player
@export var min_distance: float = 2.0  # You can adjust this distance
var target_position: Vector3  # The Pikmin's assigned spot in the zone
var _random_offset := Vector3.ZERO
var _last_target_position := Vector3.ZERO

@export var current_state: State = State.FOLLOWING  # Default state is FOLLOWING

const SPEED = 3.0

func _ready():
	_navigation_agent.avoidance_enabled = true  # Makes Pikmin avoid each other
	_navigation_agent.path_desired_distance = 0.5  # Lower to allow finer control to the path
	_navigation_agent.radius = 0.5  # Adjust radius if needed for the Pikmin's size
	assign_new_target_position()  # Pick an initial spot
	
# Called every frame. Handles state transitions and movement
func _process(delta: float) -> void:
	if player:
		var target_position = player.global_transform.origin
		target_position.y = global_transform.origin.y  # Keep it on the same Y plane
		look_at(target_position, Vector3.UP)
	match current_state:
		State.FOLLOWING:
			if player:
				# Only assign a new target position if needed
				if global_transform.origin.distance_to(target_position) > reposition_threshold:
					assign_new_target_position()  # Assign a new spot if the Pikmin is too far
			#follow_target(delta)
		State.WAITING:
			waiting_state(delta)
		State.IDLE:
			idle_state(delta)
		State.GATHERING:
			gathering_state(delta)
		State.THROWN:
			thrown_state_update(delta)
		
func _physics_process(delta):
	# If Pikmin is in THROWN state, handle ballistic arc and skip navigation
	if current_state == State.THROWN:
		thrown_state_update(delta)
		return  # <--- stop here, so we don't run the navigation code at all

	# Otherwise, do the normal pathfinding movement
	if _navigation_agent.is_navigation_finished():
		return

	var next_position = _navigation_agent.get_next_path_position()
	var direction = (next_position - global_transform.origin).normalized()
	velocity = direction * SPEED
	move_and_slide()


# FOLLOWING state: Pikmin moves toward the target
# old version that targetted a single point
#func follow_target(delta: float) -> void:
	#if _target:
		#var base_target_position = _target.global_transform.origin
		## Check if we need a new offset
		#if (_navigation_agent.is_navigation_finished() 
			#or _target.global_transform.origin.distance_to(_last_target_position) > min_distance):
			#_random_offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * min_distance * 0.5  # Adjust spread size
		#
		#var target_position = base_target_position + _random_offset
		#
		#_navigation_agent.set_target_position(target_position)
		#
		#_last_target_position = _target.global_transform.origin

# WAITING state: Pikmin waits, can implement more advanced logic like idle animations here
func waiting_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are in the waiting state.
	
# IDLE state: Pikmin does nothing
func idle_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are idle.

# GATHERING state: Pikmin interacts with nearby objects (could be implemented later)
func gathering_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are gathering.


func start_throw(origin_transform: Transform3D):
	current_state = State.THROWN  # <--- CRITICAL

	var direction = player.global_transform.basis.z
	direction.y = 0.0
	direction = direction.normalized()

	velocity = -direction * throw_forward_speed
	velocity.y = throw_upward_speed



func thrown_state_update(delta: float):
	velocity.y -= (gravity * delta)
	move_and_slide()

	# If we detect a collision or the Pikmin is on the ground again:
	if is_on_floor():
		# Transition back to WAITING or FOLLOWING, or do something else
		current_state = State.WAITING
		velocity = Vector3.ZERO



func assign_new_target_position():
	if player:
		var player_transform = player.global_transform
		var random_x = randf_range(-gathering_zone_size.x / 2, gathering_zone_size.x / 2)
		var random_z = randf_range(-gathering_zone_size.y, 0)  # Keeps them behind the player
		
		# Convert local offset to global space
		var offset = Vector3(random_x, 0, random_z)
		# Multiply by the player's basis to convert to world space, ensuring we are behind the player
		target_position = player_transform.origin - player_transform.basis.z * random_z + player_transform.basis.x * random_x
		
		# Ensure we have a minimum threshold for position updates
		if global_transform.origin.distance_to(target_position) > reposition_threshold:
			_navigation_agent.set_target_position(target_position)
			Log.print("New target position assigned: " + str(target_position))
