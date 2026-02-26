class_name DevWall
extends Workable

@onready var wall_collision := $WallCollision
@onready var wall_interaction := $WallInteraction
@export var obstacle : NavigationObstacle3D
@export var navigation_region: NavigationRegion3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("Workable")
		
func destroy():
	super()  # handles is_destroyed flag + pikmin cleanup
	wall_collision.disabled = true
	wall_interaction.monitoring = false

	var tween = create_tween()
	tween.tween_property(self, "global_transform:origin:y", global_transform.origin.y - 5.0, 0.3)
	await tween.finished

	# this is the part that makes it not block anymore
	obstacle.set_affect_navigation_mesh(false)
	# this is the rebake to make that change ^ have effect
	navigation_region.bake_navigation_mesh()
	#Log.print("Change in obstacle?")
	
	# actually delete the wall
	# I think it looks better if you can still see the wall tho :)
	#queue_free()
