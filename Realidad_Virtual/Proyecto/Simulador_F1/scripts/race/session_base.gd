class_name SessionBase
extends Node3D
## Lógica común a los dos niveles (Clasificación y Carrera).
##
## Una "sesión" es la escena de un nivel: contiene el circuito, el auto del
## jugador, el HUD y el menú de pausa. Esta clase base resuelve lo que ambos
## niveles comparten:
##   - carga del circuito elegido, clima y neumáticos de salida;
##   - cronometraje (LapTimer) y control de límites de pista;
##   - zonas del circuito: DRS, pit lane (límite de velocidad) y box;
##   - botones generales: volver a pista, cambiar de cámara, pausa;
##   - avisos al piloto por el HUD.
## Cada nivel hereda y completa los métodos `_setup_session()`,
## `_update_session()` y las reacciones a penalizaciones.

# Altura a la que se "suelta" el auto al ubicarlo sobre la pista [m].
const SPAWN_HEIGHT := 0.25
# Exceso de velocidad tolerado en el pit lane [m/s].
const PIT_SPEED_TOLERANCE := 1.0
# Velocidad por debajo de la cual el auto se considera detenido en el box [m/s].
const PIT_STOP_MAX_SPEED := 0.5
# Duración del cambio de neumáticos [s] (alcanza para elegir el compuesto).
const PIT_SERVICE_TIME := 3.2
# Cambio en el nivel de agua a partir del cual se actualizan el asfalto y los
# perfiles de velocidad.
const WATER_REFRESH_STEP := 0.05
# Velocidad media supuesta para estimar la duración de una vuelta [m/s].
const ESTIMATED_AVERAGE_SPEED := 45.0
# Duración por defecto de los mensajes del HUD [s].
const MESSAGE_TIME := 2.5

const COLOR_INFO := Color(1.0, 1.0, 1.0)
const COLOR_GOOD := Color(0.3, 1.0, 0.45)
const COLOR_WARNING := Color(1.0, 0.8, 0.2)
const COLOR_BAD := Color(1.0, 0.35, 0.3)

@onready var car: F1Car = $Auto
@onready var hud: Hud = $HUD
@onready var pause_menu: PauseMenu = $MenuPausa
@onready var weather: Weather = $Clima

## Circuito elegido (se carga al iniciar: el nivel no trae ninguno fijo).
var track: Track
## Progreso del auto en la vuelta [m], con búsqueda local.
var car_offset: float = 0.0
## Compuesto elegido para montar en la parada en boxes en curso.
var pit_choice: TyreCompound = null

var lap_timer: LapTimer
var camera_rig: CameraRig

## Paradas en boxes completadas.
var pit_stops: int = 0
## Segundos de penalización acumulados.
var penalty_seconds: float = 0.0
## true mientras se realiza el cambio de neumáticos.
var servicing: bool = false
## Nombre del nivel (lo muestra el HUD y la pantalla de resultados).
var session_title: String = "Sesión"
## Texto con circuito y clima (lo muestra el HUD).
var notify_title: String = ""
## true cuando la sesión terminó (se muestran los resultados).
var finished: bool = false

var _drs_zones: Array[Area3D] = []
var _pit_lane_area: Area3D = null
var _pit_box_area: Area3D = null
var _pit_speeding_flagged: bool = false
var _pit_service_timer: float = 0.0
var _pit_serviced_this_visit: bool = false
var _controls_before_service: bool = true
var _water_applied: float = -1.0


func _ready() -> void:
	GameState.in_menu = false
	_load_circuit()
	camera_rig = car.get_node("Camaras") as CameraRig
	car.track = track
	car.weather = weather
	car.set_compound(TyreCompound.load_compound(Settings.sel_compound))
	weather.setup(Settings.sel_weather, _estimate_duration())

	lap_timer = LapTimer.new()
	lap_timer.name = "Cronometro"
	add_child(lap_timer)
	lap_timer.setup(car, track)
	lap_timer.lap_invalidated.connect(_on_lap_invalidated)

	for area: Area3D in get_tree().get_nodes_in_group(Track.GROUP_DRS_ZONE):
		_drs_zones.append(area)
	_pit_lane_area = get_tree().get_first_node_in_group(Track.GROUP_PIT_LANE) as Area3D
	_pit_box_area = get_tree().get_first_node_in_group(Track.GROUP_PIT_BOX) as Area3D

	InputManager.reset_pressed.connect(_on_reset_pressed)
	InputManager.camera_next_pressed.connect(_on_camera_next_pressed)
	InputManager.pause_pressed.connect(_on_pause_pressed)
	InputManager.shift_up_pressed.connect(_on_pit_choice_changed.bind(1))
	InputManager.shift_down_pressed.connect(_on_pit_choice_changed.bind(-1))
	InputManager.drs_pressed.connect(_on_pit_choice_changed.bind(1))
	InputManager.set_autopilot_target(car, track)
	InputManager.control_toggled.connect(_on_control_toggled)
	car.flipped.connect(_on_car_flipped)

	pause_menu.finish_requested.connect(finish_session)

	_setup_session()
	car.tyres.life_distance = _get_tyre_life()
	_refresh_conditions()
	hud.bind(self)


