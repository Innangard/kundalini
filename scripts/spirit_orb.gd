extends Area3D

# Spirit orb — collectible only in spirit world
# Snake eats these on right-click contact in spirit world

@export var bob_speed: float = 2.0
@export var bob_height: float = 0.15
@export var spin_speed: float = 1.5

var base_y: float = 0.0
var time: float = 0.0
var orb_mesh: MeshInstance3D
var glow_mesh: MeshInstance3D

func _ready():
	# Collision setup — layer 16 (spirit orbs), mask nothing (snake detects us)
	collision_layer = 16
	collision_mask = 0

	base_y = global_position.y

	# Core orb (small bright sphere)
	orb_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.85, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	orb_mesh.mesh = sphere
	add_child(orb_mesh)

	# Outer glow (larger, more transparent)
	glow_mesh = MeshInstance3D.new()
	var glow_sphere = SphereMesh.new()
	glow_sphere.radius = 0.3
	glow_sphere.height = 0.6
	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.3, 0.5, 1.0, 0.15)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.2, 0.4, 0.9)
	glow_mat.emission_energy_multiplier = 1.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.no_depth_test = true
	glow_sphere.material = glow_mat
	glow_mesh.mesh = glow_sphere
	add_child(glow_mesh)

	# Collision shape (sphere slightly larger than visual)
	var col = CollisionShape3D.new()
	var col_shape = SphereShape3D.new()
	col_shape.radius = 0.25
	col.shape = col_shape
	add_child(col)

	# Start hidden — spirit world toggle controls visibility
	_update_visibility()

func _process(delta):
	time += delta
	# Bob up and down
	var y_offset = sin(time * bob_speed) * bob_height
	position.y = base_y + y_offset

	# Gentle spin
	orb_mesh.rotation.y += spin_speed * delta
	glow_mesh.rotation.y -= spin_speed * delta * 0.5

	# Pulse the glow
	var pulse = 0.8 + sin(time * 3.0) * 0.2
	glow_mesh.scale = Vector3.ONE * pulse

	_update_visibility()

func _update_visibility():
	# Only visible and active in spirit world
	var player = _find_player()
	if player and "spirit_world" in player:
		visible = player.spirit_world
		# Disable/enable collision monitoring
		monitoring = player.spirit_world
		monitorable = player.spirit_world
	else:
		visible = false

func _find_player():
	# Walk up to find player in scene tree
	var root = get_tree().current_scene
	if root:
		return root.get_node_or_null("Player")
	return null

func eat():
	# Called by snake when it eats this orb
	# Quick shrink animation then remove
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.2)  # not zero: a zero scale logs a basis error
	tween.tween_callback(queue_free)
