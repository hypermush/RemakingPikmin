class_name DevFlower
extends Workable

@onready var flower_collision := $FlowerCollision
@onready var flower_interaction := $FlowerInteraction
@export var pellet_to_spawn : PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("Workable")
		
func destroy():
	super()  # handles is_destroyed flag + pikmin cleanup
	flower_collision.disabled = true
	flower_interaction.monitoring = false

	var tween = create_tween()
	tween.tween_property(self, "global_transform:origin:y", global_transform.origin.y - 6.0, 0.3)
	await tween.finished

	# spawn in a pellet
	var pellet = pellet_to_spawn.instantiate()
	# up in the y pos otherwise it spawns below the world!
	pellet.global_transform.origin = self.global_transform.origin + Vector3(0, 4, 0)
	get_tree().current_scene.add_child(pellet)
	
	# actually delete the flower
	#queue_free()
