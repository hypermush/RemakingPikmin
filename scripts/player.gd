# Player Code:
extends CharacterBody3D

# signals
signal update_hud_values(hud_vals)

# temp test stuff for spawning pikmin at will
@export var pikmin_scene: PackedScene  # Drag and drop Pikmin.tscn in the inspector
var _pikmin_list: Array = [] # List to track Pikmin
@onready var _debug_spawn: Node3D = $PlayerSkin/DebugSpawnPoint
# these two are for scene tree organization
@export var _idle_pikmin_container: Node3D
@export var _squad_pikmin_container: Node3D

@onready var whistle_mesh = $WhistleArea/WhistleCollision/WhistleMesh
@onready var whistle_collision = $WhistleArea

@onready var _follow_count := 0
@export var follow_point: PackedScene # set in inspector
@onready var follow_source: Node3D = %FollowSource

# follow layers
var squad_layers = [
	[2, 4, 4, 2],  # layers1
	[2, 4, 6, 6, 4, 2],  # layers2
	[3, 5, 7, 7, 7, 5, 3], # layers3
	[2, 6, 6, 8, 8, 6, 6, 2],  # layers4
	[3, 5, 7, 9, 9, 9, 7, 5, 3], #layers5
	[2, 6, 8, 8, 10, 10, 8, 8, 6, 2], #layer6
	[3, 7, 9, 9, 11, 11, 11, 9, 9, 7, 3],  # layers7
	[4, 6, 8, 10, 12, 12, 12, 12, 10, 8, 6, 4]  # layers8
]
var squad_formations = []
var max_pikmin_count = 100  # Estimated upper limit
var last_grid_index := -1

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

@onready var reticle: Node3D = $Reticle 
@export var reticle_distance: float = 10.0  # Default distance for the reticle

var target_velocity = Vector3.ZERO

var _formation_dirty := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# camera setup
	_camera_spring.spring_length = zoom_middle
	_camera_pivot.rotation.x = angle_over_shoulder
	_camera_input_direction = Vector2.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # <-- Change this line before release
	
	# check for scene container references
	if not _idle_pikmin_container:
		Log.print("no idle container set")
	if not _squad_pikmin_container:
		Log.print("no squad container set")
		
	# generate squad formations ahead of time
	pre_generate_positions()
	
	# recruitment
	$RecruitmentArea.body_entered.connect(_on_recruitment_body_entered)
	
	# whistle
	whistle_collision.body_entered.connect(_on_whistle_body_entered)

func pre_generate_positions():
	squad_formations.clear()  # Ensure we start fresh
		# Ensure we have enough follow points
	while _follow_count < max_pikmin_count:
		add_follow_point()  # Create new follow points

	for i in range(squad_layers.size()):
		#Log.print("Generating squad layer:" + str(i))
		var formation = generate_follow_positions(squad_layers[i])  # Generate once
		squad_formations.append(formation)  # Store it in the matching index

func _process(_delta):
	throw()
	update_reticle_position()

func _physics_process(delta: float) -> void:
	camera_logic(delta)
	player_movement(delta)
	interact_call()
	dismiss_pikmin()
	whistle_pikmin()
	dev_spawn_pikmin()
	mouse_cursor_visible()
	if _formation_dirty:
		update_pikmin_follow_targets()
		_formation_dirty = false

func _on_recruitment_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Pikmin"):
		return
	if body.current_state == body.State.WAITING or body.current_state == body.State.IDLE:
		body.current_state = body.State.FOLLOWING
		_idle_pikmin_container.remove_child(body)
		_squad_pikmin_container.add_child(body)
		_pikmin_list.append(body)
		body.player = self
		_formation_dirty = true

#func check_pikmin_recruitment():
	#var space_state = get_world_3d().direct_space_state
	#var query = PhysicsShapeQueryParameters3D.new()
	#query.set_shape($RecruitmentAreaShape.shape)  # Make this a small sphere or box
	#
	#query.transform = $RecruitmentAreaShape.global_transform  # Set the query's position
	#query.collision_mask = 2  # Detect Pikmin layer (Layer 2)
#
	#var results = space_state.intersect_shape(query, 10)
	#for result in results:
		#var pikmin = result.collider
		#if pikmin and (pikmin.current_state == pikmin.State.WAITING
					#or pikmin.current_state == pikmin.State.IDLE):
			#pikmin.current_state = pikmin.State.FOLLOWING
			#_idle_pikmin_container.remove_child(pikmin)
			#_squad_pikmin_container.add_child(pikmin)
			#_pikmin_list.append(pikmin)
			#pikmin.player = self
			#update_pikmin_follow_targets()
			##Log.print("Pikmin Collision, Following?")

func add_pikmin_to_idle(pikmin: Node3D):
	if _idle_pikmin_container:
		_idle_pikmin_container.add_child(pikmin)
		pikmin.player = self  # Reset in case it was unset
	pikmin.target_position = pikmin.global_transform.origin
	pikmin.current_state = pikmin.State.IDLE
	pikmin.velocity = Vector3.ZERO
	pikmin._navigation_agent.set_target_position(pikmin.target_position)
	
