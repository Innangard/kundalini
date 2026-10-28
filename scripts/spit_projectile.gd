extends Area3D

# Projectile spit by the snake — flies forward, hits targets and breakable walls

const SPEED = 18.0
const LIFETIME = 3.0
const RADIUS = 0.12

var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0
var trail_mesh: MeshInstance3D
var exploded = false

func _ready():
	# Collision: layer 32 (projectile), detect layers 1 (environment) + 8 (pushable blocks)
	# + 64 (spit targets) + 128 (breakable). Blocks stop shots, so they can plug a firing lane.
	collision_layer = 32
	collision_mask = 1 | 8 | 64 | 128

	# Projectile mesh — bright glowing sphere
	var mesh_node = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.8, 1.0, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	mesh_node.mesh = sphere
	add_child(mesh_node)

	# Trailing glow
	trail_mesh = MeshInstance3D.new()
	var trail_sphere = SphereMesh.new()
	trail_sphere.radius = RADIUS * 2.5
	trail_sphere.height = RADIUS * 5.0
	var trail_mat = StandardMaterial3D.new()
	trail_mat.albedo_color = Color(0.2, 0.4, 0.9, 0.1)
	trail_mat.emission_enabled = true
	trail_mat.emission = Color(0.15, 0.3, 0.7)
	trail_mat.emission_energy_multiplier = 1.5
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.no_depth_test = true
	trail_sphere.material = trail_mat
	trail_mesh.mesh = trail_sphere
	add_child(trail_mesh)

	# Collision shape
	var col = CollisionShape3D.new()
	var col_shape = SphereShape3D.new()
	col_shape.radius = RADIUS * 1.5
	col.shape = col_shape
	add_child(col)

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta):
	age += delta
	if age > LIFETIME:
		_explode()
		return

	# Move forward
	global_position += direction * SPEED * delta

	# Pulse trail
	var pulse = 0.8 + sin(age * 12.0) * 0.3
	trail_mesh.scale = Vector3.ONE * pulse

func _on_body_entered(body):
	if exploded:
		return
	if body.has_method("spit_hit"):
		body.spit_hit()
	elif body.has_method("break_wall"):
		body.break_wall()
	_explode()

func _on_area_entered(area):
	if exploded:
		return
	if area.has_method("spit_hit"):
		area.spit_hit()
	_explode()

func _explode():
	if exploded or not is_inside_tree():
		return
	exploded = true
	# Brief flash then disappear
	set_process(false)
	set_deferred("monitoring", false)  # Can't set directly during body_entered signal
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 3.0, 0.15)
	tween.tween_callback(queue_free)
