extends Node3D

@onready var _halo_mesh: MeshInstance3D = %ZoneHalo
@onready var _interact_zone: Area3D = %Area3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _interact_zone.has_overlapping_bodies():
		Log.print("Body entered: " + str(_interact_zone.get_overlapping_bodies()))

# trying to detect when a body enters (signal)
func _bodyEntered():
	pass
