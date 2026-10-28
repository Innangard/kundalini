extends "res://scripts/pushable_block.gd"

# Phase block: a pushable block that exists in only one world.
# In its own world it behaves exactly like a normal block (push, pull, presses plates,
# wedges phase walls). In the other world it is a faint ghost: no collision, frozen
# in place, can't be bitten or pushed.
# The player's E toggle asks blocks_toggle(): switching is refused if this block
# would reappear on top of the player or inside something solid.
# Scene needs Col (CollisionShape3D) and Mesh (MeshInstance3D) children, like normal blocks.

@export var world: String = "spirit"   # "real" or "spirit"

var present = true
var ghost: MeshInstance3D = null
var test_box: BoxShape3D
var shimmer_time = 0.0

func _ready():
	add_to_group("phase")
	var c = get_node_or_null("Col")
	test_box = BoxShape3D.new()
	if c and c.shape is BoxShape3D:
		# much shorter so the floor the block rests on never counts as overlap
		test_box.size = c.shape.size - Vector3(0.04, 0.2, 0.04)
	else:
		test_box.size = Vector3(0.66, 0.5, 0.66)

func _exists_in(spirit: bool) -> bool:
	return (world == "real" and not spirit) or (world == "spirit" and spirit)

func _physics_process(delta):
	var player = _find_player()
	var in_spirit = false
	if player and "spirit_world" in player:
		in_spirit = player.spirit_world
	var gm = get_node_or_null("/root/GameManager")
	var wanted = _exists_in(in_spirit)
	if gm and not gm.phase_walk_unlocked:
		wanted = true

	if wanted and not present:
		_set_present(true)
	elif not wanted and present:
		_set_present(false)

	if present:
		super._physics_process(delta)
	else:
		# Stay put as a ghost even if something tried to move us
		freeze = true
		linear_velocity = Vector3.ZERO

	_update_ghost(delta)

func blocks_toggle(to_spirit: bool) -> bool:
	if present or not _exists_in(to_spirit):
		return false
	# Would reappear on top of the player, a wall, or another block?
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = test_box
	params.transform = global_transform
	params.collision_mask = 1 | 2 | 8
	params.exclude = [get_rid()]
	var hits = get_world_3d().direct_space_state.intersect_shape(params, 4)
	for h in hits:
		var other = h["collider"]
		# Phase walls that will vanish in the new world don't count
		if other.has_method("_exists_in") and other.is_in_group("phase") and not other._exists_in(to_spirit):
			continue
		shimmer_time = 0.8
		return true
	return false

func _set_present(on: bool):
	present = on
	var m = get_node_or_null("Mesh")
	if m:
		m.visible = on
	if on:
		collision_layer = 8
		collision_mask = 15
		freeze = false
	else:
		collision_layer = 0
		collision_mask = 0
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
		linear_velocity = Vector3.ZERO
	sleeping = false

func _update_ghost(delta):
	shimmer_time = max(shimmer_time - delta, 0.0)
	var show = not present
	if show and ghost == null:
		_make_ghost()
	if ghost:
		ghost.visible = show
		if show:
			var mat = ghost.mesh.material as StandardMaterial3D
			var a = 0.13
			if shimmer_time > 0.0:
				a = 0.45 * (shimmer_time / 0.8) + 0.13
			mat.albedo_color.a = a

func _make_ghost():
	# Faint outline so the player can see where the block will be in its own world
	ghost = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = test_box.size + Vector3(0.04, 0.2, 0.04)
	var mat = StandardMaterial3D.new()
	if world == "real":
		mat.albedo_color = Color(1.0, 0.75, 0.45, 0.13)
		mat.emission = Color(0.6, 0.4, 0.2)
	else:
		mat.albedo_color = Color(0.55, 0.75, 1.0, 0.13)
		mat.emission = Color(0.25, 0.45, 0.9)
	mat.emission_enabled = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	ghost.mesh = box
	add_child(ghost)

func _find_player() -> Node:
	var root = get_tree().current_scene
	if root:
		return root.get_node_or_null("Player")
	return null
