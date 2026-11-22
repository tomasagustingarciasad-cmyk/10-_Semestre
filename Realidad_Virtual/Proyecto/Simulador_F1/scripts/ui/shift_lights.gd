class_name ShiftLights
extends Control
## Shift lights virtuales: la tira de LEDs que indica cuándo cambiar de marcha.
##
## Es la versión en pantalla de la tira WS2812 del volante físico. Ambas usan
## exactamente la misma regla (WheelProtocol.leds_for_rpm / led_color), así
## que lo que se ve acá es lo que debe mostrar el firmware a partir del
## campo <rpm_pct> de la telemetría.

const LED_GAP := 6.0
const COLOR_LED_OFF := Color(1.0, 1.0, 1.0, 0.12)
# Frecuencia del parpadeo al llegar al régimen de cambio [Hz].
const FLASH_HZ := 9.0

## Porcentaje de RPM (0..100).
var rpm_pct: float = 0.0:
	set(value):
		rpm_pct = value
		queue_redraw()


func _process(_delta: float) -> void:
	# Mientras parpadea hay que redibujar todos los frames.
	if rpm_pct >= WheelProtocol.SHIFT_LED_FLASH_PCT:
		queue_redraw()


func _draw() -> void:
	var count := WheelProtocol.SHIFT_LED_COUNT
	var lit := WheelProtocol.leds_for_rpm(rpm_pct)
	var flashing := rpm_pct >= WheelProtocol.SHIFT_LED_FLASH_PCT
	var flash_on := fmod(Time.get_ticks_msec() / 1000.0 * FLASH_HZ, 1.0) < 0.5

	var slot_width := (size.x - LED_GAP * (count - 1)) / count
	var radius := minf(slot_width, size.y) * 0.5
	for i in count:
		var center := Vector2(slot_width * 0.5 + i * (slot_width + LED_GAP), size.y * 0.5)
		var color := COLOR_LED_OFF
		if flashing:
			# Toda la tira parpadea en azul: "cambiá ya".
			color = WheelProtocol.led_color(count - 1) if flash_on else COLOR_LED_OFF
		elif i < lit:
			color = WheelProtocol.led_color(i)
		draw_circle(center, radius, color)
