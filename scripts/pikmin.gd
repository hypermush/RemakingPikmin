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
	THROWN,
	POSITIONING,
	WORKING,
}
# carrying stuff
var assigned_carry_point: Node3D = null
var carryable_target: Node3D = null

#wall stuff
var assigned_wall: Node3D = null
var _last_wall_hit_time := 0

# ideally, we don't need a var for each type of interactable
var assigned_object: Node3D = null
var _last_wall_object_time := 0
# currently this is made to be a flower and not a wall^
# todo is generalizing this

@onready var _detection_area: Area3D = $DetectionRadius

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
	_navigation_agent.avoidance_enabled = true  # Not sure if this results in more organic movement
	_navigation_agent.path_desired_distance = 0.1  # Lower to allow finer control to the path
	_navigation_agent.radius = 0.5  # Adjust radius if needed for the Pikmin's size
	_navigation_agent.target_desired_distance = 0.05
	_navigation_agent.path_height_offset = 0.0
	
	# connect to signal for detection
	_detection_area.area_entered.connect(_on_area_entered)
	
	add_to_group("Pikmin")
	
# Called every frame. Handles state transitions and movement
func _process(delta: float) -> void:
	match current_state:
		State.FOLLOWING:
			if player:
				var look_position = player.global_transform.origin
				look_position.y = global_transform.origin.y  # Keep it on the same Y plane
				look_at(look_position, Vector3.UP)
			follow_target(delta)
		State.WAITING:
			waiting_state(delta)
		State.IDLE:
			idle_state(delta)
		State.GATHERING:
			gathering_state(delta)
		State.THROWN:
			thrown_state_update(delta)
		State.POSITIONING:
			positioning_state(delta)
		
func _physics_process(delta):
	match current_state:
		State.POSITIONING:
			if assigned_carry_point:
				var target = assigned_carry_point.global_transform.origin
				target.y = global_transform.origin.y  # Optional: flatten to Y

				# Only update if needed
				if _navigation_agent.get_target_position().distance_to(target) > 0.1:
					target.y = 0.0
					_navigation_agent.set_target_position(target)

				if not _navigation_agent.is_navigation_finished():
					var next_position = _navigation_agent.get_next_path_position()
					var direction = (next_position - global_transform.origin).normalized()
					velocity = direction * SPEED
				else:
					# ✅ Lock in: stop navigating and reparent
					#Log.print("Pikmin reached carry point!")
					velocity = Vector3.ZERO
					current_state = State.WORKING

					# Save global transform (no scale/rotation changes)
					var global_xform := global_transform

					# Remove from squad container or idle container
					if get_parent():
						get_parent().remove_child(self)

					# Add to object being carried (the carryable)
					carryable_target.add_child(self)
					
					_navigation_agent.set_target_position(global_transform.origin)  # Clears nav path
					_navigation_agent.set_velocity_forced(Vector3.ZERO)  # Stop nav steering
					
					snap_to_ground()

					# ✅ Reapply original world transform (to avoid scale/stretch bugs)
					set_global_transform(global_xform)

					# Optional: align with the point visually (lock in)
					global_transform.origin = assigned_carry_point.global_transform.origin
					
					# actually commit weight to carryable
					carryable_target.lift += 1
					return
					
				move_and_slide()
			return

		State.THROWN:
			thrown_state_update(delta)
			return
			
		State.WORKING:
			if assigned_wall:
				# Face the wall
				var look_position = assigned_wall.global_transform.origin
				look_position.y = global_transform.origin.y  # Keep it on the same Y plane
				look_at(look_position, Vector3.UP)

				# Only damage once per second
				if Time.get_ticks_msec() - _last_wall_hit_time > 1000:
					_last_wall_hit_time = Time.get_ticks_msec()  # Lock timer immediately

					# Animate
					scale = Vector3(1.1, 0.9, 1.1)
					await get_tree().create_timer(0.1).timeout
					scale = Vector3.ONE

					# Recheck before dealing damage
					if assigned_wall and not assigned_wall.is_destroyed:
						assigned_wall.take_damage(1)
					else:
						# Stop working if wall is gone
						assigned_wall = null
						current_state = State.IDLE
				return
			if assigned_object:
				# flower for now
				# Face the object
				var look_position = assigned_object.global_transform.origin
				look_position.y = global_transform.origin.y  # Keep it on the same Y plane
				look_at(look_position, Vector3.UP)
				
				# Only damage once per second
				if Time.get_ticks_msec() - _last_wall_object_time > 1000:
					_last_wall_object_time = Time.get_ticks_msec()  # Lock timer immediately

					# Animate
					scale = Vector3(1.1, 0.9, 1.1)
					await get_tree().create_timer(0.1).timeout
					scale = Vector3.ONE

					# Recheck before dealing damage
					if assigned_object and not assigned_object.is_destroyed:
						assigned_object.take_damage(1)
					else:
						# Stop working if wall is gone
						assigned_object = null
						current_state = State.IDLE
				return
				
			elif carryable_target:
				# Face the target
				var look_position = carryable_target.global_transform.origin
				look_position.y = global_transform.origin.y  # Keep it on the same Y plane
				look_at(look_position, Vector3.UP)
				velocity = Vector3.ZERO
				return

	# Default pathing for FOLLOWING etc.
	if not _navigation_agent.is_navigation_finished():
		var next_position = _navigation_agent.get_next_path_position()
		var direction = (next_position - global_transform.origin).normalized()
		var distance = global_transform.origin.distance_to(target_position)

		if distance > 0.1:
			velocity = direction * SPEED
		else:
			velocity = Vector3.ZERO
	else:
		velocity = Vector3.ZERO  # ← add this to ensure no ghost sliding
	
	if velocity != Vector3.ZERO:
		move_and_slide()

