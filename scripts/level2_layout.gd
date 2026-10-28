extends Node3D

# Level 2 — "The Serpent's Warren"
# Abilities available: Push + Pull (Pull newly unlocked this level)
# Layout: Hub-and-spoke with 3 branches, each hiding a lever
# Goal: Find and pull all 3 levers to open the Final Gate
#
# ROOMS (inner bounds [x1,x2, z1,z2]):
#  Spawn        [-1.5, 1.5,  -1.5, 1.5]     3x3
#  Tutorial     [ 1.5, 9.5,  -4,   4  ]     8x8
#  Alcove       [ 3.75,6.25, -6.5,-4  ]     2.5x2.5
#  Connector    [ 9.5, 15,   -2,   2  ]     5.5x4
#  Hub          [15,   29,   -7,   7  ]     14x14
#  N.Corridor   [20.75,23.25,-7,  -12 ]     2.5x5
#  N.Workshop   [15,   29,   -12, -24 ]     14x12
#  N.LeverRoom  [20,   24,   -24, -28 ]     4x4
#  N.Secret     [29,   34,   -16.5,-19.5]   5x3
#  S.Corridor   [20.75,23.25, 7,   12 ]     2.5x5
#  S.Maze       [15,   29,    12,  24 ]     14x12
#  S.LeverRoom  [29,   34,    18,  22 ]     5x4
#  S.Secret     [11,   15,    19,  22 ]     4x3
#  Exit         [29,   35,   -2,   2  ]     6x4
#  Victory      [35,   39,   -2,   2  ]     4x4

# --- Preloaded scripts (avoids set_script() issues) ---
const PushableBlockScript = preload("res://scripts/pushable_block.gd")
const LeverScript = preload("res://scripts/lever.gd")
const PressurePlateScript = preload("res://scripts/pressure_plate.gd")
const PressureDoorScript = preload("res://scripts/pressure_door.gd")
const LeverDoorScript = preload("res://scripts/lever_door.gd")
const LevelCompleteScript = preload("res://scripts/level_complete.gd")
const LevelBoundsScript = preload("res://scripts/level_bounds.gd")

# --- Materials ---
var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var ceil_mat: StandardMaterial3D
var crate_mat: StandardMaterial3D
var door_mat: StandardMaterial3D
var lever_base_mat: StandardMaterial3D
var lever_handle_mat: StandardMaterial3D
var pillar_mat: StandardMaterial3D
var accent_mat: StandardMaterial3D    # blue zone highlights
var secret_mat: StandardMaterial3D    # slightly different wall shade for secrets

# --- Key interactive node refs (wired after all are created) ---
var final_gate: Node        # LeverDoor needing 3 levers
var tut_door: Node          # PressureDoor in tutorial
var north_plate_door: Node  # PressureDoor guarding north lever room
var lever_a: Node           # hub lever
var lever_b: Node           # north lever
var lever_c: Node           # south lever
var tut_plate: Node         # tutorial pressure plate
var n_plates: Array = []    # north workshop pressure plates


func _ready():
	_init_materials()
	_build_environment()
	_build_spawn()
	_build_tutorial()
	_build_connector()
	_build_hub()
	_build_north_corridor()
	_build_north_workshop()
	_build_north_lever_room()
	_build_north_secret()
	_build_south_corridor()
	_build_south_maze()
	_build_south_lever_room()
	_build_south_secret()
	_build_exit()
	_build_victory()
	_build_bounds()
	# Wire all target_path references now that every node is in tree
	_wire_targets()


# ============================================================
#  MATERIALS
# ============================================================
func _init_materials():
	floor_mat = RoomBuilder.mat(Color(0.30, 0.22, 0.13))
	wall_mat = RoomBuilder.mat(Color(0.55, 0.48, 0.38))
	ceil_mat = RoomBuilder.mat(Color(0.45, 0.40, 0.33), 0.85)
	crate_mat = RoomBuilder.mat(Color(0.22, 0.32, 0.50))
	door_mat = RoomBuilder.mat(Color(0.28, 0.16, 0.08))
	lever_base_mat = RoomBuilder.mat(Color(0.18, 0.18, 0.20))
	lever_handle_mat = RoomBuilder.mat(Color(0.40, 0.22, 0.10))
	pillar_mat = RoomBuilder.mat(Color(0.40, 0.32, 0.22))
	accent_mat = RoomBuilder.mat(Color(0.20, 0.35, 0.55))
	secret_mat = RoomBuilder.mat(Color(0.50, 0.42, 0.33))


