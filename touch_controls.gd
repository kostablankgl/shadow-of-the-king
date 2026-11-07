extends Control

var move := Vector2.ZERO
var crouch := false

var _jump_queued := false
var _echo_queued := false
var _look_delta := Vector2.ZERO

var _roles := {}
var _move_origin := Vector2.ZERO
var _look_last := Vector2.ZERO
var _crouch_held := false

const STICK_RADIUS := 92.0
const DEADZONE := 14.0
const R_JUMP := 72.0
const R_ECHO := 58.0
const R_CROUCH := 46.0

func _ready() -> void:
	add_to_group("touch_controls")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func consume_jump() -> bool:
	var value := _jump_queued
	_jump_queued = false
	return value

func consume_echo() -> bool:
	var value := _echo_queued
	_echo_queued = false
	return value

func consume_look() -> Vector2:
	var value := _look_delta
	_look_delta = Vector2.ZERO
	return value

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var point := event.position
		if point.distance_to(_jump_pos()) <= R_JUMP:
			_roles[event.index] = "jump"
			_jump_queued = true
		elif point.distance_to(_echo_pos()) <= R_ECHO:
			_roles[event.index] = "echo"
			_echo_queued = true
		elif point.distance_to(_crouch_pos()) <= R_CROUCH:
			_roles[event.index] = "crouch"
			_crouch_held = true
		elif point.x < _viewport_size().x * 0.42:
			_roles[event.index] = "move"
			_move_origin = point
			move = Vector2.ZERO
		else:
			_roles[event.index] = "look"
			_look_last = point
	else:
		var role: String = _roles.get(event.index, "")
		if role == "move":
			move = Vector2.ZERO
		elif role == "crouch":
			_crouch_held = false
		_roles.erase(event.index)
	crouch = _crouch_held
	queue_redraw()

func _on_drag(event: InputEventScreenDrag) -> void:
	var role: String = _roles.get(event.index, "")
	if role == "move":
		var offset := event.position - _move_origin
		if offset.length() < DEADZONE:
			move = Vector2.ZERO
		else:
			var value := offset / STICK_RADIUS
			if value.length() > 1.0:
				value = value.normalized()
			move = Vector2(value.x, -value.y)
		queue_redraw()
	elif role == "look":
		_look_delta += event.position - _look_last
		_look_last = event.position

func _viewport_size() -> Vector2:
	return get_viewport_rect().size

func _stick_center() -> Vector2:
	var size := _viewport_size()
	return Vector2(190.0, size.y - 190.0)

func _jump_pos() -> Vector2:
	var size := _viewport_size()
	return Vector2(size.x - 150.0, size.y - 160.0)

func _echo_pos() -> Vector2:
	var size := _viewport_size()
	return Vector2(size.x - 175.0, size.y - 330.0)

func _crouch_pos() -> Vector2:
	var size := _viewport_size()
	return Vector2(size.x - 330.0, size.y - 150.0)

func _draw() -> void:
	var line := Color(0.85, 0.92, 1.0, 0.45)
	var stick := _stick_center()
	draw_arc(stick, STICK_RADIUS, 0.0, TAU, 48, line, 3.0)
	var knob := stick + Vector2(move.x, -move.y) * STICK_RADIUS
	draw_circle(knob, 30.0, Color(0.85, 0.92, 1.0, 0.7))
	_draw_button(_jump_pos(), R_JUMP, "JUMP", Color(0.29, 0.64, 1.0, 0.55))
	_draw_button(_echo_pos(), R_ECHO, "ECHO", Color(0.18, 0.72, 0.85, 0.55))
	_draw_button(_crouch_pos(), R_CROUCH, "CROUCH", Color(0.45, 0.5, 0.62, 0.55))

func _draw_button(center: Vector2, radius: float, label: String, color: Color) -> void:
	draw_circle(center, radius, color)
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.75), 3.0)
	var font := ThemeDB.fallback_font
	var font_size := 18
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95))
