extends StaticBody3D

@export var target_path: NodePath = ""
var is_pulled = false

func pull():
	if is_pulled:
		return
	is_pulled = true
	# Animate handle — tilts forward when pulled
	var handle = $HandlePivot
	var tween = create_tween()
	tween.tween_property(handle, "rotation:x", -1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Activate target door
	if not target_path.is_empty():
		var target = get_node_or_null(target_path)
		if target and target.has_method("lever_pulled"):
			target.lever_pulled()
		elif target and target.has_method("_open_door"):
			target._open_door()