# ============================================================
#  ENVIRONMENT (light + fog)
# ============================================================
func _build_environment():
	var dir_light = DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	dir_light.light_color = Color(1, 0.95, 0.85)
	dir_light.light_energy = 0.12
	dir_light.shadow_enabled = true
	add_child(dir_light)

	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.24, 0.20)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.12, 0.10)
	env.fog_density = 0.008
	world_env.environment = env
	add_child(world_env)


# ============================================================
#  WALL HELPERS — build wall segments with door gaps
# ============================================================

# North-south wall (runs along Z) at given X, from z1 to z2
# gaps: Array of {pos: float, width: float}
func _ns_wall(x: float, z1: float, z2: float, mat: Material, gaps: Array = []):
	var sorted = gaps.duplicate()
	sorted.sort_custom(func(a, b): return a.pos < b.pos)
	var segs = []
	var cur = z1
	for g in sorted:
		var gs = g.pos - g.width / 2.0
		var ge = g.pos + g.width / 2.0
		if gs > cur + 0.05:
			segs.append([cur, gs])
		cur = ge
	if cur < z2 - 0.05:
		segs.append([cur, z2])
	for s in segs:
		var length = s[1] - s[0]
		var center = (s[0] + s[1]) / 2.0
		RoomBuilder.wall(self, x, center, RoomBuilder.WT, length, mat)

# East-west wall (runs along X) at given Z, from x1 to x2
func _ew_wall(z: float, x1: float, x2: float, mat: Material, gaps: Array = []):
	var sorted = gaps.duplicate()
	sorted.sort_custom(func(a, b): return a.pos < b.pos)
	var segs = []
	var cur = x1
	for g in sorted:
		var gs = g.pos - g.width / 2.0
		var ge = g.pos + g.width / 2.0
		if gs > cur + 0.05:
			segs.append([cur, gs])
		cur = ge
	if cur < x2 - 0.05:
		segs.append([cur, x2])
	for s in segs:
		var length = s[1] - s[0]
		var center = (s[0] + s[1]) / 2.0
		RoomBuilder.wall(self, center, z, length, RoomBuilder.WT, mat)


# ============================================================
#  INTERACTIVE ELEMENT HELPERS
# ============================================================

func _make_block(pos: Vector3) -> RigidBody3D:
	var block = PushableBlockScript.new()
	block.position = pos
	block.collision_layer = 8
	block.collision_mask = 15
	block.mass = 3.0
	block.axis_lock_angular_x = true
	block.axis_lock_angular_y = true
	block.axis_lock_angular_z = true
	# Collision shape (0.7 cube)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.7, 0.7, 0.7)
	col.shape = shape
	block.add_child(col)
	# Mesh
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.7, 0.7, 0.7)
	mesh.material = crate_mat
	mi.mesh = mesh
	block.add_child(mi)
	add_child(block)
	return block

func _make_lever(pos: Vector3) -> StaticBody3D:
	var lev = LeverScript.new()
	lev.position = pos
	lev.collision_layer = 1
	lev.collision_mask = 0
	# Collision shape for interaction
	var col = CollisionShape3D.new()
	col.name = "Col"
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.3, 0.8, 0.25)
	col.shape = shape
	lev.add_child(col)
	# Base mesh
	var base_mi = MeshInstance3D.new()
	base_mi.name = "Base"
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(0.25, 0.25, 0.12)
	base_mesh.material = lever_base_mat
	base_mi.mesh = base_mesh
	lev.add_child(base_mi)
	# Handle pivot (lever.gd animates $HandlePivot)
	var pivot = Node3D.new()
	pivot.name = "HandlePivot"
	pivot.position = Vector3(0, 0.15, 0)
	lev.add_child(pivot)
	# Handle mesh on the pivot
	var handle_mi = MeshInstance3D.new()
	handle_mi.name = "Handle"
	handle_mi.position = Vector3(0, 0.25, 0)
	var handle_mesh = BoxMesh.new()
	handle_mesh.size = Vector3(0.06, 0.5, 0.06)
	handle_mesh.material = lever_handle_mat
	handle_mi.mesh = handle_mesh
	pivot.add_child(handle_mi)
	add_child(lev)
	return lev

