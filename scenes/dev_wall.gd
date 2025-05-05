extends StaticBody3D

@export var max_health: int = 10

var current_health: int
var is_destroyed := false
@onready var wall_collision := $WallCollision
@onready var wall_interaction := $WallInteraction
@export var obstacle : NavigationObstacle3D
@export var navigation_region: NavigationRegion3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	# this group is what pikmin look for
	add_to_group("DestructibleWall")
	
	# tell me about the obstacle:
	#Log.print("Obstacle affect nav mesh?:" + str(obstacle.affect_navigation_mesh))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func take_damage(amount: int):
	if ! is_destroyed:
		current_health = current_health - amount
		Log.print("Wall health: " + str(current_health))
		if current_health < 1:
			destroy()
		
func destroy():
	is_destroyed = true
	wall_collision.disabled = true
	wall_interaction.monitoring = false

	var tween = create_tween()
	tween.tween_property(self, "global_transform:origin:y", global_transform.origin.y - 5.0, 0.3)
	await tween.finished

	# Tell Pikmin to stop
	for pikmin in get_tree().get_nodes_in_group("Pikmin"):
		if pikmin.assigned_wall == self:
			pikmin.assigned_wall = null
			pikmin.current_state = pikmin.State.IDLE

	# this is the part that makes it not block anymore
	obstacle.set_affect_navigation_mesh(false)
	# this is the rebake to make that change ^ have effect
	navigation_region.bake_navigation_mesh()
	Log.print("Change in obstacle?")
	
	# actually delete the wall
	# I think it looks better if you can still see the wall tho :)
	#queue_free()
