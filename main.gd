extends Node3D

const REVEAL_SHADER := preload("res://reveal.gdshader")

@onready var echo_system = $EchoSystem
@onready var player = $Player

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = REVEAL_SHADER
	echo_system.setup_reveal(material, player)
	_build_room(material)

func _build_room(material: Material) -> void:
	var room := Node3D.new()
	room.name = "Room"
	add_child(room)

	_add_box(room, Vector3(0, -0.5, 0), Vector3(32, 1, 32), material)
	_add_box(room, Vector3(0, 3, -16), Vector3(32, 6, 1), material)
	_add_box(room, Vector3(0, 3, 16), Vector3(32, 6, 1), material)
	_add_box(room, Vector3(-16, 3, 0), Vector3(1, 6, 32), material)
	_add_box(room, Vector3(16, 3, 0), Vector3(1, 6, 32), material)

	_add_box(room, Vector3(-11, 2, -7), Vector3(1.2, 4, 1.2), material)
	_add_box(room, Vector3(11, 2, 7), Vector3(1.2, 4, 1.2), material)
	_add_box(room, Vector3(0, 0.4, 4), Vector3(4, 0.8, 0.5), material)

	_add_box(room, Vector3(-8, 0.25, 8), Vector3(3, 0.5, 3), material)
	_add_box(room, Vector3(-12, 0.5, 4), Vector3(3, 1, 3), material)
	_add_box(room, Vector3(-8, 0.75, 0), Vector3(3, 1.5, 3), material)

	for i in 8:
		var step_h := 0.22 * float(i + 1)
		_add_mesh(room, Vector3(-8, step_h * 0.5, 6.0 - float(i) * 0.55), Vector3(3, step_h, 0.55), material)
	_add_ramp(room, Vector3(-8, 0.84, 4.14), Vector3(3, 0.2, 4.5), 0.39)
	_add_box(room, Vector3(-8, 0.88, 0.7), Vector3(3, 1.76, 2.0), material)

	_add_box(room, Vector3(6, 0.25, 9), Vector3(2, 0.5, 2), material)
	_add_box(room, Vector3(10, 0.35, 9), Vector3(2, 0.7, 2), material)
	_add_box(room, Vector3(14, 0.5, 9), Vector3(2, 1.0, 2), material)

	_add_box(room, Vector3(6, 1.0, 3), Vector3(3, 2.0, 3), material)
	_add_box(room, Vector3(11, 1.15, -1), Vector3(3, 2.3, 3), material)

	_add_box(room, Vector3(8, 1.6, -13), Vector3(4, 3.2, 4), material)
	_add_ladder(room, Vector3(8, 0, -10.65), 3.2, 3.2, Vector3(0, 0, -1), material)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh.mesh = box
	mesh.scale = size
	mesh.material_override = material
	body.add_child(mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	parent.add_child(body)

func _add_ramp(parent: Node3D, pos: Vector3, size: Vector3, angle: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.x = angle
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _add_mesh(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh.mesh = box
	mesh.position = pos
	mesh.scale = size
	mesh.material_override = material
	parent.add_child(mesh)

func _add_ladder(parent: Node3D, base: Vector3, height: float, top_y: float, exit_forward: Vector3, material: Material) -> void:
	var ladder := Node3D.new()
	ladder.name = "Ladder"
	ladder.position = base
	parent.add_child(ladder)

	for x in [-0.38, 0.38]:
		_add_mesh(ladder, Vector3(x, height * 0.5, 0), Vector3(0.08, height, 0.08), material)
	var rungs := int(height / 0.35)
	for i in range(rungs + 1):
		_add_mesh(ladder, Vector3(0, 0.15 + float(i) * 0.35, 0), Vector3(0.9, 0.06, 0.08), material)

	var area := Area3D.new()
	area.name = "LadderArea"
	area.position = Vector3(0, height * 0.5, 0)
	area.collision_layer = 4
	area.collision_mask = 0
	area.add_to_group("ladder")
	area.set_meta("top_y", top_y)
	area.set_meta("exit_forward", exit_forward)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, height, 0.55)
	collision.shape = shape
	area.add_child(collision)
	ladder.add_child(area)
