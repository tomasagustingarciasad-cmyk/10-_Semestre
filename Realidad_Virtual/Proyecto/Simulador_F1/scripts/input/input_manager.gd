extends Node
## Autoload "InputManager": interfaz ÚNICA de entrada del simulador.
##
## Regla de arquitectura del proyecto: el juego nunca lee el teclado, el
## gamepad ni la red directamente. Todo pasa por acá:
##
##     Dispositivo -> InputSource (teclado / gamepad / volante UDP)
##                 -> InputManager (zona muerta, curva, sensibilidad, eventos)
##                 -> lógica de juego (auto, sesión, cámaras, menús)
##
## Interfaz que consume el juego:
##   - `steer` (-1 izquierda .. 1 derecha), `throttle` (0..1), `brake` (0..1)
##   - señal `action_pressed(action)` y una señal dedicada por cada botón
##   - `is_held(action)` para botones que se mantienen (por ejemplo ERS)
##   - señal `encoder_turned(steps)` para el encoder rotativo
##
## Las fuentes son intercambiables en caliente con `set_source()`; la elección
## se guarda en Settings y se cambia desde el menú de opciones.
##
## Fuentes "de respaldo": aunque la fuente activa sea otra (piloto automático
## o volante), el teclado y el gamepad se siguen escuchando para las acciones
## de sistema (pausa, volver a pista, cámara) y para tomar el control:
##   - la acción `take_control` (tecla T / R3 del gamepad) alterna entre el
##     piloto automático y la fuente manual;
##   - con el piloto automático activo, tocar la dirección o un pedal del
##     teclado o del gamepad devuelve el control al jugador.

# --- Nombres de las acciones (botones) ---------------------------------------
const ACTION_SHIFT_UP := &"shift_up"
const ACTION_SHIFT_DOWN := &"shift_down"
const ACTION_DRS := &"drs"
const ACTION_ERS := &"ers"
const ACTION_PIT_LIMITER := &"pit_limiter"
const ACTION_RESET := &"reset"
const ACTION_CAMERA_NEXT := &"camera_next"
const ACTION_PAUSE := &"pause"
## Alterna entre el piloto automático y la conducción manual.
const ACTION_TAKE_CONTROL := &"take_control"

# --- Fuentes de respaldo --------------------------------------------------------
## Fuentes que se escuchan siempre, aunque no sean la activa.
const BACKUP_SOURCES: Array[String] = ["keyboard", "gamepad"]
## Acciones de una fuente de respaldo que llegan al juego (las demás se ignoran
## para que, por ejemplo, el teclado no cambie de marcha mientras se usa el volante).
const SYSTEM_ACTIONS: Array[StringName] = [&"pause", &"reset", &"camera_next"]
## Umbral de dirección o pedal (0..1) a partir del cual una fuente de respaldo
## le quita el control al piloto automático.
const TAKEOVER_THRESHOLD := 0.3

# --- Señales -------------------------------------------------------------------
## Se emite cuando un botón recién se aprieta (flanco ascendente).
signal action_pressed(action: StringName)
signal shift_up_pressed
signal shift_down_pressed
signal drs_pressed
signal ers_pressed
signal pit_limiter_pressed
signal reset_pressed
signal camera_next_pressed
signal pause_pressed
## Giro del encoder: pasos positivos = sentido horario.
signal encoder_turned(steps: int)
## Cambió la fuente activa.
signal source_changed(source_id: String)
## El jugador tomó el control (`manual` = true) o se lo cedió al piloto
## automático (`manual` = false) durante la sesión.
signal control_toggled(manual: bool, source_label: String)
## El dispositivo activo se conectó o se desconectó (timeout del volante,
## gamepad desenchufado, etc.).
signal connection_changed(connected: bool)

# --- Estado público (lo que lee el juego) --------------------------------------
## Dirección procesada: -1 = todo a la izquierda, 1 = todo a la derecha.
var steer: float = 0.0
## Acelerador 0..1.
var throttle: float = 0.0
## Freno 0..1.
var brake: float = 0.0

