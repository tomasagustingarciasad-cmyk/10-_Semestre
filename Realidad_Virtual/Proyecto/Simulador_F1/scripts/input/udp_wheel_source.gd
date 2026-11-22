class_name UdpWheelSource
extends InputSource
## Fuente de entrada: volante casero (ESP32) por UDP.
##
## Escucha en el puerto WheelProtocol.PORT_WHEEL_TO_PC los mensajes
## "W,<steer>,<throttle>,<brake>,<buttons>,<encoder_delta>". Aplica la
## calibración guardada (tope izquierdo / centro / tope derecho) y detecta la
## desconexión por timeout. No sabe nada del juego: solo traduce paquetes.
##
## Sirve igual para el volante real, para `tools/fake_wheel.py` y para el
## puente serie `tools/serial_bridge.py`, porque los tres hablan el mismo
## protocolo.

var _udp := PacketPeerUDP.new()
var _listening := false
var _bind_error := false

# Marca de tiempo (ms) del último paquete válido; -1 = nunca llegó ninguno.
var _last_packet_ms: int = -1
# IP desde la que llegó el último paquete (a ella se le envía la telemetría).
var _last_sender_ip: String = ""
# Bits de botones del último paquete (para detectar flancos).
var _last_buttons: int = 0

## Valor crudo de dirección del último paquete (-1000..1000). Lo usa la
## pantalla de calibración.
var raw_steer_units: int = 0
## Cantidad total de paquetes válidos recibidos (diagnóstico).
var packets_received: int = 0
## Paquetes descartados por formato inválido (diagnóstico).
var packets_invalid: int = 0


func get_id() -> String:
	return Settings.SOURCE_UDP_WHEEL


func get_label() -> String:
	return "Volante UDP"


func is_analog() -> bool:
	return true


func is_available() -> bool:
	if not _listening or _last_packet_ms < 0:
		return false
	return Time.get_ticks_msec() - _last_packet_ms <= WheelProtocol.TIMEOUT_MS


func get_status_text() -> String:
	if _bind_error:
		return "Puerto %d ocupado" % WheelProtocol.PORT_WHEEL_TO_PC
	if is_available():
		return "Conectado (%s)" % _last_sender_ip
	if _last_packet_ms < 0:
		return "Esperando volante..."
	return "Sin señal"


## IP del volante (vacía si todavía no llegó ningún paquete).
func get_sender_ip() -> String:
	return _last_sender_ip


func start() -> void:
	if _listening:
		return
	var err := _udp.bind(WheelProtocol.PORT_WHEEL_TO_PC)
	_bind_error = err != OK
	_listening = err == OK
	if _bind_error:
		push_warning("UdpWheelSource: no se pudo abrir el puerto UDP %d (error %d)"
				% [WheelProtocol.PORT_WHEEL_TO_PC, err])


func stop() -> void:
	if _listening:
		_udp.close()
	_listening = false
	_last_packet_ms = -1
	_last_buttons = 0
	super.stop()


func update(_delta: float) -> void:
	if not _listening:
		return
	# Se procesan todos los paquetes pendientes; el último define los ejes.
	while _udp.get_available_packet_count() > 0:
		var data := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		# Un datagrama puede traer más de una línea.
		for line in data.get_string_from_ascii().split("\n", false):
			_handle_line(line, ip)

	# Timeout: si el volante dejó de transmitir se sueltan ejes y botones para
	# que el auto no quede acelerando solo.
	if _last_packet_ms >= 0 and not is_available():
		raw_steer = 0.0
		raw_throttle = 0.0
		raw_brake = 0.0
		for action: StringName in WheelProtocol.BUTTON_ACTIONS.values():
			_held[action] = false
		_last_buttons = 0


# Interpreta una línea del protocolo y actualiza el estado.
func _handle_line(line: String, ip: String) -> void:
	var packet := WheelProtocol.parse_wheel_packet(line)
	if packet.is_empty():
		packets_invalid += 1
		return
	packets_received += 1
	_last_packet_ms = Time.get_ticks_msec()
	_last_sender_ip = ip

	raw_steer_units = packet["steer"]
	raw_steer = _calibrated_steer(raw_steer_units)
	raw_throttle = float(packet["throttle"]) / WheelProtocol.PEDAL_SCALE
	raw_brake = float(packet["brake"]) / WheelProtocol.PEDAL_SCALE

	var buttons: int = packet["buttons"]
	for bit: int in WheelProtocol.BUTTON_ACTIONS:
		_set_button(WheelProtocol.BUTTON_ACTIONS[bit], (buttons & bit) != 0)
	_last_buttons = buttons

	_encoder_steps += int(packet["encoder"])


# Convierte el valor crudo (-1000..1000) a -1..1 usando la calibración:
# se interpola por separado a cada lado del centro, de modo que un centro
# corrido o topes asimétricos queden corregidos.
func _calibrated_steer(units: int) -> float:
	var left := float(Settings.cal_steer_left)
	var center := float(Settings.cal_steer_center)
	var right := float(Settings.cal_steer_right)
	var value := float(units)
	if value >= center:
		var span := right - center
		if absf(span) < 1.0:
			return 0.0
		return clampf((value - center) / span, 0.0, 1.0)
	var span_left := center - left
	if absf(span_left) < 1.0:
		return 0.0
	return clampf((value - center) / span_left, -1.0, 0.0)
