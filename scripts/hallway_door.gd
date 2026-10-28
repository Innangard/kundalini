extends StaticBody3D

# Hallway bounding box for block detection
const HALLWAY_MIN_X = -10.125
const HALLWAY_MAX_X = -7.125
const HALLWAY_MIN_Z = 2.75
const HALLWAY_MAX_Z = 4.75
const REQUIRED_BLOCKS = 3

var is_open = false
var check_timer = 0.0

func _process(delta):
	if is_open:
		return

	check_timer += delta
	if check_timer < 0.3:
		return
	check_timer = 0.0

	# Count pushable blocks (RigidBody3D, layer 8) inside the hallway zone
	var count = 0
	for node in get_tree().current_scene.get_children():
		if node is RigidBody3D and (node.collision_layer & 8) != 0:
			var pos = node.global_position
			if pos.x >= HALLWAY_MIN_X and pos.x <= HALLWAY_MAX_X \
			   and pos.z >= HALLWAY_MIN_Z and pos.z <= HALLWAY_MAX_Z:
				count += 1

	if count >= REQUIRED_BLOCKS:
		_open_door()

func _open_door():
	is_open = true
	# Slide the door up into the ceiling
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 3.5, 1.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
