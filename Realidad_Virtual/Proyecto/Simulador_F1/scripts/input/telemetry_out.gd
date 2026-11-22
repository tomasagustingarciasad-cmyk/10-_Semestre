extends Node
## Autoload "TelemetryOut": salida de datos del juego hacia el dispositivo.
##
## Es la contracara del InputManager: el juego publica acá su estado y este
## nodo lo envía al volante por UDP (puerto WheelProtocol.PORT_PC_TO_WHEEL):
##   - telemetría periódica (~30 Hz): "T,<rpm_pct>,<gear>,<flags>"
##   - eventos de vibración:          "V,<intensidad>,<duracion_ms>"
##
## El volante usa la telemetría para la tira de LEDs (shift lights) y los
## eventos para el motor de vibración. En esta fase todavía no hay hardware:
## los paquetes se pueden ver con `tools/fake_wheel.py` o activando el log de
## depuración en las opciones.

# Tipos de evento de vibración.
const VIB_KERB := &"piano"
const VIB_GRASS := &"pasto"
const VIB_CRASH := &"choque"
const VIB_SHIFT := &"cambio"
const VIB_AQUAPLANING := &"aquaplaning"

# Intensidad (0-255) y duración (ms) base de cada evento.
const VIBRATION_PRESETS := {
	VIB_KERB: {"intensity": 130, "duration_ms": 70},
	VIB_GRASS: {"intensity": 90, "duration_ms": 110},
	VIB_CRASH: {"intensity": 255, "duration_ms": 350},
	VIB_SHIFT: {"intensity": 60, "duration_ms": 30},
	VIB_AQUAPLANING: {"intensity": 170, "duration_ms": 120},
}
# Tiempo mínimo entre dos eventos del mismo tipo (evita saturar al volante).
const VIBRATION_MIN_INTERVAL_MS := 90
# Cada cuánto se imprime la telemetría cuando el log de depuración está activo.
const DEBUG_LOG_INTERVAL_S := 0.5

## Se emite por cada evento de vibración (lo usa el HUD para mostrarlo).
signal vibration_sent(kind: StringName, intensity: int, duration_ms: int)

# Último estado publicado por el auto.
var rpm_pct: int = 0
var gear: int = 0
var flags: int = 0
## false = no se envía telemetría periódica (por ejemplo en los menús).
var active: bool = false

## Contadores para diagnóstico.
var packets_sent: int = 0
var last_packet_text: String = ""

var _udp := PacketPeerUDP.new()
var _send_accumulator: float = 0.0
var _debug_accumulator: float = 0.0
var _last_vibration_ms: Dictionary = {}   # tipo -> marca de tiempo


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not active:
		return
	_send_accumulator += delta
	var period := 1.0 / WheelProtocol.TELEMETRY_SEND_HZ
	if _send_accumulator < period:
		return
	_send_accumulator = fmod(_send_accumulator, period)
	var text := WheelProtocol.format_telemetry(rpm_pct, gear, flags)
	_send(text)

	if Settings.telemetry_debug_log:
		_debug_accumulator += period
		if _debug_accumulator >= DEBUG_LOG_INTERVAL_S:
			_debug_accumulator = 0.0
			print("[TelemetryOut] ", text.strip_edges(), " -> ", _destination_ip())


# ==============================================================================
# API pública
# ==============================================================================

## Publica el estado del auto. Lo llama el auto del jugador en cada tick.
func publish_state(new_rpm_pct: float, new_gear: int, new_flags: int) -> void:
	rpm_pct = clampi(int(round(new_rpm_pct)), 0, 100)
	gear = new_gear
	flags = new_flags
	active = true


## Detiene el envío periódico (al salir de la pista) y apaga los LEDs.
func stop() -> void:
	if active:
		_send(WheelProtocol.format_telemetry(0, WheelProtocol.GEAR_NEUTRAL, 0))
	active = false
	rpm_pct = 0
	gear = 0
	flags = 0


## Dispara un evento de vibración. `kind` es una de las constantes VIB_*;
## `strength` (0..1) escala la intensidad base del evento.
func vibrate(kind: StringName, strength: float = 1.0) -> void:
	if not VIBRATION_PRESETS.has(kind):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_vibration_ms.get(kind, -VIBRATION_MIN_INTERVAL_MS)) < VIBRATION_MIN_INTERVAL_MS:
		return
	_last_vibration_ms[kind] = now

	var preset: Dictionary = VIBRATION_PRESETS[kind]
	var intensity := clampi(int(round(preset["intensity"] * clampf(strength, 0.0, 1.0))),
			0, WheelProtocol.VIBRATION_MAX)
	var duration_ms: int = preset["duration_ms"]
	if intensity <= 0:
		return
	_send(WheelProtocol.format_vibration(intensity, duration_ms))
	# El gamepad (si es la fuente activa) vibra localmente con el mismo evento.
	InputManager.vibrate(float(intensity) / WheelProtocol.VIBRATION_MAX, duration_ms / 1000.0)
	vibration_sent.emit(kind, intensity, duration_ms)
	if Settings.telemetry_debug_log:
		print("[TelemetryOut] vibración '%s': intensidad %d, %d ms" % [kind, intensity, duration_ms])


# ==============================================================================
# Internos
# ==============================================================================

# IP de destino: la del volante si ya transmitió, si no la configurada.
func _destination_ip() -> String:
	var ip := InputManager.get_wheel_ip()
	return ip if ip != "" else Settings.wheel_host


func _send(text: String) -> void:
	var ip := _destination_ip()
	if ip == "":
		return
	if _udp.set_dest_address(ip, WheelProtocol.PORT_PC_TO_WHEEL) != OK:
		return
	_udp.put_packet(text.to_ascii_buffer())
	packets_sent += 1
	last_packet_text = text.strip_edges()
