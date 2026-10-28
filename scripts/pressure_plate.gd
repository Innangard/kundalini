extends Area3D

# Pressure plate: activates when a player or pushable block stands on it.
# Notifies target via plate_activated() / plate_deactivated().
#
# world = "both"   : works in either world (default, how every plate worked before)
# world = "real"   : only counts while the player is in the real world
# world = "spirit" : only counts while the player is in the spirit world
# A world-bound plate lets go when you switch away from its world.

@export var target_path: NodePath = ""
@export var plate_size: Vector3 = Vector3(1.2, 0.05, 1.2)
@export var detect_player: bool = true  # false = only pushable blocks press it
@export var world: String = "both"

var on_plate = {}          # instance_id -> true, for every body currently counted
var is_active: bool = false
var plate_mat: StandardMaterial3D
var mesh_inst: MeshInstance3D
var base_color = Color(0.3, 0.3, 0.5)

func _ready():
	collision_layer = 0
	collision_mask = 14  # player (2) + snake (4) + pushable (8)
	if not detect_player:
		collision_mask = 8  # blocks only

	if world == "real":
		base_color = Color(0.55, 0.36, 0.2)
	elif world == "spirit":
		base_color = Color(0.25, 0.38, 0.7)

	# Visual plate (flat slab on the floor)
	mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = plate_size
	plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = base_color
	box.material = plate_mat
	mesh_inst.mesh = box
	mesh_inst.name = "PlateMesh"
	add_child(mesh_inst)

	# Detection shape: taller than the visual so bodies standing on it register
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(plate_size.x, 0.6, plate_size.z)
	col.shape = shape
	col.position.y = 0.3
	col.name = "Col"
	add_child(col)

	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _counts(body) -> bool:
	if (body.collision_layer & 8) != 0:
		return true
	if detect_player and ((body.collision_layer & 2) != 0 or (body.collision_layer & 4) != 0):
		return true
	return false

func _on_enter(body):
	if _counts(body):
		on_plate[body.get_instance_id()] = true
		_update_state()

func _on_exit(body):
	# Remove by identity: a phase block turning into a ghost has already lost its layer
	if on_plate.has(body.get_instance_id()):
		on_plate.erase(body.get_instance_id())
		_update_state()

func _process(_delta):
	# World-bound plates re-check every frame so switching worlds releases them
	if world != "both":
		_update_state()

func _world_ok() -> bool:
	if world == "both":
		return true
	var root = get_tree().current_scene
	var player = root.get_node_or_null("Player") if root else null
	var in_spirit = false
	if player and "spirit_world" in player:
		in_spirit = player.spirit_world
	if world == "spirit":
		return in_spirit
	return not in_spirit

func _update_state():
	var now_active = on_plate.size() > 0 and _world_ok()
	if now_active == is_active:
		return
	is_active = now_active

	# Visual feedback
	if is_active:
		_set_color(Color(0.2, 0.6, 0.3))
		plate_mat.emission_enabled = true
		plate_mat.emission = Color(0.1, 0.4, 0.15)
		plate_mat.emission_energy_multiplier = 0.5
	else:
		_set_color(base_color)
		plate_mat.emission_enabled = false

	# Notify target
	var target = get_node_or_null(target_path)
	if target:
		if is_active and target.has_method("plate_activated"):
			target.plate_activated()
		elif not is_active and target.has_method("plate_deactivated"):
			target.plate_deactivated()

func _set_color(c: Color):
	plate_mat.albedo_color = c
	# The spirit-world shader replaces the mesh material at level start,
	# so push the color into it too or the change never shows
	if mesh_inst.material_override is ShaderMaterial:
		mesh_inst.material_override.set_shader_parameter("albedo_color", c)
