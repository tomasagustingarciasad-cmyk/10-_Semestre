class_name RaceSession
extends SessionBase
## Nivel 2 — Carrera: N vueltas bajo la lluvia contra rivales con IA.
##
## Diferencias con la Clasificación (segundo escenario de interacción):
##   - largada desde la grilla con semáforo de 5 luces;
##   - rivales (AiCar) que siguen el trazado con un perfil de velocidad;
##   - clima elegible (seco, lluvia o variable) que condiciona a todos;
##   - neumáticos: los rivales eligen el compuesto según el agua en pista;
##   - parada en boxes obligatoria y penalizaciones en tiempo;
##   - posiciones en vivo y pantalla de resultados al terminar.

enum Phase { GRID, COUNTDOWN, RACING, FINISHED }

# Tiempos del procedimiento de largada [s].
const GRID_WAIT_TIME := 2.5
const LIGHT_INTERVAL := 1.0
const LIGHTS_OUT_MIN_DELAY := 0.6
const LIGHTS_OUT_MAX_DELAY := 1.8
# Penalizaciones [s].
const PENALTY_PIT_SPEEDING := 5.0
const PENALTY_NO_PIT_STOP := 30.0
# La parada obligatoria rige si la carrera tiene al menos estas vueltas.
const MIN_LAPS_FOR_MANDATORY_STOP := 2
# Los rivales cambian de neumático si el mejor compuesto para el agua actual
# rinde al menos esta fracción más que el que llevan.
const AI_COMPOUND_SWITCH_MARGIN := 0.04
# Para entrar a boxes en la vuelta en curso, el rival tiene que estar al menos
# a esta distancia de la entrada [m].
const AI_PIT_DECISION_DISTANCE := 250.0
# Perfil de velocidad de los rivales: agarre efectivo en seco y velocidad máxima.
const AI_TOP_SPEED := 95.0
## Vida del neumático medio (rodando derecho) en distancias de carrera. Con
## el desgaste extra por las curvas (x1,45 en promedio), un medio llega al
## final de la carrera con ~95 % de desgaste, un blando "muere" al 60 % de
## la carrera y un duro termina cerca del acantilado.
const RACE_TYRE_LIFE_FACTOR := 1.5
# Tiempo entre la bandera a cuadros y la pantalla de resultados [s].
const RESULTS_DELAY := 3.0
# Velocidad media supuesta para estimar el tiempo de quien no llegó [m/s].
const FALLBACK_AVERAGE_SPEED := 42.0
# Tiempo mínimo de carrera [s] para confiar en la velocidad media real de un rival.
const MIN_TIME_FOR_AVERAGE := 20.0
const PLAYER_NAME := "Vos"

@onready var _rivals_root: Node = $Rivales

var phase: Phase = Phase.GRID
var total_laps: int = 3
var rivals: Array[AiCar] = []
## Posición del jugador (1 = primero) y cantidad de autos.
var player_position: int = 1
var car_count: int = 1
## Luces del semáforo encendidas (0..5), para el HUD.
var lights_lit: int = 0
## Distancia total recorrida por el jugador desde la línea (negativa en la grilla).
var player_distance: float = 0.0
## Tiempo de carrera del jugador al cruzar la meta (sin penalizaciones).
var player_finish_time: float = 0.0

var _phase_timer: float = 0.0
var _lights_out_delay: float = 0.0
var _previous_offset: float = 0.0
var _start_lights: StartLights = null
# Perfiles de velocidad de los rivales, uno por compuesto: id -> PackedFloat32Array.
var _profiles: Dictionary = {}


