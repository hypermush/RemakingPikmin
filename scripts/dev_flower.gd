extends StaticBody3D

@export var max_health: int = 10

var current_health: int
var is_destroyed := false
@onready var flower_collision := $FlowerCollision
@onready var flower_interaction := $FlowerInteraction
@export var pellet_to_spawn : PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	# this group is what pikmin look for
	add_to_group("Flowers")
	
	if not pellet_to_spawn:
		Log.print("No spawnable pellet set!")

func take_damage(amount: int):
	if ! is_destroyed:
		current_health = current_health - amount
		Log.print("Flower health: " + str(current_health))
		if current_health < 1:
			destroy()
		
func destroy():
	is_destroyed = true
	flower_collision.disabled = true
	flower_interaction.monitoring = false

	var tween = create_tween()
	tween.tween_property(self, "global_transform:origin:y", global_transform.origin.y - 6.0, 0.3)
	await tween.finished

	# Tell Pikmin to stop
	for pikmin in get_tree().get_nodes_in_group("Pikmin"):
		if pikmin.assigned_object == self:
			pikmin.assigned_object = null
			pikmin.current_state = pikmin.State.IDLE

	# spawn in a pellet
	var pellet = pellet_to_spawn.instantiate()
	# up in the y pos otherwise it spawns below the world!
	pellet.global_transform.origin = self.global_transform.origin + Vector3(0, 4, 0)
	get_tree().current_scene.add_child(pellet)
	
	# actually delete the flower
	#queue_free()
