@tool
class_name TreeScatter
extends Node3D
## Arboleda del decorado: muchos árboles iguales dibujados con MultiMesh.
##
## Cada árbol son dos primitivas: un cilindro (tronco) y un cono (copa). En
## vez de crear cientos de nodos, se guarda solo la lista de posiciones,
## giros y escalas, y al iniciar se arman dos MultiMesh (uno por primitiva)
## que la placa de video dibuja en una sola pasada.
## Es un script @tool para que los árboles también se vean en el editor.

const TRUNK_HEIGHT := 3.0
const TRUNK_TOP_RADIUS := 0.25
const TRUNK_BOTTOM_RADIUS := 0.35
const CROWN_HEIGHT := 7.0
const CROWN_RADIUS := 2.4
const RADIAL_SEGMENTS := 8
const TRUNK_COLOR := Color(0.35, 0.24, 0.14)
const CROWN_COLOR := Color(0.12, 0.36, 0.14)

## Posición de la base de cada árbol.
@export var positions: PackedVector3Array = PackedVector3Array()
## Giro alrededor del eje vertical de cada árbol [rad].
@export var rotations: PackedFloat32Array = PackedFloat32Array()
## Escala uniforme de cada árbol.
@export var scales: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = TRUNK_TOP_RADIUS
	trunk.bottom_radius = TRUNK_BOTTOM_RADIUS
	trunk.height = TRUNK_HEIGHT
	trunk.radial_segments = RADIAL_SEGMENTS
	trunk.material = _make_material(TRUNK_COLOR)
	# Un cono es un cilindro con el radio superior en cero.
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = CROWN_RADIUS
	crown.height = CROWN_HEIGHT
	crown.radial_segments = RADIAL_SEGMENTS
	crown.material = _make_material(CROWN_COLOR)

	# Las mallas están centradas en su origen: se las sube para apoyarlas.
	_add_multimesh("Troncos", trunk, TRUNK_HEIGHT * 0.5)
	_add_multimesh("Copas", crown, TRUNK_HEIGHT * 0.7 + CROWN_HEIGHT * 0.5)


func _add_multimesh(node_name: String, mesh: Mesh, center_height: float) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for i in positions.size():
		var tree_scale := scales[i] if i < scales.size() else 1.0
		var angle := rotations[i] if i < rotations.size() else 0.0
		var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * tree_scale)
		var origin := positions[i] + Vector3.UP * center_height * tree_scale
		multimesh.set_instance_transform(i, Transform3D(basis, origin))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