func _make_pressure_plate(pos: Vector3) -> Area3D:
	var plate = PressurePlateScript.new()
	plate.position = pos
	plate.monitoring = true
	# Script creates its own mesh/collision in _ready()
	add_child(plate)
	return plate

# PressureDoor — creates its own mesh/collision in _ready()
# horizontal=true rotates size for east-west walls (gap runs in Z direction)
func _make_pressure_door(pos: Vector3, required: int = 1, stays: bool = false, horizontal: bool = false) -> StaticBody3D:
	var door = PressureDoorScript.new()
	door.position = pos
	door.required_plates = required
	door.stays_open = stays
	if horizontal:
		door.door_size = Vector3(1.75, 2.5, 0.25)
	add_child(door)
	return door

# LeverDoor — does NOT create its own mesh, we must provide Col + Mesh children
func _make_lever_door(pos: Vector3, req_levers: int = 1) -> StaticBody3D:
	var door = LeverDoorScript.new()
	door.position = pos
	door.collision_layer = 1
	door.collision_mask = 0
	door.required_levers = req_levers
	# Collision
	var col = CollisionShape3D.new()
	col.name = "Col"
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.25, 2.5, 1.75)
	col.shape = shape
	door.add_child(col)
	# Mesh
	var mi = MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.25, 2.5, 1.75)
	mesh.material = door_mat
	mi.mesh = mesh
	door.add_child(mi)
	add_child(door)
	return door

func _make_level_complete(pos: Vector3) -> Area3D:
	var trigger = LevelCompleteScript.new()
	trigger.position = pos
	trigger.name = "LevelCompleteTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	trigger.monitoring = true
	trigger.next_level = "res://scenes/level3.tscn"
	trigger.unlock_type = "eat_spit"
	# Collision shape (resized to 3x3x3 in level_complete._ready())
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	col.shape = shape
	trigger.add_child(col)
	add_child(trigger)
	return trigger


# ============================================================
#  SPAWN CORRIDOR  [-1.5, 1.5, -1.5, 1.5]
# ============================================================
func _build_spawn():
	RoomBuilder.floor_at(self, 0, 0, 3, 3, floor_mat)
	RoomBuilder.ceil_at(self, 0, 0, 3, 3, ceil_mat)
	# N, S, W walls (solid). E wall built by tutorial (shared boundary).
	_ew_wall(-1.625, -1.5, 1.5, wall_mat)
	_ew_wall(1.625, -1.5, 1.5, wall_mat)
	_ns_wall(-1.625, -1.5, 1.5, wall_mat)
	RoomBuilder.light(self, 0, 0, Color(1, 0.9, 0.75), 0.5, 4)


# ============================================================
#  TUTORIAL ROOM  [1.5, 9.5, -4, 4]  +  ALCOVE [3.75,6.25,-6.5,-4]
# ============================================================
func _build_tutorial():
	# --- Main room floor/ceiling ---
	RoomBuilder.floor_at(self, 5.5, 0, 8, 8, floor_mat)
	RoomBuilder.ceil_at(self, 5.5, 0, 8, 8, ceil_mat)

	# W wall with door from spawn (gap at z=0, width=2)
	_ns_wall(1.625, -4, 4, wall_mat, [{pos = 0.0, width = 2.0}])
	# S wall (solid)
	_ew_wall(4.125, 1.5, 9.5, wall_mat)
	# N wall with alcove opening (gap at x=5, width=2.5)
	_ew_wall(-4.125, 1.5, 9.5, wall_mat, [{pos = 5.0, width = 2.5}])
	# E wall with door to connector (gap at z=0, width=2)
	_ns_wall(9.625, -4, 4, wall_mat, [{pos = 0.0, width = 2.0}])

	# --- Tutorial Alcove ---
	RoomBuilder.floor_at(self, 5.0, -5.25, 2.5, 2.5, floor_mat)
	RoomBuilder.ceil_at(self, 5.0, -5.25, 2.5, 2.5, ceil_mat)
	_ew_wall(-6.625, 3.75, 6.25, wall_mat)   # alcove N wall
	_ns_wall(3.625, -6.5, -4, wall_mat)      # alcove W wall
	_ns_wall(6.375, -6.5, -4, wall_mat)      # alcove E wall

	# --- Tutorial Puzzle ---
	# Block in alcove — player must PULL it south (can't push north into wall)
	_make_block(Vector3(5.0, 0.35, -5.5))
	# Pressure plate near east door
	tut_plate = _make_pressure_plate(Vector3(8.0, 0, 0))
	# Pressure door blocking east exit (in doorway gap)
	tut_door = _make_pressure_door(Vector3(9.625, 1.1, 0), 1, true)

	# Floor indicator showing where to push the block
	RoomBuilder.short_wall(self, 8.0, 0, 1.3, 0.02, 1.3, accent_mat)

	RoomBuilder.light(self, 5.5, 0, Color(1, 0.9, 0.75), 0.6, 7)
	RoomBuilder.light(self, 5.0, -5.0, Color(1, 0.85, 0.7), 0.4, 3)


