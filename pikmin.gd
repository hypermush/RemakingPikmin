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

@export var current_state: State = State.FOLLOWING  # Default state is FOLLOWING

const SPEED = 3.0

func _ready():
	_navigation_agent.path_desired_distance = 0.5  # How close it considers "at destination"
	_navigation_agent.target_desired_distance = 0.5  # How close to the target before stopping
	
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
		_navigation_agent.target_position = _target.global_transform.origin
		# You can add more logic here for distance checks, or other behaviors when close to target.
		
# WAITING state: Pikmin waits, can implement more advanced logic like idle animations here
func waiting_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are in the waiting state.
	
# IDLE state: Pikmin does nothing
func idle_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are idle.

# GATHERING state: Pikmin interacts with nearby objects (could be implemented later)
func gathering_state(delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are gathering.
