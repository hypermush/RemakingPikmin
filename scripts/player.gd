# Player Code:
extends CharacterBody3D

# temp test stuff for spawning pikmin at will
@export var pikmin_scene: PackedScene  # Drag and drop Pikmin.tscn in the inspector
@onready var _target_point: Node3D = %TargetPoint  # The point Pikmin will follow
@onready var _pikmin_container: Node3D = $PikminContainer  # Empty Node3D for organization
@onready var _debug_spawn: Node3D = $PlayerSkin/DebugSpawnPoint
@export var _idle_pikmin_container: Node3D

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
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# default zoom is middle, default angle is over shoulder
	_camera_spring.spring_length = zoom_middle
	_camera_pivot.rotation.x = angle_over_shoulder
	
	if not _idle_pikmin_container:
		Log.print("no idle container set")
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta):
	move_input.x = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	move_input.z = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# camera shit
	#_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO
	
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
	
	# get mouse back in order to close window (escape)	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# camera inputs
	if Input.is_action_just_pressed("camera_angle"):
		toggle_camera_angle()
	if Input.is_action_just_pressed("camera_back"):
		Log.print("Camera Back")
		update_camera_rotation = true
		camera_rotation_target = _skin.global_rotation.y
	if Input.is_action_just_pressed("camera_zoom"):
		toggle_camera_zoom()
		
	# check if camera needs to move
	# camera back
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
		
	# interaction (A press)
	if Input.is_action_just_pressed("interact"):
		if current_interaction_zone:
			# Call a function on the zone to handle interaction
			current_interaction_zone.interact()
		else:
			Log.print("No interaction available.")
	
	# dismiss (x press, or y)
	if Input.is_action_just_pressed("dismiss"):
		dismiss_squad()
	
	# dev use, press p to pikmin
	if Input.is_action_just_pressed("spawn_pikmin"):
		spawn_pikmin()
	
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
	for pikmin in _pikmin_container.get_children():
		if pikmin.is_in_group("pikmin"):
			pikmin.current_state = pikmin.State.IDLE
			pikmin.player = null  # Remove the reference to the player (no longer follows)
			pikmin.reparent(_idle_pikmin_container)  # Move the Pikmin to the idle container
			Log.print("pikmin should now be idle")
	
func spawn_pikmin():
	if pikmin_scene:
		var pikmin = pikmin_scene.instantiate()  # Create a new Pikmin instance
		_pikmin_container.add_child(pikmin)  # Parent it under a container node
		pikmin.global_transform.origin = _debug_spawn.global_transform.origin
		Log.print("Making a pikmin at " + str(_debug_spawn.global_transform.origin))
		
		# Assign the player's target point and player reference
		pikmin.player = _skin
		#pikmin._target = _target_point
		pikmin.gathering_zone_size = Vector2(%ArmyArea.scale.x, %ArmyArea.scale.z)

func _unhandled_input(event: InputEvent) -> void:
	pass

#func is_on_floor():    
	##test_move returns true if the movement provided would cause a collision, but does not move anything
	#if test_move(transform, Vector3.DOWN*0.0001 * get_physics_process_delta_time() ) == true:  
		#return true  
	#else:  
		#return false 