# ============================================================
#  CONNECTOR  [9.5, 15, -2, 2]
# ============================================================
func _build_connector():
	RoomBuilder.floor_at(self, 12.25, 0, 5.5, 4, floor_mat)
	RoomBuilder.ceil_at(self, 12.25, 0, 5.5, 4, ceil_mat)
	# Side walls only (W shared with tutorial E, E shared with hub W)
	_ew_wall(-2.125, 9.5, 15, wall_mat)
	_ew_wall(2.125, 9.5, 15, wall_mat)
	RoomBuilder.light(self, 12.25, 0, Color(1, 0.9, 0.75), 0.4, 5)


# ============================================================
#  HUB / GRAND HALL  [15, 29, -7, 7]
# ============================================================
func _build_hub():
	RoomBuilder.floor_at(self, 22, 0, 14, 14, floor_mat)
	RoomBuilder.ceil_at(self, 22, 0, 14, 14, ceil_mat)

	# W wall with door from connector (gap at z=0, w=2)
	_ns_wall(14.875, -7, 7, wall_mat, [{pos = 0.0, width = 2.0}])
	# N wall with door to north corridor (gap at x=22, w=2.5)
	_ew_wall(-7.125, 15, 29, wall_mat, [{pos = 22.0, width = 2.5}])
	# S wall with door to south corridor (gap at x=22, w=2.5)
	_ew_wall(7.125, 15, 29, wall_mat, [{pos = 22.0, width = 2.5}])
	# E wall with Final Gate door (gap at z=0, w=2)
	_ns_wall(29.125, -7, 7, wall_mat, [{pos = 0.0, width = 2.0}])

	# --- Final Gate (LeverDoor, needs 3 levers) ---
	final_gate = _make_lever_door(Vector3(29.125, 1.1, 0), 3)
	final_gate.name = "FinalGate"

	# --- 4 decorative pillars ---
	RoomBuilder.pillar(self, 18, -3.5, 0.4, pillar_mat)
	RoomBuilder.pillar(self, 18, 3.5, 0.4, pillar_mat)
	RoomBuilder.pillar(self, 26, -3.5, 0.4, pillar_mat)
	RoomBuilder.pillar(self, 26, 3.5, 0.4, pillar_mat)

	# --- Hub puzzle: Lever A in NE alcove ---
	# Internal short wall creates a nook in the NE corner
	# Wall runs EW at z=-4.5 from x=26 to x=29 (blocks off NE corner)
	_ew_wall(-4.5, 26, 29, wall_mat, [{pos = 27.5, width = 1.5}])
	# Block sits in the gap, must pull it south to enter nook
	_make_block(Vector3(27.5, 0.35, -4.5))
	# Lever A inside the nook against the N wall
	lever_a = _make_lever(Vector3(27.5, 0.5, -6.0))
	lever_a.name = "LeverA"

	# Lights
	RoomBuilder.light(self, 19, -2, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 25, -2, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 19, 2, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 25, 2, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 22, 0, Color(1, 0.85, 0.7), 0.3, 8)


