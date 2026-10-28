extends StaticBody3D

# Cord door: opens in proportion to how far its cord block is pulled
# and slides shut again as the cord winds back.
# - Never closes on the player: anyone standing under it is nudged out to the side they're on.
# - A block underneath stops it, propping it about 0.7 m open (shots and the snake fit
#   under, the player doesn't).
# Scene needs Col (CollisionShape3D) and Mesh (MeshInstance3D) children.

@export var cord_path: NodePath = ""
@export var door_size: Vector3 = Vector3(2.5, 3.0, 0.25)
@export var lift: float = 3.0
@export var move_speed: float = 4.0

var closed_y: float
var opened = 0.0     # current lift in metres
var cord: Node = null
var test_box: BoxShape3D

func _ready():
	collision_layer = 1
	collision_mask = 0
	closed_y = position.y
	cord = get_node_or_null(cord_path)
	test_box = BoxShape3D.new()
	test_box.size = door_size - Vector3(0.04, 0.04, 0.04)

func _physics_process(delta):
	if cord == null:
		return
	var target = cord.get_fraction() * lift
	if target > opened:
		opened = min(opened + move_speed * delta, target)
	elif target < opened:
		var next = max(opened - move_speed * delta, target)
		_push_player_out(next)
		if not _block_under(next):
			opened = next
	position.y = closed_y + opened

func _door_xform(open_amount: float) -> Transform3D:
	var t = global_transform
	t.origin.y += open_amount - opened
	return t

func _block_under(open_amount: float) -> bool:
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = test_box
	params.transform = _door_xform(open_amount)
	params.collision_mask = 8
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).size() > 0

func _push_player_out(open_amount: float):
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = test_box
	params.transform = _door_xform(open_amount)
	params.collision_mask = 2
	params.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(params, 2):
		var body = hit["collider"]
		if body is Node3D:
			_nudge(body)

func _nudge(body: Node3D):
	# Move the body out along the door's thin axis, to whichever side it's already on
	var local = global_transform.affine_inverse() * body.global_position
	var clear = 0.36
	if door_size.x < door_size.z:
		var s = 1.0 if local.x >= 0.0 else -1.0
		local.x = s * (door_size.x * 0.5 + clear)
	else:
		var s = 1.0 if local.z >= 0.0 else -1.0
		local.z = s * (door_size.z * 0.5 + clear)
	var world_pos = global_transform * local
	body.global_position = Vector3(world_pos.x, body.global_position.y, world_pos.z)