# --- Internos ------------------------------------------------------------------
var _sources: Dictionary = {}          # id -> InputSource
var _active: InputSource = null
var _was_connected: bool = true
# Fuente manual a la que se vuelve al soltar el piloto automático con T.
var _manual_source_id: String = "keyboard"
# id -> true cuando la fuente de respaldo ya tiene su estado de botones al día
# (la primera lectura después de dejar de ser activa no genera eventos).
var _backup_primed: Dictionary = {}
# id -> true cuando la fuente de respaldo estuvo con ejes en reposo desde que
# arrancó el piloto automático (evita que una tecla que ya estaba apretada al
# activarlo le quite el control enseguida).
var _takeover_armed: Dictionary = {}

# Acciones del volante que se traducen a navegación de menús (acciones "ui_*"
# estándar de Godot) cuando hay un menú en pantalla.
const UI_ACTIONS_FROM_WHEEL := {
	ACTION_SHIFT_UP: &"ui_right",
	ACTION_SHIFT_DOWN: &"ui_left",
	ACTION_DRS: &"ui_accept",
	ACTION_RESET: &"ui_cancel",
}
const UI_ENCODER_NEXT := &"ui_down"
const UI_ENCODER_PREV := &"ui_up"


func _ready() -> void:
	# Debe seguir funcionando con el juego en pausa (para poder despausar) y
	# ejecutarse antes que el auto en cada tick de física.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100

	_register(KeyboardSource.new())
	_register(GamepadSource.new())
	_register(UdpWheelSource.new())
	_register(AutopilotSource.new())

	set_source(Settings.input_source)
	Settings.changed.connect(_on_settings_changed)


func _physics_process(delta: float) -> void:
	if _active == null:
		return
	_active.update(delta)

	# --- Ejes ---------------------------------------------------------------
	if _active.is_analog():
		steer = _shape_steer(_active.raw_steer)
	else:
		steer = clampf(_active.raw_steer, -1.0, 1.0)
	throttle = clampf(_active.raw_throttle, 0.0, 1.0)
	brake = clampf(_active.raw_brake, 0.0, 1.0)

	# --- Botones --------------------------------------------------------------
	var menu_visible := GameState.in_menu or get_tree().paused
	var active_id := _active.get_id()
	for action in _active.take_events():
		_dispatch_action(action, menu_visible, active_id)

	# --- Encoder --------------------------------------------------------------
	var steps := _active.take_encoder_steps()
	if steps != 0:
		if menu_visible:
			if _translates_ui():
				_inject_ui_action(UI_ENCODER_NEXT if steps > 0 else UI_ENCODER_PREV)
		else:
			encoder_turned.emit(steps)

	# --- Conexión -------------------------------------------------------------
	var connected := _active.is_available()
	if connected != _was_connected:
		_was_connected = connected
		connection_changed.emit(connected)

	# --- Fuentes de respaldo -----------------------------------------------
	_listen_backup_sources(delta, menu_visible)


# ==============================================================================
# API pública
# ==============================================================================

## Cambia la fuente activa. `source_id` es una de las constantes
## Settings.SOURCE_*. Devuelve false si el identificador no existe.
func set_source(source_id: String) -> bool:
	if not _sources.has(source_id):
		push_warning("InputManager: fuente desconocida '%s'" % source_id)
		return false
	if _active != null:
		if _active.get_id() == source_id:
			return true
		_active.stop()
	_active = _sources[source_id]
	_active.start()
	if source_id != Settings.SOURCE_AUTOPILOT:
		_manual_source_id = source_id
	# Las fuentes de respaldo vuelven a "cebarse" y a armarse.
	_backup_primed.clear()
	_takeover_armed.clear()
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	_was_connected = _active.is_available()
	source_changed.emit(source_id)
	connection_changed.emit(_was_connected)
	return true


## Identificador de la fuente activa.
func get_source_id() -> String:
	return _active.get_id() if _active != null else ""


## Nombre para mostrar de la fuente activa.
func get_source_label() -> String:
	return _active.get_label() if _active != null else ""


