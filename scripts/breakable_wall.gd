extends StaticBody3D

# Barrier destroyed by spit projectile impact
# Shatters into pieces and reveals path behind

var is_broken = false
var wall_mesh: MeshInstance3D

func _ready():
	# Collision layer 128 (breakable), layer 1 (environment) for blocking movement
	collision_layer = 128 | 1
	collision_mask = 0

	# Visual — cracked-looking wall segment
	wall_mesh = get_node_or_null("WallMesh")
	if not wall_mesh:
		wall_mesh = MeshInstance3D.new()
		wall_mesh.name = "WallMesh"
		var box = BoxMesh.new()
		box.size = Vector3(1.5, 2.5, 0.25)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.25, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.05, 0.15)
		mat.emission_energy_multiplier = 0.3
		box.material = mat
		wall_mesh.mesh = box
		add_child(wall_mesh)

	# Ensure collision shape exists
	if not get_node_or_null("CollisionShape3D"):
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(1.5, 2.5, 0.25)
		col.shape = shape
		add_child(col)

func spit_hit():
	break_wall()

func break_wall():
	if is_broken:
		return
	is_broken = true

	# Disable collision immediately
	collision_layer = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	# Shatter effect — spawn debris pieces
	_spawn_debris()

	# Hide original mesh
	if wall_mesh:
		wall_mesh.visible = false

	# Remove after debris settles
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(queue_free)

func _spawn_debris():
	if not is_inside_tree():
		return
	var debris_mat = StandardMaterial3D.new()
	debris_mat.albedo_color = Color(0.35, 0.25, 0.35)

	for i in range(8):
		var piece = RigidBody3D.new()
		piece.mass = 0.5
		piece.gravity_scale = 1.5

		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		var sx = randf_range(0.15, 0.4)
		var sy = randf_range(0.15, 0.5)
		var sz = randf_range(0.08, 0.15)
		box.size = Vector3(sx, sy, sz)
		box.material = debris_mat
		mesh.mesh = box
		piece.add_child(mesh)

		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(sx, sy, sz)
		col.shape = shape
		piece.add_child(col)

		# Add to tree BEFORE setting global_position (requires being in tree)
		get_parent().add_child(piece)

		# Random position within wall area
		piece.global_position = global_position + Vector3(
			randf_range(-0.5, 0.5),
			randf_range(-0.8, 0.8),
			randf_range(-0.1, 0.1)
		)

		# Burst outward
		piece.apply_impulse(Vector3(
			randf_range(-2.0, 2.0),
			randf_range(1.0, 4.0),
			randf_range(-3.0, 3.0)
		))

		# Fade and remove each piece
		var tween = create_tween()
		tween.tween_interval(1.0)
		tween.tween_property(mesh, "transparency", 1.0, 0.8)
		tween.tween_callback(piece.queue_free)
