# Player Code:
extends CharacterBody3D

# temp test stuff for spawning pikmin at will
@export var pikmin_scene: PackedScene  # Drag and drop Pikmin.tscn in the inspector
@onready var _target_point: Node3D = %TargetPoint  # The point Pikmin will follow
#@onready var _pikmin_container: Node3D = $PikminContainer  # Empty Node3D for organization
var _pikmin_list: Array = [] # List to track Pikmin
@onready var _debug_spawn: Node3D = $PlayerSkin/DebugSpawnPoint
@export var _idle_pikmin_container: Node3D
@onready var _follow_count := 0
@export var follow_point: PackedScene # set in inspector
@onready var follow_source: Node3D = %FollowSource
@export var _starter_squad_size := 12

# follow layers
var layers1 = [2, 4, 4, 2]
var layers2 = [2, 4, 6, 6, 4, 2]
var layers3 = [2, 6, 6, 8, 8, 6, 6, 2]
var layers4 = [3, 7, 9, 9, 11, 11, 11, 9, 9, 7, 3]
var layers5 = [4, 6, 8, 10, 12, 12, 12, 12, 10, 8, 6, 4]
var squad_grid = layers1

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

var current_interaction_zone: Node3D = null  # Tracks the zone the player is in

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.FORWARD

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _skin: MeshInstance3D = %PlayerSkin
@onready var _camera_spring: SpringArm3D = %CameraSpringArm

# zoom distances
@export var zoom_close := 4.0
@export var zoom_middle := 7.0
@export var zoom_far := 12.0
var camera_zoom_target: float = zoom_middle

# camera angles (in degrees)
@export var angle_over_shoulder := -22.0 * (PI / 180)
@export var angle_birds_eye := -80 * (PI / 180)

# camera angle enums
enum CameraAngles {over_shoulder, birds_eye}
@export var _current_angle_enum = CameraAngles.over_shoulder
var camera_angle_target: float = angle_over_shoulder

@export var camera_tolerance := 0.01
@export var camera_update_speed := 12.0
var min_speed = 5.0
var update_camera_rotation = false
var camera_rotation_target := 0.0

@export_group("Movement")
# How fast the player moves in meters per second.
@export var move_speed := 5.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
# The downward acceleration when in the air, in meters per second squared
@export var fall_acceleration = 100

var target_velocity = Vector3.ZERO
var tracked_velocity = 0
var move_input = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_camera_spring.spring_length = zoom_middle
	_camera_pivot.rotation.x = angle_over_shoulder
	_camera_input_direction = Vector2.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # <-- Change this line
	
	if not _idle_pikmin_container:
		Log.print("no idle container set")
	
	# starter squad size
	for num in _starter_squad_size:
		add_follow_point()

func _process(delta):
	move_input.x = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	move_input.z = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	throw()
	update_reticle_position()
	
@onready var reticle: Node3D = $Reticle 
@export var reticle_distance: float = 10.0  # Default distance for the reticle

func _physics_process(delta: float) -> void:
	camera_logic(delta)
	player_movement(delta)
	interact_call()
	dismiss_pikmin()
	whistle_pikmin()
	dev_spawn_pikmin()
	mouse_cursor_visible()
	
# toggle between over the shoulder and bird's eye view
func toggle_camera_angle():
	if _current_angle_enum == CameraAngles.birds_eye:
		camera_angle_target = angle_over_shoulder
		_current_angle_enum = CameraAngles.over_shoulder
		Log.print("Camera Angle over shoulder")
	elif _current_angle_enum == CameraAngles.over_shoulder:
		camera_angle_target = angle_birds_eye
		_current_angle_enum = CameraAngles.birds_eye
		Log.print("Camera Angle birds eye")
	
# toggle between three zoom levels
func toggle_camera_zoom():
	if camera_zoom_target == zoom_middle:
		camera_zoom_target = zoom_far
		Log.print("Camera Zoom Far")
	elif camera_zoom_target == zoom_far:
		camera_zoom_target = zoom_close
		Log.print("Camera Zoom Close")
	elif camera_zoom_target == zoom_close:
		camera_zoom_target = zoom_middle
		Log.print("Camera Zoom Middle")
		
func set_interaction_zone(zone):
	current_interaction_zone = zone

