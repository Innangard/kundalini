extends Node

# Ability unlocks — persists across level transitions
var pull_unlocked = false
var eat_spit_unlocked = false
var phase_walk_unlocked = false
var constrict_unlocked = false

# UI references (created in _ready)
var notify_label: Label
var fade_rect: ColorRect
var _needs_unlock_check = false

func _ready():
	# Flag: check unlocks once the scene is actually loaded
	_needs_unlock_check = true

	# Create a CanvasLayer for UI overlays — layer 200 to render above
	# the player's spirit world overlay (layer 100)
	var canvas = CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)

	# Full-screen fade rect for level transitions
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade_rect)

	# Centered notification label
	notify_label = Label.new()
	notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notify_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notify_label.add_theme_font_size_override("font_size", 36)
	notify_label.add_theme_color_override("font_color", Color(0.3, 0.55, 0.95))
	notify_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	notify_label.add_theme_constant_override("shadow_offset_x", 2)
	notify_label.add_theme_constant_override("shadow_offset_y", 2)
	notify_label.modulate.a = 0.0
	notify_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(notify_label)

func _process(_delta):
	if _needs_unlock_check:
		var scene = get_tree().current_scene
		if scene:
			_needs_unlock_check = false
			_check_level_unlocks()

func unlock_pull():
	pull_unlocked = true
	print("[GameManager] unlock_pull() called — pull_unlocked is now TRUE")
	show_notification("PULL UNLOCKED\nRight-click to pull objects")

func unlock_eat_spit():
	eat_spit_unlocked = true
	show_notification("EAT & SPIT UNLOCKED\nRight-click spirits to eat\nSpace to spit in spirit world")

func unlock_phase_walk():
	phase_walk_unlocked = true
	show_notification("PHASE WALK UNLOCKED\nSome walls exist only in one world\nToggle spirit to pass through them")

func unlock_constrict():
	constrict_unlocked = true
	show_notification("CONSTRICT UNLOCKED\nPress C to wrap objects\nHold them on plates while you move")

func show_notification(text: String, duration: float = 3.0):
	notify_label.text = text
	# Kill any existing notification tween so they don't fight
	var tween = create_tween()
	tween.tween_property(notify_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(duration)
	tween.tween_property(notify_label, "modulate:a", 0.0, 0.8)

func transition_to_level(scene_path: String, delay: float = 1.0):
	print("[GameManager] transition_to_level: %s (delay %.1f)" % [scene_path, delay])
	var tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(fade_rect, "color:a", 1.0, 1.5)
	tween.tween_callback(_do_scene_change.bind(scene_path))
	tween.tween_interval(0.3)
	tween.tween_property(fade_rect, "color:a", 0.0, 1.5)

func _do_scene_change(scene_path: String):
	print("[GameManager] Changing scene to: %s" % scene_path)
	get_tree().change_scene_to_file(scene_path)
	_needs_unlock_check = true

# Auto-unlock abilities that the player should already have for the current level
# Level 1 (house) = push only (no unlocks needed)
# Level 2 = pull unlocked (from completing level 1)
# Level 3 = pull + eat/spit
# Level 4 = pull + eat/spit + phase walk
# Level 5 = pull + eat/spit + phase walk + constrict
func _check_level_unlocks():
	var scene = get_tree().current_scene
	if not scene:
		return
	var scene_file = scene.scene_file_path
	print("[GameManager] Current scene: %s — checking unlocks" % scene_file)

	# Already unlocked abilities stay unlocked (GameManager persists across transitions)
	# Only upgrade, never downgrade
	if "level2" in scene_file and not pull_unlocked:
		pull_unlocked = true
		print("[GameManager] Auto-unlocked: pull")
	if "level3" in scene_file:
		if not pull_unlocked:
			pull_unlocked = true
		if not eat_spit_unlocked:
			eat_spit_unlocked = true
		print("[GameManager] Auto-unlocked: pull, eat/spit")
	if "level4" in scene_file:
		if not pull_unlocked:
			pull_unlocked = true
		if not eat_spit_unlocked:
			eat_spit_unlocked = true
		if not phase_walk_unlocked:
			phase_walk_unlocked = true
		print("[GameManager] Auto-unlocked: pull, eat/spit, phase_walk")
	if "level5" in scene_file:
		if not pull_unlocked:
			pull_unlocked = true
		if not eat_spit_unlocked:
			eat_spit_unlocked = true
		if not phase_walk_unlocked:
			phase_walk_unlocked = true
		if not constrict_unlocked:
			constrict_unlocked = true
		print("[GameManager] Auto-unlocked: all abilities")