## true si hay que limitar la dirección al ángulo que el agarre aprovecha.
## Depende de la opción "Ayuda de dirección": automática (solo fuentes de
## teclas), siempre o nunca.
func uses_steer_assist() -> bool:
	match Settings.steer_assist:
		Settings.STEER_ASSIST_ON:
			return true
		Settings.STEER_ASSIST_OFF:
			return false
	return _active != null and _active.wants_steer_assist()


## true si el piloto automático está conduciendo.
func is_autopilot_active() -> bool:
	return _active != null and _active.get_id() == Settings.SOURCE_AUTOPILOT


## Le cede el control al piloto automático (si hay un auto en pista) o lo
## recupera para la fuente manual `source_id`. Cambia la opción en memoria
## (no la guarda en disco), así el menú de opciones muestra la fuente real.
func toggle_autopilot(source_id: String = "") -> void:
	if is_autopilot_active():
		var target := source_id if source_id != "" else _manual_source_id
		_switch_in_session(target, true)
	else:
		var autopilot := _sources.get(Settings.SOURCE_AUTOPILOT) as AutopilotSource
		if autopilot == null or not autopilot.has_target():
			return
		_switch_in_session(Settings.SOURCE_AUTOPILOT, false)


## Registra una fuente de entrada adicional (por ejemplo la de una prueba
## automática o un dispositivo nuevo). Después se activa con set_source(id).
func register_source(source: InputSource) -> void:
	_register(source)


## Lista de [id, nombre] de todas las fuentes (para el menú de opciones).
func get_source_list() -> Array:
	var list := []
	for id: String in _sources:
		list.append([id, (_sources[id] as InputSource).get_label()])
	return list


## Devuelve el objeto de una fuente por su id (por ejemplo para calibrar).
func get_source(source_id: String) -> InputSource:
	return _sources.get(source_id)


## true si el dispositivo activo está conectado y entregando datos.
func is_device_connected() -> bool:
	return _active != null and _active.is_available()


## Texto de estado del dispositivo activo (para el HUD).
func get_status_text() -> String:
	return _active.get_status_text() if _active != null else ""


## true mientras el botón de la acción sigue apretado.
func is_held(action: StringName) -> bool:
	return _active != null and _active.is_held(action)


## IP del volante UDP (vacía si nunca se recibió un paquete).
func get_wheel_ip() -> String:
	var wheel := _sources.get(Settings.SOURCE_UDP_WHEEL) as UdpWheelSource
	return wheel.get_sender_ip() if wheel != null else ""


## Vibración local del dispositivo activo (gamepad). intensity: 0..1.
func vibrate(intensity: float, duration_s: float) -> void:
	if _active != null:
		_active.vibrate(clampf(intensity, 0.0, 1.0), duration_s)


## Le indica al piloto automático qué auto conducir y sobre qué circuito.
func set_autopilot_target(car: Node3D, track: Node3D) -> void:
	var autopilot := _sources.get(Settings.SOURCE_AUTOPILOT) as AutopilotSource
	if autopilot != null:
		autopilot.set_target(car, track)


## Le informa al piloto automático las condiciones de agarre: factor por
## neumático y clima, y datos de aquaplaning (ver Track.build_speed_profile).
func set_autopilot_conditions(grip_scale: float, aquaplaning: Vector3) -> void:
	var autopilot := _sources.get(Settings.SOURCE_AUTOPILOT) as AutopilotSource
	if autopilot != null:
		autopilot.set_conditions(grip_scale, aquaplaning)


## Le indica al piloto automático qué otros autos hay en pista (para que
## los esquive). Cada elemento debe ser un Node3D con una propiedad `speed`.
func set_autopilot_obstacles(obstacles: Array) -> void:
	var autopilot := _sources.get(Settings.SOURCE_AUTOPILOT) as AutopilotSource
	if autopilot != null:
		autopilot.set_obstacles(obstacles)


# ==============================================================================
# Internos
# ==============================================================================

func _register(source: InputSource) -> void:
	_sources[source.get_id()] = source