func dismiss_squad():
	Log.print("dismiss called")
	for pikmin in _pikmin_list:
		if pikmin.is_in_group("pikmin"):
			pikmin.current_state = pikmin.State.IDLE
			pikmin.player = null  # Remove the reference to the player (no longer follows)
			_pikmin_list.erase(pikmin)
			pikmin.queue_free()
			Log.print("pikmin should now be idle")
	
func spawn_pikmin():
	if pikmin_scene:
		var pikmin = pikmin_scene.instantiate()  # Create a new Pikmin instance
		get_parent().add_child(pikmin)  # Moves Pikmin to scene root, outside of player movement
		_pikmin_list.append(pikmin)  # Parent it under a container node
		pikmin.global_transform.origin = _debug_spawn.global_transform.origin
		#Log.print("Making a pikmin at " + str(_debug_spawn.global_transform.origin))
		
		# Assign the player's target point and player reference
		pikmin.player = _skin
		
		if _pikmin_list.size() > _follow_count:
			#Log.print("new spot for new pikmin")
			add_follow_point()
			
		update_pikmin_follow_targets()
		
func _unhandled_input(event: InputEvent) -> void:
	pass
	

# Helpers: ========================

func player_movement(delta):
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# global basis based on camera
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	move_and_slide()
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	# rotating skin and not player itself, might need to change
	var target_angle := Vector3.FORWARD.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
	
	# for anims, not implemented yet
	var ground_speed := velocity.length()
	if ground_speed > 0.0:
		pass
		# anim move
	else:
		pass
		# anim idle

func dev_spawn_pikmin(): # dev use, press p to spawn pikmin
	if Input.is_action_just_pressed("spawn_pikmin"):
		spawn_pikmin()	

func mouse_cursor_visible():	# get mouse back in order to close window (escape)	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func dismiss_pikmin():
	# dismiss (x press, or y) on controller
	# Added X on keyboard
	if Input.is_action_just_pressed("dismiss"):
		SoundEffects.play_sound("dismiss-whistle")
		dismiss_squad()
		update_pikmin_follow_targets()
		
func whistle_pikmin():
	# whistle, b on controller, c on keyboard
	if Input.is_action_just_pressed("whistle"):
		#Log.print("whistle")
		# debugging squad shape mechanics
		# generating follow grid
		# pressing b will up the follow count
		#Log.print("Follow Count is now:" + str(_follow_count))
		# add follow point as child of follow source
		add_follow_point()
		

func add_follow_point():
	_follow_count += 1
	var new_follow_point = follow_point.instantiate()
	new_follow_point.name = "FollowPoint" + str(_follow_count)
	new_follow_point.transform.origin = Vector3(0, 0, 1.0)
	follow_source.add_child(new_follow_point)
	determine_grid()

func determine_grid():
	# multi grid based on follow count
	if _follow_count < 13:
		squad_grid = layers1
	elif _follow_count >= 13 and _follow_count < 25:
		squad_grid = layers2
	elif _follow_count >= 25 and _follow_count < 45:
		squad_grid = layers3
	elif _follow_count >= 45 and _follow_count < 90:
		squad_grid = layers4
	elif _follow_count >= 90 and _follow_count < 101:
		squad_grid = layers5
	elif _follow_count >= 101:
		Log.print("101+ is altogether too many  pikmin!")
		return
	generate_follow_positions(squad_grid)

func generate_follow_positions(squad_grid):
	#Log.print("Generate Called with squad grid:" + str(squad_grid))
	var follow_positions = []
	var pikmin_index = 0  # Tracks which Pikmin we're placing
	var row_z_offset = 0.5  # Distance between rows
	
	for row in range(squad_grid.size()):
		var num_in_row = squad_grid[row]
		var row_z = row * row_z_offset  # Move row further back
		var row_x_offset = 0.5  # Spacing between Pikmin
		var row_width = (num_in_row - 1) * row_x_offset  # Total row width
		var row_start_x = -row_width / 2  # Center row

		for i in range(num_in_row):
			# Calculate Pikmin position
			var x_pos = row_start_x + (i * row_x_offset)
			var z_pos = row_z
			follow_positions.append(Vector3(x_pos, 0, z_pos))  # Negative Z to follow player

			pikmin_index += 1

	# Now apply positions to follow points
	var follow_points = follow_source.get_children()
	for i in range(min(follow_points.size(), follow_positions.size())):
		follow_points[i].transform.origin = follow_positions[i]

