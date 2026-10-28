extends RigidBody3D

# Cord block: a block tied to a cord anchored in the wall.
# - Pull it out along its track with the snake (bite + retract). It only moves along the track.
# - Left alone, the cord slowly winds it back home at return_speed (m/s).
# - Constrict holds it in place (C, or press C while it's in your jaws).
# - Anything solid in its way home (a block, a phase block in its own world) jams it.
# A cord_door linked to it opens in proportion to how far it is pulled.
# Scene needs Col (CollisionShape3D) and Mesh (MeshInstance3D) children.

@export var track_dir: Vector3 = Vector3(-1, 0, 0)   # direction it moves when pulled
@export var max_pull: float = 2.5
@export var return_speed: float = 0.5

var home: Vector3
var pulled = 0.0          # metres out from home, 0..max_pull
var held = false          # bitten or constricted by the snake
var test_box: BoxShape3D
var cord_mesh: MeshInstance3D
var anchor: Vector3

func _ready():
	add_to_group("cord")
	collision_layer = 8
	collision_mask = 0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	track_dir.y = 0
	track_dir = track_dir.normalized()
	home = global_position
	var c = get_node_or_null("Col")
	test_box = BoxShape3D.new()
	var full = Vector3(0.7, 0.7, 0.7)
	if c and c.shape is BoxShape3D:
		full = c.shape.size
	# Slightly LONGER than the block along the track, so a jam is detected before we touch it
	# (otherwise the kinematic cord nudges the jam block away a little every frame);
	# slightly narrower across the track so walls beside the track never count.
	if abs(track_dir.x) > abs(track_dir.z):
		test_box.size = Vector3(full.x + 0.06, full.y * 0.6, full.z * 0.92)
	else:
		test_box.size = Vector3(full.x * 0.92, full.y * 0.6, full.z + 0.06)
	anchor = home - track_dir * 0.65
	anchor.y = home.y + 0.1
	_build_visuals()

func _build_visuals():
	# Anchor ring in the wall and the cord itself (made at runtime, kept out of the shader pass)
	var rope = StandardMaterial3D.new()
	rope.albedo_color = Color(0.55, 0.42, 0.25)
	rope.roughness = 1.0
	cord_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 1.0)
	box.material = rope
	cord_mesh.mesh = box
	cord_mesh.top_level = true
	add_child(cord_mesh)
	var post = MeshInstance3D.new()
	var pbox = BoxMesh.new()
	pbox.size = Vector3(0.18, 0.18, 0.18)
	var iron = StandardMaterial3D.new()
	iron.albedo_color = Color(0.15, 0.13, 0.12)
	iron.metallic = 0.6
	pbox.material = iron
	post.mesh = pbox
	post.top_level = true
	add_child(post)
	post.global_position = anchor
	_update_cord()

func _update_cord():
	var a = anchor
	var b = global_position + Vector3(0, 0.1, 0)
	var d = b - a
	var length = max(d.length(), 0.01)
	cord_mesh.global_position = (a + b) * 0.5
	if d.length() > 0.01:
		cord_mesh.look_at(b, Vector3.UP if abs(d.normalized().y) < 0.99 else Vector3.RIGHT)
	cord_mesh.scale = Vector3(1, 1, length)

# Snake treats anything with push() as a block it can bite or constrict
func push(_direction: Vector3):
	pass   # cords can't be pushed, only pulled

func snake_grab():
	held = true

func snake_release():
	held = false

# Snake asks where a dragged position lands: project it onto the track
func constrain_drag(pos: Vector3) -> Vector3:
	var t = clamp((pos - home).dot(track_dir), 0.0, max_pull)
	pulled = t
	return home + track_dir * t

func get_fraction() -> float:
	return pulled / max_pull

func reset_home():
	pulled = 0.0
	held = false
	global_position = home

func _physics_process(delta):
	# Keep 'pulled' in sync if the snake moved us
	pulled = clamp((global_position - home).dot(track_dir), 0.0, max_pull)
	if not held and pulled > 0.0:
		var next_t = max(pulled - return_speed * delta, 0.0)
		var next_pos = home + track_dir * next_t
		if not _blocked_at(next_pos):
			pulled = next_t
			global_position = next_pos
	_update_cord()

func _blocked_at(pos: Vector3) -> bool:
	# Jammed if a wall, the player, or a block sits where we'd move next
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = test_box
	params.transform = Transform3D(Basis(), pos)
	params.collision_mask = 1 | 2 | 8
	params.exclude = [get_rid()]
	var hits = get_world_3d().direct_space_state.intersect_shape(params, 1)
	return hits.size() > 0
