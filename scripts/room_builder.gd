class_name RoomBuilder
# Static utility for procedural level construction in Godot 4
# Builds walls, floors, ceilings, pillars, and lights from code

const WH = 3.0   # wall height
const WT = 0.25   # wall thickness
const FT = 0.2    # floor thickness

# Create a StandardMaterial3D with given color
static func mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

# Create a StaticBody3D box with mesh and collision at given position/size
static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var b = StaticBody3D.new()
	b.position = pos
	b.collision_layer = 1
	b.collision_mask = 0
	var c = CollisionShape3D.new()
	var s = BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	var mi = MeshInstance3D.new()
	var m = BoxMesh.new()
	m.size = size
	m.material = material
	mi.mesh = m
	b.add_child(mi)
	parent.add_child(b)
	return b

# Wall centered at (x, WH/2, z) with X-extent sx and Z-extent sz
static func wall(parent: Node3D, x: float, z: float, sx: float, sz: float, material: Material) -> StaticBody3D:
	return box(parent, Vector3(x, WH / 2.0, z), Vector3(sx, WH, sz), material)

# Floor with walking surface at y=0
static func floor_at(parent: Node3D, x: float, z: float, sx: float, sz: float, material: Material) -> StaticBody3D:
	return box(parent, Vector3(x, -FT / 2.0, z), Vector3(sx, FT, sz), material)

# Ceiling at top of wall height
static func ceil_at(parent: Node3D, x: float, z: float, sx: float, sz: float, material: Material) -> StaticBody3D:
	return box(parent, Vector3(x, WH + 0.05, z), Vector3(sx, 0.1, sz), material)

# Short wall/divider with base at y=0
static func short_wall(parent: Node3D, x: float, z: float, sx: float, h: float, sz: float, material: Material) -> StaticBody3D:
	return box(parent, Vector3(x, h / 2.0, z), Vector3(sx, h, sz), material)

# Decorative square pillar (full wall height)
static func pillar(parent: Node3D, x: float, z: float, r: float, material: Material) -> StaticBody3D:
	return wall(parent, x, z, r * 2, r * 2, material)

# Omni light at ceiling level
static func light(parent: Node3D, x: float, z: float, color: Color = Color(1, 0.9, 0.75), energy: float = 0.6, rng: float = 6.0) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.position = Vector3(x, 2.8, z)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	parent.add_child(l)
	return l
