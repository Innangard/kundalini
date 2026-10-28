extends StaticBody3D

# Orb well: a small shrine that always offers one spirit orb.
# When the orb is eaten, a new one grows back after respawn_time seconds,
# so the player can never run out of spit ammo.
# Place the node on the floor (y = 0). Builds its own mesh and collision.

@export var respawn_time: float = 4.0
@export var orb_height: float = 0.75

var orb: Area3D = null
var wait_timer = 0.0
var orb_script = preload("res://scripts/spirit_orb.gd")

func _ready():
	collision_layer = 1
	collision_mask = 0

	# Stone pedestal
	var stone = StandardMaterial3D.new()
	stone.albedo_color = Color(0.32, 0.3, 0.36)
	stone.roughness = 0.95
	var pedestal = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.3
	cyl.height = 0.4
	cyl.material = stone
	pedestal.mesh = cyl
	pedestal.position.y = 0.2
	add_child(pedestal)

	# Faint glowing ring on top so the well reads as special in the normal world
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color(0.35, 0.55, 0.9)
	glow.emission_enabled = true
	glow.emission = Color(0.2, 0.4, 0.9)
	glow.emission_energy_multiplier = 1.2
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.2
	torus.material = glow
	ring.mesh = torus
	ring.position.y = 0.42
	add_child(ring)

	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 0.4
	col.shape = shape
	col.position.y = 0.2
	add_child(col)

	_spawn_orb(false)

func _process(delta):
	# Orb still here, nothing to do
	if orb != null and is_instance_valid(orb) and not orb.is_queued_for_deletion():
		return
	orb = null
	wait_timer += delta
	if wait_timer >= respawn_time:
		wait_timer = 0.0
		_spawn_orb(true)

func _spawn_orb(grow: bool):
	orb = Area3D.new()
	orb.set_script(orb_script)
	# Position must be set before add_child: the orb records its bob height in _ready
	orb.position = Vector3(0, orb_height, 0)
	add_child(orb)
	if grow:
		orb.scale = Vector3.ONE * 0.05
		var tween = create_tween()
		tween.tween_property(orb, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