func update_collision(state):
	if state == State.THROWN:
		# don't bump into player (layer 1)
		collision_mask &= ~(1)
	else:
		collision_mask |= (1)

# FOLLOWING state: Pikmin moves toward the target
func follow_target(_delta: float) -> void:
	if target_follow_point:
		target_position = target_follow_point.global_transform.origin  # Direct access
		target_position.y = 0.0
		_navigation_agent.set_target_position(target_position)

# POSITIONING state: Pikmin move to carry point and stay put
func positioning_state(_delta: float) -> void:
	pass
	#if target_position:
		##Log.print("moving to carry pos?")
		#_navigation_agent.set_target_position(target_position)
		
# WAITING state: Pikmin waits, can implement more advanced logic like idle animations here
func waiting_state(_delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are in the waiting state.
	
# IDLE state: Pikmin does nothing
func idle_state(_delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are idle.

# GATHERING state: Pikmin interacts with nearby objects (could be implemented later)
func gathering_state(_delta: float) -> void:
	pass  # Placeholder for any behavior when Pikmin are gathering.

func start_throw(origin_transform: Transform3D, direction: Vector3, reticle_distance: float):
	current_state = State.THROWN  # <--- CRITICAL
	update_collision(current_state)
	# Get the target position (reticle's position)
	var throw_target_position = origin_transform.origin + direction * reticle_distance

	# Calculate the horizontal distance to the target
	var horizontal_distance = Vector2(throw_target_position.x - global_transform.origin.x, throw_target_position.z - global_transform.origin.z).length()

	# Calculate the vertical distance to the target
	var vertical_distance = throw_target_position.y - global_transform.origin.y

	# Calculate the required initial velocity using kinematic equations
	var angle = 45.0 * (PI / 180)  # 45 degrees for a balanced arc (you can adjust this)
	var initial_speed = sqrt((gravity * horizontal_distance * horizontal_distance) / (2 * (horizontal_distance * tan(angle) - vertical_distance) * cos(angle) * cos(angle)))

	# Calculate the horizontal and vertical components of the velocity
	var horizontal_velocity = initial_speed * cos(angle)
	var vertical_velocity = initial_speed * sin(angle)

	# Apply the velocity in the direction of the reticle
	var throw_direction = Vector3(throw_target_position.x - global_transform.origin.x, 0, throw_target_position.z - global_transform.origin.z).normalized()
	velocity = throw_direction * horizontal_velocity
	velocity.y = vertical_velocity
	
	# make sure the throw target becomes the nav target when they land
	target_position = throw_target_position

func thrown_state_update(delta: float):
	velocity.y -= (gravity * delta)
	move_and_slide()

	# If we detect a collision or the Pikmin is on the ground again:
	if is_on_floor():
		# Transition back to WAITING or FOLLOWING, or do something else
		current_state = State.WAITING
		# ensure that the target pos is its current spot
		target_position.y = 0.0
		_navigation_agent.set_target_position(target_position)
		update_collision(current_state)
		velocity = Vector3.ZERO

func _on_area_entered(area: Area3D):
	#Log.print("Area entered: " + str(area.name))
	if current_state in [State.POSITIONING, State.WORKING, State.FOLLOWING] or assigned_carry_point != null:
		#var state_name = State.keys()[current_state]
		#Log.print("non-carry state: " + state_name)
		return
	var item = area.get_parent()
	if item.is_in_group("carryable"):
		#Log.print("carryable interaction")
		var point = item.get_available_carry_point(self)
		if point:
			target_position = point.global_transform.origin
			#Log.print("Cached carry point position: " + str(target_position))
			assigned_carry_point = point
			carryable_target = item
			current_state = State.POSITIONING
			#Log.print("Assigned carry point: " + str(assigned_carry_point))
			#Log.print("Pikmin assigned to carry point!")
	elif item.is_in_group("DestructibleWall"):
		Log.print("wall interaction")
		assigned_wall = item
		current_state = State.WORKING
		snap_to_ground()
	elif item.is_in_group("Flowers"):
		Log.print("flower interaction")
		assigned_object = item
		current_state = State.WORKING
		snap_to_ground()
		
func detach_from_carryable():
	if assigned_carry_point and carryable_target:
		#Log.print("Releasing a pikmin?")
		# Free up the carry point
		carryable_target.release_carry_point(assigned_carry_point)
		assigned_carry_point = null

		# Save current world position
		var xform := global_transform

		# Reparent to idle or player container (you’ll do this outside this method)
		carryable_target.remove_child(self)
		carryable_target = null

		# Reapply position
		global_transform = xform
		current_state = State.IDLE
		
func snap_to_ground():
	var space_state = get_world_3d().direct_space_state

	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.from = global_transform.origin + Vector3.UP * 1.0
	ray_params.to = global_transform.origin + Vector3.DOWN * 5.0
	ray_params.exclude = [self]

	var result = space_state.intersect_ray(ray_params)
	if result:
		global_transform.origin.y = result.position.y
