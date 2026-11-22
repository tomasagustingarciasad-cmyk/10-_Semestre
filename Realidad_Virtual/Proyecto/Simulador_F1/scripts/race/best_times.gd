class_name BestTimes
extends RefCounted
## Tabla de mejores tiempos por circuito y clima (`user://tiempos.cfg`).
##
## Guarda las mejores vueltas válidas de cada combinación circuito + clima,
## con el compuesto usado y la fecha. La muestran el menú de preparación de
## la sesión y la pantalla de resultados.

const FILE_PATH := "user://tiempos.cfg"
## Cantidad de tiempos que se conservan por circuito y clima.
const MAX_ENTRIES := 5


## Registra una vuelta. Devuelve su puesto en la tabla (1 = récord) o 0 si no entró.
static func add(circuit_id: String, weather_id: String, lap_time: float, compound_id: String) -> int:
	if lap_time <= 0.0:
		return 0
	var cfg := ConfigFile.new()
	cfg.load(FILE_PATH)
	var entries: Array = cfg.get_value(circuit_id, weather_id, [])
	var entry := {
		"time": lap_time,
		"compound": compound_id,
		"date": Time.get_date_string_from_system(),
	}
	entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	cfg.set_value(circuit_id, weather_id, entries)
	cfg.save(FILE_PATH)
	return entries.find(entry) + 1


## Tiempos guardados de un circuito con un clima, del mejor al peor.
## Cada elemento es un Dictionary {time, compound, date}.
static func get_list(circuit_id: String, weather_id: String) -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(FILE_PATH) != OK:
		return []
	return cfg.get_value(circuit_id, weather_id, [])


## Mejor tiempo de un circuito con un clima (0 si no hay ninguno).
static func get_best(circuit_id: String, weather_id: String) -> float:
	var entries := get_list(circuit_id, weather_id)
	return entries[0]["time"] if not entries.is_empty() else 0.0
