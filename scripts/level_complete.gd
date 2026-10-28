extends Area3D

@export var next_level = ""
@export var unlock_type = "pull"

var triggered = false

func _ready():
	# Ensure monitoring is on so body_entered fires
	monitoring = true
	# Enlarge the trigger zone at runtime for reliability
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			child.shape = child.shape.duplicate()
			child.shape.size = Vector3(3.0, 3.0, 3.0)
	# Primary detection: signal
	body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	# Backup detection: poll overlapping bodies every frame
	if triggered:
		set_physics_process(false)
		return
	for body in get_overlapping_bodies():
		if _is_player(body):
			_trigger_completion(body)
			return

func _on_body_entered(body):
	if triggered:
		return
	if _is_player(body):
		_trigger_completion(body)

func _is_player(body: Node) -> bool:
	if body.is_in_group("player"):
		return true
	if body.name == "Player":
		return true
	if body is CharacterBody3D and (body.collision_layer & 2) != 0:
		return true
	return false

func _trigger_completion(_body):
	if triggered:
		return
	triggered = true
	set_physics_process(false)
	print("[LevelComplete] Triggered! unlock_type=%s next_level=%s" % [unlock_type, str(next_level)])

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		_do_unlock(gm)
		var path = str(next_level)
		if path.length() > 0:
			gm.transition_to_level(path, 4.0)
	else:
		# Fallback: handle everything inline without GameManager
		print("[LevelComplete] GameManager not found — using inline fallback")
		_fallback_notify_and_transition()

func _do_unlock(gm):
	match unlock_type:
		"eat_spit":
			gm.unlock_eat_spit()
		"phase_walk":
			gm.unlock_phase_walk()
		"constrict":
			gm.unlock_constrict()
		"complete":
			gm.show_notification("ALL ABILITIES MASTERED\nThe serpent has awakened", 5.0)
		_:
			gm.unlock_pull()

func _fallback_notify_and_transition():
	# Build our own notification UI
	var canvas = CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)

	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.3, 0.55, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label)

	# Set text based on unlock type
	match unlock_type:
		"eat_spit":
			label.text = "EAT & SPIT UNLOCKED\nRight-click spirits to eat\nSpace to spit in spirit world"
		"phase_walk":
			label.text = "PHASE WALK UNLOCKED\nSome walls exist only in one world\nToggle spirit to pass through them"
		"constrict":
			label.text = "CONSTRICT UNLOCKED\nPress C to wrap objects\nHold them on plates while you move"
		"complete":
			label.text = "ALL ABILITIES MASTERED\nThe serpent has awakened"
		_:
			label.text = "PULL UNLOCKED\nRight-click to pull objects"

	# Fade in notification
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)

	# Scene transition with fade to black
	var lvl_path = str(next_level)
	if lvl_path.length() > 0:
		var fade = ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(fade)

		var t2 = create_tween()
		t2.tween_interval(4.0)
		t2.tween_property(fade, "color:a", 1.0, 1.5)
		t2.tween_callback(get_tree().change_scene_to_file.bind(lvl_path))
