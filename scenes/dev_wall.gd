extends StaticBody3D

@export var max_health: int = 10

var current_health: int
var is_destroyed := false
@onready var wall_collision := $WallCollision
@onready var wall_interaction := $WallInteraction

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	# this group is what pikmin look for
	add_to_group("DestructibleWall")

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
	# Disable collision
	wall_collision.disabled = true
	wall_interaction.monitoring = false

	# Animate downward over 0.5s
	var tween = create_tween()
	tween.tween_property(self, "global_transform:origin:y", global_transform.origin.y - 4.0, 0.3)

	await tween.finished
	# Tell all Pikmin to stop working on this wall
	for pikmin in get_tree().get_nodes_in_group("Pikmin"):
		if pikmin.assigned_wall == self:
			pikmin.assigned_wall = null
			pikmin.current_state = pikmin.State.IDLE
			
	queue_free()
