extends Node3D

# Snake extension
const EXTEND_SPEED = 8.0
const RETRACT_SPEED = 16.0
const DRAG_RETRACT_SPEED = 5.0  # Slower retraction when dragging a bitten block
const MAX_LENGTH = 6.0

# Visual segments
const SEGMENT_COUNT = 20
const BODY_RADIUS = 0.08

# Jaw animation
const JAW_OPEN_ANGLE = 0.5
const JAW_ANIM_SPEED = 8.0

# Eat/spit
const MAX_ORBS = 3
const SPIT_COOLDOWN = 0.3

var current_length = 0.0
var segments = []
var was_retracted = true
var time = 0.0
var pull_mode = false
var bitten_object: RigidBody3D = null
var bite_y: float = 0.0
var jaw_upper_pivot: Node3D
var jaw_lower_pivot: Node3D
var mouth_open = 0.0
var _pull_debug_logged = false  # Debug: one-shot print for pull state

# Eat/spit state
var orbs_held: int = 0
var spit_timer: float = 0.0
var segment_base_mats = []

# Constrict state
var constricting = false
var constrict_target: RigidBody3D = null
var constrict_seek = false

@onready var head: CharacterBody3D = $SnakeHead

func _ready():
	# Replace head mesh with a flattened capsule (snake-like)
	var head_mesh_node = $SnakeHead/HeadMesh
	var head_capsule = CapsuleMesh.new()
	head_capsule.radius = 0.1
	head_capsule.height = 0.3
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.5, 0.5, 0.52)
	head_capsule.material = head_mat
	head_mesh_node.mesh = head_capsule
	# Rotate so capsule height runs forward (-Z)
	head_mesh_node.rotation = Vector3(PI / 2.0, 0, 0)
	# Flatten slightly to look like a snake head
	head_mesh_node.scale = Vector3(1.2, 1.0, 0.7)

	# Eyes (children of SnakeHead so they orient with it)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.3, 0.55, 0.95)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.1, 0.25, 0.8)
	eye_mat.emission_energy_multiplier = 0.6

	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.025
		eye_mesh.height = 0.05
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.07, 0.055, -0.1)
		head.add_child(eye)

	# Jaws (children of SnakeHead — open when pulling, close on bite)
	var jaw_mat = StandardMaterial3D.new()
	jaw_mat.albedo_color = Color(0.45, 0.45, 0.47)

	jaw_upper_pivot = Node3D.new()
	jaw_upper_pivot.position = Vector3(0, 0.035, -0.12)
	head.add_child(jaw_upper_pivot)
	var jaw_up = MeshInstance3D.new()
	var jaw_up_mesh = BoxMesh.new()
	jaw_up_mesh.size = Vector3(0.16, 0.025, 0.1)
	jaw_up_mesh.material = jaw_mat
	jaw_up.mesh = jaw_up_mesh
	jaw_up.position = Vector3(0, 0.012, -0.05)
	jaw_upper_pivot.add_child(jaw_up)

	jaw_lower_pivot = Node3D.new()
	jaw_lower_pivot.position = Vector3(0, -0.035, -0.12)
	head.add_child(jaw_lower_pivot)
	var jaw_lo = MeshInstance3D.new()
	var jaw_lo_mesh = BoxMesh.new()
	jaw_lo_mesh.size = Vector3(0.16, 0.025, 0.1)
	jaw_lo_mesh.material = jaw_mat
	jaw_lo.mesh = jaw_lo_mesh
	jaw_lo.position = Vector3(0, -0.012, -0.05)
	jaw_lower_pivot.add_child(jaw_lo)

	# Body segments with alternating grey colors
	var mat_a = StandardMaterial3D.new()
	mat_a.albedo_color = Color(0.78, 0.78, 0.8)
	var mat_b = StandardMaterial3D.new()
	mat_b.albedo_color = Color(0.15, 0.15, 0.17)

	for i in range(SEGMENT_COUNT):
		var mi = MeshInstance3D.new()
		var capsule = CapsuleMesh.new()
		var t = float(i) / float(SEGMENT_COUNT - 1)
		# Taper from thick near body to thin toward head
		var r = lerp(BODY_RADIUS * 1.4, BODY_RADIUS * 0.25, t * t)
		capsule.radius = r
		capsule.height = max(r * 3.5, 0.05)
		var seg_mat = mat_a.duplicate() if i % 2 == 0 else mat_b.duplicate()
		capsule.material = seg_mat
		mi.mesh = capsule
		add_child(mi)
		segments.append(mi)
		segment_base_mats.append(seg_mat)
		mi.visible = false