func _physics_process(delta: float) -> void:
	if finished:
		return
	car_offset = track.get_offset_near(car.global_position, car_offset)
	lap_timer.car_offset = car_offset
	weather.clock_running = lap_timer.running
	if absf(weather.water_level - _water_applied) >= WATER_REFRESH_STEP:
		_refresh_conditions()
	_update_zones()
	_update_track_limits()
	_update_pit_lane()
	_update_pit_service(delta)
	car.lap_invalid = lap_timer.lap_number > 0 and not lap_timer.lap_valid
	_update_session(delta)


# ==============================================================================
# Métodos que completa cada nivel
# ==============================================================================

## Preparación inicial del nivel (ubicar autos, cargar datos, etc.).
func _setup_session() -> void:
	pass


## Lógica propia del nivel, una vez por tick de física.
func _update_session(_delta: float) -> void:
	pass


## El jugador superó el límite de velocidad en el pit lane.
func _on_pit_speeding() -> void:
	pass


## Se completó una parada en boxes.
func _on_pit_stop_completed() -> void:
	pass


## Cambió el agua en pista o el neumático del jugador: cada nivel recalcula
## lo que dependa de eso (por ejemplo el perfil de velocidad de los rivales).
func _on_conditions_changed() -> void:
	pass


## Duración estimada de la sesión [s] (la usa el clima variable).
## Distancia de vida del neumático medio en esta sesión [m].
func _get_tyre_life() -> float:
	return car.setup.tyre_life_distance


func _estimate_duration() -> float:
	return 4.0 * track.length / ESTIMATED_AVERAGE_SPEED


## Arma los datos para la pantalla de resultados: {title, headers, rows, footer}.
func _build_results() -> Dictionary:
	return {}


## true si el botón "volver a pista" está permitido en este momento.
func _can_reset() -> bool:
	return car.controls_enabled and not servicing


# ==============================================================================
# API para los niveles, el HUD y el menú de pausa
# ==============================================================================

## Termina la sesión y muestra la pantalla de resultados.
func finish_session() -> void:
	if finished:
		return
	finished = true
	car.controls_enabled = false
	TelemetryOut.stop()
	hud.visible = false
	var results := _build_results()
	var screen := (load("res://scenes/ui/results_screen.tscn") as PackedScene).instantiate() as ResultsScreen
	add_child(screen)
	screen.show_results(results)


## Muestra un aviso al piloto.
func notify(text: String, color: Color = COLOR_INFO, seconds: float = MESSAGE_TIME) -> void:
	hud.show_message(text, color, seconds)


## Ubica el auto sobre el eje de la pista en `offset`, detenido.
func place_car_on_track(offset: float, lateral: float = 0.0) -> void:
	car.teleport(track.get_transform_at(offset, lateral, SPAWN_HEIGHT))
	car_offset = track.wrap_offset(offset)
	camera_rig.snap()


## Ubica el auto en una transformación cualquiera (grilla, boxes).
func place_car_at(target: Transform3D) -> void:
	car.teleport(target)
	car_offset = track.get_closest_offset(target.origin)
	camera_rig.snap()


## Identificador del clima elegido ("seco", "lluvia", "variable").
func get_weather_id() -> String:
	return weather.get_mode_id()


## Velocidad máxima permitida en el pit lane [m/s].
func get_pit_speed_limit() -> float:
	return car.setup.get_pit_speed_limit()


# ==============================================================================
# Circuito y condiciones
# ==============================================================================

# Carga la escena del circuito elegido (solo esa) y la agrega al nivel.
func _load_circuit() -> void:
	var id := Settings.sel_circuit
	if not ResourceLoader.exists(TrackLayout.scene_path(id)):
		push_warning("No existe el circuito '%s': se usa el circuito por defecto" % id)
		id = TrackLayout.DEFAULT_CIRCUIT
	track = (load(TrackLayout.scene_path(id)) as PackedScene).instantiate() as Track
	track.name = "Circuito"
	add_child(track)
	move_child(track, 0)


