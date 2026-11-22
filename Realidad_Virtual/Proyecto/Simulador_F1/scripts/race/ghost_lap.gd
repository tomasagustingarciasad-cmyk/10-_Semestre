class_name GhostLap
extends RefCounted
## Datos de una vuelta grabada: trayectoria (posición + rotación) y tiempos.
##
## Se usa para el auto fantasma y como referencia del "delta" en vivo.
##   - Trayectoria: una muestra cada SAMPLE_INTERVAL segundos (posición y
##     rotación como cuaternión). Al reproducir se interpola entre muestras.
##   - Tabla distancia -> tiempo: cuánto tiempo de vuelta llevaba el auto al
##     pasar por cada DISTANCE_STEP metros de pista. Comparando contra esa
##     tabla se obtiene la diferencia de tiempo en cualquier punto.
##
## Se guarda en `user://` con FileAccess.store_var().

const FILE_VERSION := 1
## Intervalo entre muestras de trayectoria [s] (60 por segundo).
const SAMPLE_INTERVAL := 1.0 / 60.0
## Paso de la tabla distancia -> tiempo [m].
const DISTANCE_STEP := 10.0

var lap_time: float = 0.0
var sector_times: Array[float] = []
var positions: PackedVector3Array = PackedVector3Array()
## Cuaterniones aplanados: x, y, z, w por muestra.
var rotations: PackedFloat32Array = PackedFloat32Array()
## Tiempo de vuelta al pasar por cada múltiplo de DISTANCE_STEP.
var distance_times: PackedFloat32Array = PackedFloat32Array()

var _time_since_sample: float = SAMPLE_INTERVAL


func is_empty() -> bool:
	return positions.is_empty()


## Agrega una muestra si ya pasó el intervalo. Llamar en cada tick de física.
func record(delta: float, car_transform: Transform3D) -> void:
	_time_since_sample += delta
	if _time_since_sample < SAMPLE_INTERVAL:
		return
	_time_since_sample -= SAMPLE_INTERVAL
	positions.append(car_transform.origin)
	var quaternion := car_transform.basis.get_rotation_quaternion()
	rotations.append_array([quaternion.x, quaternion.y, quaternion.z, quaternion.w])


## Registra el tiempo de paso por la distancia `distance` [m] desde la línea.
func record_distance(distance: float, time: float) -> void:
	var index := int(floor(distance / DISTANCE_STEP))
	while distance_times.size() <= index:
		distance_times.append(time)


## Tiempo de vuelta que llevaba esta vuelta al pasar por `distance`.
## Devuelve -1 si no hay dato.
func get_time_at_distance(distance: float) -> float:
	if distance_times.is_empty():
		return -1.0
	var position := distance / DISTANCE_STEP
	var index := int(floor(position))
	if index >= distance_times.size() - 1:
		return distance_times[distance_times.size() - 1]
	return lerpf(distance_times[index], distance_times[index + 1], position - index)


## Transformación interpolada en el instante `time` [s].
func get_transform_at(time: float) -> Transform3D:
	var count := positions.size()
	if count == 0:
		return Transform3D.IDENTITY
	var position := clampf(time / SAMPLE_INTERVAL, 0.0, float(count - 1))
	var index := int(floor(position))
	var next_index := mini(index + 1, count - 1)
	var weight := position - index
	var origin := positions[index].lerp(positions[next_index], weight)
	var rotation := _get_quaternion(index).slerp(_get_quaternion(next_index), weight)
	return Transform3D(Basis(rotation), origin)


## Guarda la vuelta en disco. Devuelve true si salió bien.
func save(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("GhostLap: no se pudo escribir %s" % path)
		return false
	file.store_var({
		"version": FILE_VERSION,
		"lap_time": lap_time,
		"sector_times": sector_times,
		"positions": positions,
		"rotations": rotations,
		"distance_times": distance_times,
	})
	file.close()
	return true


## Carga una vuelta desde disco. Devuelve null si no existe o es inválida.
static func load_from(path: String) -> GhostLap:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data: Variant = file.get_var()
	file.close()
	if not (data is Dictionary) or data.get("version", 0) != FILE_VERSION:
		return null
	var ghost := GhostLap.new()
	ghost.lap_time = data.get("lap_time", 0.0)
	ghost.sector_times.assign(data.get("sector_times", []))
	ghost.positions = data.get("positions", PackedVector3Array())
	ghost.rotations = data.get("rotations", PackedFloat32Array())
	ghost.distance_times = data.get("distance_times", PackedFloat32Array())
	if ghost.lap_time <= 0.0 or ghost.positions.is_empty():
		return null
	return ghost


func _get_quaternion(index: int) -> Quaternion:
	var base := index * 4
	return Quaternion(rotations[base], rotations[base + 1], rotations[base + 2], rotations[base + 3]).normalized()
