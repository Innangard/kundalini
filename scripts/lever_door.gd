extends StaticBody3D

@export var required_levers: int = 1
@export var required_blocks: int = 0
@export var zone_min_x: float = 0.0
@export var zone_max_x: float = 0.0
@export var zone_min_z: float = 0.0
@export var zone_max_z: float = 0.0

var levers_pulled = 0
var is_open = false
var check_timer = 0.0

func lever_pulled():
	levers_pulled += 1
	_check_open()

func _process(delta):
	if is_open:
		return
	# Only poll when blocks are required (levers trigger instantly via lever_pulled)
	if required_blocks <= 0:
		return
	check_timer += delta
	if check_timer < 0.3:
		return
	check_timer = 0.0
	_check_open()

func _check_open():
	if is_open:
		return
	if levers_pulled < required_levers:
		return
	if required_blocks > 0:
		var count = 0
		for node in get_tree().current_scene.get_children():
			if node is RigidBody3D and (node.collision_layer & 8) != 0:
				var pos = node.global_position
				if pos.x >= zone_min_x and pos.x <= zone_max_x \
				   and pos.z >= zone_min_z and pos.z <= zone_max_z:
					count += 1
		if count < required_blocks:
			return
	_open_door()

func _open_door():
	is_open = true
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 3.5, 1.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
