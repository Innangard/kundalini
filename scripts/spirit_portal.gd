extends StaticBody3D

# Cycle timing (seconds) — 16 s total
const CYCLE_PERIOD = 16.0
const COOLDOWN = 9.0
const FADE_IN = 1.0
const OPEN_TIME = 5.0
const FADE_OUT = 1.0

# Door size in local space (wall mesh 0.25 x 3 x 1.75)
const DOOR_WIDTH = 1.0
const DOOR_HEIGHT = 2.2

@export var face_sign: float = 1.0

var portal_strength = 0.0
var col_was_disabled = false
var mat: ShaderMaterial
var player: Node

func _ready():
	# Build shader material, preserving the original wall color
	var mesh_node = $Mesh
	var orig_color = Color.WHITE
	if mesh_node.mesh and mesh_node.mesh.get_surface_count() > 0:
		var m = mesh_node.mesh.surface_get_material(0)
		if m is StandardMaterial3D:
			orig_color = m.albedo_color

	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/spirit_portal.gdshader")
	mat.set_shader_parameter("albedo_color", orig_color)
	mat.set_shader_parameter("portal_strength", 0.0)
	mesh_node.material_override = mat
	player = get_tree().current_scene.get_node("Player")

func _process(_delta):
	var transition: float = player.spirit_transition

	# ── Not in spirit world — keep wall solid, clear screen dimming ──
	if transition < 0.01:
		portal_strength = 0.0
		mat.set_shader_parameter("portal_strength", 0.0)
		if col_was_disabled:
			col_was_disabled = false
			$Col.set_deferred("disabled", false)
		RenderingServer.global_shader_parameter_set("portal_fade", 0.0)
		return

	# ── Compute portal strength from deterministic cycle ──
	var spirit_time: float = player.spirit_time
	var cycle_pos = fmod(spirit_time, CYCLE_PERIOD)

	if cycle_pos < COOLDOWN:
		portal_strength = 0.0
	elif cycle_pos < COOLDOWN + FADE_IN:
		portal_strength = (cycle_pos - COOLDOWN) / FADE_IN
	elif cycle_pos < COOLDOWN + FADE_IN + OPEN_TIME:
		portal_strength = 1.0
	else:
		portal_strength = 1.0 - (cycle_pos - COOLDOWN - FADE_IN - OPEN_TIME) / FADE_OUT

	portal_strength = clamp(portal_strength, 0.0, 1.0)
	mat.set_shader_parameter("portal_strength", portal_strength)

	# ── Toggle collision — passable while strength is high ──
	var passable = portal_strength > 0.5
	if passable != col_was_disabled:
		col_was_disabled = passable
		$Col.set_deferred("disabled", passable)

	# ── Screen-space rect for post-process dimming ──
	_update_screen_rect(transition)

func _update_screen_rect(transition: float):
	var fade = portal_strength * transition
	if fade < 0.01:
		RenderingServer.global_shader_parameter_set("portal_fade", 0.0)
		return

	var camera = get_viewport().get_camera_3d()
	if not camera:
		RenderingServer.global_shader_parameter_set("portal_fade", 0.0)
		return

	# Door corners in world space (+X face of the 0.25-thick wall)
	var face_x  = global_position.x + face_sign * 0.125
	var floor_y = global_position.y - 1.5
	var cz      = global_position.z

	var corners = [
		Vector3(face_x, floor_y,               cz - DOOR_WIDTH * 0.5),
		Vector3(face_x, floor_y + DOOR_HEIGHT,  cz - DOOR_WIDTH * 0.5),
		Vector3(face_x, floor_y,               cz + DOOR_WIDTH * 0.5),
		Vector3(face_x, floor_y + DOOR_HEIGHT,  cz + DOOR_WIDTH * 0.5),
	]

	var vp_size = get_viewport().get_visible_rect().size
	var uv_min = Vector2(1.0, 1.0)
	var uv_max = Vector2(0.0, 0.0)

	for corner in corners:
		# Skip if any corner is behind the camera
		var cam_local = camera.global_transform.affine_inverse() * corner
		if cam_local.z > 0.0:
			RenderingServer.global_shader_parameter_set("portal_fade", 0.0)
			return

		var uv = camera.unproject_position(corner) / vp_size
		uv_min = Vector2(min(uv_min.x, uv.x), min(uv_min.y, uv.y))
		uv_max = Vector2(max(uv_max.x, uv.x), max(uv_max.y, uv.y))

	RenderingServer.global_shader_parameter_set("portal_screen_rect",
		Vector4(uv_min.x, uv_min.y, uv_max.x, uv_max.y))
	RenderingServer.global_shader_parameter_set("portal_fade", fade)
