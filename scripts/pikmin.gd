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

# Minimum distance from the player
@export var min_distance: float = 2.0  # You can adjust this distance
var target_position: Vector3  # The Pikmin's assigned spot in the zone
@export var target_follow_point: Node3D  # Direct reference to assigned follow point

@export var current_state: State = State.FOLLOWING  # Default state is FOLLOWING

const SPEED = 4.0

func _ready():
	_navigation_agent.avoidance_enabled = false  # Not sure if this results in more organic movement
	_navigation_agent.path_desired_distance = 0.1  # Lower to allow finer control to the path
	_navigation_agent.radius = 0.5  # Adjust radius if needed for the Pikmin's size
	_navigation_agent.target_desired_distance = 0.01
	
# Called every frame. Handles state transitions and movement
func _process(delta: float) -> void:
	if player:
		var look_position = player.global_transform.origin
		look_position.y = global_transform.origin.y  # Keep it on the same Y plane
		look_at(look_position, Vector3.UP)
	match current_state:
		State.FOLLOWING:
			follow_target(delta)
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

	# Ensure there's a valid target position
	if not _navigation_agent.is_navigation_finished():
		var next_position = _navigation_agent.get_next_path_position()
		var direction = (next_position - global_transform.origin).normalized()
		var distance = global_transform.origin.distance_to(target_position)

		if distance > 0.1:  # Allow small tolerance before stopping
			velocity = direction * SPEED
		else:
			velocity = Vector3.ZERO  # Stop moving when close

		move_and_slide()

func update_collision(state):
	if state == State.THROWN:
		collision_mask &= ~(1)
	else:
		collision_mask |= (1)

# FOLLOWING state: Pikmin moves toward the target
func follow_target(delta: float) -> void:
	if target_follow_point:
		target_position = target_follow_point.global_transform.origin  # Direct access
		_navigation_agent.set_target_position(target_position)

# WAITING state: Pikmin waits, can implement more advanced logic like idle animations here
func waiting_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are in the waiting state.
	
# IDLE state: Pikmin does nothing
func idle_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are idle.

# GATHERING state: Pikmin interacts with nearby objects (could be implemented later)
func gathering_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are gathering.

func start_throw(origin_transform: Transform3D, direction: Vector3, reticle_distance: float):
	current_state = State.THROWN  # <--- CRITICAL
	update_collision(current_state)
	# Get the target position (reticle's position)
	var target_position = origin_transform.origin + direction * reticle_distance

	# Calculate the horizontal distance to the target
	var horizontal_distance = Vector2(target_position.x - global_transform.origin.x, target_position.z - global_transform.origin.z).length()

	# Calculate the vertical distance to the target
	var vertical_distance = target_position.y - global_transform.origin.y

	# Calculate the required initial velocity using kinematic equations
	var gravity = 9.8  # Adjust this based on your game's gravity
	var angle = 45.0 * (PI / 180)  # 45 degrees for a balanced arc (you can adjust this)
	var initial_speed = sqrt((gravity * horizontal_distance * horizontal_distance) / (2 * (horizontal_distance * tan(angle) - vertical_distance) * cos(angle) * cos(angle)))

	# Calculate the horizontal and vertical components of the velocity
	var horizontal_velocity = initial_speed * cos(angle)
	var vertical_velocity = initial_speed * sin(angle)

	# Apply the velocity in the direction of the reticle
	var throw_direction = Vector3(target_position.x - global_transform.origin.x, 0, target_position.z - global_transform.origin.z).normalized()
	velocity = throw_direction * horizontal_velocity
	velocity.y = vertical_velocity

func thrown_state_update(delta: float):
	velocity.y -= (gravity * delta)
	move_and_slide()

	# If we detect a collision or the Pikmin is on the ground again:
	if is_on_floor():
		# Transition back to WAITING or FOLLOWING, or do something else
		current_state = State.WAITING
		update_collision(current_state)
		velocity = Vector3.ZERO
