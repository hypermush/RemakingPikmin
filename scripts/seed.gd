extends StaticBody3D

# onion tells the seed both of these
@export var pikmin_scene: PackedScene
@export var player: Node3D  # Set this when the seed is created

func _ready():
	pass
	
func pluck():
	Log.print("Seed has been plucked!")
	if pikmin_scene and player:
		var pikmin = pikmin_scene.instantiate()
		pikmin.global_transform.origin = global_transform.origin
		player.add_pikmin_to_squad(pikmin)
		queue_free()