# ── Constrict input (C key) ──────────────────────────────────────────
func _unhandled_input(event):
	if not (event is InputEventKey and event.keycode == KEY_C):
		return
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.constrict_unlocked:
		return
	if event.pressed and not event.echo:
		# C pressed — toggle constrict
		if constricting:
			_release_constrict()
		elif bitten_object != null:
			# Already holding something in the jaws: wrap it where it is
			var obj = bitten_object
			bitten_object = null
			_start_constrict(obj)
		elif current_length < 0.05 and bitten_object == null and not constrict_seek:
			constrict_seek = true
	elif not event.pressed:
		# C released — cancel seek if not yet constricting
		if constrict_seek and not constricting:
			constrict_seek = false

# ── Main physics loop ────────────────────────────────────────────────
func _physics_process(delta):
	time += delta
	if spit_timer > 0:
		spit_timer -= delta

	var player = get_parent()
	var gm = get_node_or_null("/root/GameManager")
	var in_spirit = player and "spirit_world" in player and player.spirit_world

	# ── Active constrict — handle separately and return ──
	if constricting and constrict_target:
		_process_constrict(delta)
		return

	var want_push = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# Pull requires unlock from GameManager (right-click)
	var want_pull = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and gm and gm.pull_unlocked

	# Debug: diagnose pull chain (one-shot print per session)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not _pull_debug_logged:
		_pull_debug_logged = true
		if want_pull:
			print("[Snake] Pull is WORKING — gm found, pull_unlocked=true")
		else:
			var _gm_ok = gm != null
			var _pull_ok = gm.pull_unlocked if gm else false
			print("[Snake] RIGHT-CLICK but pull blocked — gm_found=%s pull_unlocked=%s" % [_gm_ok, _pull_ok])

	# Constrict seek disables other modes
	if constrict_seek:
		want_push = false
		want_pull = false

	# Eat/spit: Space to spit in spirit world (requires eat_spit unlock)
	if Input.is_action_just_pressed("ui_accept") and in_spirit and orbs_held > 0 and spit_timer <= 0:
		if gm and gm.eat_spit_unlocked:
			_spit_projectile()

	# Can't do both at once — push wins
	if want_push and want_pull:
		want_pull = false

	# Only switch mode when fully retracted and nothing bitten
	if current_length < 0.05 and bitten_object == null:
		if want_pull:
			pull_mode = true
		elif want_push:
			pull_mode = false

	# Can't start opposite mode while extended
	if current_length > 0.05:
		if pull_mode:
			want_push = false
		else:
			want_pull = false

	# Active extending (not while dragging a bitten object back)
	var extending = (want_push or want_pull or constrict_seek) and bitten_object == null

	# Extend or retract
	if extending:
		current_length = min(current_length + EXTEND_SPEED * delta, MAX_LENGTH)
	else:
		# Retract slower when dragging a bitten object
		var retract_spd = DRAG_RETRACT_SPEED if bitten_object else RETRACT_SPEED
		current_length = max(current_length - retract_spd * delta, 0.0)

	# Direction the snake extends (player's forward)
	var extend_dir = -player.global_transform.basis.z

	# Animate jaws — open when pulling/constricting and extending, close otherwise
	var want_open = (pull_mode or constrict_seek) and extending and bitten_object == null
	if want_open:
		mouth_open = min(mouth_open + JAW_ANIM_SPEED * delta, 1.0)
	else:
		mouth_open = max(mouth_open - JAW_ANIM_SPEED * delta, 0.0)
	jaw_upper_pivot.rotation.x = -mouth_open * JAW_OPEN_ANGLE
	jaw_lower_pivot.rotation.x = mouth_open * JAW_OPEN_ANGLE

	# Fully retracted — snap head home, hide everything
	if current_length < 0.05:
		head.global_position = global_position
		head.visible = false
		for seg in segments:
			seg.visible = false
		was_retracted = true
		constrict_seek = false
		# Release bitten object when fully retracted
		if bitten_object:
			_release_bite()
		return

	# Just started extending
	if was_retracted:
		head.global_position = global_position
		was_retracted = false

	if extending:
		# Move head toward target with collision
		var target_pos = global_position + extend_dir * current_length
		var movement = target_pos - head.global_position
		var collision = head.move_and_collide(movement)
		if collision:
			var collider = collision.get_collider()
			if constrict_seek:
				# Constrict mode: wrap around eligible objects
				if collider is RigidBody3D and collider.has_method("push"):
					_start_constrict(collider)
					return
			elif pull_mode:
				# Pull mode: bite moveable objects, activate levers
				if collider is RigidBody3D and collider.has_method("push"):
					_bite(collider)
				elif collider.has_method("pull"):
					collider.pull()
			else:
				# Push mode: push blocks on contact
				if collider is RigidBody3D and collider.has_method("push"):
					collider.push(-collision.get_normal())
			# Clamp length to where the head actually ended up
			current_length = (head.global_position - global_position).length()

		# Check for spirit orb eating (only in spirit world with eat/spit unlocked)
		if in_spirit and pull_mode and gm and gm.eat_spit_unlocked and orbs_held < MAX_ORBS:
			_check_eat_orbs()
	elif bitten_object:
		# Retracting with bitten object — drag it along
		var head_dir = head.global_position - global_position
		if head_dir.length() > 0.05:
			head.global_position = global_position + head_dir.normalized() * current_length
		else:
			head.global_position = global_position
		# Move bitten object to follow head (slightly ahead)
		var drag_dir = head.global_position - global_position
		if drag_dir.length() > 0.1:
			var obj_pos = head.global_position + drag_dir.normalized() * 0.45
			obj_pos.y = bite_y
			_move_bitten(obj_pos)
		else:
			var fwd = -player.global_transform.basis.z
			var obj_pos = global_position + fwd * 0.8
			obj_pos.y = bite_y
			_move_bitten(obj_pos)
	else:
		# Retracting normally — phase through everything, pull straight back
		var head_dir = head.global_position - global_position
		if head_dir.length() > 0.05:
			head.global_position = global_position + head_dir.normalized() * current_length
		else:
			head.global_position = global_position

	head.visible = true

	# Orient head to face extension direction
	var head_vec = head.global_position - global_position
	if head_vec.length() > 0.1:
		head.look_at(head.global_position + head_vec.normalized(), Vector3.UP)

	# Undulation setup
	var snake_dir = head_vec.normalized() if head_vec.length() > 0.01 else extend_dir
	var right = snake_dir.cross(Vector3.UP)
	if right.length() < 0.01:
		right = snake_dir.cross(Vector3.RIGHT)
	right = right.normalized()

	# Place and orient body segments
	for i in range(SEGMENT_COUNT):
		var t = float(i + 1) / float(SEGMENT_COUNT + 1)
		var pos = global_position.lerp(head.global_position, t)

		# Sine wave slither (stronger in middle of body, scales with length)
		var wave_envelope = sin(t * PI) * 0.05 * (current_length / MAX_LENGTH)
		var wave = sin(t * PI * 3.0 + time * 5.0) * wave_envelope
		pos += right * wave

		segments[i].global_position = pos

		# Point capsule along the body curve
		var next_t = min(float(i + 2) / float(SEGMENT_COUNT + 1), 1.0)
		var next_pos = global_position.lerp(head.global_position, next_t)
		var next_wave = sin(next_t * PI * 3.0 + time * 5.0) * sin(next_t * PI) * 0.05 * (current_length / MAX_LENGTH)
		next_pos += right * next_wave

		var seg_dir = next_pos - pos
		if seg_dir.length() > 0.001:
			segments[i].look_at(next_pos, Vector3.UP)
			segments[i].rotate_object_local(Vector3(1, 0, 0), PI / 2.0)

		segments[i].visible = true

	# Update body glow based on orbs held
	_update_body_glow()

