extends Node3D

# Procedural furniture detailing - replaces single-box meshes with
# multi-part compositions for more realistic furniture shapes.
# Collision shapes are untouched; only visuals change.
# Attach to level root alongside house_decor.gd.

var mat_frame: StandardMaterial3D     # dark accent for legs/frames/trim
var mat_book_colors: Array = []       # dusty book spine colors
var rng := RandomNumberGenerator.new()

func _ready():
	rng.seed = hash("props") + 13
	_init_materials()
	call_deferred("_rebuild_all")

func _init_materials():
	mat_frame = StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.1, 0.07, 0.04, 1)
	mat_frame.roughness = 0.95

	# Dusty book spine colors
	for c in [Color(0.5, 0.2, 0.15), Color(0.15, 0.25, 0.35),
			  Color(0.35, 0.3, 0.15), Color(0.25, 0.15, 0.3),
			  Color(0.3, 0.2, 0.12), Color(0.15, 0.3, 0.2),
			  Color(0.4, 0.15, 0.1), Color(0.1, 0.2, 0.3)]:
		var m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		mat_book_colors.append(m)

func _rebuild_all():
	var root = get_parent()
	for child in root.get_children():
		var cn = child.name as String
		match cn:
			"DiningTable": _table(child, Vector3(2, 0.75, 1.2), false)
			"Couch": _couch(child)
			"Counter": _counter(child)
			"TVStand": _tvstand(child)
			"Bookshelf": _bookshelf(child)
			"Pillar": _pillar(child)
			"Workbench1", "Workbench2": _workbench(child)
			"CoffeeTable": _table(child, Vector3(1.0, 0.35, 0.6), true)
			"Chair1", "Chair2": _chair(child)
			"KitchenCart": _cart(child)
			"SideTable": _table(child, Vector3(0.5, 0.5, 0.5), true)
			"TV": _tv(child)
		if cn.begins_with("Crate"):
			_crate(child)

# ── Helpers ──

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var m = BoxMesh.new()
	m.size = size
	m.material = mat
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _swap(node: Node) -> Array:
	# Hides original box mesh, returns [mesh_child, material, size]
	var mesh_child = node.get_node_or_null("Mesh")
	if not mesh_child or not mesh_child is MeshInstance3D:
		return []
	if not mesh_child.mesh or not mesh_child.mesh is BoxMesh:
		return []
	var mat = mesh_child.mesh.material
	var sz = mesh_child.mesh.size
	mesh_child.mesh = null
	return [mesh_child, mat, sz]

# ── Furniture builders ──

func _table(node: Node, sz: Vector3, lower_shelf: bool):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var w = sz.x; var h = sz.y; var d = sz.z

	# Tabletop
	var top_t = 0.06
	_box(p, Vector3(w, top_t, d), Vector3(0, h / 2 - top_t / 2, 0), mat)

	# 4 legs
	var leg_h = h - top_t
	var ly = -h / 2 + leg_h / 2
	var lx = w / 2 - 0.08
	var lz = d / 2 - 0.08
	for c in [Vector3(-lx, ly, -lz), Vector3(lx, ly, -lz),
			  Vector3(-lx, ly, lz), Vector3(lx, ly, lz)]:
		_box(p, Vector3(0.06, leg_h, 0.06), c, mat_frame)

	# Optional lower shelf (coffee table, side table)
	if lower_shelf:
		var shelf_y = -h / 2 + leg_h * 0.25
		_box(p, Vector3(w - 0.2, 0.03, d - 0.2), Vector3(0, shelf_y, 0), mat)