func _setup_session() -> void:
	session_title = "Carrera"
	total_laps = Settings.race_laps
	_start_lights = track.get_node_or_null("Decorado/Largada/Portico/Semaforo") as StartLights

	# --- Rivales: grilla, neumáticos y vuelta de parada --------------------------
	var start_compound := TyreCompound.best_for(weather.water_level)
	for node in _rivals_root.get_children():
		if node is AiCar:
			rivals.append(node)
	for i in rivals.size():
		var rival := rivals[i]
		rival.compound = start_compound
		rival.difficulty = Settings.get_ai_pace()
		rival.player = car
		rival.pit_stop_completed.connect(_on_rival_pit_stop_completed)
		rival.pit_box_index = i + 1
		rival.place_on_grid(track, i)
		rival.lap_completed.connect(_on_rival_lap_completed)
		if total_laps >= MIN_LAPS_FOR_MANDATORY_STOP:
			# Cada rival para en una vuelta distinta (nunca en la última).
			rival.pit_on_lap = 1 + (i % (total_laps - 1))
	car_count = rivals.size() + 1

	# --- Jugador: último cajón de la grilla --------------------------------------
	var player_slot := rivals.size()
	place_car_at(track.get_grid_transform(player_slot, SPAWN_HEIGHT))
	car.controls_enabled = false
	car.drs.enabled = false   # Sin DRS hasta que se apague el semáforo.
	player_distance = -(track.grid_first_row_distance + track.grid_row_spacing * player_slot)
	_previous_offset = car_offset
	_update_positions()
	InputManager.set_autopilot_obstacles(rivals)

	lap_timer.lap_completed.connect(_on_player_lap_completed)
	phase = Phase.GRID
	_phase_timer = GRID_WAIT_TIME
	_lights_out_delay = randf_range(LIGHTS_OUT_MIN_DELAY, LIGHTS_OUT_MAX_DELAY)
	notify_title = "%s — %s" % [track.display_name, weather.get_description()]
	notify("%s: %d vueltas, %s" % [track.display_name, total_laps, weather.get_description()], COLOR_INFO, GRID_WAIT_TIME)


func _update_session(delta: float) -> void:
	for rival in rivals:
		rival.player_offset = car_offset
	match phase:
		Phase.GRID:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				phase = Phase.COUNTDOWN
				_phase_timer = LIGHT_INTERVAL
		Phase.COUNTDOWN:
			_update_countdown(delta)
		Phase.RACING:
			_update_player_progress()
			_update_positions()
		Phase.FINISHED:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				finish_session()


# ==============================================================================
# Largada
# ==============================================================================
func _update_countdown(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return
	if lights_lit < StartLights.LIGHT_COUNT:
		# Se enciende una luz por segundo.
		_set_lights(lights_lit + 1)
		_phase_timer = LIGHT_INTERVAL if lights_lit < StartLights.LIGHT_COUNT else _lights_out_delay
	else:
		# Se apagan todas: ¡largada!
		_set_lights(0)
		phase = Phase.RACING
		car.controls_enabled = true
		car.drs.enabled = true
		lap_timer.running = true
		for rival in rivals:
			rival.active = true
		notify("¡LARGARON!", COLOR_GOOD, 1.5)


func _set_lights(count: int) -> void:
	lights_lit = count
	if _start_lights != null:
		_start_lights.set_lit(count)


# ==============================================================================
# Posiciones
# ==============================================================================

# Acumula la distancia recorrida por el jugador a partir del avance de su
# proyección sobre el eje de la pista (sirve aunque circule por el pit lane).
func _update_player_progress() -> void:
	player_distance += track.signed_offset_difference(_previous_offset, car_offset)
	_previous_offset = car_offset


func _update_positions() -> void:
	var position := 1
	for rival in rivals:
		if rival.total_distance > player_distance:
			position += 1
	player_position = position


## Lista de autos ordenada por posición: [{name, distance, is_player}].
func get_standings() -> Array[Dictionary]:
	var standings: Array[Dictionary] = [
		{"name": PLAYER_NAME, "distance": player_distance, "is_player": true}]
	for rival in rivals:
		standings.append({"name": rival.driver_name, "distance": rival.total_distance, "is_player": false})
	standings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] > b["distance"])
	return standings


## true si la carrera exige parada en boxes.
func is_pit_stop_mandatory() -> bool:
	return total_laps >= MIN_LAPS_FOR_MANDATORY_STOP


