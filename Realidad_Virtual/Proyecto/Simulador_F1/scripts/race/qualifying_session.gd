class_name QualifyingSession
extends SessionBase
## Nivel 1 — Clasificación: vuelta rápida contra el fantasma.
##
## El jugador gira solo, en seco, buscando su mejor tiempo. Cada vuelta se
## graba (posición + rotación del auto). La mejor vuelta válida de todos los
## tiempos se guarda en `user://` y se reproduce como un auto semitransparente
## ("fantasma") que sale junto al jugador cada vez que cruza la línea. El
## delta del HUD compara contra esa misma vuelta.

## Carpeta de los fantasmas: uno por circuito y por clima,
## `user://fantasmas/<circuito>_<clima>.dat`.
const GHOST_DIR := "user://fantasmas/"
## Archivo único de la Fase 1 (se migra al esquema nuevo si existe).
const LEGACY_GHOST_FILE := "user://fantasma_clasificacion.dat"
const LEGACY_CIRCUIT := "los_aromos"
const LEGACY_WEATHER := "seco"
const GHOST_SCENE := "res://scenes/car/ghost_car.tscn"
# Distancia antes de la línea de llegada desde donde sale el auto [m].
const START_DISTANCE_BEFORE_LINE := 260.0

## Mejor vuelta histórica (cargada del disco o lograda en esta sesión).
var record: GhostLap = null

var _ghost_car: GhostCar
var _ghost_file: String = ""


func _setup_session() -> void:
	session_title = "Clasificación"

	# Fantasma: se carga el récord guardado (si existe).
	_ghost_car = (load(GHOST_SCENE) as PackedScene).instantiate() as GhostCar
	add_child(_ghost_car)
	_ghost_file = get_ghost_path(track.circuit_id, get_weather_id())
	_migrate_legacy_ghost()
	record = GhostLap.load_from(_ghost_file)
	if record != null:
		_ghost_car.set_lap(record)
		lap_timer.reference = record

	lap_timer.lap_started.connect(_on_lap_started)
	lap_timer.lap_completed.connect(_on_lap_completed)

	# Vuelta de salida corta: el auto arranca sobre la recta principal y la
	# primera vuelta cronometrada empieza al cruzar la línea.
	place_car_on_track(track.length - START_DISTANCE_BEFORE_LINE)
	lap_timer.running = true
	notify_title = "%s — %s" % [track.display_name, weather.get_description()]

	if record != null:
		notify("Récord a batir: " + GameState.format_time(record.lap_time), COLOR_INFO, 4.0)
	else:
		notify("Cruzá la línea para empezar tu vuelta", COLOR_INFO, 4.0)


func _update_session(_delta: float) -> void:
	# El fantasma solo se muestra durante una vuelta cronometrada.
	if lap_timer.lap_number > 0:
		_ghost_car.show_at(lap_timer.get_lap_elapsed())
	else:
		_ghost_car.hide_ghost()


func _on_pit_speeding() -> void:
	lap_timer.invalidate("Exceso de velocidad en boxes")
	notify("Exceso de velocidad en boxes", COLOR_BAD)


func _on_lap_started(_lap_number: int) -> void:
	# Cada vuelta arranca comparando contra el récord vigente.
	if record != null:
		_ghost_car.set_lap(record)


func _on_lap_completed(lap_time: float, valid: bool, _is_best: bool) -> void:
	if valid:
		BestTimes.add(track.circuit_id, get_weather_id(), lap_time, car.compound.id)
	if not valid:
		notify("Vuelta no válida: " + GameState.format_time(lap_time), COLOR_BAD)
		return
	if record == null or lap_time < record.lap_time:
		record = lap_timer.last_recording
		DirAccess.make_dir_recursive_absolute(GHOST_DIR)
		record.save(_ghost_file)
		notify("¡Nuevo récord! " + GameState.format_time(lap_time), COLOR_GOOD, 4.0)
	else:
		notify("Vuelta: %s (%s)" % [GameState.format_time(lap_time),
				GameState.format_delta(lap_time - record.lap_time)], COLOR_INFO, 4.0)


## Ruta del fantasma de un circuito con un clima.
static func get_ghost_path(circuit_id: String, weather_id: String) -> String:
	return "%s%s_%s.dat" % [GHOST_DIR, circuit_id, weather_id]


# El récord de la Fase 1 (un único archivo) pasa a ser el de Los Aromos en seco.
func _migrate_legacy_ghost() -> void:
	if not FileAccess.file_exists(LEGACY_GHOST_FILE):
		return
	var target := get_ghost_path(LEGACY_CIRCUIT, LEGACY_WEATHER)
	DirAccess.make_dir_recursive_absolute(GHOST_DIR)
	if not FileAccess.file_exists(target):
		DirAccess.rename_absolute(LEGACY_GHOST_FILE, target)


func _build_results() -> Dictionary:
	var rows: Array = []
	for lap: Dictionary in lap_timer.history:
		var sectors: Array = lap["sectors"]
		var row := [str(lap["number"]), GameState.format_time(lap["time"])]
		for i in LapTimer.SECTOR_COUNT:
			row.append("%.3f" % sectors[i] if i < sectors.size() else "-")
		row.append("Sí" if lap["valid"] else "No")
		rows.append(row)
	var footer := "Mejor vuelta de la sesión: %s     Récord guardado: %s" % [
		GameState.format_time(lap_timer.best_lap_time),
		GameState.format_time(record.lap_time if record != null else 0.0)]
	return {
		"title": "Clasificación — %s (%s)" % [track.display_name, weather.get_description()],
		"headers": ["Vuelta", "Tiempo", "S1", "S2", "S3", "Válida"],
		"rows": rows,
		"footer": footer,
	}
