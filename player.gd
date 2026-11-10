extends CharacterBody3D

enum State { NORMAL, HANG, CLIMB, LADDER }

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var crouch_speed := 1.6
@export var acceleration := 18.0
@export var air_acceleration := 6.0
@export var jump_velocity := 5.4
@export var gravity := 20.0
@export var touch_sensitivity := 0.006
@export var echo_cooldown := 2.0
@export var step_height := 0.32
@export var ladder_speed := 2.2
@export var ledge_reach := 0.65
@export var hang_offset := 0.45

const CLIMB_TIME := 0.55

@onready var visual: Node3D = $Visual
@onready var anim: Variant = $Visual/PlayerAnim
@onready var camera_rig: Node3D = $CameraRig
@onready var ladder_sensor: Area3D = $LadderSensor

var yaw := 0.0
var pitch := -0.22
var _touch = null
var _echo_system = null
var _echo_timer := 0.0
var _state := State.NORMAL
var _ladder_area: Area3D = null
var _ladder_center := Vector3.ZERO
var _ladder_top := 0.0
var _ladder_exit := Vector3.ZERO
var _hang_forward := Vector3.ZERO
var _ledge_top := 0.0
var _climb_start := Vector3.ZERO
var _climb_mid := Vector3.ZERO
var _climb_end := Vector3.ZERO
var _climb_time := 0.0
var _hang_lock := 0.0

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

	if _state == State.CLIMB:
		_process_climb(delta)
		return
	if _state == State.HANG:
		_process_hang(move, jump, crouch, delta)
		return
	if _state == State.LADDER:
		_process_ladder(move, jump, crouch, delta)
		return

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

	_update_ladder_area()
	if _ladder_area != null and move.y > 0.25 and not crouch:
		_enter_ladder()
		return

	if is_on_floor() and direction.length() > 0.1:
		_try_step_up(direction)

	if not is_on_floor() and move.y > 0.25:
		var grab_dir := direction
		if grab_dir.length() < 0.1:
			grab_dir = -visual.global_transform.basis.z
		if _try_grab_ledge(grab_dir):
			return

	if direction.length() > 0.05:
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 12.0 * delta)

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if anim:
		anim.set_hang(false)
		anim.set_ladder(false)
		anim.update_motion(horizontal_speed, is_on_floor(), crouch, velocity.y, delta)
	camera_rig.position.y = lerpf(camera_rig.position.y, 0.26 if crouch else 0.5, 10.0 * delta)

