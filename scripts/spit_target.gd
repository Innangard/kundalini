extends StaticBody3D

# Wall switch activated by a spit projectile impact
# Works like a lever but triggered remotely

@export var target_path: NodePath = ""
var is_activated = false
var indicator_mesh: MeshInstance3D
var mat_inactive: StandardMaterial3D
var mat_active: StandardMaterial3D

func _ready():
	# Collision layer 64 (spit target)
	collision_layer = 64
	collision_mask = 0

	# Visual indicator — a glowing circle/gem on the wall
	indicator_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.12

	mat_inactive = StandardMaterial3D.new()
	mat_inactive.albedo_color = Color(0.6, 0.15, 0.15)
	mat_inactive.emission_enabled = true
	mat_inactive.emission = Color(0.5, 0.1, 0.1)
	mat_inactive.emission_energy_multiplier = 1.5

	mat_active = StandardMaterial3D.new()
	mat_active.albedo_color = Color(0.15, 0.6, 0.3)
	mat_active.emission_enabled = true
	mat_active.emission = Color(0.1, 0.5, 0.2)
	mat_active.emission_energy_multiplier = 2.0

	sphere.material = mat_inactive
	indicator_mesh.mesh = sphere
	indicator_mesh.scale = Vector3(1.0, 1.0, 0.4)
	add_child(indicator_mesh)

	# Collision shape — tall column from floor to above the indicator
	# Projectile fires at snake-head height (~y=0.3) but the visual sits
	# at wall height (~y=1.5), so the hitbox must span the full range.
	# Also wide+deep enough that fast projectiles can't tunnel through.
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.0, 3.0, 0.6)
	col.shape = box
	col.position.y = -1.0  # shift down so bottom reaches below floor level
	add_child(col)

func spit_hit():
	if is_activated:
		return
	is_activated = true

	# Change visual to active
	indicator_mesh.mesh.material = mat_active

	# Animate — pulse then settle
	var tween = create_tween()
	tween.tween_property(indicator_mesh, "scale", Vector3(1.5, 1.5, 0.6), 0.15)
	tween.tween_property(indicator_mesh, "scale", Vector3(1.0, 1.0, 0.4), 0.2)

	# Activate target
	if not target_path.is_empty():
		var target = get_node_or_null(target_path)
		if target and target.has_method("lever_pulled"):
			target.lever_pulled()
		elif target and target.has_method("_open_door"):
			target._open_door()
		elif target and target.has_method("spit_hit"):
			target.spit_hit()