# ==============================================================================
# Eventos
# ==============================================================================
func _can_reset() -> bool:
	return phase == Phase.RACING and super._can_reset()


func _on_pit_speeding() -> void:
	penalty_seconds += PENALTY_PIT_SPEEDING
	notify("Exceso de velocidad en boxes: +%d s" % int(PENALTY_PIT_SPEEDING), COLOR_BAD, 3.5)


func _on_pit_stop_completed() -> void:
	if is_pit_stop_mandatory() and pit_stops == 1:
		notify("Parada obligatoria cumplida", COLOR_GOOD)


func _on_player_lap_completed(lap_time: float, valid: bool, _is_best: bool) -> void:
	if phase != Phase.RACING:
		return
	if valid:
		BestTimes.add(track.circuit_id, get_weather_id(), lap_time, car.compound.id)
	if lap_timer.laps_completed >= total_laps:
		# Bandera a cuadros para el jugador.
		player_finish_time = lap_timer.last_finish_time
		phase = Phase.FINISHED
		_phase_timer = RESULTS_DELAY
		car.controls_enabled = false
		if is_pit_stop_mandatory() and pit_stops == 0:
			penalty_seconds += PENALTY_NO_PIT_STOP
			notify("¡Bandera a cuadros! Sin parada en boxes: +%d s" % int(PENALTY_NO_PIT_STOP), COLOR_BAD, RESULTS_DELAY)
		else:
			notify("¡Bandera a cuadros!", COLOR_GOOD, RESULTS_DELAY)
	else:
		var remaining := total_laps - lap_timer.laps_completed
		var text := "Vuelta %s" % GameState.format_time(lap_time)
		if remaining == 1:
			text += " — ¡Última vuelta!"
		if is_pit_stop_mandatory() and pit_stops == 0 and remaining == 1:
			text += " Falta la parada en boxes"
		notify(text, COLOR_INFO, 3.5)


func _on_rival_lap_completed(rival: AiCar, lap: int) -> void:
	var now := lap_timer.session_time
	var lap_time := now - rival.last_lap_start_time
	if lap > 0 and (rival.best_lap_time <= 0.0 or lap_time < rival.best_lap_time):
		rival.best_lap_time = lap_time
	rival.last_lap_start_time = now
	if lap >= total_laps and not rival.finished:
		rival.finished = true
		rival.finish_time = now


# ==============================================================================
# Condiciones: agua en pista y neumáticos de los rivales
# ==============================================================================

# Desgaste proporcional a la carrera: la vida del neumático es un múltiplo de
# la distancia total, así en una carrera de 3 vueltas se gasta (y obliga a
# pensar la estrategia) igual que en una de 20. Nunca más que la vida real.
func _get_tyre_life() -> float:
	return minf(car.setup.tyre_life_distance, RACE_TYRE_LIFE_FACTOR * total_laps * track.length)


func _estimate_duration() -> float:
	return Settings.race_laps * track.length / ESTIMATED_AVERAGE_SPEED


# Cambió el agua en pista: se recalculan los perfiles de velocidad y cada
# rival decide si le conviene entrar a cambiar neumáticos.
func _on_conditions_changed() -> void:
	_profiles.clear()
	var best := TyreCompound.best_for(weather.water_level)
	for rival in rivals:
		_assign_profile(rival)
		if rival.finished or rival.compound == null or rival.state != AiCar.State.ON_TRACK:
			continue
		var wants_change := rival.compound.id != best.id
		if rival.pit_on_lap > 0:
			# Ya tiene una parada prevista: en ella monta el mejor compuesto del momento.
			rival.next_compound = best if wants_change else null
			continue
		if not wants_change:
			continue
		var gain := best.get_score(weather.water_level) / rival.compound.get_score(weather.water_level) - 1.0
		if gain > AI_COMPOUND_SWITCH_MARGIN:
			# Entra en esta vuelta si todavía está lejos de la entrada; si no, en la próxima.
			var far_enough := track.distance_ahead(rival.track_offset, track.pit_entry_offset) > AI_PIT_DECISION_DISTANCE
			var wanted_lap := rival.laps_completed + (1 if far_enough else 2)
			if wanted_lap <= total_laps:
				rival.next_compound = best
				rival.pit_on_lap = wanted_lap


