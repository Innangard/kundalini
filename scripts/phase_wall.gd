extends StaticBody3D

# Phase wall: exists only in one world (real or spirit).
# In the other world it is invisible and non-collidable.
#
# Wedge rule: a wall can only form when its space is empty. If a block (or the
# player) is standing in its footprint, the wall waits, shown as a faint shimmer,
# and forms the moment the space is clear. A block left in a doorway therefore
# keeps that doorway open in both worlds.
#
# The player's E toggle asks blocks_toggle() first, so switching worlds is refused
# when a wall would appear on top of the player.
#
# Name nodes with a "Wall" prefix so the spiral shader treats them as structural.

@export var phase: String = "real"  # "real" or "spirit"
@export var wall_size: Vector3 = Vector3(0.25, 3.0, 1.75)

var present = true
var wedged = false
var ghost: MeshInstance3D = null
var ghost_mat: StandardMaterial3D = null
var shimmer_time = 0.0
var pulse = 0.0
var col: CollisionShape3D
var mesh_inst: MeshInstance3D
var test_box: BoxShape3D

func _ready():
	add_to_group("phase")
	collision_layer = 1
	collision_mask = 0

	mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = wall_size
	var mat = StandardMaterial3D.new()
	if phase == "real":
		mat.albedo_color = Color(0.68, 0.65, 0.72, 1)
	else:
		mat.albedo_color = Color(0.55, 0.48, 0.7, 1)
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	mesh_inst.name = "Mesh"
	add_child(mesh_inst)

	col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = wall_size
	col.shape = shape
	col.name = "Col"
	add_child(col)

	# Footprint test box: 2 cm smaller on every side so things merely touching
	# the wall's face don't count as "inside" it
	test_box = BoxShape3D.new()
	test_box.size = Vector3(max(wall_size.x - 0.04, 0.02), max(wall_size.y - 0.04, 0.02), max(wall_size.z - 0.04, 0.02))

func _physics_process(delta):
	var gm = get_node_or_null("/root/GameManager")
	if gm and not gm.phase_walk_unlocked:
		# Ability not unlocked yet: every phase wall is a plain solid wall
		if not present:
			_set_present(true)
		_set_wedged(false)
		return

	var player = _find_player()
	if player == null:
		return
	var in_spirit = player.spirit_world if "spirit_world" in player else false
	var wanted = _exists_in(in_spirit)

	if not wanted:
		if present:
			_set_present(false)
		_set_wedged(false)
	elif not present:
		# Wants to form: only if nothing occupies the space
		if _footprint_blocked(2 | 4 | 8):
			_set_wedged(true)
		else:
			_set_wedged(false)
			_set_present(true)

	_update_ghost(delta)

func _exists_in(spirit: bool) -> bool:
	return (phase == "real" and not spirit) or (phase == "spirit" and spirit)

# Called by the player before switching worlds. True = this wall would trap the player.
func blocks_toggle(to_spirit: bool) -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if gm and not gm.phase_walk_unlocked:
		return false
	if present or not _exists_in(to_spirit):
		return false
	if _footprint_blocked(2):
		shimmer()
		return true
	return false

func shimmer():
	shimmer_time = 0.8

func _footprint_blocked(mask: int) -> bool:
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = test_box
	params.transform = global_transform
	params.collision_mask = mask
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	var hits = get_world_3d().direct_space_state.intersect_shape(params, 1)
	return hits.size() > 0

func _set_present(on: bool):
	present = on
	mesh_inst.visible = on
	collision_layer = 1 if on else 0
	col.disabled = not on

func _set_wedged(on: bool):
	wedged = on

func _update_ghost(delta):
	# Faint shimmer shows a wedged wall, or flashes when a toggle was refused
	shimmer_time = max(shimmer_time - delta, 0.0)
	var show = (wedged or shimmer_time > 0.0) and not present
	if show and ghost == null:
		_make_ghost()
	if ghost:
		ghost.visible = show
		if show:
			pulse += delta
			var a = 0.12 + sin(pulse * 4.0) * 0.05
			if shimmer_time > 0.0:
				a = 0.35 * (shimmer_time / 0.8) + 0.1
			ghost_mat.albedo_color.a = a

func _make_ghost():
	# Created at runtime so the spirit-world shader pass never overrides it
	ghost = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = wall_size
	ghost_mat = StandardMaterial3D.new()
	if phase == "real":
		ghost_mat.albedo_color = Color(0.95, 0.8, 0.6, 0.15)
		ghost_mat.emission = Color(0.6, 0.45, 0.3)
	else:
		ghost_mat.albedo_color = Color(0.6, 0.75, 1.0, 0.15)
		ghost_mat.emission = Color(0.3, 0.45, 0.9)
	ghost_mat.emission_enabled = true
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.material = ghost_mat
	ghost.mesh = box
	add_child(ghost)

func _find_player() -> Node:
	var p = get_node_or_null("../Player")
	if p:
		return p
	var root = get_tree().current_scene
	if root:
		return root.get_node_or_null("Player")
	return null
