extends CharacterBody3D

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var crouch_speed := 1.6
@export var acceleration := 18.0
@export var air_acceleration := 6.0
@export var jump_velocity := 6.2
@export var gravity := 20.0
@export var touch_sensitivity := 0.006
@export var echo_cooldown := 2.0

@onready var visual: Node3D = $Visual
@onready var anim: Variant = $Visual/PlayerAnim
@onready var camera_rig: Node3D = $CameraRig

var yaw := 0.0
var pitch := -0.22
var _touch = null
var _echo_system = null
var _echo_timer := 0.0

func _physics_process(delta: float) -> void:
	if _touch == null or not is_instance_valid(_touch):
		_touch = get_tree().get_first_node_in_group("touch_controls")
	_echo_timer = maxf(0.0, _echo_timer - delta)

	var move := Vector2.ZERO
	var jump := false
	var crouch := false
	var look := Vector2.ZERO
	var echo_pressed := false
	if _touch:
		move = _touch.move
		jump = _touch.consume_jump()
		crouch = _touch.crouch
		look = _touch.consume_look()
		echo_pressed = _touch.consume_echo()

	var keyboard := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	)
	if keyboard.length() > 1.0:
		keyboard = keyboard.normalized()
	if keyboard.length() > 0.01:
		move = keyboard
	if Input.is_key_pressed(KEY_SPACE):
		jump = true
	crouch = crouch or Input.is_key_pressed(KEY_CTRL)
	if Input.is_key_pressed(KEY_E):
		echo_pressed = true
	if echo_pressed and _echo_timer <= 0.0:
		_try_echo()

	yaw -= look.x * touch_sensitivity
	pitch = clampf(pitch - look.y * touch_sensitivity, -1.15, 0.35)
	camera_rig.rotation = Vector3(pitch, yaw, 0.0)

	var cam_basis := camera_rig.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := right * move.x + forward * move.y
	if direction.length() > 1.0:
		direction = direction.normalized()

	var magnitude := minf(1.0, move.length())
	var target_speed := 0.0
	if magnitude > 0.08:
		target_speed = lerpf(walk_speed, run_speed, clampf((magnitude - 0.15) / 0.85, 0.0, 1.0))
	if crouch:
		target_speed = minf(target_speed, crouch_speed)

	var target_velocity := direction * target_speed
	var accel := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump:
		velocity.y = jump_velocity

	move_and_slide()

	if direction.length() > 0.05:
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 12.0 * delta)

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if anim:
		anim.update_motion(horizontal_speed, is_on_floor(), crouch, velocity.y, delta)
	camera_rig.position.y = lerpf(camera_rig.position.y, 0.3 if crouch else 0.5, 10.0 * delta)

func _try_echo() -> void:
	if _echo_system == null or not is_instance_valid(_echo_system):
		_echo_system = get_tree().get_first_node_in_group("echo_system")
	if _echo_system:
		var origin := visual.global_position + Vector3(0.0, 0.72, 0.0)
		if anim:
			origin = anim.get_head_position()
		_echo_system.emit_echo(origin)
		if anim:
			anim.play_cast()
		_echo_timer = echo_cooldown