# Aplica el agua en pista a todo lo que depende de ella: aspecto del asfalto,
# piloto automático y lo propio de cada nivel.
func _refresh_conditions() -> void:
	_water_applied = weather.water_level
	track.set_wet(weather.water_level)
	InputManager.set_autopilot_conditions(car.compound.get_grip(weather.water_level),
			car.compound.get_profile_aquaplaning(weather.water_level))
	_on_conditions_changed()


# ==============================================================================
# Zonas y reglas
# ==============================================================================

# DRS y pit lane: se consulta directamente qué Area3D contiene al auto.
func _update_zones() -> void:
	var in_drs_zone := false
	for zone in _drs_zones:
		if zone.overlaps_body(car):
			in_drs_zone = true
			break
	car.drs.in_zone = in_drs_zone
	car.in_pit_lane = _pit_lane_area != null and _pit_lane_area.overlaps_body(car)


# Límites de pista: con las cuatro ruedas afuera se invalida la vuelta.
func _update_track_limits() -> void:
	if car.wheels_off_track >= F1Car.WHEEL_COUNT:
		lap_timer.invalidate("Límites de pista")


# Límite de velocidad en boxes: una infracción por pasada.
func _update_pit_lane() -> void:
	if not car.in_pit_lane:
		_pit_speeding_flagged = false
		return
	if not _pit_speeding_flagged and absf(car.speed) > get_pit_speed_limit() + PIT_SPEED_TOLERANCE:
		_pit_speeding_flagged = true
		_on_pit_speeding()


# Parada en boxes: detenerse dentro del box inicia el cambio de neumáticos.
func _update_pit_service(delta: float) -> void:
	if _pit_box_area == null:
		return
	var in_box := _pit_box_area.overlaps_body(car)
	if not in_box:
		_pit_serviced_this_visit = false
		_pit_service_timer = 0.0
		return
	if _pit_serviced_this_visit:
		return

	var stopped := absf(car.speed) < PIT_STOP_MAX_SPEED
	if not servicing:
		if stopped and car.controls_enabled:
			servicing = true
			pit_choice = car.compound   # Por defecto, el mismo compuesto.
			_pit_service_timer = 0.0
			_controls_before_service = car.controls_enabled
			car.controls_enabled = false   # El auto queda frenado en el box.
			notify("Cambiando neumáticos: elegí el compuesto con las levas", COLOR_WARNING, PIT_SERVICE_TIME)
		return

	_pit_service_timer += delta
	if _pit_service_timer >= PIT_SERVICE_TIME:
		servicing = false
		_pit_serviced_this_visit = true
		car.service_in_pits(pit_choice)
		car.controls_enabled = _controls_before_service
		pit_stops += 1
		notify("¡%s nuevos! Salí de boxes" % car.compound.display_name, COLOR_GOOD)
		_refresh_conditions()
		_on_pit_stop_completed()


# ==============================================================================
# Botones generales
# ==============================================================================

# Durante la parada, las levas (o el botón DRS) cambian el compuesto a montar.
func _on_pit_choice_changed(direction: int) -> void:
	if not servicing or pit_choice == null:
		return
	var ids := TyreCompound.IDS
	var index := posmod(ids.find(pit_choice.id) + direction, ids.size())
	pit_choice = TyreCompound.load_compound(ids[index])


func _on_reset_pressed() -> void:
	if finished or not _can_reset():
		return
	reset_car_to_track()


## Devuelve el auto al eje de la pista en el punto más cercano.
func reset_car_to_track() -> void:
	place_car_on_track(car_offset)
	lap_timer.abort_lap()
	notify("Auto reubicado en pista", COLOR_WARNING)


func _on_camera_next_pressed() -> void:
	if finished:
		return
	camera_rig.next()
	notify("Cámara: " + camera_rig.get_mode_label(), COLOR_INFO, 1.2)


# Aviso al tomar o ceder el control del piloto automático (tecla T).
func _on_control_toggled(manual: bool, source_label: String) -> void:
	if manual:
		notify("Control manual: %s" % source_label, COLOR_GOOD)
	else:
		notify("Piloto automático activado (T para retomar el control)", COLOR_INFO)


func _on_pause_pressed() -> void:
	if finished:
		return
	pause_menu.toggle()


func _on_car_flipped() -> void:
	if not finished:
		reset_car_to_track()


func _on_lap_invalidated(reason: String) -> void:
	notify("Vuelta invalidada: " + reason, COLOR_BAD)
