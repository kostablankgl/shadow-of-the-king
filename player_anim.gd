extends Node3D

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var walk_cycle_speed := 6.0
@export var run_cycle_speed := 12.0
@export var crouch_lower := 0.29
@export var cast_time := 0.55

var _model: Node3D
var _hips: Node3D
var _torso: Node3D
var _cape: Node3D
var _neck: Node3D
var _head: Node3D
var _head_marker: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _foot_l: Node3D
var _foot_r: Node3D

var _hips_base_y := 0.0
var _torso_base_y := 0.0
var _move_blend := 0.0
var _run_blend := 0.0
var _crouch_blend := 0.0
var _air_blend := 0.0
var _phase := 0.0
var _time := 0.0
var _cast_timer := 0.0
var _hang_target := 0.0
var _hang_blend := 0.0
var _ladder_target := 0.0
var _ladder_blend := 0.0
var _vertical_velocity := 0.0
var _climb_timer := 0.0


func _ready() -> void:
	_model = get_node_or_null("../Model") as Node3D
	if _model == null:
		push_error("PlayerAnim: falta Visual/Model")
		return
	_hips = _model.get_node_or_null("Root/Hips") as Node3D
	_torso = _model.get_node_or_null("Root/Hips/Torso") as Node3D
	_cape = _model.get_node_or_null("Root/Hips/Torso/CapeRig") as Node3D
	_neck = _model.get_node_or_null("Root/Hips/Torso/Neck") as Node3D
	_head = _model.get_node_or_null("Root/Hips/Torso/Neck/Head") as Node3D
	_head_marker = _model.get_node_or_null("Root/Hips/Torso/Neck/Head/HeadMarker") as Node3D
	_arm_l = _model.get_node_or_null("Root/Hips/Torso/ArmL") as Node3D
	_arm_r = _model.get_node_or_null("Root/Hips/Torso/ArmR") as Node3D
	_leg_l = _model.get_node_or_null("Root/Hips/LegL") as Node3D
	_leg_r = _model.get_node_or_null("Root/Hips/LegR") as Node3D
	_shin_l = _model.get_node_or_null("Root/Hips/LegL/ShinL") as Node3D
	_shin_r = _model.get_node_or_null("Root/Hips/LegR/ShinR") as Node3D
	_foot_l = _model.get_node_or_null("Root/Hips/LegL/ShinL/FootL") as Node3D
	_foot_r = _model.get_node_or_null("Root/Hips/LegR/ShinR/FootR") as Node3D
	if _hips == null or _torso == null or _neck == null or _head == null or _head_marker == null \
			or _arm_l == null or _arm_r == null or _leg_l == null or _leg_r == null \
			or _shin_l == null or _shin_r == null or _foot_l == null or _foot_r == null:
		push_error("PlayerAnim: faltan nodos de la jerarquia del modelo")
		return
	_hips_base_y = _hips.position.y
	_torso_base_y = _torso.position.y


func update_motion(speed: float, on_floor: bool, crouch: bool, vertical_velocity: float, delta: float) -> void:
	if _hips == null:
		return
	_time += delta
	_cast_timer = maxf(0.0, _cast_timer - delta)
	_climb_timer = maxf(0.0, _climb_timer - delta)
	_vertical_velocity = vertical_velocity
	_hang_blend = _damp(_hang_blend, _hang_target, 12.0, delta)
	_ladder_blend = _damp(_ladder_blend, _ladder_target, 12.0, delta)

	var target_move := clampf(speed / run_speed, 0.0, 1.0)
	if speed < 0.08:
		target_move = 0.0
	_move_blend = _damp(_move_blend, target_move, 10.0, delta)
	_run_blend = _damp(_run_blend, clampf((speed - walk_speed) / (run_speed - walk_speed), 0.0, 1.0), 8.0, delta)
	_crouch_blend = _damp(_crouch_blend, 1.0 if crouch else 0.0, 10.0, delta)
	_air_blend = _damp(_air_blend, 0.0 if on_floor else 1.0, 9.0, delta)
	_phase += delta * lerpf(walk_cycle_speed, run_cycle_speed, _run_blend) * _move_blend
	_apply_pose()


func play_cast() -> void:
	_cast_timer = cast_time


func set_hang(active: bool) -> void:
	_hang_target = 1.0 if active else 0.0


func set_ladder(active: bool) -> void:
	_ladder_target = 1.0 if active else 0.0


func play_climb() -> void:
	_climb_timer = 0.55


func get_head_position() -> Vector3:
	if _head_marker != null and is_instance_valid(_head_marker):
		return _head_marker.global_position
	if _model != null and is_instance_valid(_model):
		return _model.global_position + Vector3(0.0, 0.72, 0.0)
	return global_position + Vector3(0.0, 0.72, 0.0)


