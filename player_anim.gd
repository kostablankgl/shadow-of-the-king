extends Node3D

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var walk_cycle_speed := 6.0
@export var run_cycle_speed := 12.0
@export var crouch_lower := 0.0
@export var cast_time := 0.55

var _model: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _head_marker: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D

var _hips_base_y := 0.0
var _torso_base_y := 0.0
var _move_blend := 0.0
var _run_blend := 0.0
var _crouch_blend := 0.0
var _air_blend := 0.0
var _phase := 0.0
var _time := 0.0
var _cast_timer := 0.0


func _ready() -> void:
	_model = get_node_or_null("../Model") as Node3D
	if _model == null:
		push_error("PlayerAnim: falta Visual/Model")
		return
	_hips = _model.get_node_or_null("Root/Hips") as Node3D
	_torso = _model.get_node_or_null("Root/Hips/Torso") as Node3D
	_head = _model.get_node_or_null("Root/Hips/Torso/Head") as Node3D
	_head_marker = _model.get_node_or_null("Root/Hips/Torso/Head/HeadMarker") as Node3D
	_arm_l = _model.get_node_or_null("Root/Hips/Torso/ArmL") as Node3D
	_arm_r = _model.get_node_or_null("Root/Hips/Torso/ArmR") as Node3D
	_leg_l = _model.get_node_or_null("Root/Hips/LegL") as Node3D
	_leg_r = _model.get_node_or_null("Root/Hips/LegR") as Node3D
	_shin_l = _model.get_node_or_null("Root/Hips/LegL/ShinL") as Node3D
	_shin_r = _model.get_node_or_null("Root/Hips/LegR/ShinR") as Node3D
	if _hips == null or _torso == null or _head == null or _head_marker == null \
			or _arm_l == null or _arm_r == null or _leg_l == null or _leg_r == null \
			or _shin_l == null or _shin_r == null:
		push_error("PlayerAnim: faltan nodos de la jerarquia del modelo")
		return
	_hips_base_y = _hips.position.y
	_torso_base_y = _torso.position.y


func update_motion(speed: float, on_floor: bool, crouch: bool, _vertical_velocity: float, delta: float) -> void:
	if _hips == null:
		return
	_time += delta
	_cast_timer = maxf(0.0, _cast_timer - delta)

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
	var swing := sin(_phase)
	var bob := sin(_phase * 2.0) * 0.012 * move + absf(swing) * 0.045 * move

	_hips.position.y = _hips_base_y - crouch_lower * crouch + bob
	_torso.position.y = _torso_base_y + sin(_time * 2.0) * 0.004 * (1.0 - move)

	_hips.rotation.y = -0.05 * swing * move
	_torso.rotation.y = 0.08 * swing * move + 0.08 * cast
	_head.rotation.y = -0.04 * swing * move + 0.06 * cast
	_torso.rotation.x = 0.02 * move + 0.16 * crouch + 0.06 * air - 0.05 * cast
	_head.rotation.x = -0.04 * move - 0.04 * crouch - 0.03 * air - 0.04 * cast

	var leg_amp := 0.38 * move * (1.0 - 0.35 * crouch)
	_leg_l.rotation.x = leg_amp * swing - 0.45 * crouch - 0.35 * air
	_leg_r.rotation.x = -leg_amp * swing - 0.45 * crouch - 0.35 * air
	_shin_l.rotation.x = maxf(0.0, swing) * 0.55 * move + 0.9 * crouch + 0.75 * air
	_shin_r.rotation.x = maxf(0.0, -swing) * 0.55 * move + 0.9 * crouch + 0.75 * air

	var arm_amp := 0.35 * move
	_arm_l.rotation.x = -arm_amp * swing + 0.35 * air - 0.15 * crouch
	_arm_r.rotation.x = arm_amp * 0.75 * swing + 0.15 * air - 0.10 * crouch - 1.15 * cast
	_arm_l.rotation.z = 0.0
	_arm_r.rotation.z = -0.18 * cast


func _cast_weight() -> float:
	if _cast_timer <= 0.0:
		return 0.0
	var t := 1.0 - _cast_timer / cast_time
	return sin(PI * clampf(t, 0.0, 1.0))


func _damp(current: float, target: float, speed: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))
