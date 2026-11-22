extends Node
## Autoload "Settings": opciones persistentes del simulador.
##
## Guarda y carga las preferencias del usuario en `user://opciones.cfg`
## (fuente de entrada, sensibilidad, zona muerta, caja automática, calibración
## del volante, etc.). El resto del juego lee estas variables y escucha la
## señal `changed` para reaccionar cuando el usuario toca algo en el menú.

## Se emite cada vez que cambia alguna opción (después de `save()`).
signal changed

const FILE_PATH := "user://opciones.cfg"

# Identificadores de las fuentes de entrada disponibles (ver scripts/input/).
const SOURCE_KEYBOARD := "keyboard"
const SOURCE_GAMEPAD := "gamepad"
const SOURCE_UDP_WHEEL := "udp_wheel"
const SOURCE_AUTOPILOT := "autopilot"

# Límites de los controles deslizantes del menú de opciones.
const SENSITIVITY_MIN := 0.5
const SENSITIVITY_MAX := 2.0
const CURVE_MIN := 1.0
const CURVE_MAX := 3.0
const DEADZONE_MAX := 0.3
const RACE_LAPS_MIN := 1
const RACE_LAPS_MAX := 20

# Ayuda de dirección (limita el ángulo al que el agarre puede usar).
const STEER_ASSIST_AUTO := "auto"   ## Solo con teclado
const STEER_ASSIST_ON := "on"       ## Con cualquier dispositivo
const STEER_ASSIST_OFF := "off"     ## Nunca
const STEER_ASSIST_IDS: Array[String] = [STEER_ASSIST_AUTO, STEER_ASSIST_ON, STEER_ASSIST_OFF]
const STEER_ASSIST_LABELS: Array[String] = ["Automática (solo teclado)", "Siempre", "Nunca"]

# Dificultad de los rivales: multiplicador de su ritmo (velocidad).
const AI_DIFFICULTY_LABELS: Array[String] = ["Fácil", "Normal", "Difícil"]
const AI_DIFFICULTY_PACE: Array[float] = [0.94, 1.0, 1.04]
const AI_DIFFICULTY_DEFAULT := 1

# --- Entrada -----------------------------------------------------------------
## Fuente de entrada activa (una de las constantes SOURCE_*).
var input_source: String = SOURCE_KEYBOARD
## Multiplicador lineal de la dirección (1.0 = sin cambios).
var steer_sensitivity: float = 1.0
## Exponente de la curva de dirección: 1 = lineal; >1 = más suave en el centro.
var steer_curve: float = 1.0
## Zona muerta de la dirección para fuentes analógicas (0..DEADZONE_MAX).
var deadzone: float = 0.04
## Ayuda de dirección (una de las constantes STEER_ASSIST_*).
var steer_assist: String = STEER_ASSIST_AUTO

# --- Conducción ---------------------------------------------------------------
## true = caja automática, false = cambios manuales con las levas.
var auto_gearbox: bool = true
## Cantidad de vueltas del nivel Carrera.
var race_laps: int = 3
## Dificultad de los rivales (índice de AI_DIFFICULTY_LABELS).
var ai_difficulty: int = AI_DIFFICULTY_DEFAULT

# --- Última sesión elegida (menú "Preparar sesión") ---------------------------
## Circuito (identificador de assets/circuits/).
var sel_circuit: String = "los_aromos"
## Clima: "seco", "lluvia" o "variable".
var sel_weather: String = "seco"
## Compuesto de neumático de salida (identificador de assets/tyres/).
var sel_compound: String = "medio"

# --- Audio y video ------------------------------------------------------------
var master_volume: float = 0.8
## true = pantalla completa, false = ventana.
var fullscreen: bool = false

# --- Volante por UDP ----------------------------------------------------------
## IP a la que se envía la telemetría si todavía no se recibió ningún paquete
## del volante (cuando llega uno, se usa la IP de origen de ese paquete).
var wheel_host: String = "127.0.0.1"
## Si es true, TelemetryOut imprime por consola lo que envía (depuración).
var telemetry_debug_log: bool = false

# --- Calibración del volante (unidades crudas del protocolo: -1000..1000) ----
var cal_steer_left: int = -1000
var cal_steer_center: int = 0
var cal_steer_right: int = 1000
var cal_done: bool = false


func _ready() -> void:
	load_from_disk()
	_apply_audio()
	_apply_video()