func _apply_pose() -> void:
	var cast := _cast_weight()
	var move := _move_blend
	var crouch := _crouch_blend
	var air := _air_blend
	var rise := clampf(_vertical_velocity / 5.4, 0.0, 1.0) * air
	var fall := clampf(-_vertical_velocity / 7.0, 0.0, 1.0) * air
	var swing := sin(_phase)
	var bob := (sin(_phase * 2.0) * 0.012 + absf(swing) * 0.045) * move * (1.0 - 0.7 * crouch)

	_hips.position.y = _hips_base_y - crouch_lower * crouch + bob
	_torso.position.y = _torso_base_y + sin(_time * 2.0) * 0.004 * (1.0 - move)

	_hips.rotation.y = -0.05 * swing * move
	_torso.rotation.y = 0.08 * swing * move + 0.08 * cast
	_neck.rotation.y = 0.02 * swing * move
	_head.rotation.y = -0.04 * swing * move + 0.06 * cast
	_torso.rotation.x = 0.02 * move + 0.16 * crouch + 0.06 * air + 0.08 * rise - 0.02 * fall - 0.05 * cast
	_neck.rotation.x = 0.34 * crouch + 0.02 * move - 0.02 * rise
	_head.rotation.x = -0.04 * move - 0.30 * crouch - 0.03 * air - 0.04 * rise + 0.02 * fall - 0.04 * cast

	var leg_amp := 0.38 * move * (1.0 - 0.45 * crouch)
	var leg_l_x := leg_amp * swing - 1.15 * crouch - 0.35 * air - 0.25 * rise + 0.08 * fall
	var leg_r_x := -leg_amp * swing - 1.15 * crouch - 0.35 * air - 0.25 * rise + 0.08 * fall
	var shin_l_x := maxf(0.0, swing) * 0.55 * move + 2.08 * crouch + 0.75 * air + 0.35 * rise - 0.15 * fall
	var shin_r_x := maxf(0.0, -swing) * 0.55 * move + 2.08 * crouch + 0.75 * air + 0.35 * rise - 0.15 * fall
	_leg_l.rotation.x = leg_l_x
	_leg_r.rotation.x = leg_r_x
	_shin_l.rotation.x = shin_l_x
	_shin_r.rotation.x = shin_r_x
	_foot_l.rotation.x = -(leg_l_x + shin_l_x) * crouch
	_foot_r.rotation.x = -(leg_r_x + shin_r_x) * crouch

	var arm_amp := 0.35 * move * (1.0 - 0.35 * crouch)
	_arm_l.rotation.x = -arm_amp * swing + 0.35 * air - 0.28 * crouch - 0.55 * rise + 0.20 * fall
	_arm_r.rotation.x = arm_amp * 0.75 * swing + 0.15 * air - 0.24 * crouch - 1.15 * cast - 0.55 * rise + 0.20 * fall
	_arm_l.rotation.y = 0.18 * crouch
	_arm_r.rotation.y = -0.18 * crouch
	_arm_l.rotation.z = 0.0
	_arm_r.rotation.z = -0.18 * cast
	if _cape != null:
		_cape.rotation.x = 0.25 * crouch + 0.04 * swing * move

	var hang := _hang_blend
	if hang > 0.001:
		var sway := sin(_time * 2.4) * 0.05
		var pull := 0.0
		if _climb_timer > 0.0:
			pull = sin((1.0 - _climb_timer / 0.55) * PI)
		_hips.position.y = lerpf(_hips.position.y, _hips_base_y + 0.03, hang)
		_torso.rotation.x = lerpf(_torso.rotation.x, 0.06, hang)
		_neck.rotation.x = lerpf(_neck.rotation.x, -0.05, hang)
		_head.rotation.x = lerpf(_head.rotation.x, -0.12, hang)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.35 + sway - 0.3 * pull, hang)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.35 - sway - 0.3 * pull, hang)
		_arm_l.rotation.y = lerpf(_arm_l.rotation.y, 0.16, hang)
		_arm_r.rotation.y = lerpf(_arm_r.rotation.y, -0.16, hang)
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.05, hang)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.05, hang)
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, -0.38 + sway * 0.4, hang)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.30 - sway * 0.4, hang)
		_shin_l.rotation.x = lerpf(_shin_l.rotation.x, 0.55, hang)
		_shin_r.rotation.x = lerpf(_shin_r.rotation.x, 0.45, hang)
		_foot_l.rotation.x = lerpf(_foot_l.rotation.x, 0.15, hang)
		_foot_r.rotation.x = lerpf(_foot_r.rotation.x, 0.15, hang)

	var ladder := _ladder_blend
	if ladder > 0.001:
		var cycle := sin(_time * 7.0)
		_hips.position.y = lerpf(_hips.position.y, _hips_base_y, ladder)
		_torso.rotation.x = lerpf(_torso.rotation.x, 0.05, ladder)
		_neck.rotation.x = lerpf(_neck.rotation.x, -0.02, ladder)
		_head.rotation.x = lerpf(_head.rotation.x, -0.05, ladder)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.0 + 0.45 * cycle, ladder)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.0 - 0.45 * cycle, ladder)
		_arm_l.rotation.y = lerpf(_arm_l.rotation.y, 0.15, ladder)
		_arm_r.rotation.y = lerpf(_arm_r.rotation.y, -0.15, ladder)
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.0, ladder)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.0, ladder)
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, -0.35 - 0.25 * cycle, ladder)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.35 + 0.25 * cycle, ladder)
		_shin_l.rotation.x = lerpf(_shin_l.rotation.x, 0.7 + 0.15 * cycle, ladder)
		_shin_r.rotation.x = lerpf(_shin_r.rotation.x, 0.7 - 0.15 * cycle, ladder)
		_foot_l.rotation.x = lerpf(_foot_l.rotation.x, 0.0, ladder)
		_foot_r.rotation.x = lerpf(_foot_r.rotation.x, 0.0, ladder)


func _cast_weight() -> float:
	if _cast_timer <= 0.0:
		return 0.0
	var t := 1.0 - _cast_timer / cast_time
	return sin(PI * clampf(t, 0.0, 1.0))


func _damp(current: float, target: float, speed: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))