# ============================================================
#  NORTH CORRIDOR  [20.75, 23.25, -7, -12]
# ============================================================
func _build_north_corridor():
	RoomBuilder.floor_at(self, 22, -9.5, 2.5, 5, floor_mat)
	RoomBuilder.ceil_at(self, 22, -9.5, 2.5, 5, ceil_mat)
	# Side walls only (N/S shared with hub and workshop)
	_ns_wall(20.625, -7, -12, wall_mat)
	_ns_wall(23.375, -7, -12, wall_mat)
	RoomBuilder.light(self, 22, -9.5, Color(1, 0.9, 0.75), 0.4, 4)


# ============================================================
#  NORTH WORKSHOP  [15, 29, -12, -24]
# ============================================================
func _build_north_workshop():
	RoomBuilder.floor_at(self, 22, -18, 14, 12, floor_mat)
	RoomBuilder.ceil_at(self, 22, -18, 14, 12, ceil_mat)

	# S wall with door from N corridor (gap at x=22, w=2.5)
	_ew_wall(-12.125, 15, 29, wall_mat, [{pos = 22.0, width = 2.5}])
	# W wall (solid)
	_ns_wall(14.875, -12, -24, wall_mat)
	# E wall with hidden secret door (gap at z=-18, w=2)
	_ns_wall(29.125, -12, -24, wall_mat, [{pos = -18.0, width = 2.0}])
	# N wall with door to lever room (gap at x=22, w=2)
	_ew_wall(-24.125, 15, 29, wall_mat, [{pos = 22.0, width = 2.0}])

	# --- Internal divider wall at z=-18 splits room into upper/lower halves ---
	# Gap at x=22, width=2.5 for passage between halves
	_ew_wall(-18, 15, 29, wall_mat, [{pos = 22.0, width = 2.5}])

	# --- Western niche for block D (pull puzzle) ---
	# Small alcove created by a short NS wall at x=18, from z=-20 to z=-22
	_ns_wall(18.125, -20, -22, wall_mat)
	# Block D sits inside the niche against the west wall
	_make_block(Vector3(16.5, 0.35, -21))

	# --- Blocks in upper half ---
	_make_block(Vector3(17.0, 0.35, -14))   # Block A — freely available
	_make_block(Vector3(27.0, 0.35, -14))   # Block B — freely available

	# --- Block in lower half ---
	_make_block(Vector3(22.0, 0.35, -21))   # Block C — freely available

	# --- Secret door blocker (block covering the E wall gap) ---
	# This block sits in front of the gap at x=29, z=-18 and looks like wall
	_make_block(Vector3(28.5, 0.35, -18))

	# --- 3 pressure plates near lever room door ---
	var p1 = _make_pressure_plate(Vector3(19.5, 0, -23))
	var p2 = _make_pressure_plate(Vector3(22.0, 0, -23))
	var p3 = _make_pressure_plate(Vector3(24.5, 0, -23))
	n_plates = [p1, p2, p3]

	# Floor indicators for plate positions
	RoomBuilder.short_wall(self, 19.5, -23, 1.3, 0.02, 1.3, accent_mat)
	RoomBuilder.short_wall(self, 22.0, -23, 1.3, 0.02, 1.3, accent_mat)
	RoomBuilder.short_wall(self, 24.5, -23, 1.3, 0.02, 1.3, accent_mat)

	# Pressure door blocking lever room (in the N wall gap, oriented for EW wall)
	north_plate_door = _make_pressure_door(Vector3(22.0, 1.1, -24.125), 3, true, true)
	north_plate_door.name = "NorthPlateDoor"

	# Lights
	RoomBuilder.light(self, 18, -15, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 26, -15, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 18, -21, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 26, -21, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 22, -18, Color(1, 0.85, 0.7), 0.3, 5)


# ============================================================
#  NORTH LEVER ROOM  [20, 24, -24, -28]
# ============================================================
func _build_north_lever_room():
	RoomBuilder.floor_at(self, 22, -26, 4, 4, floor_mat)
	RoomBuilder.ceil_at(self, 22, -26, 4, 4, ceil_mat)
	# S wall shared with workshop N wall — skip
	# W, E, N walls
	_ns_wall(19.875, -24, -28, wall_mat)
	_ns_wall(24.125, -24, -28, wall_mat)
	_ew_wall(-28.125, 20, 24, wall_mat)
	# Lever B
	lever_b = _make_lever(Vector3(22.0, 0.5, -27.0))
	lever_b.name = "LeverB"
	RoomBuilder.light(self, 22, -26, Color(0.9, 0.7, 0.4), 0.6, 4)


