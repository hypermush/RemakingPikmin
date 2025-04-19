extends RigidBody3D

# onion tells the seed both of these
@export var pikmin_scene: PackedScene
@export var player: Node3D  # Set this when the seed is created
var has_landed := false  # To prevent double-triggering
@onready var poof_particles = $PoofParticles

func _ready():
	contact_monitor = true
	max_contacts_reported = 1  # How many contacts to report

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
	#Log.print("Seed landed. Freezing in place.")

	# Snap rotation to upright
	var xform = global_transform
	xform.basis = Basis()  # Reset rotation to identity (upright)
	global_transform = xform

	freeze = true  # Stop simulation
	poof_particles.restart()
	poof_particles.emitting = true
