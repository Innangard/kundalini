extends RigidBody3D

# Block pushing - controlled speed, no momentum buildup
const PUSH_SPEED = 2.5
const FRICTION = 0.7

var is_on_target = false
var pushed_this_frame = false

# Called by the snake head on collision
func push(direction: Vector3):
	direction.y = 0
	direction = direction.normalized()
	linear_velocity = direction * PUSH_SPEED
	pushed_this_frame = true

func _physics_process(_delta):
	if not pushed_this_frame:
		# Decelerate quickly when not being pushed
		linear_velocity *= FRICTION
		if linear_velocity.length() < 0.1:
			linear_velocity = Vector3.ZERO
	pushed_this_frame = false
