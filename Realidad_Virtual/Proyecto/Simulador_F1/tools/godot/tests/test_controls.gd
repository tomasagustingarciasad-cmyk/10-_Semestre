extends SceneTree
## Prueba automática de la lógica de interacción con TECLADO (sin ventana).
##
## Simula pulsaciones de teclas reales (eventos de entrada de Godot) sobre el
## nivel Clasificación y verifica toda la cadena:
##   tecla -> KeyboardSource -> InputManager -> auto / sesión / cámaras / pausa
##
## Uso:
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_controls.gd

var _session
var _car
var _stage := 0
var _timer := 0.0
var _failures := 0
var _crashes := 0
var _invalidations := 0
var _max_lateral := 0.0
var _charge_before := 0.0
var _mode_before := 0
var _done := {}
var _max_speed_kmh := 0.0
var _max_gear := 0
var _speed_at_first_crash := 0.0


func _physics_process(delta: float) -> bool:
	_timer += delta
	var input_manager := root.get_node("InputManager")
	match _stage:
		0:
			var settings := root.get_node("Settings")
			settings.input_source = "keyboard"
			settings.auto_gearbox = false
			settings.sel_circuit = "los_aromos"
			settings.sel_weather = "seco"
			settings.sel_compound = "medio"
			input_manager.set_source("keyboard")
			change_scene_to_file("res://scenes/levels/clasificacion.tscn")
			_stage = 1
		1:
			if current_scene != null and current_scene.get("lap_timer") != null:
				_session = current_scene
				_car = _session.car
				_car.crashed.connect(_on_crashed)
				_session.lap_timer.lap_invalidated.connect(func(_reason): _invalidations += 1)
				print("1) Acelerador con caja MANUAL")
				_key(KEY_W, true)
				_next()
		2:
			if _timer > 0.15 and _once("suavizado"):
				_check("el teclado se suaviza (acelerador entre 0 y 1 a los 0,15 s)",
						input_manager.throttle > 0.2 and input_manager.throttle < 0.95)
			if _timer > 5.0:
				_check("acelerador a fondo", is_equal_approx(input_manager.throttle, 1.0))
				_check("caja manual: sigue en 1ª", _car.get_gear() == 1)
				_check("limitador de régimen activo en 1ª a fondo", _car.drivetrain.rev_limiter_active)
				print("   velocidad en el corte de 1ª: %.0f km/h" % _car.speed_kmh)
				_tap(KEY_E)
				_next()
		3:
			if _timer > 0.3:
				_check("tecla E: sube a 2ª", _car.get_gear() == 2)
				_tap(KEY_Q)
				_next()
		4:
			if _timer > 0.3:
				_check("tecla Q a fondo en 2ª: rebaja rechazada (pasaría de vueltas)", _car.get_gear() == 2)
				_key(KEY_W, false)
				print("2) Caja AUTOMÁTICA, recta sin doblar hasta el muro de la curva 1")
				root.get_node("Settings").auto_gearbox = true
				_key(KEY_W, true)
				_next()
		5:
			var offset: float = _session.track.get_closest_offset(_car.global_position)
			_max_lateral = maxf(_max_lateral, absf(_session.track.get_lateral(_car.global_position, offset)))
			_max_speed_kmh = maxf(_max_speed_kmh, _car.speed_kmh)
			_max_gear = maxi(_max_gear, _car.get_gear())
			if _timer > 1.0 and _once("drs"):
				_tap(KEY_F)   # DRS en la recta principal
			if _timer > 3.0 and _once("ayuda_direccion"):
				# Ayuda de dirección: con teclado, el tope de giro es el que el
				# agarre puede usar (menor que el de las fuentes analógicas).
				var settings := root.get_node("Settings")
				var with_assist: float = _car.get_max_steer_angle()
				settings.steer_assist = "off"
				var without_assist: float = _car.get_max_steer_angle()
				settings.steer_assist = "auto"
				print("   a %.0f km/h: giro máximo con ayuda %.1f°, sin ayuda %.1f°" % [
						_car.speed_kmh, rad_to_deg(with_assist), rad_to_deg(without_assist)])
				_check("ayuda de dirección: el teclado limita el giro al agarre disponible",
						with_assist < without_assist * 0.8
						and is_equal_approx(with_assist, _car.get_grip_steer_angle()))
				_check("la ayuda se puede apagar desde Opciones", input_manager.uses_steer_assist())
			if _timer > 2.0 and _once("drs_abierto"):
				_check("tecla F: DRS abierto en zona de DRS", _car.drs.open)
				_charge_before = _car.ers.get_charge()
				_key(KEY_SPACE, true)
			if _timer > 4.0 and _once("ers"):
				_check("tecla Espacio: ERS desplegando", _car.ers.deploying)
				_check("la batería baja al usar ERS", _car.ers.get_charge() < _charge_before)
				_key(KEY_SPACE, false)
			if _timer > 16.0:
				print("   velocidad máxima: %.0f km/h en %dª; velocidad justo antes del primer choque: %.0f km/h; choques: %d; desvío lateral máx: %.1f m" % [
					_max_speed_kmh, _max_gear, _speed_at_first_crash, _crashes, _max_lateral])
				_check("caja automática: subió de marcha sola", _max_gear >= 6)
				_check("vuelta invalidada por límites de pista", _invalidations >= 1)
				_check("choque detectado contra el muro", _crashes >= 1)
				_check("el muro contuvo al auto (no lo atravesó)", _max_lateral < 22.0)
				_key(KEY_W, false)
				print("3) Volver a pista, cámara y pausa")
				_tap(KEY_R)
				_next()
		6:
			if _timer > 0.5:
				var offset: float = _session.track.get_closest_offset(_car.global_position)
				_check("tecla R: auto sobre el eje de la pista", absf(_session.track.get_lateral(_car.global_position, offset)) < 0.5)
				_check("tecla R: auto detenido", _car.speed_kmh < 5.0)
				_mode_before = _session.camera_rig.mode
				_tap(KEY_C)
				_next()
		7:
			if _timer > 0.3:
				_check("tecla C: cambia la cámara", _session.camera_rig.mode != _mode_before)
				_tap(KEY_L)
				_next()
		8:
			if _timer > 0.3:
				_check("tecla L: limitador de boxes activado", _car.pit_limiter_on)
				_tap(KEY_PAGEUP)
				_next()
		9:
			if _timer > 0.3:
				_check("Re Pág (encoder): reparto de frenos +1 %", is_equal_approx(_car.brake_bias, _car.setup.brake_bias + _car.setup.brake_bias_step))
				_tap(KEY_ESCAPE)
				_next()
		10:
			if _timer > 0.3:
				_check("tecla Esc: juego en pausa", paused and _session.pause_menu.visible)
				_tap(KEY_ESCAPE)
				_next()
		11:
			if _timer > 0.3:
				_check("tecla Esc otra vez: vuelve al juego", not paused and not _session.pause_menu.visible)
				print("4) Marcha atrás (caja automática: freno mantenido en parado)")
				_key(KEY_S, true)
				_next()
		12:
			if _timer > 3.0:
				_check("marcha atrás engranada", _car.get_gear() == -1)
				_check("el auto retrocede", _car.speed < -1.0)
				_key(KEY_S, false)
				print("5) Piloto automático: tomar y ceder el control con el teclado")
				_tap(KEY_T)
				_next()
		13:
			if _timer > 0.5:
				_check("tecla T: el piloto automático toma el control", input_manager.is_autopilot_active())
				_tap(KEY_ESCAPE)
				_next()
		14:
			if _timer > 0.3:
				_check("con piloto automático, Esc pausa igual", paused and _session.pause_menu.visible)
				_tap(KEY_ESCAPE)
				_next()
		15:
			if _timer > 0.3:
				_check("con piloto automático, Esc otra vez vuelve al juego", not paused)
				_check("en pausa el piloto automático no se desactivó", input_manager.is_autopilot_active())
				_mode_before = _session.camera_rig.mode
				_tap(KEY_C)
				_next()
		16:
			if _timer > 0.3:
				_check("con piloto automático, C cambia la cámara", _session.camera_rig.mode != _mode_before)
				_tap(KEY_T)
				_next()
		17:
			if _timer > 0.3:
				_check("tecla T otra vez: vuelve el control al teclado", input_manager.get_source_id() == "keyboard")
				_tap(KEY_T)
				_next()
		18:
			if _timer > 0.5:
				_check("tecla T: el piloto automático vuelve a manejar", input_manager.is_autopilot_active())
				_key(KEY_W, true)
				_next()
		19:
			if _timer > 0.5:
				_check("acelerar con W le quita el control al piloto automático",
						input_manager.get_source_id() == "keyboard")
				_key(KEY_W, false)
				print("RESULTADO: %s" % ("TODO OK" if _failures == 0 else "%d FALLAS" % _failures))
				quit(_failures)
	return false


func _on_crashed(_strength: float) -> void:
	if _crashes == 0:
		_speed_at_first_crash = _max_speed_kmh
	_crashes += 1


# Devuelve true solo la primera vez que se la llama con esa clave.
func _once(key: String) -> bool:
	if _done.has(key):
		return false
	_done[key] = true
	return true


func _next() -> void:
	_stage += 1
	_timer = 0.0


# Simula apretar o soltar una tecla física.
func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


# Pulsación corta: aprieta ahora y suelta un instante después.
func _tap(keycode: Key) -> void:
	_key(keycode, true)
	create_timer(0.1, true, true).timeout.connect(func(): _key(keycode, false))


func _check(description: String, condition: bool) -> void:
	print("  [%s] %s" % ["OK" if condition else "FALLA", description])
	if not condition:
		_failures += 1