# ── Bite / Release (pull mechanic) ───────────────────────────────────
func _bite(obj: RigidBody3D):
	print("[Snake] BITE: %s at %s" % [obj.name, obj.global_position])
	bitten_object = obj
	bite_y = obj.global_position.y
	bitten_object.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	bitten_object.freeze = true
	if obj.has_method("snake_grab"):
		obj.snake_grab()

func _move_bitten(obj_pos: Vector3):
	# Dragged blocks used to phase through walls because their position is set directly.
	# Now: if the next position would overlap a wall (layer 1) or another block (layer 8),
	# the snake lets go and the block stays where it is.
	if bitten_object.has_method("constrain_drag"):
		var on_track = bitten_object.constrain_drag(obj_pos)
		if not _drag_blocked(on_track):
			bitten_object.global_position = on_track
		else:
			# Hit something: stay where it is, still in the jaws (C can wrap it now)
			bitten_object.constrain_drag(bitten_object.global_position)
		return
	if _drag_blocked(obj_pos):
		_release_bite()
		return
	bitten_object.global_position = obj_pos

func _drag_blocked(obj_pos: Vector3) -> bool:
	var col_shape: CollisionShape3D = null
	for c in bitten_object.get_children():
		if c is CollisionShape3D:
			col_shape = c
			break
	if col_shape == null or not (col_shape.shape is BoxShape3D):
		return false
	# Test a slightly smaller box: narrower so a block touching a wall can still slide
	# away from it, and much shorter so it never touches the floor it rests on
	var test_box = BoxShape3D.new()
	var full = col_shape.shape.size
	test_box.size = Vector3(full.x * 0.92, full.y * 0.7, full.z * 0.92)
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = test_box
	params.transform = Transform3D(bitten_object.global_transform.basis, obj_pos + col_shape.position)
	params.collision_mask = 1 | 8
	params.exclude = [bitten_object.get_rid()]
	var hits = get_world_3d().direct_space_state.intersect_shape(params, 1)
	return hits.size() > 0

