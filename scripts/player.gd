extends CharacterBody3D

# Movement
const SPEED = 5.0
const MOUSE_SENS = 0.003
const GRAVITY = 9.8

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var snake = $Snake

var camera_default_pos: Vector3
var spirit_world = false
var spirit_transition = 0.0
var spirit_distortion = 0.0
var spirit_time = 0.0
var spirit_overlay: ColorRect
var spirit_material: ShaderMaterial
static var _spirit_globals_registered = false
const SPIRIT_FADE_DURATION = 1.2
const DISTORTION_SNAKE_RATE = 0.08  # per second while using snake
const DISTORTION_PASSIVE_RATE = 0.005  # very slow when just standing around
const STRUCTURE_PREFIXES = ["Floor", "Ceiling", "Wall", "Hall", "Front"]

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_default_pos = camera.position
	add_to_group("player")

	# Spirit world post-process overlay (hidden until toggled)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	spirit_overlay = ColorRect.new()
	spirit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spirit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spirit_material = ShaderMaterial.new()
	spirit_material.shader = load("res://shaders/spirit_world.gdshader")
	spirit_overlay.material = spirit_material
	spirit_overlay.visible = false
	canvas_layer.add_child(spirit_overlay)

	# Register global shader params for per-object spiral distortion
	_register_spirit_globals()
	# Apply spiral shaders to world objects after the full scene tree is built
	call_deferred("_apply_spirit_shaders")

func _unhandled_input(event):
	# Mouse look - rotate player on Y, camera pivot on X
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENS)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -1.2, 0.5)

	# Release mouse cursor with Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Spirit world toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if _toggle_refused(not spirit_world):
			return
		spirit_world = !spirit_world
		if spirit_world:
			# Fresh entry resets distortion
			spirit_distortion = 0.0
			spirit_time = 0.0

func _process(delta):
	# Animate spirit world transition
	var target = 1.0 if spirit_world else 0.0
	spirit_transition = move_toward(spirit_transition, target, delta / SPIRIT_FADE_DURATION)
	spirit_overlay.visible = spirit_transition > 0.0

	# Build distortion while in spirit world
	if spirit_world:
		spirit_time += delta
		# Snake usage ramps distortion fast, idle is barely noticeable
		if snake.current_length > 0.1:
			spirit_distortion = min(spirit_distortion + DISTORTION_SNAKE_RATE * delta, 1.0)
		else:
			spirit_distortion = min(spirit_distortion + DISTORTION_PASSIVE_RATE * delta, 1.0)
	elif spirit_transition > 0.0:
		# Keep time ticking during fade-out so the spiral animates smoothly
		spirit_time += delta

	if spirit_overlay.visible:
		spirit_material.set_shader_parameter("transition", spirit_transition)
		spirit_material.set_shader_parameter("distortion", spirit_distortion)
		spirit_material.set_shader_parameter("spirit_time", spirit_time)

	# Update global uniforms for per-object spatial shaders
	RenderingServer.global_shader_parameter_set("spirit_distortion", spirit_distortion)
	RenderingServer.global_shader_parameter_set("spirit_time", spirit_time)
	RenderingServer.global_shader_parameter_set("spirit_transition", spirit_transition)

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# WASD input
	var input_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	# Move relative to player facing direction
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Slow down when snake is extended
	var move_speed = SPEED
	if snake.current_length > 0.1:
		move_speed = SPEED * 0.4

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

	# Camera wall collision - pull camera in front of walls
	var space = get_world_3d().direct_space_state
	var from = camera_pivot.global_position
	var to = camera_pivot.to_global(camera_default_pos)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # environment only
	query.exclude = [self.get_rid()]
	var result = space.intersect_ray(query)
	if result:
		var margin = (from - to).normalized() * 0.2
		camera.global_position = result.position + margin
	else:
		camera.position = camera_default_pos

# ── Spirit world: per-object shader system ──────────────────────────

func _toggle_refused(to_spirit: bool) -> bool:
	# Phase walls and phase blocks refuse the switch if they would appear on top of
	# the player (each one shimmers so you can see what's in the way)
	var refused = false
	for node in get_tree().get_nodes_in_group("phase"):
		if node.has_method("blocks_toggle") and node.blocks_toggle(to_spirit):
			refused = true
	if refused:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("show_notification"):
			gm.show_notification("Something is in the way", 1.2)
	return refused

func _register_spirit_globals():
	# Global shader params persist across scene changes (they are NOT freed
	# when the Player node is removed).  On a level transition the new Player
	# tries to add them again, which prints an error.  Guard with a static
	# flag so we only register once per game session.
	if _spirit_globals_registered:
		return
	_spirit_globals_registered = true

	RenderingServer.global_shader_parameter_add(
		"spirit_distortion", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add(
		"spirit_time", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add(
		"spirit_transition", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add(
		"portal_screen_rect", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_add(
		"portal_fade", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)

func _apply_spirit_shaders():
	var surface_shader = load("res://shaders/spiral_surface.gdshader")
	var object_shader = load("res://shaders/spiral_object.gdshader")
	_walk_and_apply(get_tree().current_scene, surface_shader, object_shader)

func _walk_and_apply(node: Node, surface_sh: Shader, object_sh: Shader):
	# Skip player and all descendants (body meshes, snake, camera)
	if node == self:
		return
	# Skip SpiritPortal nodes — they manage their own shader material
	if node.name.begins_with("SpiritPortal"):
		return

	if node is MeshInstance3D:
		var parent_name = ""
		if node.get_parent():
			parent_name = node.get_parent().name
		var structural = _is_structural(parent_name) or _is_structural(node.name)

		var mat = ShaderMaterial.new()
		mat.shader = surface_sh if structural else object_sh

		# Preserve original albedo color and emission from the mesh material
		var color = Color.WHITE
		var orig_mat: StandardMaterial3D = null
		if node.mesh and node.mesh.get_surface_count() > 0:
			var m = node.mesh.surface_get_material(0)
			if m is StandardMaterial3D:
				orig_mat = m
				color = orig_mat.albedo_color
		mat.set_shader_parameter("albedo_color", color)
		if orig_mat and orig_mat.emission_enabled:
			mat.set_shader_parameter("emission", orig_mat.emission)
			mat.set_shader_parameter("emission_energy", orig_mat.emission_energy_multiplier)

		node.material_override = mat

	for child in node.get_children():
		_walk_and_apply(child, surface_sh, object_sh)

func _is_structural(node_name: String) -> bool:
	for prefix in STRUCTURE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false
