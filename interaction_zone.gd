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
@onready var _sprite: Sprite3D = %Sprite3D  # Reference to the Sprite3D node

@onready var _halo_mesh: MeshInstance3D = %ZoneHalo
@onready var _interact_zone: Area3D = %Area3D

@export var interaction_type: InteractionType = InteractionType.SHIP

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_interact_zone.body_entered.connect(bodyEntered)
	_interact_zone.body_exited.connect(bodyExited)
	
	_sprite.texture = _sub_viewport.get_texture()  # Set the SubViewport's texture as the sprite's texture
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# trying to detect when a body enters (signal)
func bodyEntered(body: Node3D):
	if body.is_in_group("Player"):
		body.current_interaction_zone = self  # Store reference to this zone
		Log.print("Player entered interaction zone.")
		
func bodyExited(body: Node3D):
	if body.is_in_group("Player"):
		body.current_interaction_zone = null  # Clear reference
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
