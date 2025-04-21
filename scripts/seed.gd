extends RigidBody3D

# onion tells the seed both of these
@export var pikmin_scene: PackedScene
@export var player: Node3D  # Set this when the seed is created
var has_landed := false  # To prevent double-triggering
@onready var poof_particles = $PoofParticles

func _ready():
	contact_monitor = true
	max_contacts_reported = 2  # How many contacts to report

func _physics_process(delta):
	if not has_landed and get_contact_count() > 0:
		has_landed = true
		freeze_seed()
	
func pluck():
	#Log.print("Seed has been plucked!")
	if pikmin_scene and player:
		var pikmin = pikmin_scene.instantiate()
		pikmin.global_transform.origin = global_transform.origin
		player.add_pikmin_to_squad(pikmin)
		queue_free()
		
func freeze_seed():
	# Snap rotation to upright
	var xform = global_transform
	xform.basis = Basis()  # Reset rotation
	global_transform = xform

	# Raycast down to find ground
	var space_state = get_world_3d().direct_space_state
	var from = global_transform.origin + Vector3.UP * 0.5
	var to = global_transform.origin + Vector3.DOWN * 2.0

	var ray = PhysicsRayQueryParameters3D.new()
	ray.from = from
	ray.to = to
	ray.exclude = [self]

	var result = space_state.intersect_ray(ray)
	if result:
		global_transform.origin.y = result.position.y

	freeze = true
