extends Node3D

# Destination tyle
enum DestinationType {
	SHIP,
	ONION,
}

@onready var dropoff_point: Node3D = $DropoffPoint
@export var destination_type: DestinationType


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not destination_type:
		Log.print("Destination is missing type!")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func get_dropoff_position():
	return dropoff_point.global_transform.origin
