class_name LapTimer
extends Node
## Cronometraje del auto del jugador.
##
## Funciona con tres checkpoints (Area3D del circuito) que deben cruzarse en
## orden: línea de llegada (0) -> fin del sector 1 (1) -> fin del sector 2 (2)
## -> línea de llegada. Con eso se obtienen:
##   - tiempo de vuelta y de cada uno de los 3 sectores;
##   - mejor vuelta y mejores sectores de la sesión;
##   - "delta" en vivo contra una vuelta de referencia (GhostLap);
##   - validez de la vuelta (se invalida al salirse de la pista).
##
## El reloj es `session_time`: avanza con los ticks de física, así que se
## detiene solo cuando el juego está en pausa. Para no depender de la
## duración del tick (1/120 s), el instante de cruce se corrige con la
## distancia del auto a la línea y su velocidad (ver _crossing_time).

signal lap_started(lap_number: int)
## sector_index: 0..2. best_time: mejor tiempo previo de ese sector (0 si no hay).
signal sector_completed(sector_index: int, time: float, best_time: float)
signal lap_completed(lap_time: float, valid: bool, is_best: bool)
signal lap_invalidated(reason: String)

const SECTOR_COUNT := 3
const CHECKPOINT_FINISH := 0
# Velocidad mínima [m/s] para aplicar la corrección del instante de cruce.
const MIN_SPEED_FOR_CORRECTION := 1.0
# Al comienzo de la vuelta el auto todavía está "antes" de la línea durante
# unos instantes: en ese lapso la distancia recorrida se toma como cero.
const LAP_START_GRACE_TIME := 2.0

var car: Node3D = null
var track: Track = null
## Progreso del auto en la vuelta [m]. Lo actualiza la sesión en cada tick
## (búsqueda local, válida aunque el circuito tenga tramos pegados o cruces).
var car_offset: float = 0.0

## Reloj de la sesión [s].
var session_time: float = 0.0
## false = reloj detenido (antes de la largada).
var running: bool = false

## Vuelta en curso (0 = todavía no pasó por la línea: vuelta de salida).
var lap_number: int = 0
var laps_completed: int = 0
var lap_valid: bool = true
## Sector en curso (0..2).
var current_sector: int = 0
## Tiempos de los sectores ya completados de la vuelta en curso.
var current_sector_times: Array[float] = []

var last_lap_time: float = 0.0
var last_lap_valid: bool = true
var last_sector_times: Array[float] = []
var best_lap_time: float = 0.0
## Mejor tiempo individual de cada sector en la sesión (0 = sin dato).
var best_sector_times: Array[float] = [0.0, 0.0, 0.0]
## Instante de sesión en que se completó la última vuelta.
var last_finish_time: float = 0.0

## Vuelta de referencia para el delta (mejor vuelta o fantasma cargado).
var reference: GhostLap = null
## Diferencia en vivo contra la referencia [s] (negativo = más rápido).
var delta: float = 0.0
var has_delta: bool = false
## Grabación de la vuelta en curso y de la última vuelta completada.
var recording: GhostLap = null
var last_recording: GhostLap = null
## Historial: un Dictionary por vuelta {number, time, valid, sectors}.
var history: Array[Dictionary] = []

var _lap_start_time: float = 0.0
var _sector_start_time: float = 0.0
var _next_checkpoint: int = CHECKPOINT_FINISH


## Conecta el cronómetro con el auto, el circuito y sus checkpoints.
func setup(target_car: Node3D, circuit: Track) -> void:
	car = target_car
	track = circuit
	for area: Area3D in get_tree().get_nodes_in_group(Track.GROUP_CHECKPOINT):
		area.body_entered.connect(_on_checkpoint_body_entered.bind(area))


func _physics_process(delta_time: float) -> void:
	if not running:
		return
	session_time += delta_time
	if lap_number == 0 or car == null:
		return

	var elapsed := get_lap_elapsed()
	var distance := car_offset
	if elapsed < LAP_START_GRACE_TIME and distance > track.length * 0.5:
		distance = 0.0

	# Grabación de la vuelta (trayectoria + tabla distancia/tiempo).
	if recording != null:
		recording.record(delta_time, car.global_transform)
		recording.record_distance(distance, elapsed)

	# Delta contra la referencia en el mismo punto de la pista.
	has_delta = false
	if reference != null:
		var reference_time := reference.get_time_at_distance(distance)
		if reference_time >= 0.0:
			delta = elapsed - reference_time
			has_delta = true