## Lee el archivo de opciones. Si no existe se conservan los valores por defecto.
func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE_PATH) != OK:
		return
	input_source = cfg.get_value("input", "source", input_source)
	steer_sensitivity = cfg.get_value("input", "steer_sensitivity", steer_sensitivity)
	steer_curve = cfg.get_value("input", "steer_curve", steer_curve)
	steer_assist = cfg.get_value("input", "steer_assist", steer_assist)
	if not STEER_ASSIST_IDS.has(steer_assist):
		steer_assist = STEER_ASSIST_AUTO
	deadzone = cfg.get_value("input", "deadzone", deadzone)
	auto_gearbox = cfg.get_value("driving", "auto_gearbox", auto_gearbox)
	ai_difficulty = clampi(cfg.get_value("driving", "ai_difficulty", ai_difficulty), 0, AI_DIFFICULTY_PACE.size() - 1)
	race_laps = cfg.get_value("driving", "race_laps", race_laps)
	sel_circuit = cfg.get_value("session", "circuit", sel_circuit)
	sel_weather = cfg.get_value("session", "weather", sel_weather)
	sel_compound = cfg.get_value("session", "compound", sel_compound)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	wheel_host = cfg.get_value("wheel", "host", wheel_host)
	telemetry_debug_log = cfg.get_value("wheel", "telemetry_debug_log", telemetry_debug_log)
	cal_steer_left = cfg.get_value("calibration", "steer_left", cal_steer_left)
	cal_steer_center = cfg.get_value("calibration", "steer_center", cal_steer_center)
	cal_steer_right = cfg.get_value("calibration", "steer_right", cal_steer_right)
	cal_done = cfg.get_value("calibration", "done", cal_done)
	_sanitize()


## Escribe las opciones a disco y avisa al resto del juego.
func save() -> void:
	_sanitize()
	var cfg := ConfigFile.new()
	cfg.set_value("input", "source", input_source)
	cfg.set_value("input", "steer_sensitivity", steer_sensitivity)
	cfg.set_value("input", "steer_curve", steer_curve)
	cfg.set_value("input", "steer_assist", steer_assist)
	cfg.set_value("input", "deadzone", deadzone)
	cfg.set_value("driving", "auto_gearbox", auto_gearbox)
	cfg.set_value("driving", "ai_difficulty", ai_difficulty)
	cfg.set_value("driving", "race_laps", race_laps)
	cfg.set_value("session", "circuit", sel_circuit)
	cfg.set_value("session", "weather", sel_weather)
	cfg.set_value("session", "compound", sel_compound)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("wheel", "host", wheel_host)
	cfg.set_value("wheel", "telemetry_debug_log", telemetry_debug_log)
	cfg.set_value("calibration", "steer_left", cal_steer_left)
	cfg.set_value("calibration", "steer_center", cal_steer_center)
	cfg.set_value("calibration", "steer_right", cal_steer_right)
	cfg.set_value("calibration", "done", cal_done)
	cfg.save(FILE_PATH)
	_apply_audio()
	_apply_video()
	changed.emit()


## Guarda una calibración nueva del volante (valores crudos del protocolo).
func set_calibration(left: int, center: int, right: int) -> void:
	cal_steer_left = left
	cal_steer_center = center
	cal_steer_right = right
	cal_done = true
	save()


## Vuelve la calibración a los valores nominales del protocolo.
func reset_calibration() -> void:
	cal_steer_left = -1000
	cal_steer_center = 0
	cal_steer_right = 1000
	cal_done = false
	save()


# Mantiene todos los valores dentro de rangos válidos (por si alguien edita el
# archivo a mano o una versión vieja guardó algo raro).
func _sanitize() -> void:
	var valid_sources := [SOURCE_KEYBOARD, SOURCE_GAMEPAD, SOURCE_UDP_WHEEL, SOURCE_AUTOPILOT]
	if not valid_sources.has(input_source):
		input_source = SOURCE_KEYBOARD
	steer_sensitivity = clampf(steer_sensitivity, SENSITIVITY_MIN, SENSITIVITY_MAX)
	steer_curve = clampf(steer_curve, CURVE_MIN, CURVE_MAX)
	deadzone = clampf(deadzone, 0.0, DEADZONE_MAX)
	race_laps = clampi(race_laps, RACE_LAPS_MIN, RACE_LAPS_MAX)
	master_volume = clampf(master_volume, 0.0, 1.0)


# Aplica el volumen general al bus maestro de audio.
func _apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)


# Aplica el modo de ventana elegido (solo si hace falta cambiarlo).
func _apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var current := DisplayServer.window_get_mode()
	var is_fullscreen := current == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_fullscreen:
		DisplayServer.window_set_mode(wanted)


## Multiplicador de ritmo de los rivales para la dificultad elegida.
func get_ai_pace() -> float:
	return AI_DIFFICULTY_PACE[clampi(ai_difficulty, 0, AI_DIFFICULTY_PACE.size() - 1)]