# Perfil de velocidad de un rival según su compuesto y el agua actual. El
# agarre del perfil incluye el compuesto y el aquaplaning: con slicks bajo la
# lluvia el rival va mucho más despacio.
func _assign_profile(rival: AiCar) -> void:
	var compound := rival.compound
	if not _profiles.has(compound.id):
		_profiles[compound.id] = track.build_speed_profile(car.setup,
				compound.get_grip(weather.water_level), AI_TOP_SPEED,
				compound.get_profile_aquaplaning(weather.water_level))
	rival.profile = _profiles[compound.id]
	rival.setup = car.setup
	rival.tyre_life = _get_tyre_life()
	rival.wear_multiplier = compound.get_wear_multiplier(weather.water_level)
	rival.grip_scale = compound.get_grip(weather.water_level)


func _on_rival_pit_stop_completed(rival: AiCar) -> void:
	_assign_profile(rival)


# ==============================================================================
# Resultados
# ==============================================================================
func _build_results() -> Dictionary:
	var entries: Array[Dictionary] = []
	var now := lap_timer.session_time
	var player_finished := lap_timer.laps_completed >= total_laps

	entries.append({
		"name": PLAYER_NAME,
		"finished": player_finished,
		"time": (player_finish_time + penalty_seconds) if player_finished else INF,
		"distance": player_distance,
		"best": lap_timer.best_lap_time,
		"penalty": penalty_seconds,
		"stops": pit_stops,
	})
	for rival in rivals:
		var time := rival.finish_time
		if not rival.finished:
			# Todavía en pista: se estima cuánto le falta con su ritmo medio.
			var remaining := maxf(total_laps * track.length - rival.total_distance, 0.0)
			var average_speed := FALLBACK_AVERAGE_SPEED
			if now > MIN_TIME_FOR_AVERAGE and rival.total_distance > 0.0:
				average_speed = maxf(rival.total_distance / now, 10.0)
			time = now + remaining / average_speed
		entries.append({
			"name": rival.driver_name,
			"finished": true,
			"time": time,
			"distance": rival.total_distance,
			"best": rival.best_lap_time,
			"penalty": 0.0,
			"stops": rival.pit_stops,
		})

	# Orden: por tiempo total; quien abandonó (jugador sin terminar) va al final.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["finished"] != b["finished"]:
			return a["finished"]
		if a["finished"]:
			return a["time"] < b["time"]
		return a["distance"] > b["distance"])

	var rows: Array = []
	var winner_time: float = entries[0]["time"]
	var player_place := 0
	for i in entries.size():
		var entry := entries[i]
		if entry["name"] == PLAYER_NAME:
			player_place = i + 1
		var total_text := "No terminó"
		var gap_text := ""
		if entry["finished"] and not is_inf(entry["time"]):
			total_text = GameState.format_time(entry["time"])
			gap_text = "" if i == 0 else "+%.3f" % (entry["time"] - winner_time)
		rows.append([
			str(i + 1),
			entry["name"],
			total_text,
			gap_text,
			GameState.format_time(entry["best"]),
			str(entry["stops"]),
			("+%d s" % int(entry["penalty"])) if entry["penalty"] > 0.0 else "",
		])

	var footer := "Terminaste en la posición %d de %d" % [player_place, entries.size()]
	if not player_finished:
		footer = "Carrera abandonada"
	return {
		"title": "Carrera — %s (%d vueltas, %s)" % [track.display_name, total_laps, weather.get_description()],
		"headers": ["Pos.", "Piloto", "Tiempo total", "Diferencia", "Mejor vuelta", "Paradas", "Penalización"],
		"rows": rows,
		"footer": footer,
	}
