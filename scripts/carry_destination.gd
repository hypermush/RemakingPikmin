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
	#connect("reached_destination", Callable(self, "_on_carryable_reached_destination"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func get_dropoff_position():
	return dropoff_point.global_transform.origin
	
func _on_carryable_reached_destination(payload: Dictionary):
	Log.print("Final call of destination reached!")
	if payload.has("weight"):
		var pikmin_to_spawn = payload["weight"]
		# spawn_pikmin(pikmin_to_spawn)
