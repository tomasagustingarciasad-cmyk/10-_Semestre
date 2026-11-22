class_name CarVisual
extends Node3D
## Modelo visual del auto armado con primitivas (cajas, cilindros, esfera, toro).
##
## Se usa en tres lugares: la carrocería del auto del jugador, los autos
## rivales y el fantasma. Este script permite repintar el modelo (colores de
## cada rival) o volverlo semitransparente (fantasma) sin duplicar la escena.

## Metadato que marca qué piezas llevan color de decoración.
const META_LIVERY := &"decoracion"
const LIVERY_PRIMARY := "primario"
const LIVERY_SECONDARY := "secundario"

# Velocidad [m/s] -> giro de las ruedas estáticas del modelo.
const WHEEL_RADIUS := 0.34


## Pinta las piezas marcadas con los colores indicados.
func set_livery(primary: Color, secondary: Color) -> void:
	var primary_material := _make_paint(primary)
	var secondary_material := _make_paint(secondary)
	for mesh_instance in _get_mesh_instances(self):
		match mesh_instance.get_meta(META_LIVERY, ""):
			LIVERY_PRIMARY:
				mesh_instance.material_override = primary_material
			LIVERY_SECONDARY:
				mesh_instance.material_override = secondary_material


## Convierte todo el modelo en un "fantasma" de un solo color translúcido.
func set_ghost(color: Color, alpha: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	for mesh_instance in _get_mesh_instances(self):
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hace girar las ruedas del modelo estático según la distancia recorrida.
## Solo tiene efecto en la escena `car_model.tscn` (que trae nodo "Ruedas").
func spin_wheels(distance: float) -> void:
	var wheels := get_node_or_null("Ruedas")
	if wheels == null:
		return
	var angle := distance / WHEEL_RADIUS
	for wheel: Node3D in wheels.get_children():
		wheel.rotate_object_local(Vector3.RIGHT, -angle)


func _make_paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.3
	material.roughness = 0.35
	return material


# Recorre el árbol y devuelve todas las mallas del modelo.
func _get_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_mesh_instances(child))
	return result
