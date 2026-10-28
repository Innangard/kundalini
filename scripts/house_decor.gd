extends Node3D

# Procedural house decoration - abandoned/decrepit aesthetic
# Attach to level root. Scans for Floor/Ceiling/Wall/Light nodes
# and adds stains, debris, dirt bands, and light flicker at runtime.
# Deterministic per-level via seeded RNG so decoration is consistent.

var rng = RandomNumberGenerator.new()
var _flicker_lights: Array = []  # [[light, base_energy, phase_offset], ...]
var _flicker_time: float = 0.0

# --- Materials (shared across all generated meshes) ---
var mat_floor_stain: StandardMaterial3D
var mat_ceiling_stain: StandardMaterial3D
var mat_dirt_band: StandardMaterial3D
var mat_debris_dark: StandardMaterial3D
var mat_debris_light: StandardMaterial3D

func _ready():
	rng.seed = hash(get_tree().current_scene.name) + 7
	_init_materials()
	call_deferred("_decorate")

func _init_materials():
	# Floor stains - dark brownish patches
	mat_floor_stain = StandardMaterial3D.new()
	mat_floor_stain.albedo_color = Color(0.12, 0.08, 0.05, 0.4)
	mat_floor_stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_floor_stain.roughness = 1.0

	# Ceiling water stains - yellowish brown
	mat_ceiling_stain = StandardMaterial3D.new()
	mat_ceiling_stain.albedo_color = Color(0.45, 0.35, 0.18, 0.3)
	mat_ceiling_stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ceiling_stain.roughness = 1.0

	# Wall dirt bands - dark grime at base of walls
	mat_dirt_band = StandardMaterial3D.new()
	mat_dirt_band.albedo_color = Color(0.15, 0.1, 0.07, 0.35)
	mat_dirt_band.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_dirt_band.roughness = 1.0

	# Debris materials - dark and light variants
	mat_debris_dark = StandardMaterial3D.new()
	mat_debris_dark.albedo_color = Color(0.18, 0.13, 0.08, 1)
	mat_debris_dark.roughness = 1.0

	mat_debris_light = StandardMaterial3D.new()
	mat_debris_light.albedo_color = Color(0.4, 0.35, 0.28, 1)
	mat_debris_light.roughness = 1.0

func _decorate():
	var root = get_parent()
	for child in root.get_children():
		var cname = child.name as String
		# Floor nodes - add stains and debris
		if cname.begins_with("Floor") or cname.begins_with("HallFloor") or _is_short("F", cname):
			_stain_surface(child, true)
			_scatter_debris(child)
		# Ceiling nodes - add water damage
		elif cname.begins_with("Ceiling") or _is_short("C", cname):
			_stain_surface(child, false)
		# Wall/Hall nodes (not floors) - add dirt band at base
		elif _is_wall(cname):
			_add_dirt_band(child)
		# Lights - register for flicker
		elif child is OmniLight3D:
			var offset = rng.randf_range(0, TAU)
			_flicker_lights.append([child, child.light_energy, offset])

func _is_short(prefix: String, cname: String) -> bool:
	# Match short names like F1, C2, W12 (prefix + digits only)
	if not cname.begins_with(prefix) or cname.length() <= prefix.length():
		return false
	return cname.substr(prefix.length()).is_valid_int()

func _is_wall(cname: String) -> bool:
	if _is_short("W", cname):
		return true
	for prefix in ["Wall", "Hall"]:
		if cname.begins_with(prefix) and not "Floor" in cname and not "Light" in cname:
			return true
	return false

# --- Floor/Ceiling stains ---

