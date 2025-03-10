extends Node3D

var forward = global_transform.basis.z # Player's forward direction (not negated)
var right = global_transform.basis.x   # Player's right direction
var up = global_transform.basis.y      # Player's up direction

var offsets = [
	forward * 3,   # Close over-the-shoulder
	forward * 5,   # Middle over-the-shoulder
	forward * 7,   # Far over-the-shoulder
	up * 3 + forward * 2,  # Close bird's-eye (higher up)
	up * 5 + forward * 2,  # Middle bird's-eye (higher up)
	up * 7 + forward * 2   # Far bird's-eye (highest up)
]
var zoom_gap = 2.5  # Distance between each zoom level

func _ready():
	for base_offset in offsets:
		for i in range(3):  # Generate close, mid, far
			var offset = base_offset + Vector3(0, 0, -i * zoom_gap)  # Just add the vector
			var transform_offset = Transform3D()  # Create a new Transform3D
			transform_offset.origin = offset  # Set the origin to the calculated offset
			create_marker(transform_offset, Color(1, 0, 0))

func create_marker(offset: Transform3D, color: Color):
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = SphereMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.set_surface_override_material(0, mat)
	mesh_instance.transform = offset
	add_child(mesh_instance)