func update_pikmin_follow_targets():
	var follow_points = follow_source.get_children()
	
	if _pikmin_list.is_empty() or follow_points.is_empty():
		Log.print("No Pikmin or follow points to assign!")
		return
		
	for i in range(min(_pikmin_list.size(), follow_points.size())):
		# Log.print("Assigning Pikmin " + str(i) + " to follow point " + str(follow_points[i].name))
		_pikmin_list[i].target_follow_point = follow_points[i]  # Assign reference

func interact_call():
	# interaction (A press)
	if Input.is_action_just_pressed("interact"):
		if current_interaction_zone:
			# Call a function on the zone to handle interaction
			current_interaction_zone.interact()
		else:
			Log.print("No interaction available.")

func throw():
	if Input.is_action_just_pressed("left_click"):
		throw_pikmin()

func throw_pikmin():
	# Find the first Pikmin in _pikmin_container that is in FOLLOWING state
	for pikmin in _pikmin_list:
		if pikmin.current_state == pikmin.State.FOLLOWING:
			# Calculate the direction to the reticle
			var throw_direction = (reticle.global_transform.origin - self.global_transform.origin).normalized()
			# Call a function on the Pikmin to handle the throw
			pikmin.start_throw(self.global_transform, throw_direction, reticle_distance)
			break

func camera_logic(delta):
	# camera inputs
	if Input.is_action_just_pressed("camera_angle"):
		toggle_camera_angle()
	if Input.is_action_just_pressed("camera_back"):
		Log.print("Camera Back")
		update_camera_rotation = true
		camera_rotation_target = _skin.global_rotation.y
	if Input.is_action_just_pressed("camera_zoom"):
		toggle_camera_zoom()
		
	if update_camera_rotation:
		var angle_diff = fposmod(camera_rotation_target - _camera_pivot.rotation.y + PI, TAU) - PI  # Normalize to [-PI, PI]
		
		if absf(angle_diff) > camera_tolerance:
			var t = absf(angle_diff) / PI  # Normalize [0, 1] based on how far we have to rotate
			var eased_speed = ease(t, -1.5) * camera_update_speed  # Smooth curve

			# Ensure a minimum rotation speed to prevent slow creep
			eased_speed = max(eased_speed, min_speed)

			_camera_pivot.rotation.y += sign(angle_diff) * min(absf(angle_diff), delta * eased_speed)
		else:
			update_camera_rotation = false
	# now do camera zoom
	var zoom_diff = camera_zoom_target - _camera_spring.spring_length

	if absf(zoom_diff) > camera_tolerance:  # Use tolerance to stop smoothly
		var t = absf(zoom_diff) / (zoom_far - zoom_close)  # Normalize [0, 1]
		var eased_speed = ease(t, -1.5) * camera_update_speed  # Use same curve

		eased_speed = max(eased_speed, min_speed)  # Ensure minimum speed
		_camera_spring.spring_length += sign(zoom_diff) * min(absf(zoom_diff), delta * eased_speed)
	# finally camera angle
	var angle_diff = camera_angle_target - _camera_pivot.rotation.x

	if absf(angle_diff) > camera_tolerance:
		var t = absf(angle_diff) / absf(angle_birds_eye - angle_over_shoulder)  # Normalize [0, 1]
		var eased_speed = ease(t, -1.5) * camera_update_speed  

		eased_speed = max(eased_speed, min_speed)  # Ensure minimum speed
		_camera_pivot.rotation.x += sign(angle_diff) * min(absf(angle_diff), delta * eased_speed)

func update_reticle_position():
	var camera = _camera
	var viewport = get_viewport()
	var mouse_position = viewport.get_mouse_position()

	# Create a ray from the camera through the mouse position
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_direction = camera.project_ray_normal(mouse_position)
	var ray_length = 1000.0  # Adjust this based on your game's scale

	# Create PhysicsRayQueryParameters3D
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = ray_origin
	ray_params.to = ray_origin + ray_direction * ray_length
	ray_params.collision_mask = 1  # Adjust collision mask as needed

	# Perform the raycast
	var space_state = get_world_3d().direct_space_state
	var ray_result = space_state.intersect_ray(ray_params)

	if ray_result:
		# Place the reticle at the intersection point
		reticle.global_transform.origin = ray_result.position
	else:
		# If no intersection, place the reticle at a default distance
		reticle.global_transform.origin = ray_origin + ray_direction * reticle_distance
