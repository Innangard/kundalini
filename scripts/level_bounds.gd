extends Node3D

# Invisible boundary walls that prevent the player from falling out
# Attach this to a Node3D in each level with the bounds set

@export var bound_x_min: float = -3.0
@export var bound_x_max: float = 17.0
@export var bound_z_min: float = -4.0
@export var bound_z_max: float = 4.0
@export var bound_y_min: float = -1.0
@export var bound_y_max: float = 6.0

const WALL_THICKNESS = 1.0

func _ready():
	var cx = (bound_x_min + bound_x_max) / 2.0
	var cz = (bound_z_min + bound_z_max) / 2.0
	var cy = (bound_y_min + bound_y_max) / 2.0
	var wx = bound_x_max - bound_x_min
	var wz = bound_z_max - bound_z_min
	var wy = bound_y_max - bound_y_min

	# Floor
	_add_wall("BoundaryFloor",
		Vector3(cx, bound_y_min - WALL_THICKNESS / 2.0, cz),
		Vector3(wx + 4.0, WALL_THICKNESS, wz + 4.0))

	# Ceiling
	_add_wall("BoundaryCeiling",
		Vector3(cx, bound_y_max + WALL_THICKNESS / 2.0, cz),
		Vector3(wx + 4.0, WALL_THICKNESS, wz + 4.0))

	# North wall (+Z)
	_add_wall("BoundaryNorth",
		Vector3(cx, cy, bound_z_max + WALL_THICKNESS / 2.0),
		Vector3(wx + 4.0, wy + 4.0, WALL_THICKNESS))

	# South wall (-Z)
	_add_wall("BoundarySouth",
		Vector3(cx, cy, bound_z_min - WALL_THICKNESS / 2.0),
		Vector3(wx + 4.0, wy + 4.0, WALL_THICKNESS))

	# East wall (+X)
	_add_wall("BoundaryEast",
		Vector3(bound_x_max + WALL_THICKNESS / 2.0, cy, cz),
		Vector3(WALL_THICKNESS, wy + 4.0, wz + 4.0))

	# West wall (-X)
	_add_wall("BoundaryWest",
		Vector3(bound_x_min - WALL_THICKNESS / 2.0, cy, cz),
		Vector3(WALL_THICKNESS, wy + 4.0, wz + 4.0))

func _add_wall(wall_name: String, pos: Vector3, box_size: Vector3):
	var body = StaticBody3D.new()
	body.name = wall_name
	body.position = pos
	body.collision_layer = 1  # environment layer
	body.collision_mask = 0   # doesn't need to detect anything
	add_child(body)

	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
