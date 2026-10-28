extends StaticBody3D

# Door that blocks passage in the normal world but becomes passable
# in the spirit world.  Toggle E to enter spirit mode and walk through.

var door_mesh: MeshInstance3D
var mat_solid: StandardMaterial3D
var mat_spirit: StandardMaterial3D
var _last_spirit = false
var _pulse_time = 0.0

func _ready():
	collision_layer = 1
	collision_mask = 0

	door_mesh = get_node_or_null("DoorMesh")

	# Solid state — visible, semi-translucent purple with faint glow
	mat_solid = StandardMaterial3D.new()
	mat_solid.albedo_color = Color(0.3, 0.15, 0.45, 0.8)
	mat_solid.emission_enabled = true
	mat_solid.emission = Color(0.2, 0.08, 0.35)
	mat_solid.emission_energy_multiplier = 0.6
	mat_solid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Spirit state — faded, bright blue, passable
	mat_spirit = StandardMaterial3D.new()
	mat_spirit.albedo_color = Color(0.15, 0.3, 0.7, 0.12)
	mat_spirit.emission_enabled = true
	mat_spirit.emission = Color(0.1, 0.25, 0.65)
	mat_spirit.emission_energy_multiplier = 2.5
	mat_spirit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	if door_mesh:
		door_mesh.material_override = mat_solid

func _process(delta):
	_pulse_time += delta
	var player = _find_player()
	if not player:
		return

	var in_spirit = "spirit_world" in player and player.spirit_world

	if in_spirit != _last_spirit:
		_last_spirit = in_spirit
		if in_spirit:
			# Spirit world: passable
			collision_layer = 0
			if door_mesh:
				door_mesh.material_override = mat_spirit
		else:
			# Normal world: solid
			collision_layer = 1
			if door_mesh:
				door_mesh.material_override = mat_solid

	# Gentle pulse on the emission so the door looks alive
	var pulse = 0.7 + sin(_pulse_time * 2.5) * 0.3
	if in_spirit:
		mat_spirit.emission_energy_multiplier = 2.0 + pulse
	else:
		mat_solid.emission_energy_multiplier = 0.4 + pulse * 0.3

func _find_player():
	var root = get_tree().current_scene
	if root:
		return root.get_node_or_null("Player")
	return null