# Zona muerta + curva + sensibilidad para fuentes analógicas.
func _shape_steer(raw: float) -> float:
	var magnitude := absf(raw)
	var dz := Settings.deadzone
	if magnitude <= dz:
		return 0.0
	# Reescala para que justo al salir de la zona muerta el valor sea 0.
	magnitude = (magnitude - dz) / (1.0 - dz)
	# Curva: exponente > 1 = menos sensible cerca del centro.
	magnitude = pow(magnitude, Settings.steer_curve)
	magnitude *= Settings.steer_sensitivity
	return clampf(signf(raw) * magnitude, -1.0, 1.0)


# Escucha el teclado y el gamepad cuando NO son la fuente activa: pausa,
# volver a pista, cámara y tomar el control del piloto automático.
func _listen_backup_sources(delta: float, menu_visible: bool) -> void:
	for id: String in BACKUP_SOURCES:
		if _active == null or _active.get_id() == id or not _sources.has(id):
			continue
		var source: InputSource = _sources[id]
		if not source.is_available():
			continue
		source.update(delta)
		source.take_encoder_steps()
		var events := source.take_events()
		# Primera lectura: solo se registra qué está apretado (sin eventos).
		if not _backup_primed.get(id, false):
			_backup_primed[id] = true
			continue
		if is_autopilot_active() and not menu_visible and _wants_to_drive(source, id):
			toggle_autopilot(id)
			return
		for action in events:
			if action == ACTION_TAKE_CONTROL or SYSTEM_ACTIONS.has(action):
				_dispatch_action(action, menu_visible, id)
				if action == ACTION_TAKE_CONTROL and not menu_visible:
					return   # Cambió la fuente activa: no seguir en este tick.


# true si el jugador está usando la dirección o un pedal de esa fuente. Solo
# cuenta si antes estuvieron en reposo (fuente "armada").
func _wants_to_drive(source: InputSource, id: String) -> bool:
	var in_use := absf(source.raw_steer) > TAKEOVER_THRESHOLD \
			or source.raw_throttle > TAKEOVER_THRESHOLD \
			or source.raw_brake > TAKEOVER_THRESHOLD
	if not _takeover_armed.get(id, false):
		if not in_use:
			_takeover_armed[id] = true
		return false
	return in_use


# Cambia de fuente durante una sesión y avisa (el HUD muestra un mensaje).
func _switch_in_session(source_id: String, manual: bool) -> void:
	if not set_source(source_id):
		return
	Settings.input_source = source_id
	control_toggled.emit(manual, get_source_label())


# Reparte un botón recién apretado: al juego, a los menús o a ambos.
# `from_id` es la fuente que generó el evento.
func _dispatch_action(action: StringName, menu_visible: bool, from_id: String = "") -> void:
	if action == ACTION_TAKE_CONTROL:
		if not menu_visible:
			toggle_autopilot(from_id)
		return
	if menu_visible:
		if _translates_ui() and UI_ACTIONS_FROM_WHEEL.has(action):
			_inject_ui_action(UI_ACTIONS_FROM_WHEEL[action])
		# Con un menú en pantalla el único botón de juego que sigue vivo es
		# la pausa (para poder volver a la pista).
		if action != ACTION_PAUSE:
			return
	action_pressed.emit(action)
	match action:
		ACTION_SHIFT_UP: shift_up_pressed.emit()
		ACTION_SHIFT_DOWN: shift_down_pressed.emit()
		ACTION_DRS: drs_pressed.emit()
		ACTION_ERS: ers_pressed.emit()
		ACTION_PIT_LIMITER: pit_limiter_pressed.emit()
		ACTION_RESET: reset_pressed.emit()
		ACTION_CAMERA_NEXT: camera_next_pressed.emit()
		ACTION_PAUSE: pause_pressed.emit()


# Solo el volante necesita traducción a acciones de menú: el teclado y el
# gamepad ya manejan los menús con las acciones "ui_*" propias de Godot.
func _translates_ui() -> bool:
	return _active != null and _active.get_id() == Settings.SOURCE_UDP_WHEEL


# Simula la pulsación de una acción de interfaz ("ui_accept", "ui_down"...).
func _inject_ui_action(ui_action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = ui_action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = ui_action
	release.pressed = false
	Input.parse_input_event(release)


func _on_settings_changed() -> void:
	if Settings.input_source != get_source_id():
		set_source(Settings.input_source)