# ==============================================================================
# API pública
# ==============================================================================

## Tiempo transcurrido de la vuelta en curso [s].
func get_lap_elapsed() -> float:
	if lap_number == 0:
		return 0.0
	return maxf(session_time - _lap_start_time, 0.0)


## Invalida la vuelta en curso (salida de pista, reinicio, exceso en boxes).
func invalidate(reason: String) -> void:
	if lap_number == 0 or not lap_valid:
		return
	lap_valid = false
	lap_invalidated.emit(reason)


## Vuelve a esperar la línea de llegada sin contar la vuelta actual (se usa
## al reubicar el auto: no se puede completar una vuelta "teletransportado").
func abort_lap() -> void:
	if lap_number > 0:
		invalidate("Auto reubicado")


# ==============================================================================
# Internos
# ==============================================================================

func _on_checkpoint_body_entered(body: Node3D, area: Area3D) -> void:
	if body != car or not running:
		return
	var index: int = area.get_meta(Track.META_CHECKPOINT_INDEX, -1)
	if index != _next_checkpoint:
		return   # Checkpoint fuera de orden (marcha atrás, atajo, etc.).
	var time := _crossing_time(area)
	if index == CHECKPOINT_FINISH:
		if lap_number > 0:
			_finish_sector(time)
			_finish_lap(time)
		_start_lap(time)
	else:
		_finish_sector(time)
	_next_checkpoint = (index + 1) % SECTOR_COUNT


# Instante exacto de cruce de la línea. El motor avisa del ingreso al Area3D
# en un tick de física, pero el cruce real ocurrió entre dos ticks (o, como
# el auto tiene largo, ocurrirá unos metros más adelante). Se corrige con
#     t_cruce = t_ahora - d / v
# donde d es la distancia con signo del centro del auto al plano de la línea
# (positiva si ya lo pasó) y v su velocidad hacia adelante.
func _crossing_time(area: Area3D) -> float:
	var forward := -area.global_basis.z
	var distance_past := (car.global_position - area.global_position).dot(forward)
	var speed := 0.0
	if car is RigidBody3D:
		speed = (car as RigidBody3D).linear_velocity.dot(forward)
	if speed < MIN_SPEED_FOR_CORRECTION:
		return session_time
	return session_time - distance_past / speed


func _start_lap(time: float) -> void:
	lap_number += 1
	lap_valid = true
	current_sector = 0
	current_sector_times = []
	_lap_start_time = time
	_sector_start_time = time
	recording = GhostLap.new()
	has_delta = false
	lap_started.emit(lap_number)


func _finish_sector(time: float) -> void:
	var sector_time := time - _sector_start_time
	_sector_start_time = time
	var sector_index := current_sector
	current_sector_times.append(sector_time)
	var previous_best := best_sector_times[sector_index]
	sector_completed.emit(sector_index, sector_time, previous_best)
	if lap_valid and (previous_best <= 0.0 or sector_time < previous_best):
		best_sector_times[sector_index] = sector_time
	current_sector = mini(current_sector + 1, SECTOR_COUNT - 1)


func _finish_lap(time: float) -> void:
	last_lap_time = time - _lap_start_time
	last_lap_valid = lap_valid
	last_sector_times = current_sector_times.duplicate()
	last_finish_time = time
	laps_completed += 1

	if recording != null:
		recording.lap_time = last_lap_time
		recording.sector_times = last_sector_times.duplicate()
	last_recording = recording

	var is_best := lap_valid and (best_lap_time <= 0.0 or last_lap_time < best_lap_time)
	if is_best:
		best_lap_time = last_lap_time
	# La referencia del delta pasa a ser esta vuelta si es válida y más rápida.
	if lap_valid and last_recording != null \
			and (reference == null or last_lap_time < reference.lap_time):
		reference = last_recording

	history.append({
		"number": lap_number,
		"time": last_lap_time,
		"valid": lap_valid,
		"sectors": last_sector_times.duplicate(),
	})
	lap_completed.emit(last_lap_time, lap_valid, is_best)