func _stain_surface(node: Node, is_floor: bool):
	var mesh_child = node.get_node_or_null("Mesh")
	if not mesh_child or not mesh_child is MeshInstance3D:
		return
	if not mesh_child.mesh or not mesh_child.mesh is BoxMesh:
		return
	var size = mesh_child.mesh.size
	var pos = mesh_child.global_position

	var count = rng.randi_range(2, 4)
	for i in range(count):
		var sx = rng.randf_range(0.4, 1.8)
		var sz = rng.randf_range(0.3, 1.4)
		var stain = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(sx, 0.005, sz)
		mesh.material = mat_floor_stain if is_floor else mat_ceiling_stain
		stain.mesh = mesh
		# Place just above floor or just below ceiling
		var y_offset = 0.105 if is_floor else -0.055
		stain.position = Vector3(
			pos.x + rng.randf_range(-size.x * 0.35, size.x * 0.35),
			pos.y + y_offset,
			pos.z + rng.randf_range(-size.z * 0.35, size.z * 0.35)
		)
		stain.rotation.y = rng.randf_range(0, TAU)
		get_parent().add_child(stain)

# --- Floor debris ---

func _scatter_debris(floor_node: Node):
	var mesh_child = floor_node.get_node_or_null("Mesh")
	if not mesh_child or not mesh_child is MeshInstance3D:
		return
	if not mesh_child.mesh or not mesh_child.mesh is BoxMesh:
		return
	var size = mesh_child.mesh.size
	var pos = mesh_child.global_position

	# Scale debris count by floor area
	var area = size.x * size.z
	var count = clampi(int(area * 0.15), 2, 12)
	for i in range(count):
		var piece = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		var sx = rng.randf_range(0.03, 0.15)
		var sy = rng.randf_range(0.01, 0.06)
		var sz = rng.randf_range(0.03, 0.12)
		mesh.size = Vector3(sx, sy, sz)
		# Alternate between dark and light debris
		if rng.randf() > 0.4:
			mesh.material = mat_debris_dark
		else:
			mesh.material = mat_debris_light
		piece.mesh = mesh
		piece.position = Vector3(
			pos.x + rng.randf_range(-size.x * 0.42, size.x * 0.42),
			pos.y + 0.1 + sy * 0.5,
			pos.z + rng.randf_range(-size.z * 0.42, size.z * 0.42)
		)
		piece.rotation = Vector3(
			rng.randf_range(-0.3, 0.3),
			rng.randf_range(0, TAU),
			rng.randf_range(-0.2, 0.2)
		)
		get_parent().add_child(piece)

# --- Wall dirt bands ---

func _add_dirt_band(wall_node: Node):
	var mesh_child = wall_node.get_node_or_null("Mesh")
	if not mesh_child or not mesh_child is MeshInstance3D:
		return
	if not mesh_child.mesh or not mesh_child.mesh is BoxMesh:
		return
	var wsize = mesh_child.mesh.size
	var wpos = mesh_child.global_position

	# Dirt band: covers bottom 0.4m of the wall, slightly thicker than wall
	var band = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	var band_height = 0.4
	# Make band slightly thicker than wall so it wraps both faces
	if wsize.x > wsize.z:
		# N/S wall (extends along X)
		mesh.size = Vector3(wsize.x, band_height, wsize.z + 0.006)
	else:
		# E/W wall (extends along Z)
		mesh.size = Vector3(wsize.x + 0.006, band_height, wsize.z)
	mesh.material = mat_dirt_band
	band.mesh = mesh
	# Position at the base of the wall
	var wall_bottom = wpos.y - wsize.y * 0.5
	band.position = Vector3(wpos.x, wall_bottom + band_height * 0.5, wpos.z)
	get_parent().add_child(band)

# --- Light flicker ---

func _process(delta):
	if _flicker_lights.is_empty():
		return
	_flicker_time += delta
	for entry in _flicker_lights:
		var light = entry[0] as OmniLight3D
		var base = entry[1] as float
		var phase = entry[2] as float
		if is_instance_valid(light):
			# Very subtle sine-based flicker - not horror strobe, just uneasy
			var v = sin(_flicker_time * 1.7 + phase) * 0.04
			v += sin(_flicker_time * 4.3 + phase * 1.5) * 0.02
			v += sin(_flicker_time * 7.1 + phase * 0.7) * 0.01
			light.light_energy = base * (1.0 + v)
