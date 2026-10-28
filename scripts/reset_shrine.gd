extends StaticBody3D

# Reset shrine: touch it with the snake in pull mode (right-click) and every block,
# phase block, and cord listed in targets snaps back to where it started.
# Lit braziers and latched doors are not affected.
# Builds its own mesh and collision.

@export var targets: Array[NodePath] = []

var starts = {}      # node path -> starting global transform
var cooldown = 0.0
var glow_mat: StandardMaterial3D
var ring: MeshInstance3D

func _ready():
	collision_layer = 1
	collision_mask = 0

	var stone = StandardMaterial3D.new()
	stone.albedo_color = Color(0.3, 0.28, 0.34)
	var base = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.38
	cyl.height = 0.9
	cyl.material = stone
	base.mesh = cyl
	base.position.y = 0.45
	add_child(base)

	glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.9, 0.85, 0.5)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.8, 0.7, 0.3)
	glow_mat.emission_energy_multiplier = 0.8
	ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.26
	torus.material = glow_mat
	ring.mesh = torus
	ring.position.y = 0.95
	add_child(ring)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.7, 1.0, 0.7)
	col.shape = shape
	col.position.y = 0.5
	add_child(col)

	call_deferred("_record")

func _record():
	for p in targets:
		var n = get_node_or_null(p)
		if n is Node3D:
			starts[p] = n.global_transform

func _process(delta):
	cooldown = max(cooldown - delta, 0.0)
	ring.rotation.y += delta * (4.0 if cooldown > 0.0 else 0.6)

# The snake calls pull() on anything it touches in pull mode (same as levers)
func pull():
	if cooldown > 0.0:
		return
	cooldown = 1.5
	for p in starts.keys():
		var n = get_node_or_null(p)
		if n == null:
			continue
		if n.has_method("reset_home"):
			n.reset_home()
			continue
		if n is RigidBody3D:
			n.linear_velocity = Vector3.ZERO
			n.angular_velocity = Vector3.ZERO
		n.global_transform = starts[p]
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("show_notification"):
		gm.show_notification("The room resets", 1.5)
