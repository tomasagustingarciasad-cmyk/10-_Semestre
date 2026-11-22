class_name WheelProtocol
extends RefCounted
## Definición del protocolo UDP entre el volante (ESP32) y el simulador.
##
## Este archivo es la "fuente de verdad" del protocolo dentro de Godot: puertos,
## mapa de bits y funciones para armar/interpretar los mensajes. La misma
## especificación está explicada en `docs/protocolo.md` y replicada en
## `tools/wheel_protocol.py` para las herramientas en Python.
##
## Mensajes (texto ASCII, un mensaje por línea, terminados en '\n'):
##   Volante -> PC  (puerto 4210, ~100 Hz):
##       W,<steer>,<throttle>,<brake>,<buttons_bitmask>,<encoder_delta>
##   PC -> Volante  (puerto 4211, ~30 Hz):
##       T,<rpm_pct>,<gear>,<flags_bitmask>
##       V,<intensidad>,<duracion_ms>        (evento de vibración)

# --- Puertos y tiempos --------------------------------------------------------
## Puerto UDP donde la PC escucha los paquetes del volante.
const PORT_WHEEL_TO_PC := 4210
## Puerto UDP donde el volante escucha la telemetría de la PC.
const PORT_PC_TO_WHEEL := 4211
## Frecuencia nominal de envío del volante.
const WHEEL_SEND_HZ := 100.0
## Frecuencia de envío de telemetría hacia el volante.
const TELEMETRY_SEND_HZ := 30.0
## Si pasan más de estos milisegundos sin paquetes, el volante se considera
## desconectado.
const TIMEOUT_MS := 500

# --- Escalas de los ejes ------------------------------------------------------
## La dirección viaja como entero en -1000..1000 (negativo = izquierda).
const STEER_SCALE := 1000.0
## Acelerador y freno viajan como entero en 0..1000.
const PEDAL_SCALE := 1000.0

# --- Mapa de bits de botones (campo <buttons_bitmask> del mensaje W) --------
const BTN_SHIFT_UP := 1 << 0      ## Leva derecha: subir marcha
const BTN_SHIFT_DOWN := 1 << 1    ## Leva izquierda: bajar marcha
const BTN_DRS := 1 << 2           ## Botón DRS
const BTN_ERS := 1 << 3           ## Botón ERS (se mantiene apretado)
const BTN_PIT_LIMITER := 1 << 4   ## Limitador de boxes
const BTN_RESET := 1 << 5         ## Volver a pista
const BTN_CAMERA := 1 << 6        ## Cambiar de cámara
const BTN_PAUSE := 1 << 7         ## Pausa / menú (pulsador del encoder)

## Relación bit -> nombre de acción del InputManager.
const BUTTON_ACTIONS := {
	BTN_SHIFT_UP: &"shift_up",
	BTN_SHIFT_DOWN: &"shift_down",
	BTN_DRS: &"drs",
	BTN_ERS: &"ers",
	BTN_PIT_LIMITER: &"pit_limiter",
	BTN_RESET: &"reset",
	BTN_CAMERA: &"camera_next",
	BTN_PAUSE: &"pause",
}

# --- Mapa de bits de estado (campo <flags_bitmask> del mensaje T) -----------
const FLAG_DRS_AVAILABLE := 1 << 0   ## El auto está en zona de DRS
const FLAG_DRS_OPEN := 1 << 1        ## Alerón abierto
const FLAG_PIT_LIMITER := 1 << 2     ## Limitador de boxes activo
const FLAG_ERS_DEPLOY := 1 << 3      ## Se está usando la batería
const FLAG_REV_LIMIT := 1 << 4       ## Motor en el limitador (cambiar ya)
const FLAG_IN_PIT_LANE := 1 << 5     ## El auto está dentro del pit lane
const FLAG_LAP_INVALID := 1 << 6     ## La vuelta actual fue invalidada
const FLAG_AQUAPLANING := 1 << 7     ## Alguna rueda está aquaplaneando (agregado en la Fase 1b)

# --- Valores especiales de <gear> ---------------------------------------------
const GEAR_REVERSE := -1
const GEAR_NEUTRAL := 0

# --- Shift lights -------------------------------------------------------------
## Cantidad de LEDs de la tira (igual en el HUD y en el volante físico).
const SHIFT_LED_COUNT := 10
## Porcentaje de RPM al que se enciende el primer LED.
const SHIFT_LED_START_PCT := 62.0
## Porcentaje de RPM al que quedan todos encendidos.
const SHIFT_LED_FULL_PCT := 94.0
## Desde este porcentaje toda la tira parpadea ("cambiá ya").
const SHIFT_LED_FLASH_PCT := 97.0
## Cantidad de LEDs verdes y rojos (el resto son azules).
const SHIFT_LED_GREEN := 4
const SHIFT_LED_RED := 3

# --- Vibración ----------------------------------------------------------------
const VIBRATION_MAX := 255


## Interpreta una línea "W,..." enviada por el volante.
## Devuelve un Dictionary vacío si la línea no es válida.
static func parse_wheel_packet(line: String) -> Dictionary:
	var parts := line.strip_edges().split(",")
	if parts.size() != 6 or parts[0] != "W":
		return {}
	for i in range(1, 6):
		if not parts[i].is_valid_int():
			return {}
	return {
		"steer": clampi(parts[1].to_int(), -int(STEER_SCALE), int(STEER_SCALE)),
		"throttle": clampi(parts[2].to_int(), 0, int(PEDAL_SCALE)),
		"brake": clampi(parts[3].to_int(), 0, int(PEDAL_SCALE)),
		"buttons": parts[4].to_int(),
		"encoder": parts[5].to_int(),
	}


## Arma el mensaje de telemetría "T,<rpm_pct>,<gear>,<flags>\n".
static func format_telemetry(rpm_pct: int, gear: int, flags: int) -> String:
	return "T,%d,%d,%d\n" % [clampi(rpm_pct, 0, 100), gear, flags]


## Arma el mensaje de vibración "V,<intensidad>,<duracion_ms>\n".
static func format_vibration(intensity: int, duration_ms: int) -> String:
	return "V,%d,%d\n" % [clampi(intensity, 0, VIBRATION_MAX), maxi(duration_ms, 0)]


## Cantidad de LEDs encendidos para un porcentaje de RPM dado.
## Es la misma fórmula que debe implementar el firmware del volante.
static func leds_for_rpm(rpm_pct: float) -> int:
	if rpm_pct < SHIFT_LED_START_PCT:
		return 0
	var span := SHIFT_LED_FULL_PCT - SHIFT_LED_START_PCT
	var lit := int(floor((rpm_pct - SHIFT_LED_START_PCT) / span * SHIFT_LED_COUNT)) + 1
	return clampi(lit, 0, SHIFT_LED_COUNT)


## Color del LED número `index` (0 = el primero en encenderse).
static func led_color(index: int) -> Color:
	if index < SHIFT_LED_GREEN:
		return Color(0.15, 0.9, 0.25)
	if index < SHIFT_LED_GREEN + SHIFT_LED_RED:
		return Color(0.95, 0.15, 0.15)
	return Color(0.35, 0.45, 1.0)
