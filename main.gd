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

	_add_box(room, Vector3(0, -0.5, 0), Vector3(24, 1, 24), material)
	_add_box(room, Vector3(0, 2.5, -12), Vector3(24, 5, 1), material)
	_add_box(room, Vector3(0, 2.5, 12), Vector3(24, 5, 1), material)
	_add_box(room, Vector3(-12, 2.5, 0), Vector3(1, 5, 24), material)
	_add_box(room, Vector3(12, 2.5, 0), Vector3(1, 5, 24), material)

	_add_box(room, Vector3(-4, 1.5, -3), Vector3(2, 3, 2), material)
	_add_box(room, Vector3(4, 1, -5), Vector3(3, 2, 3), material)
	_add_box(room, Vector3(6, 2, 2), Vector3(2, 4, 2), material)
	_add_box(room, Vector3(-6, 0.6, 4), Vector3(4, 1.2, 2), material)
	_add_box(room, Vector3(0, 0.6, -7), Vector3(6, 1.2, 2), material)
	_add_box(room, Vector3(0, 0.15, 3.5), Vector3(2, 0.3, 1), material)

	for x in [-8.0, 8.0]:
		for z in [-8.0, 8.0]:
			_add_box(room, Vector3(x, 2, z), Vector3(1.2, 4, 1.2), material)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	parent.add_child(body)
