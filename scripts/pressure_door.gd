extends StaticBody3D

# Pressure door — opens when enough pressure plates are active
# Closes when plates deactivate (unless stays_open is true)

@export var required_plates: int = 1
@export var door_size: Vector3 = Vector3(0.25, 2.5, 1.75)
@export var stays_open: bool = false

var plates_active: int = 0
var is_open: bool = false
var closed_y: float

func _ready():
	collision_layer = 1
	collision_mask = 0
	closed_y = position.y

	# Create mesh if not already provided as a child in the scene
	if not has_node("Mesh"):
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = door_size
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.2, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.05, 0.12)
		mat.emission_energy_multiplier = 0.3
		box.material = mat
		mesh_inst.mesh = box
		mesh_inst.name = "Mesh"
		add_child(mesh_inst)

	# Create collision if not already provided as a child in the scene
	if not has_node("Col"):
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = door_size
		col.shape = shape
		col.name = "Col"
		add_child(col)

func plate_activated():
	plates_active += 1
	if plates_active >= required_plates and not is_open:
		_open_door()

func plate_deactivated():
	if stays_open:
		return
	plates_active = max(plates_active - 1, 0)
	if plates_active < required_plates and is_open:
		_close_door()

func _open_door():
	is_open = true

func _close_door():
	is_open = false

func _physics_process(delta):
	# Slide toward open (3 m up) or closed at 3 m/s
	var target = closed_y + (3.0 if is_open else 0.0)
	if position.y < target:
		position.y = min(position.y + 3.0 * delta, target)
	elif position.y > target:
		_push_player_out()
		position.y = max(position.y - 3.0 * delta, target)

func _push_player_out():
	# A closing door never traps the player: anyone under it is moved out to their side
	var box = BoxShape3D.new()
	box.size = door_size - Vector3(0.04, 0.04, 0.04)
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.transform = global_transform
	params.collision_mask = 2
	params.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(params, 2):
		var body = hit["collider"]
		var local = global_transform.affine_inverse() * body.global_position
		if door_size.x < door_size.z:
			local.x = (1.0 if local.x >= 0.0 else -1.0) * (door_size.x * 0.5 + 0.36)
		else:
			local.z = (1.0 if local.z >= 0.0 else -1.0) * (door_size.z * 0.5 + 0.36)
		var w = global_transform * local
		body.global_position = Vector3(w.x, body.global_position.y, w.z)
