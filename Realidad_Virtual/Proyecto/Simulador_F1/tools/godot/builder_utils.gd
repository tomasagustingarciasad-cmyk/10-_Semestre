extends RefCounted
## Utilidades compartidas por los generadores de escenas (tools/godot/).
##
## Funciones cortas para crear primitivas 3D con su material, posición y
## rotación en una sola llamada, y para guardar un árbol de nodos como
## escena `.tscn`.

## Crea un material opaco simple.
static func make_material(color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


## Crea un material emisivo (luces).
static func make_emissive(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var material := make_material(color, 0.4)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## Agrega una caja (BoxMesh) como hija de `parent`.
static func add_box(parent: Node, node_name: String, size: Vector3, position: Vector3,
		material: Material, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, node_name, mesh, position, rotation_deg, material)


## Agrega un cilindro o cono (CylinderMesh). Con `top_radius` 0 es un cono.
static func add_cylinder(parent: Node, node_name: String, top_radius: float, bottom_radius: float,
		height: float, position: Vector3, material: Material,
		rotation_deg: Vector3 = Vector3.ZERO, radial_segments: int = 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = 1
	return _add_mesh(parent, node_name, mesh, position, rotation_deg, material)


## Agrega una esfera (SphereMesh).
static func add_sphere(parent: Node, node_name: String, radius: float, position: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _add_mesh(parent, node_name, mesh, position, Vector3.ZERO, material)


## Agrega un toro (TorusMesh) con el eje en Y.
static func add_torus(parent: Node, node_name: String, inner_radius: float, outer_radius: float,
		position: Vector3, material: Material, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 8
	return _add_mesh(parent, node_name, mesh, position, rotation_deg, material)


## Agrega un cuerpo estático con forma de caja (colisión) y su malla visible.
static func add_static_box(parent: Node, node_name: String, size: Vector3, position: Vector3,
		material: Material, rotation_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees = rotation_deg
	parent.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Colision"
	collision.shape = shape
	body.add_child(collision)
	add_box(body, "Malla", size, Vector3.ZERO, material)
	return body


## Agrega un Area3D con forma de caja que detecta la capa indicada.
static func add_area_box(parent: Node, node_name: String, size: Vector3, transform: Transform3D,
		detect_mask: int, group: StringName) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.transform = transform
	area.collision_layer = 0
	area.collision_mask = detect_mask
	area.monitorable = false
	area.add_to_group(group, true)
	parent.add_child(area)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Forma"
	collision.shape = shape
	area.add_child(collision)
	return area


## Agrega un cartel de texto 3D (Label3D).
static func add_label(parent: Node, node_name: String, text: String, position: Vector3,
		font_size: int, color: Color, rotation_deg: Vector3 = Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = font_size
	label.outline_size = int(font_size / 6.0)
	label.modulate = color
	label.pixel_size = 0.01
	label.position = position
	label.rotation_degrees = rotation_deg
	label.double_sided = true
	parent.add_child(label)
	return label


## Guarda `root` (con todos sus descendientes) como escena en `path`.
static func save_scene(root: Node, path: String) -> void:
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		push_error("No se pudo empaquetar %s (error %d)" % [path, pack_error])
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("No se pudo guardar %s (error %d)" % [path, save_error])
	else:
		print("  escena guardada: ", path)


## Instancia una escena guardada y la agrega como hija (queda como instancia,
## no como copia de sus nodos).
static func add_instance(parent: Node, scene_path: String, node_name: String,
		position: Vector3 = Vector3.ZERO) -> Node:
	var scene := load(scene_path) as PackedScene
	var instance := scene.instantiate()
	instance.name = node_name
	if instance is Node3D:
		(instance as Node3D).position = position
	parent.add_child(instance)
	return instance


static func _add_mesh(parent: Node, node_name: String, mesh: PrimitiveMesh, position: Vector3,
		rotation_deg: Vector3, material: Material) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation_deg
	parent.add_child(instance)
	return instance


# Asigna el dueño de cada nodo para que se guarde en la escena. Los nodos que
# vienen de otra escena instanciada se guardan como referencia (no se baja
# a sus hijos).
static func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		if child.scene_file_path == "":
			_set_owner_recursive(child, owner)