# ============================================================
#  NORTH SECRET  [29, 34, -16.5, -19.5]
# ============================================================
func _build_north_secret():
	RoomBuilder.floor_at(self, 31.5, -18, 5, 3, secret_mat)
	RoomBuilder.ceil_at(self, 31.5, -18, 5, 3, ceil_mat)
	# W wall shared with workshop E wall opening — skip
	_ew_wall(-16.375, 29, 34, secret_mat)
	_ns_wall(34.125, -16.5, -19.5, secret_mat)
	_ew_wall(-19.625, 29, 34, secret_mat)
	# Decorative pedestal in center
	RoomBuilder.short_wall(self, 31.5, -18, 0.6, 0.8, 0.6, pillar_mat)
	# Glowing accent on top
	RoomBuilder.short_wall(self, 31.5, -18, 0.3, 0.85, 0.3, accent_mat)
	RoomBuilder.light(self, 31.5, -18, Color(0.5, 0.7, 1.0), 0.8, 4)


# ============================================================
#  SOUTH CORRIDOR  [20.75, 23.25, 7, 12]
# ============================================================
func _build_south_corridor():
	RoomBuilder.floor_at(self, 22, 9.5, 2.5, 5, floor_mat)
	RoomBuilder.ceil_at(self, 22, 9.5, 2.5, 5, ceil_mat)
	_ns_wall(20.625, 7, 12, wall_mat)
	_ns_wall(23.375, 7, 12, wall_mat)
	RoomBuilder.light(self, 22, 9.5, Color(1, 0.9, 0.75), 0.4, 4)


# ============================================================
#  SOUTH MAZE  [15, 29, 12, 24]
# ============================================================
func _build_south_maze():
	RoomBuilder.floor_at(self, 22, 18, 14, 12, floor_mat)
	RoomBuilder.ceil_at(self, 22, 18, 14, 12, ceil_mat)

	# N wall with door from S corridor (gap at x=22, w=2.5)
	_ew_wall(11.875, 15, 29, wall_mat, [{pos = 22.0, width = 2.5}])
	# S wall (solid)
	_ew_wall(24.125, 15, 29, wall_mat)
	# W wall with hidden secret opening (gap at z=20.5, w=2)
	_ns_wall(14.875, 12, 24, wall_mat, [{pos = 20.5, width = 2.0}])
	# E wall with door to lever room (gap at z=20, w=2)
	_ns_wall(29.125, 12, 24, wall_mat, [{pos = 20.0, width = 2.0}])

	# --- Central NS divider from z=14 to z=21 (gap at z=13 and z=22 open areas) ---
	_ns_wall(22, 14, 21, wall_mat)

	# --- West side: EW wall at z=17, from x=15 to x=21 (blocks west path) ---
	# Gap at x=18, width=1.5 for passage
	_ew_wall(17, 15, 21.75, wall_mat, [{pos = 18.0, width = 1.5}])

	# --- East side: EW wall at z=19, from x=22.25 to x=29 (blocks east path) ---
	# Gap at x=26, width=1.5 for passage
	_ew_wall(19, 22.25, 29, wall_mat, [{pos = 26.0, width = 1.5}])

	# --- Maze blocks ---
	# West path: block in the gap at z=17 x=18 — pull it aside to pass
	_make_block(Vector3(18.0, 0.35, 16.5))
	# East path: block near gap at z=19 x=26 — push or pull to clear
	_make_block(Vector3(26.0, 0.35, 18.5))
	# Extra block near center for misdirection
	_make_block(Vector3(20.0, 0.35, 20.0))

	# Secret entrance blocker (block covering W wall gap at z=20.5)
	_make_block(Vector3(15.5, 0.35, 20.5))

	# Lights
	RoomBuilder.light(self, 18, 14, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 26, 14, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 18, 22, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 26, 22, Color(1, 0.9, 0.75), 0.5, 6)
	RoomBuilder.light(self, 22, 18, Color(1, 0.85, 0.7), 0.3, 5)


