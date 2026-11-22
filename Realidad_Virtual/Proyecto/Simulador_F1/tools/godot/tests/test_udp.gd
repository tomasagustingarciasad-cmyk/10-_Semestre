extends SceneTree
## Prueba automática de la cadena UDP (sin ventana).
##
## Arranca el nivel Clasificación con la fuente "Volante UDP" y verifica que:
##   1. lleguen paquetes W y el InputManager refleje dirección y acelerador;
##   2. el auto se mueva con esos datos (cadena completa hasta la física);
##   3. se envíe telemetría (T) de vuelta;
##   4. al cortarse el volante, el timeout de 500 ms lo marque desconectado.
##
## Hay que ejecutar en paralelo el volante simulado:
##   python tools/fake_wheel.py --auto --duration 8 --auto-throttle 0.6
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_udp.gd
##
## (Este script NO usa --fixed-fps acelerado: necesita tiempo real para la red.)

const RUN_SECONDS := 14.0

var _stage := 0
var _start_ms := 0
var _failures := 0
var _max_steer := 0.0
var _min_steer := 0.0
var _max_throttle := 0.0
var _connected_seen := false
var _disconnected_after := false
var _camera_events := 0
var _session
var _last_report := 0.0


func _physics_process(_delta: float) -> bool:
	var elapsed := (Time.get_ticks_msec() - _start_ms) / 1000.0
	var input_manager := root.get_node("InputManager")
	match _stage:
		0:
			_start_ms = Time.get_ticks_msec()
			root.get_node("Settings").input_source = "udp_wheel"
			root.get_node("Settings").auto_gearbox = true
			root.get_node("Settings").sel_circuit = "los_aromos"
			root.get_node("Settings").sel_weather = "seco"
			root.get_node("Settings").sel_compound = "medio"
			input_manager.set_source("udp_wheel")
			input_manager.camera_next_pressed.connect(func(): _camera_events += 1)
			change_scene_to_file("res://scenes/levels/clasificacion.tscn")
			_stage = 1
		1:
			if current_scene != null and current_scene.get("lap_timer") != null:
				_session = current_scene
				_stage = 2
		2:
			if input_manager.is_device_connected():
				_connected_seen = true
				_max_steer = maxf(_max_steer, input_manager.steer)
				_min_steer = minf(_min_steer, input_manager.steer)
				_max_throttle = maxf(_max_throttle, input_manager.throttle)
			elif _connected_seen:
				_disconnected_after = true
			if elapsed - _last_report >= 2.0:
				_last_report = elapsed
				print("[%4.1f s] %s | steer=%+.2f throttle=%.2f | v=%.0f km/h | telemetría enviada: %d (%s)" % [
					elapsed, input_manager.get_status_text(), input_manager.steer, input_manager.throttle,
					_session.car.speed_kmh, root.get_node("TelemetryOut").packets_sent,
					root.get_node("TelemetryOut").last_packet_text])
			if elapsed >= RUN_SECONDS:
				var wheel = input_manager.get_source("udp_wheel")
				print("paquetes W recibidos: %d (inválidos: %d)" % [wheel.packets_received, wheel.packets_invalid])
				_check("se recibieron paquetes del volante", wheel.packets_received > 100)
				_check("la dirección recorrió ambos lados", _max_steer > 0.3 and _min_steer < -0.3)
				_check("el acelerador llegó al InputManager", _max_throttle > 0.4)
				_check("se detectaron pulsaciones de botón (cámara)", _camera_events >= 1)
				_check("el auto se movió con esas entradas", _session.track.get_closest_offset(_session.car.global_position) != 0.0 and _session.lap_timer.session_time > 1.0)
				_check("se envió telemetría al volante", root.get_node("TelemetryOut").packets_sent > 50)
				_check("timeout: desconectado al cortar el volante", _disconnected_after and not input_manager.is_device_connected())
				_check("entradas en cero tras la desconexión", is_zero_approx(input_manager.throttle))
				print("RESULTADO: %s" % ("TODO OK" if _failures == 0 else "%d FALLAS" % _failures))
				quit(_failures)
	return false


func _check(description: String, condition: bool) -> void:
	print("  [%s] %s" % ["OK" if condition else "FALLA", description])
	if not condition:
		_failures += 1