func _couch(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var w = 2.5; var h = 0.7; var d = 1.0

	# Base frame
	_box(p, Vector3(w, 0.15, d), Vector3(0, -h / 2 + 0.075, 0), mat_frame)

	# Seat cushion (inset from sides to leave room for arms)
	var seat_w = w - 0.28
	_box(p, Vector3(seat_w, 0.2, d - 0.2), Vector3(0, -0.05, 0.05), mat)

	# Back cushion (raised behind)
	_box(p, Vector3(seat_w, 0.38, 0.15), Vector3(0, 0.12, -d / 2 + 0.1), mat)

	# Arms
	_box(p, Vector3(0.12, 0.32, d - 0.15), Vector3(-w / 2 + 0.06, 0.02, 0.025), mat)
	_box(p, Vector3(0.12, 0.32, d - 0.15), Vector3(w / 2 - 0.06, 0.02, 0.025), mat)

func _counter(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var w = 6.0; var h = 0.9; var d = 0.7

	# Countertop (slight overhang)
	_box(p, Vector3(w + 0.06, 0.06, d + 0.04), Vector3(0, h / 2 - 0.03, 0.01), mat)

	# Cabinet body
	_box(p, Vector3(w, h - 0.1, d - 0.04), Vector3(0, -0.02, 0.02), mat)

	# Kick recess at bottom
	_box(p, Vector3(w - 0.1, 0.08, d - 0.15), Vector3(0, -h / 2 + 0.04, 0.05), mat_frame)

	# Vertical dividers (suggest cabinet door edges)
	for dx in [-1.8, 0.0, 1.8]:
		_box(p, Vector3(0.025, h - 0.2, 0.012), Vector3(dx, -0.02, d / 2 + 0.001), mat_frame)

func _tvstand(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var w = 1.2; var h = 0.5; var d = 0.5

	# Top and bottom shelves
	_box(p, Vector3(w, 0.04, d), Vector3(0, h / 2 - 0.02, 0), mat)
	_box(p, Vector3(w, 0.04, d), Vector3(0, -h / 2 + 0.02, 0), mat)

	# Middle shelf
	_box(p, Vector3(w - 0.04, 0.03, d - 0.04), Vector3(0, 0, 0), mat)

	# Side panels
	_box(p, Vector3(0.04, h, d), Vector3(-w / 2 + 0.02, 0, 0), mat)
	_box(p, Vector3(0.04, h, d), Vector3(w / 2 - 0.02, 0, 0), mat)

	# Back panel
	_box(p, Vector3(w, h, 0.02), Vector3(0, 0, -d / 2 + 0.01), mat_frame)

func _tv(node: Node):
	# TV is a bare MeshInstance3D, not a StaticBody3D with Col/Mesh
	if not node is MeshInstance3D: return
	if not node.mesh or not node.mesh is BoxMesh: return
	var mat = node.mesh.material
	var sz = node.mesh.size
	node.mesh = null

	# Bezel frame (slightly larger than screen)
	_box(node, Vector3(sz.x + 0.04, sz.y + 0.04, 0.03), Vector3(0, 0, 0.005), mat)

	# Screen glass (dark, reflective)
	var mat_screen = StandardMaterial3D.new()
	mat_screen.albedo_color = Color(0.02, 0.02, 0.03, 1)
	mat_screen.metallic = 0.3
	mat_screen.roughness = 0.1
	_box(node, Vector3(sz.x - 0.06, sz.y - 0.06, 0.015), Vector3(0, 0, -0.012), mat_screen)

	# Stand neck
	var neck_h = 0.1
	_box(node, Vector3(0.04, neck_h, 0.04), Vector3(0, -sz.y / 2 - neck_h / 2, 0), mat)

	# Stand base
	_box(node, Vector3(0.25, 0.02, 0.15), Vector3(0, -sz.y / 2 - neck_h - 0.01, 0), mat)

func _bookshelf(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var w = 0.4; var h = 2.0; var d = 1.2

	# Back panel (pushed to -X, shelf faces +X)
	_box(p, Vector3(0.02, h, d - 0.06), Vector3(-w / 2 + 0.01, 0, 0), mat_frame)

	# Side panels
	_box(p, Vector3(w, h, 0.03), Vector3(0, 0, -d / 2 + 0.015), mat)
	_box(p, Vector3(w, h, 0.03), Vector3(0, 0, d / 2 - 0.015), mat)

	# Top and bottom
	_box(p, Vector3(w, 0.03, d), Vector3(0, h / 2 - 0.015, 0), mat)
	_box(p, Vector3(w, 0.03, d), Vector3(0, -h / 2 + 0.015, 0), mat)

	# 4 shelves
	var num_sections = 5
	var inner_h = h - 0.06
	var shelf_space = inner_h / num_sections
	for i in range(1, num_sections):
		var sy = -h / 2 + 0.03 + i * shelf_space
		_box(p, Vector3(w - 0.04, 0.02, d - 0.06), Vector3(0.01, sy, 0), mat)

	# Books on each shelf section
	for i in range(num_sections):
		var shelf_bottom = -h / 2 + 0.03 + i * shelf_space + 0.025
		var space_h = shelf_space - 0.05
		var z = -d / 2 + 0.07
		var z_end = d / 2 - 0.07
		while z < z_end:
			var bw = rng.randf_range(0.02, 0.05)
			if z + bw > z_end:
				break
			var bh = rng.randf_range(space_h * 0.6, space_h * 0.95)
			var bd = rng.randf_range(0.12, 0.22)
			var book_mat = mat_book_colors[rng.randi() % mat_book_colors.size()]
			var bx = -w / 2 + 0.02 + bd / 2
			var by = shelf_bottom + bh / 2
			var bz = z + bw / 2
			_box(p, Vector3(bd, bh, bw), Vector3(bx, by, bz), book_mat)
			z += bw + rng.randf_range(0.005, 0.015)

func _pillar(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var s = 0.6; var h = 1.5

	# Base (wider)
	_box(p, Vector3(s + 0.12, 0.12, s + 0.12), Vector3(0, -h / 2 + 0.06, 0), mat)

	# Shaft (narrower)
	_box(p, Vector3(s - 0.1, h - 0.24, s - 0.1), Vector3(0, 0, 0), mat)

	# Capital (wider than shaft)
	_box(p, Vector3(s + 0.06, 0.12, s + 0.06), Vector3(0, h / 2 - 0.06, 0), mat)

func _workbench(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var w = 0.8; var h = 0.85; var d = 2.0

	# Thick work surface
	_box(p, Vector3(w, 0.08, d), Vector3(0, h / 2 - 0.04, 0), mat)

	# 4 legs
	var leg_h = h - 0.08
	var ly = -h / 2 + leg_h / 2
	var lx = w / 2 - 0.08
	var lz = d / 2 - 0.08
	for c in [Vector3(-lx, ly, -lz), Vector3(lx, ly, -lz),
			  Vector3(-lx, ly, lz), Vector3(lx, ly, lz)]:
		_box(p, Vector3(0.08, leg_h, 0.08), c, mat_frame)

	# Cross beams between legs (lower third)
	var beam_y = -h / 2 + leg_h * 0.3
	_box(p, Vector3(0.05, 0.05, d - 0.16), Vector3(-lx, beam_y, 0), mat_frame)
	_box(p, Vector3(0.05, 0.05, d - 0.16), Vector3(lx, beam_y, 0), mat_frame)

func _chair(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var w = 0.5; var h = 0.7; var d = 0.5

	# Seat slab (slightly below center)
	var seat_t = 0.05
	var seat_y = -0.05
	_box(p, Vector3(w, seat_t, d), Vector3(0, seat_y, 0), mat)

	# 4 legs below seat
	var leg_h = h / 2 + seat_y - seat_t / 2
	var ly = -h / 2 + leg_h / 2
	var lx = w / 2 - 0.06
	var lz = d / 2 - 0.06
	for c in [Vector3(-lx, ly, -lz), Vector3(lx, ly, -lz),
			  Vector3(-lx, ly, lz), Vector3(lx, ly, lz)]:
		_box(p, Vector3(0.05, leg_h, 0.05), c, mat_frame)

	# Backrest (above seat, at rear)
	var back_h = h / 2 - seat_y - seat_t / 2
	var back_y = seat_y + seat_t / 2 + back_h / 2
	_box(p, Vector3(w - 0.04, back_h, 0.05), Vector3(0, back_y, -d / 2 + 0.04), mat)

	# Two back slats (negative space effect)
	_box(p, Vector3(0.04, back_h - 0.06, 0.02), Vector3(-0.1, back_y, -d / 2 + 0.06), mat_frame)
	_box(p, Vector3(0.04, back_h - 0.06, 0.02), Vector3(0.1, back_y, -d / 2 + 0.06), mat_frame)

func _cart(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var w = 0.8; var h = 0.85; var d = 0.5

	# Top surface
	_box(p, Vector3(w, 0.04, d), Vector3(0, h / 2 - 0.02, 0), mat)

	# Lower shelf
	_box(p, Vector3(w - 0.08, 0.03, d - 0.08), Vector3(0, -0.08, 0), mat)

	# 4 legs
	var leg_h = h - 0.04
	var ly = -h / 2 + leg_h / 2
	var lx = w / 2 - 0.06
	var lz = d / 2 - 0.06
	for c in [Vector3(-lx, ly, -lz), Vector3(lx, ly, -lz),
			  Vector3(-lx, ly, lz), Vector3(lx, ly, lz)]:
		_box(p, Vector3(0.05, leg_h, 0.05), c, mat_frame)

	# Handle rail on one side
	_box(p, Vector3(0.03, 0.22, d - 0.1), Vector3(w / 2 - 0.035, h / 2 + 0.09, 0), mat_frame)

func _crate(node: Node):
	var parts = _swap(node)
	if parts.is_empty(): return
	var p = parts[0]; var mat = parts[1]
	var s = 0.7
	var hs = s / 2.0

	# Main body
	_box(p, Vector3(s, s, s), Vector3.ZERO, mat)

	# Corner trim strips (vertical edges - like wooden crate framing)
	var t = 0.025
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			_box(p, Vector3(t, s + 0.005, t),
				 Vector3(xs * (hs - t / 2), 0, zs * (hs - t / 2)), mat_frame)

	# Horizontal bands on Z faces (front/back)
	for zs in [-1.0, 1.0]:
		_box(p, Vector3(s + 0.003, 0.06, 0.015),
			 Vector3(0, hs * 0.45, zs * (hs + 0.001)), mat_frame)
		_box(p, Vector3(s + 0.003, 0.06, 0.015),
			 Vector3(0, -hs * 0.45, zs * (hs + 0.001)), mat_frame)

	# Horizontal bands on X faces (sides)
	for xs in [-1.0, 1.0]:
		_box(p, Vector3(0.015, 0.06, s + 0.003),
			 Vector3(xs * (hs + 0.001), hs * 0.45, 0), mat_frame)
		_box(p, Vector3(0.015, 0.06, s + 0.003),
			 Vector3(xs * (hs + 0.001), -hs * 0.45, 0), mat_frame)
