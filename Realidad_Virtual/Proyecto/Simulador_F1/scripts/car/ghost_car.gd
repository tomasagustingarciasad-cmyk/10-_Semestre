class_name GhostCar
extends Node3D
## Auto fantasma: reproduce la mejor vuelta grabada (nivel Clasificación).
##
## Es solo un modelo semitransparente sin colisión. La sesión le indica en
## cada frame qué instante de la vuelta mostrar.

const GHOST_COLOR := Color(0.55, 0.85, 1.0)
const GHOST_ALPHA := 0.38

## Vuelta que se está reproduciendo (null = fantasma oculto).
var lap: GhostLap = null


func _ready() -> void:
	var model := get_node_or_null("Modelo") as CarVisual
	if model != null:
		model.set_ghost(GHOST_COLOR, GHOST_ALPHA)
	visible = false


## Asigna la vuelta a reproducir.
func set_lap(ghost_lap: GhostLap) -> void:
	lap = ghost_lap
	visible = false


## Muestra el fantasma en el instante `time` [s] desde el inicio de la vuelta.
func show_at(time: float) -> void:
	if lap == null or lap.is_empty() or time < 0.0 or time > lap.lap_time:
		visible = false
		return
	global_transform = lap.get_transform_at(time)
	visible = true


## Oculta el fantasma (por ejemplo durante la vuelta de salida).
func hide_ghost() -> void:
	visible = false
