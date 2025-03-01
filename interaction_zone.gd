extends Node3D

# placeholder values
enum InteractionType {
	SHIP,
	DOOR,
	NPC,
	CHEST
}

# UI nonsense
@onready var _sub_viewport: SubViewport = %SubViewport  # Reference to the SubViewport
@onready var _uimesh: MeshInstance3D = %UIMesh

@onready var _halo_mesh: MeshInstance3D = %ZoneHalo
@onready var _interact_zone: Area3D = %Area3D

@export var interaction_type: InteractionType = InteractionType.SHIP

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_interact_zone.body_entered.connect(bodyEntered)
	_interact_zone.body_exited.connect(bodyExited)
	
	# mesh way that we like
	_uimesh.visible = false
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not _uimesh.visible:
		return  # No need to update if it's not visible
		
	var camera = get_viewport().get_camera_3d()
	if camera:
		# Get direction to the camera
		var to_camera = (camera.global_transform.origin - _uimesh.global_transform.origin).normalized()
		
		# Allow full 3D facing (no more squishing from bird’s eye)
		var current_scale = _uimesh.scale  # Preserve current scale
		_uimesh.basis = Basis.looking_at(-to_camera, Vector3.UP)
		_uimesh.scale = current_scale  # Restore the scale after setting the basis)
		
		# Adjust scale dynamically based on distance
		var distance = _uimesh.global_transform.origin.distance_to(camera.global_transform.origin)
		#_uimesh.scale = Vector3.ONE * clamp(distance * 0.1, 0.5, 2.0)  # Adjust min/max as needed)
		
# trying to detect when a body enters (signal)
func bodyEntered(body: Node3D):
	if body.is_in_group("Player"):
		body.current_interaction_zone = self  # Store reference to this zone
		_uimesh.visible = true
		Log.print("Player entered interaction zone.")
		
func bodyExited(body: Node3D):
	if body.is_in_group("Player"):
		body.current_interaction_zone = null  # Clear reference
		_uimesh.visible = false
		Log.print("Player left interaction zone.")
		
func interact():
	match interaction_type:
		InteractionType.SHIP:
			#open_ship_menu()
			pass
		InteractionType.DOOR:
			#open_door()
			pass
		InteractionType.NPC:
			#start_npc_dialogue()
			pass
		InteractionType.CHEST:
			#open_chest()
			pass
	Log.print("Interaction happened: " + InteractionType.find_key(interaction_type))