func add_pikmin_to_squad(pikmin: Node3D):
	if pikmin.get_parent():
		pikmin.get_parent().remove_child(pikmin)
	
	if _squad_pikmin_container:
		_squad_pikmin_container.add_child(pikmin)
		_pikmin_list.append(pikmin)
		pikmin.player = self
		pikmin.current_state = pikmin.State.FOLLOWING
		_formation_dirty = true
		
		# update UI HUD
		emit_signal("update_hud_values", _pikmin_list.size())
	
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

func spawn_pikmin():
	if pikmin_scene:
		var pikmin = pikmin_scene.instantiate()  # Create a new Pikmin instance
		_squad_pikmin_container.add_child(pikmin)
		_pikmin_list.append(pikmin)
		pikmin.global_transform.origin = _debug_spawn.global_transform.origin
		#Log.print("Making a pikmin at " + str(_debug_spawn.global_transform.origin))
		
		# Assign the player's target point and player reference
		pikmin.player = self
			
		_formation_dirty = true
		
		# update UI HUD
		emit_signal("update_hud_values", _pikmin_list.size())

func _unhandled_input(_event: InputEvent) -> void:
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
	if Input.is_action_just_pressed("spawn_pikmin") and _pikmin_list.size() < max_pikmin_count:
		spawn_pikmin()

func mouse_cursor_visible():	# get mouse back in order to close window (escape)	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func dismiss_pikmin():
	# dismiss (x press, or y) on controller
	# Added X on keyboard
	if Input.is_action_just_pressed("dismiss"):
		SoundEffects.play_sound("dismiss-whistle")
		Log.print("dismiss called")
		for pikmin in _pikmin_list:
			if pikmin.is_in_group("pikmin"):
				pikmin.current_state = pikmin.State.IDLE
				pikmin.player = null  # Remove the reference to the player (no longer follows)
				_squad_pikmin_container.remove_child(pikmin)
				_idle_pikmin_container.add_child(pikmin)
				#Log.print("pikmin should now be idle")
		_pikmin_list.clear()
		_formation_dirty = true

#func whistle_pikmin():
	## whistle, b on controller, c on keyboard
	#if Input.is_action_pressed("whistle"):
		#whistle_collision.position = Vector3(reticle.position.x, whistle_collision.position.y, reticle.position.z)
		#whistle_mesh.visible = true
		#
		## Check for Pikmin within the whistle area
		#var space_state = get_world_3d().direct_space_state
		#var query = PhysicsShapeQueryParameters3D.new()
		#query.set_shape(whistle_collision.shape)  # The collision shape for the whistle
		#
		#query.transform = whistle_collision.global_transform  # Set the query's position
		#query.collision_mask = 2  # Detect Pikmin layer (Layer 2)
#
		#var results = space_state.intersect_shape(query, 10)
		#for result in results:
			#var pikmin = result.collider
			#if pikmin and (pikmin.current_state == pikmin.State.WAITING or pikmin.current_state == pikmin.State.IDLE):
				##var state_name = pikmin.State.keys()[pikmin.current_state]
				## Log.print("Whistled Pikmin state before following: "+ str(state_name))
				## Recruit Pikmin (same logic as recruitment collider)
				#pikmin.current_state = pikmin.State.FOLLOWING
				#_idle_pikmin_container.remove_child(pikmin)
				#_squad_pikmin_container.add_child(pikmin)
				#_pikmin_list.append(pikmin)
				#pikmin.player = self
			#elif pikmin and (pikmin.current_state == pikmin.State.WORKING):
				##Log.print("Dude is working!")
				## detach from carryable
				#pikmin.detach_from_carryable()
				#
				## do other stuff to move them to player's group
				#pikmin.current_state = pikmin.State.FOLLOWING
				#_squad_pikmin_container.add_child(pikmin)
				#_pikmin_list.append(pikmin)
				#pikmin.player = self
		#update_pikmin_follow_targets()
	#else:
		#whistle_mesh.visible = false

func whistle_pikmin() -> void:
	if Input.is_action_just_pressed("whistle"):
		# Catch Pikmin already inside the area when whistle starts
		for body in whistle_collision.get_overlapping_bodies():
			_try_whistle_pikmin(body)

	if Input.is_action_pressed("whistle"):
		whistle_collision.position = Vector3(reticle.position.x, whistle_collision.position.y, reticle.position.z)
		whistle_mesh.visible = true
	else:
		whistle_mesh.visible = false

func _on_whistle_body_entered(body: Node3D) -> void:
	if Input.is_action_pressed("whistle"):
		_try_whistle_pikmin(body)
		