# ============================================================
#  SOUTH LEVER ROOM  [29, 34, 18, 22]
# ============================================================
func _build_south_lever_room():
	RoomBuilder.floor_at(self, 31.5, 20, 5, 4, floor_mat)
	RoomBuilder.ceil_at(self, 31.5, 20, 5, 4, ceil_mat)
	# W wall shared with maze E wall — skip
	_ew_wall(17.875, 29, 34, wall_mat)
	_ns_wall(34.125, 18, 22, wall_mat)
	_ew_wall(22.125, 29, 34, wall_mat)
	# Lever C
	lever_c = _make_lever(Vector3(32.0, 0.5, 20.0))
	lever_c.name = "LeverC"
	RoomBuilder.light(self, 31.5, 20, Color(0.9, 0.7, 0.4), 0.6, 4)


# ============================================================
#  SOUTH SECRET  [11, 15, 19, 22]
# ============================================================
func _build_south_secret():
	RoomBuilder.floor_at(self, 13, 20.5, 4, 3, secret_mat)
	RoomBuilder.ceil_at(self, 13, 20.5, 4, 3, ceil_mat)
	# E wall shared with maze W wall opening — skip
	_ew_wall(18.875, 11, 15, secret_mat)
	_ns_wall(10.875, 19, 22, secret_mat)
	_ew_wall(22.125, 11, 15, secret_mat)
	# Decorative pedestal
	RoomBuilder.short_wall(self, 13, 20.5, 0.6, 0.8, 0.6, pillar_mat)
	RoomBuilder.short_wall(self, 13, 20.5, 0.3, 0.85, 0.3, accent_mat)
	RoomBuilder.light(self, 13, 20.5, Color(0.5, 0.7, 1.0), 0.8, 4)


# ============================================================
#  EXIT CORRIDOR  [29, 35, -2, 2]  (behind Final Gate)
# ============================================================
func _build_exit():
	RoomBuilder.floor_at(self, 32, 0, 6, 4, floor_mat)
	RoomBuilder.ceil_at(self, 32, 0, 6, 4, ceil_mat)
	# W wall shared with hub E wall — skip
	# Side walls
	_ew_wall(-2.125, 29, 35, wall_mat)
	_ew_wall(2.125, 29, 35, wall_mat)
	# E wall with door to victory room (gap at z=0, w=2)
	_ns_wall(35.125, -2, 2, wall_mat, [{pos = 0.0, width = 2.0}])
	RoomBuilder.light(self, 32, 0, Color(1, 0.9, 0.75), 0.4, 5)


# ============================================================
#  VICTORY CHAMBER  [35, 39, -2, 2]
# ============================================================
func _build_victory():
	RoomBuilder.floor_at(self, 37, 0, 4, 4, floor_mat)
	RoomBuilder.ceil_at(self, 37, 0, 4, 4, ceil_mat)
	# W wall shared with exit E wall — skip
	_ew_wall(-2.125, 35, 39, wall_mat)
	_ns_wall(39.125, -2, 2, wall_mat)
	_ew_wall(2.125, 35, 39, wall_mat)
	# Level complete trigger
	_make_level_complete(Vector3(37, 1.0, 0))
	# Victory light (warm golden glow)
	RoomBuilder.light(self, 37, 0, Color(1, 0.85, 0.5), 1.0, 5)


# ============================================================
#  LEVEL BOUNDS
# ============================================================
func _build_bounds():
	var bounds = LevelBoundsScript.new()
	bounds.name = "LevelBounds"
	bounds.bound_x_min = -3.0
	bounds.bound_x_max = 41.0
	bounds.bound_z_min = -30.0
	bounds.bound_z_max = 26.0
	bounds.bound_y_min = -1.0
	bounds.bound_y_max = 6.0
	add_child(bounds)


# ============================================================
#  WIRE TARGET PATHS (must run after all nodes are in tree)
# ============================================================
func _wire_targets():
	# Tutorial: plate -> door
	tut_plate.target_path = tut_plate.get_path_to(tut_door)
	# Hub lever A -> Final Gate
	lever_a.target_path = lever_a.get_path_to(final_gate)
	# North lever B -> Final Gate
	lever_b.target_path = lever_b.get_path_to(final_gate)
	# South lever C -> Final Gate
	lever_c.target_path = lever_c.get_path_to(final_gate)
	# North pressure plates -> north plate door
	for plate in n_plates:
		plate.target_path = plate.get_path_to(north_plate_door)