func _try_step_up(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.05:
		return
	flat = flat.normalized()
	var feet := global_position + Vector3(0.0, -0.82, 0.0)
	var space := get_world_3d().direct_space_state
	var low_from := feet + Vector3(0.0, 0.12, 0.0)
	var low := _ray(space, low_from, low_from + flat * 0.55)
	if low.is_empty():
		return
	var high_from := feet + Vector3(0.0, step_height, 0.0)
	var high := _ray(space, high_from, high_from + flat * 0.55)
	if not high.is_empty():
		return
	var top_from := low_from + flat * 0.55 + Vector3(0.0, step_height, 0.0)
	var top := _ray(space, top_from, top_from + Vector3(0.0, -0.65, 0.0))
	if top.is_empty() or top.normal.y < 0.7:
		return
	var step_top: float = top.position.y
	var foot_y := global_position.y - 0.9
	if step_top <= foot_y + 0.03 or step_top > foot_y + step_height + 0.02:
		return
	global_position.y = step_top + 0.9 + 0.02
	velocity.y = maxf(velocity.y, 0.0)

func _try_grab_ledge(forward: Vector3) -> bool:
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.05:
		return false
	flat = flat.normalized()
	var space := get_world_3d().direct_space_state
	var wall := _ray(space, global_position, global_position + flat * ledge_reach)
	if wall.is_empty() or absf(wall.normal.y) > 0.4:
		return false
	var top_origin := Vector3(wall.position.x, global_position.y + 2.0, wall.position.z) + flat * 0.45
	var top := _ray(space, top_origin, top_origin + Vector3(0.0, -3.0, 0.0))
	if top.is_empty() or top.normal.y < 0.6:
		return false
	var top_y: float = top.position.y
	var feet_y := global_position.y - 0.9
	if top_y < feet_y + 1.0 or top_y > feet_y + 2.2:
		return false
	var headroom := _ray(space, Vector3(wall.position.x, top_y + 0.25, wall.position.z) + flat * 0.45,
			Vector3(wall.position.x, top_y + 1.25, wall.position.z) + flat * 0.45)
	if not headroom.is_empty():
		return false
	_start_hang(flat, top_y, wall.position)
	return true

func _start_hang(flat: Vector3, top_y: float, wall_pos: Vector3) -> void:
	_state = State.HANG
	_hang_forward = flat
	_ledge_top = top_y
	velocity = Vector3.ZERO
	global_position = Vector3(wall_pos.x, top_y - 0.6, wall_pos.z) - flat * hang_offset
	_hang_lock = 0.3
	visual.rotation.y = atan2(-flat.x, -flat.z)
	if anim:
		anim.set_ladder(false)
		anim.set_hang(true)
		anim.update_motion(0.0, false, false, 0.0, 0.0)

func _process_hang(move: Vector2, jump: bool, crouch: bool, delta: float) -> void:
	velocity = Vector3.ZERO
	_hang_lock = maxf(0.0, _hang_lock - delta)
	if anim:
		anim.set_hang(true)
		anim.set_ladder(false)
		anim.update_motion(0.0, false, false, 0.0, delta)
	if _hang_lock <= 0.0 and (jump or move.y > 0.35):
		_begin_climb()
	elif crouch or move.y < -0.35:
		_release_hang()

func _begin_climb() -> void:
	_state = State.CLIMB
	_climb_time = 0.0
	_climb_start = global_position
	_climb_mid = Vector3(_climb_start.x, _ledge_top + 0.45, _climb_start.z)
	_climb_end = Vector3(_climb_start.x, _ledge_top + 0.9, _climb_start.z) + _hang_forward * 0.75
	if anim:
		anim.set_hang(true)
		anim.play_climb()

func _process_climb(delta: float) -> void:
	_climb_time += delta
	if anim:
		anim.set_hang(true)
		anim.update_motion(0.0, false, false, 0.0, delta)
	var t := clampf(_climb_time / CLIMB_TIME, 0.0, 1.0)
	if t < 0.5:
		var u := t * 2.0
		global_position = _climb_start.lerp(_climb_mid, u * u * (3.0 - 2.0 * u))
	else:
		var u := (t - 0.5) * 2.0
		global_position = _climb_mid.lerp(_climb_end, u * u * (3.0 - 2.0 * u))
	if t >= 1.0:
		global_position = _climb_end
		velocity = Vector3.ZERO
		_state = State.NORMAL
		if anim:
			anim.set_hang(false)

func _release_hang() -> void:
	_state = State.NORMAL
	velocity = -_hang_forward * 1.2
	if anim:
		anim.set_hang(false)

func _update_ladder_area() -> void:
	_ladder_area = null
	if ladder_sensor == null:
		return
	for area in ladder_sensor.get_overlapping_areas():
		if area.is_in_group("ladder"):
			var top := float(area.get_meta("top_y", 999.0))
			if global_position.y > top + 0.1:
				continue
			_ladder_area = area
			return

func _enter_ladder() -> void:
	_state = State.LADDER
	velocity = Vector3.ZERO
	_ladder_center = _ladder_area.global_position
	_ladder_top = float(_ladder_area.get_meta("top_y", global_position.y + 1.0))
	_ladder_exit = (_ladder_area.get_meta("exit_forward", Vector3.ZERO) as Vector3).normalized()
	var outward := -_ladder_exit
	global_position.x = _ladder_center.x + outward.x * 0.45
	global_position.z = _ladder_center.z + outward.z * 0.45
	visual.rotation.y = atan2(-_ladder_exit.x, -_ladder_exit.z)
	if anim:
		anim.set_hang(false)
		anim.set_ladder(true)

func _process_ladder(move: Vector2, jump: bool, crouch: bool, delta: float) -> void:
	if _ladder_area == null or not is_instance_valid(_ladder_area):
		_exit_ladder(false)
		return
	if jump:
		_state = State.NORMAL
		velocity = -_ladder_exit * 1.4 + Vector3.UP * jump_velocity * 0.7
		if anim:
			anim.set_ladder(false)
		return
	if crouch:
		_exit_ladder(false)
		return
	var climb := clampf(move.y, -1.0, 1.0)
	global_position.y += climb * ladder_speed * delta
	var outward := -_ladder_exit
	global_position.x = lerpf(global_position.x, _ladder_center.x + outward.x * 0.45, 12.0 * delta)
	global_position.z = lerpf(global_position.z, _ladder_center.z + outward.z * 0.45, 12.0 * delta)
	if global_position.y >= _ladder_top + 0.9:
		_exit_ladder(true)
		return
	if global_position.y <= 0.92 and climb < 0.0:
		_exit_ladder(false)
		return
	if anim:
		anim.set_hang(false)
		anim.set_ladder(true)
		anim.update_motion(0.0, false, false, climb * ladder_speed, delta)

func _exit_ladder(at_top: bool) -> void:
	_state = State.NORMAL
	velocity = Vector3.ZERO
	if at_top:
		global_position = Vector3(_ladder_center.x, _ladder_top + 0.9 + 0.02, _ladder_center.z) + _ladder_exit * 0.75
	else:
		global_position.y = maxf(global_position.y, 0.92)
	if anim:
		anim.set_ladder(false)
	_ladder_area = null

func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)

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