func _try_whistle_pikmin(body: Node3D) -> void:
	if not body.is_in_group("Pikmin"):
		return
	if body.is_queued_for_deletion():
		return
	if body.current_state == body.State.WAITING or body.current_state == body.State.IDLE:
		body.current_state = body.State.FOLLOWING
		_idle_pikmin_container.remove_child(body)
		_squad_pikmin_container.add_child(body)
		_pikmin_list.append(body)
		body.player = self
	elif body.current_state == body.State.WORKING:
		body.detach_from_carryable()
		body.current_state = body.State.FOLLOWING
		_idle_pikmin_container.remove_child(body)
		_squad_pikmin_container.add_child(body)
		_pikmin_list.append(body)
		body.player = self
	_formation_dirty = true

func add_follow_point():
	_follow_count += 1
	var new_follow_point = follow_point.instantiate()
	new_follow_point.name = "FollowPoint" + str(_follow_count)
	new_follow_point.transform.origin = Vector3(0, 0, 1.0)
	follow_source.add_child(new_follow_point)

func determine_grid(pikmin_count: int) -> int:
	#Log.print("Grid size is: " + str(pikmin_count))
	var index := 0
	if pikmin_count < 13:
		index = 0
	elif pikmin_count < 25:
		index = 1
	elif pikmin_count < 38:
		index = 2
	elif pikmin_count < 45:
		index = 3
	elif pikmin_count < 58:
		index = 4
	elif pikmin_count < 69:
		index = 5
	elif pikmin_count < 90:
		index = 6
	elif pikmin_count < 101:
		index = 7
	else:
		Log.print("101+ is too many Pikmin!")
		index = 7  # Use the largest grid by default
	
	# reroll the random offsets in the grid:
	if index != last_grid_index:
		squad_formations[index] = generate_follow_positions(squad_layers[index])
		last_grid_index = index
	
	return index

func generate_follow_positions(current_squad_grid) -> Array:
	var follow_positions = []
	var row_z_offset = 0.5  # Distance between rows

	for row in range(current_squad_grid.size()):
		var num_in_row = current_squad_grid[row]
		var row_z = row * row_z_offset
		var row_x_offset = 0.5
		var row_width = (num_in_row - 1) * row_x_offset
		var row_start_x = -row_width / 2

		var row_positions = []
		for i in range(num_in_row):
			# Add small random offset for more natural placement
			var jitter_x = randf_range(-0.1, 0.1)
			var jitter_z = randf_range(-0.1, 0.1)
			var x_pos = row_start_x + (i * row_x_offset) + jitter_x
			var z_pos = row_z + jitter_z
			row_positions.append(Vector3(x_pos, 0, z_pos))

		if row % 2 == 1:
			row_positions.reverse()

		follow_positions.append_array(row_positions)

	return follow_positions

func update_pikmin_follow_targets():
	var current_index = determine_grid(_pikmin_list.size())  # Determine which formation to use
	var follow_positions = squad_formations[current_index]  # Fetch precomputed formation

	# Apply positions to follow points
	var follow_points = follow_source.get_children()
	
	# Disable excess follow points
	for i in range(follow_points.size()):
		follow_points[i].visible = i < follow_positions.size()  # Show only needed points
	
	# Ensure there's no mismatch
	if _pikmin_list.is_empty() or follow_positions.is_empty():
		return
		
	# Assign Pikmin to follow points
	for i in range(min(_pikmin_list.size(), follow_positions.size())):
		follow_points[i].transform.origin = follow_positions[i]  # Move point to formation position
		_pikmin_list[i].target_follow_point = follow_points[i]  # Assign follow targeterence

func interact_call():
	if Input.is_action_just_pressed("interact"):
		if current_interaction_zone:
			current_interaction_zone.interact()
		else:
			# No zone — look for seeds to pluck
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsShapeQueryParameters3D.new()
			query.set_margin(0.05)
			query.set_shape($InteractionArea.shape)
			query.transform = $InteractionArea.global_transform
			query.collision_mask = 16  # Use a new layer just for seeds

			var results = space_state.intersect_shape(query, 10)
			#Log.print("Seeds found: " + str(results.size()))
			for result in results:
				var current_seed = result.collider
				if current_seed and current_seed.has_method("pluck"):
					current_seed.pluck()
					return  # Only pluck one seed at a time

func throw():
	if Input.is_action_just_pressed("left_click"):
		throw_pikmin()

func throw_pikmin():
	# Find the first Pikmin in _pikmin_list that is in FOLLOWING state
	for pikmin in _pikmin_list:
		if pikmin.current_state == pikmin.State.FOLLOWING:
			# Calculate the direction to the reticle
			var throw_direction = (reticle.global_transform.origin - self.global_transform.origin).normalized()
			# Call a function on the Pikmin to handle the throw
			pikmin.start_throw(self.global_transform, throw_direction, reticle_distance)
			pikmin.target_follow_point = null
			_squad_pikmin_container.remove_child(pikmin)
			_idle_pikmin_container.add_child(pikmin)
			_pikmin_list.erase(pikmin)
			break
			
	_formation_dirty = true

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
	
	var angle_diff
	if update_camera_rotation:
		angle_diff = fposmod(camera_rotation_target - _camera_pivot.rotation.y + PI, TAU) - PI  # Normalize to [-PI, PI]
		
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
	angle_diff = camera_angle_target - _camera_pivot.rotation.x

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
