extends Node3D

const RAY_COUNT := 720
const MAX_DISTANCE := 28.0
const WAVE_SPEED := 18.0
const MEMORY_TIME := 10.0
const MAP_WIDTH := 64
const MAP_HEIGHT := 32

var _map_image: Image
var _map_texture: ImageTexture
var _reveal_material: ShaderMaterial
var _echo_origin := Vector3.ZERO
var _echo_start := -100.0
var _active := false

func _ready() -> void:
	add_to_group("echo_system")
	_map_image = Image.create(MAP_WIDTH, MAP_HEIGHT, false, Image.FORMAT_R8)
	_map_image.fill(Color(1.0, 1.0, 1.0, 1.0))
	_map_texture = ImageTexture.create_from_image(_map_image)

func setup_reveal(material: ShaderMaterial) -> void:
	_reveal_material = material
	_reveal_material.set_shader_parameter("visibility_map", _map_texture)
	_reveal_material.set_shader_parameter("echo_origin", Vector3.ZERO)
	_reveal_material.set_shader_parameter("echo_age", -100.0)
	_reveal_material.set_shader_parameter("echo_active", false)
	_reveal_material.set_shader_parameter("max_distance", MAX_DISTANCE)
	_reveal_material.set_shader_parameter("wave_speed", WAVE_SPEED)
	_reveal_material.set_shader_parameter("memory_time", MEMORY_TIME)

func emit_echo(origin: Vector3) -> void:
	if _reveal_material == null:
		return
	_echo_origin = origin
	_echo_start = _now()
	_active = true
	_build_visibility_map(origin)
	_reveal_material.set_shader_parameter("visibility_map", _map_texture)
	_reveal_material.set_shader_parameter("echo_origin", origin)
	_reveal_material.set_shader_parameter("echo_age", 0.0)
	_reveal_material.set_shader_parameter("echo_active", true)

func _process(_delta: float) -> void:
	if not _active or _reveal_material == null:
		return
	var age := _now() - _echo_start
	_reveal_material.set_shader_parameter("echo_age", age)
	if age > MAX_DISTANCE / WAVE_SPEED + MEMORY_TIME + 0.5:
		_active = false
		_reveal_material.set_shader_parameter("echo_active", false)

func _build_visibility_map(origin: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var buffer := PackedFloat32Array()
	buffer.resize(MAP_WIDTH * MAP_HEIGHT)
	buffer.fill(1.0)

	var golden := PI * (3.0 - sqrt(5.0))
	for i in RAY_COUNT:
		var y := 1.0 - (float(i) / float(RAY_COUNT - 1)) * 2.0
		var radius := sqrt(maxf(0.0, 1.0 - y * y))
		var theta := golden * float(i)
		var dir := Vector3(cos(theta) * radius, y, sin(theta) * radius).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * MAX_DISTANCE, 1)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var result := space.intersect_ray(query)
		if result.is_empty():
			continue
		var hit_pos: Vector3 = result.position
		var to_hit := hit_pos - origin
		var hit_dir := to_hit.normalized()
		var dist := to_hit.length()
		var u := atan2(hit_dir.z, hit_dir.x) / TAU + 0.5
		var v := acos(clampf(hit_dir.y, -1.0, 1.0)) / PI
		var px := int(floor(u * MAP_WIDTH)) % MAP_WIDTH
		var py := clampi(int(floor(v * MAP_HEIGHT)), 0, MAP_HEIGHT - 1)
		var value := clampf(dist / MAX_DISTANCE, 0.0, 1.0)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var sx: int = (px + int(dx) + MAP_WIDTH) % MAP_WIDTH
				var sy: int = clampi(py + int(dy), 0, MAP_HEIGHT - 1)
				var idx: int = sy * MAP_WIDTH + sx
				if value < buffer[idx]:
					buffer[idx] = value

	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			_map_image.set_pixel(x, y, Color(buffer[y * MAP_WIDTH + x], 0.0, 0.0, 1.0))
	_map_texture.update(_map_image)

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
