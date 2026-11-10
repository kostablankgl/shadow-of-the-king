extends Node3D

const MAP_WIDTH := 256
const MAP_HEIGHT := 128
const RAY_COUNT := MAP_WIDTH * MAP_HEIGHT
const RAYS_PER_FRAME := 4096
const MAX_DISTANCE := 18.0
const WAVE_SPEED := 20.0
const WAVE_WIDTH := 1.2
const FRESH_TIME := 2.0
const MEMORY_TIME := 18.0
const CANE_RADIUS := 1.0

var _map_image: Image
var _map_texture: ImageTexture
var _reveal_material: ShaderMaterial
var _player: Node3D
var _buffer := PackedFloat32Array()
var _echo_origin := Vector3.ZERO
var _echo_start := -100.0
var _active := false
var _building := false
var _ray_index := 0

func _ready() -> void:
	add_to_group("echo_system")
	_map_image = Image.create(MAP_WIDTH, MAP_HEIGHT, false, Image.FORMAT_RH)
	_map_image.fill(Color(1.0, 1.0, 1.0, 1.0))
	_map_texture = ImageTexture.create_from_image(_map_image)
	_buffer.resize(MAP_WIDTH * MAP_HEIGHT)
	_buffer.fill(1.0)

func setup_reveal(material: ShaderMaterial, player: Node3D) -> void:
	_reveal_material = material
	_player = player
	_reveal_material.set_shader_parameter("visibility_map", _map_texture)
	_reveal_material.set_shader_parameter("echo_origin", Vector3.ZERO)
	_reveal_material.set_shader_parameter("echo_age", -100.0)
	_reveal_material.set_shader_parameter("echo_active", false)
	_reveal_material.set_shader_parameter("max_distance", MAX_DISTANCE)
	_reveal_material.set_shader_parameter("wave_speed", WAVE_SPEED)
	_reveal_material.set_shader_parameter("wave_width", WAVE_WIDTH)
	_reveal_material.set_shader_parameter("fresh_time", FRESH_TIME)
	_reveal_material.set_shader_parameter("memory_time", MEMORY_TIME)
	_reveal_material.set_shader_parameter("cane_radius", CANE_RADIUS)
	_reveal_material.set_shader_parameter("player_position", _head_position())
	_reveal_material.set_shader_parameter("cane_position", _feet_position())

func emit_echo(origin: Vector3) -> void:
	if _reveal_material == null or _building:
		return
	_echo_origin = origin
	_ray_index = 0
	_building = true
	_active = false
	_buffer.fill(1.0)
	_reveal_material.set_shader_parameter("echo_active", false)

func _process(_delta: float) -> void:
	if _reveal_material == null:
		return
	_reveal_material.set_shader_parameter("player_position", _head_position())
	_reveal_material.set_shader_parameter("cane_position", _feet_position())
	if _building:
		_cast_batch()
	if _active:
		var age := _now() - _echo_start
		_reveal_material.set_shader_parameter("echo_age", age)
		if age > MAX_DISTANCE / WAVE_SPEED + MEMORY_TIME + 0.5:
			_active = false
			_reveal_material.set_shader_parameter("echo_active", false)

func _feet_position() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return Vector3.ZERO
	return _player.global_position + Vector3(0.0, -0.9, 0.0)

func _head_position() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return Vector3.ZERO
	var anim := _player.get_node_or_null("Visual/PlayerAnim")
	if anim != null and anim.has_method("get_head_position"):
		return anim.get_head_position()
	var marker := _player.get_node_or_null("Visual/Model/Root/Hips/Torso/Neck/Head/HeadMarker") as Node3D
	if marker != null:
		return marker.global_position
	return _player.global_position + Vector3(0.0, 0.72, 0.0)

func _cast_batch() -> void:
	var space := get_world_3d().direct_space_state
	var end := mini(_ray_index + RAYS_PER_FRAME, RAY_COUNT)
	while _ray_index < end:
		var i := _ray_index
		var x := i % MAP_WIDTH
		var y := i / MAP_WIDTH
		var u := (float(x) + 0.5) / float(MAP_WIDTH)
		var v := (float(y) + 0.5) / float(MAP_HEIGHT)
		var theta := (u - 0.5) * TAU
		var phi := v * PI
		var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
		var query := PhysicsRayQueryParameters3D.create(_echo_origin, _echo_origin + dir * MAX_DISTANCE, 1)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var result := space.intersect_ray(query)
		if result.is_empty():
			_buffer[i] = 1.0
		else:
			_buffer[i] = clampf(_echo_origin.distance_to(result.position) / MAX_DISTANCE, 0.0, 1.0)
		_ray_index += 1
	if _ray_index >= RAY_COUNT:
		_finish_map()

func _finish_map() -> void:
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			_map_image.set_pixel(x, y, Color(_buffer[y * MAP_WIDTH + x], 0.0, 0.0, 1.0))
	_map_texture.update(_map_image)
	_reveal_material.set_shader_parameter("visibility_map", _map_texture)
	_reveal_material.set_shader_parameter("echo_origin", _echo_origin)
	_reveal_material.set_shader_parameter("echo_age", 0.0)
	_reveal_material.set_shader_parameter("echo_active", true)
	_echo_start = _now()
	_active = true
	_building = false

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