func _release_bite():
	if bitten_object and bitten_object.has_method("snake_release"):
		bitten_object.snake_release()
		bitten_object = null
		return
	if bitten_object:
		bitten_object.freeze = false
		bitten_object.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		bitten_object.linear_velocity = Vector3.ZERO
		bitten_object = null

# ── Constrict mechanic ───────────────────────────────────────────────
func _start_constrict(obj: RigidBody3D):
	constricting = true
	constrict_target = obj
	constrict_seek = false
	# Freeze the target in place
	obj.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	obj.freeze = true
	if obj.has_method("snake_grab"):
		obj.snake_grab()
	mouth_open = 0.0
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.show_notification("CONSTRICTED\nPress C to release", 2.0)

func _process_constrict(delta):
	time += delta
	if spit_timer > 0:
		spit_timer -= delta

	var player = get_parent()

	# Keep head at the target
	head.global_position = constrict_target.global_position
	head.visible = true
	current_length = (head.global_position - global_position).length()

	# Tether player — clamp horizontal distance to MAX_LENGTH
	var offset = player.global_position - constrict_target.global_position
	offset.y = 0
	if offset.length() > MAX_LENGTH:
		offset = offset.normalized() * MAX_LENGTH
		player.global_position.x = constrict_target.global_position.x + offset.x
		player.global_position.z = constrict_target.global_position.z + offset.z

	# Orient head toward player (snake wraps the object, head faces back)
	var look_dir = global_position - head.global_position
	if look_dir.length() > 0.1:
		head.look_at(head.global_position + look_dir.normalized(), Vector3.UP)

	# Jaw animation — closed while constricting
	mouth_open = max(mouth_open - JAW_ANIM_SPEED * delta, 0.0)
	jaw_upper_pivot.rotation.x = -mouth_open * JAW_OPEN_ANGLE
	jaw_lower_pivot.rotation.x = mouth_open * JAW_OPEN_ANGLE

	# Place segments from player to target with wrapping effect
	var snake_vec = head.global_position - global_position
	var right = Vector3.RIGHT
	if snake_vec.length() > 0.01:
		var sdir = snake_vec.normalized()
		right = sdir.cross(Vector3.UP)
		if right.length() < 0.01:
			right = sdir.cross(Vector3.RIGHT)
		right = right.normalized()

	for i in range(SEGMENT_COUNT):
		var t = float(i + 1) / float(SEGMENT_COUNT + 1)
		var pos = global_position.lerp(head.global_position, t)

		# Last quarter of segments wrap around the target
		if t > 0.75:
			var wrap_t = (t - 0.75) / 0.25
			var wrap_angle = wrap_t * PI * 3.0 + time * 2.0
			var wrap_r = 0.3 * (1.0 - wrap_t * 0.3)
			pos += right * cos(wrap_angle) * wrap_r
			pos.y += sin(wrap_angle) * wrap_r * 0.5
		else:
			# Gentle slither wave along the tether
			var wave = sin(t * PI * 3.0 + time * 3.0) * sin(t * PI) * 0.03
			pos += right * wave

		segments[i].global_position = pos
		segments[i].visible = true

		var next_t = min(float(i + 2) / float(SEGMENT_COUNT + 1), 1.0)
		var next_pos = global_position.lerp(head.global_position, next_t)
		var seg_dir = next_pos - pos
		if seg_dir.length() > 0.001:
			segments[i].look_at(next_pos, Vector3.UP)
			segments[i].rotate_object_local(Vector3(1, 0, 0), PI / 2.0)

	_update_body_glow()

