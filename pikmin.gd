extends CharacterBody3D

# Pikmin states
enum State {
	FOLLOWING,
	WAITING,
	IDLE,
	GATHERING
}

# Public references
@onready var _target: Node3D  # Reference to the target position
@onready var _navigation_agent: NavigationAgent3D = $NavigationAgent3D

# Minimum distance from the player
@export var min_distance: float = 2.0  # You can adjust this distance

@export var current_state: State = State.FOLLOWING  # Default state is FOLLOWING

const SPEED = 3.0

func _ready():
	_navigation_agent.avoidance_enabled = true  # Makes Pikmin avoid each other
	_navigation_agent.path_desired_distance = 1.5  # Adjusts how close they try to get to the path
	_navigation_agent.target_desired_distance = min_distance  # Keeps them from getting too close
	
# Called every frame. Handles state transitions and movement
func _process(delta: float) -> void:
	match current_state:
		State.FOLLOWING:
			follow_target(delta)
		State.WAITING:
			waiting_state(delta)
		State.IDLE:
			idle_state(delta)
		State.GATHERING:
			gathering_state(delta)
		
func _physics_process(delta):
	if _navigation_agent.is_navigation_finished():
		return  # Stop if at the destination

	var next_position = _navigation_agent.get_next_path_position()
	var direction = (next_position - global_transform.origin).normalized()

	velocity = direction * SPEED
	move_and_slide()

# FOLLOWING state: Pikmin moves toward the target
func follow_target(delta: float) -> void:
	if _target:
		var target_position = _target.global_transform.origin
		var distance_to_target = global_transform.origin.distance_to(target_position)
		
		# If the distance to the target is larger than the minimum, keep moving
		if distance_to_target > min_distance:
			_navigation_agent.set_target_position(target_position)
		else:
			# If they are too close to the target, just stop moving
			_navigation_agent.set_target_position(global_transform.origin)  # Stop the agentget.
		
# WAITING state: Pikmin waits, can implement more advanced logic like idle animations here
func waiting_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are in the waiting state.
	
# IDLE state: Pikmin does nothing
func idle_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are idle.

# GATHERING state: Pikmin interacts with nearby objects (could be implemented later)
func gathering_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are gathering.
