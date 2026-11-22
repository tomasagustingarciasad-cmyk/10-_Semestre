class_name StartLights
extends Node3D
## Semáforo de largada: cinco luces rojas (esferas) sobre el pórtico.
##
## La carrera las enciende de a una y las apaga todas juntas para largar.
## El HUD muestra el mismo estado en pantalla.

const LIGHT_COUNT := 5
const COLOR_OFF := Color(0.12, 0.02, 0.02)
const COLOR_ON := Color(1.0, 0.05, 0.05)
const EMISSION_ENERGY := 4.0

var _lights: Array[MeshInstance3D] = []
var _material_off: StandardMaterial3D
var _material_on: StandardMaterial3D


func _ready() -> void:
	_material_off = StandardMaterial3D.new()
	_material_off.albedo_color = COLOR_OFF
	_material_on = StandardMaterial3D.new()
	_material_on.albedo_color = COLOR_ON
	_material_on.emission_enabled = true
	_material_on.emission = COLOR_ON
	_material_on.emission_energy_multiplier = EMISSION_ENERGY
	for i in LIGHT_COUNT:
		var light := get_node_or_null("Luz%d" % (i + 1)) as MeshInstance3D
		if light != null:
			_lights.append(light)
	set_lit(0)


## Enciende las primeras `count` luces y apaga el resto.
func set_lit(count: int) -> void:
	for i in _lights.size():
		_lights[i].material_override = _material_on if i < count else _material_off