func _release_constrict():
	if constrict_target and constrict_target.has_method("snake_release"):
		constrict_target.snake_release()
		constrict_target = null
	if constrict_target:
		constrict_target.freeze = false
		constrict_target.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		constrict_target.linear_velocity = Vector3.ZERO
		constrict_target = null
	constricting = false
	constrict_seek = false

# ── Eat / Spit ───────────────────────────────────────────────────────
func _check_eat_orbs():
	# Use the head's position to check for nearby spirit orbs
	var space_state = head.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.6  # Generous detection radius so orbs are easy to grab
	query.shape = sphere_shape
	query.transform = Transform3D(Basis.IDENTITY, head.global_position)
	query.collision_mask = 16  # Spirit orb layer
	query.collide_with_areas = true  # Spirit orbs are Area3D — must opt in

	var results = space_state.intersect_shape(query, 1)
	for result in results:
		var collider = result["collider"]
		if collider.has_method("eat"):
			collider.eat()
			orbs_held = min(orbs_held + 1, MAX_ORBS)
			# Brief jaw snap animation
			mouth_open = 1.0
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				gm.show_notification("Spirit consumed  [%d/%d]" % [orbs_held, MAX_ORBS], 1.0)
			break

func _spit_projectile():
	orbs_held -= 1
	spit_timer = SPIT_COOLDOWN

	var player = get_parent()
	var forward = -player.global_transform.basis.z

	# Spawn projectile from head position (or player position if retracted)
	var spawn_pos = head.global_position if current_length > 0.1 else global_position
	spawn_pos += forward * 0.3  # Slightly ahead

	var projectile_scene = preload("res://scripts/spit_projectile.gd")
	var projectile = Area3D.new()
	projectile.set_script(projectile_scene)
	projectile.direction = forward

	# Add to scene tree BEFORE setting global_position (requires being in tree)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_pos

	# Jaw snap for spit
	mouth_open = 1.0

func _update_body_glow():
	if orbs_held <= 0:
		# Reset all segments to base materials
		for i in range(SEGMENT_COUNT):
			var mat = segment_base_mats[i]
			mat.emission_enabled = false
		return

	# Glow segments based on orbs held — fills from body end toward head
	# 1 orb = bottom third glows, 2 = two thirds, 3 = all
	var glow_fraction = float(orbs_held) / float(MAX_ORBS)
	var glow_count = int(SEGMENT_COUNT * glow_fraction)

	var pulse = 0.6 + sin(time * 4.0) * 0.4

	for i in range(SEGMENT_COUNT):
		var mat = segment_base_mats[i]
		if i < glow_count:
			# This segment glows
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.5, 1.0) * pulse
			mat.emission_energy_multiplier = 1.5 * pulse
		else:
			mat.emission_enabled = false
