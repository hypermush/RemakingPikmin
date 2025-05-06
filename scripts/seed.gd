extends RigidBody3D

# onion tells the seed both of these
@export var pikmin_scene: PackedScene
@export var player: Node3D  # Set this when the seed is created
var has_landed := false  # To prevent double-triggering
@onready var poof_particles = $PoofParticles
@onready var trail_particles = $TrailParticles

func _ready():
	contact_monitor = true
	max_contacts_reported = 2  # How many contacts to report
	# Turn off trail initially
	trail_particles.emitting = false

func _physics_process(_delta):
	if not has_landed and get_contact_count() > 0:
		has_landed = true
		freeze_seed()
	
func pluck():
	if pikmin_scene and player:
		var spawn_position = global_transform.origin  # Get seed's position

		var pikmin = pikmin_scene.instantiate()
		get_tree().current_scene.add_child(pikmin)  # Must add to tree first
		pikmin.global_transform = Transform3D(Basis(), spawn_position)

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
	poof_particles.restart()
	poof_particles.emitting = true
	stop_trail()
	
func start_trail():
	trail_particles.emitting = true

func stop_trail():
	trail_particles.emitting = false
