extends StaticBody3D

# Brazier: a stone bowl that lights when hit by a spit projectile.
# When lit it notifies every node in targets:
#   - another brazier gets light()          (relay chains, hub indicators)
#   - a pressure_door gets plate_activated() (shutters, the Sanctum gate)
#   - a lever_door gets lever_pulled()
# Builds its own mesh and collision, so the scene only needs the node.

@export var targets: Array[NodePath] = []
@export var great: bool = false           # big wing brazier vs small relay brazier
@export var spit_lightable: bool = true   # false for indicator braziers the player can't light
@export var starts_lit: bool = false

var is_lit = false
var flame_mesh: MeshInstance3D
var flame_light: OmniLight3D
var flicker_time = 0.0
var base_energy = 1.0
var bowl_top = 0.0

func _ready():
	# Layer 1 blocks movement and shots, layer 64 marks it as a spit target
	collision_layer = 1
	if spit_lightable:
		collision_layer = 1 | 64
	collision_mask = 0

	# Sizes for the two variants
	var base_w = 0.4
	var base_h = 0.7
	var bowl_w = 0.7
	var bowl_h = 0.15
	if great:
		base_w = 0.6
		base_h = 0.9
		bowl_w = 1.1
		bowl_h = 0.22

	var stone = StandardMaterial3D.new()
	stone.albedo_color = Color(0.3, 0.27, 0.32)
	stone.roughness = 0.95

	var iron = StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.1, 0.1)
	iron.metallic = 0.6
	iron.roughness = 0.6

	# Pedestal
	_add_box(Vector3(base_w + 0.15, 0.1, base_w + 0.15), Vector3(0, 0.05, 0), stone)
	_add_box(Vector3(base_w, base_h, base_w), Vector3(0, base_h / 2.0, 0), stone)

	# Bowl (wide iron dish with a rim)
	bowl_top = base_h + bowl_h
	_add_box(Vector3(bowl_w, bowl_h, bowl_w), Vector3(0, base_h + bowl_h / 2.0, 0), iron)
	var rim = 0.05
	_add_box(Vector3(bowl_w + 0.04, 0.08, rim), Vector3(0, bowl_top, bowl_w / 2.0), iron)
	_add_box(Vector3(bowl_w + 0.04, 0.08, rim), Vector3(0, bowl_top, -bowl_w / 2.0), iron)
	_add_box(Vector3(rim, 0.08, bowl_w), Vector3(bowl_w / 2.0, bowl_top, 0), iron)
	_add_box(Vector3(rim, 0.08, bowl_w), Vector3(-bowl_w / 2.0, bowl_top, 0), iron)

	# Cold ash in the bowl so an unlit brazier still reads as "fuel waiting"
	var ash = StandardMaterial3D.new()
	ash.albedo_color = Color(0.2, 0.18, 0.18)
	_add_box(Vector3(bowl_w * 0.8, 0.04, bowl_w * 0.8), Vector3(0, bowl_top, 0), ash)

	# Collision covers floor to bowl so low projectiles (y ~0.45) always hit
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(bowl_w, bowl_top, bowl_w)
	col.shape = shape
	col.position.y = bowl_top / 2.0
	add_child(col)

	if starts_lit:
		call_deferred("light")

func _add_box(size: Vector3, pos: Vector3, mat: Material):
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	add_child(mi)

# Called by spit_projectile on impact
func spit_hit():
	if not spit_lightable:
		return
	light()

func light():
	if is_lit:
		return
	is_lit = true

	# Flame is created only now, so the spirit-world shader pass
	# (which runs once at level start) never overrides its glow
	var size = 0.35
	if great:
		size = 0.6
	flame_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = size * 0.5
	sphere.height = size * 1.6
	var fire = StandardMaterial3D.new()
	fire.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.45, 0.1)
	fire.emission_energy_multiplier = 4.0
	fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = fire
	flame_mesh.mesh = sphere
	flame_mesh.position = Vector3(0, bowl_top + size * 0.6, 0)
	flame_mesh.scale = Vector3.ONE * 0.01  # not zero: a zero scale can't be inverted
	add_child(flame_mesh)

	flame_light = OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.6, 0.3)
	base_energy = 1.2
	flame_light.omni_range = 5.0
	if great:
		base_energy = 2.0
		flame_light.omni_range = 9.0
	flame_light.light_energy = 0.0
	flame_light.position = Vector3(0, bowl_top + 0.6, 0)
	add_child(flame_light)

	# Flare up, then settle
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flame_mesh, "scale", Vector3.ONE * 1.4, 0.2)
	tween.tween_property(flame_light, "light_energy", base_energy * 1.8, 0.2)
	tween.chain().tween_property(flame_mesh, "scale", Vector3.ONE, 0.4)
	tween.parallel().tween_property(flame_light, "light_energy", base_energy, 0.4)

	if great:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("show_notification"):
			gm.show_notification("A great brazier burns", 2.0)

	_notify_targets()

func _notify_targets():
	for path in targets:
		var target = get_node_or_null(path)
		if target == null:
			continue
		if target.has_method("light"):
			target.light()
		elif target.has_method("plate_activated"):
			target.plate_activated()
		elif target.has_method("lever_pulled"):
			target.lever_pulled()
		elif target.has_method("_open_door"):
			target._open_door()

func _process(delta):
	if not is_lit or flame_light == null:
		return
	flicker_time += delta
	# Layered sines so the fire never looks like a clean pulse
	var f = sin(flicker_time * 9.0) * 0.08
	f += sin(flicker_time * 23.0 + 1.3) * 0.05
	f += sin(flicker_time * 3.7) * 0.06
	flame_light.light_energy = base_energy * (1.0 + f)
	flame_mesh.scale.y = 1.0 + f * 1.5
