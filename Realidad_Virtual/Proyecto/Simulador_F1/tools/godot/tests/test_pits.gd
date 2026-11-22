extends SceneTree
## Prueba automática de las reglas de boxes (sin ventana).
##
## Sobre el nivel Carrera real:
##   1. coloca el auto dentro del pit lane por encima del límite de velocidad
##      y verifica que se aplique la penalización;
##   2. lo detiene dentro del box y verifica el cambio de neumáticos;
##   3. verifica que el limitador de boxes mantenga la velocidad máxima.
##
## Uso:
##   4. durante la parada, elige otro compuesto con la leva y verifica el cambio.
##
## Uso (el circuito es opcional):
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_pits.gd -- monaco

var _session
var _stage := 0
var _timer := 0.0
var _failures := 0
var _service_checked := false
var _limited_max_speed := 0.0
var _circuit := "los_aromos"


func _initialize() -> void:
	# Opcional: id del circuito (por defecto, Los Aromos).
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_circuit = arguments[0]


func _physics_process(delta: float) -> bool:
	_timer += delta
	match _stage:
		0:
			root.get_node("Settings").input_source = "keyboard"
			root.get_node("Settings").race_laps = 3
			root.get_node("Settings").sel_circuit = _circuit
			root.get_node("Settings").sel_weather = "lluvia"
			root.get_node("Settings").sel_compound = "intermedio"
			root.get_node("InputManager").set_source("keyboard")
			change_scene_to_file("res://scenes/levels/carrera.tscn")
			_stage = 1
		1:
			if current_scene != null and current_scene.get("lap_timer") != null:
				_session = current_scene
				_stage = 2
		2:
			# Espera a que termine la largada.
			if _session.phase == 2:
				print("Largada completada a los %.1f s" % _timer)
				# --- 1. Exceso de velocidad en el pit lane ---
				var track = _session.track
				var inside: Transform3D = track.get_pit_transform_at(track.pit_limit_start + 20.0, -2.0, 0.25)
				_session.car.teleport(inside, 40.0)
				_timer = 0.0
				_stage = 3
		3:
			if _timer > 0.5:
				_check("auto detectado dentro del pit lane", _session.car.in_pit_lane)
				_check("penalización por exceso de velocidad (+5 s)", is_equal_approx(_session.penalty_seconds, 5.0))
				# --- 2. Parada en el box ---
				_session.car.tyres.wear = [0.5, 0.5, 0.5, 0.5] as Array[float]
				_session.car.teleport(_session.track.get_pit_box_transform(0, 0.25), 0.0)
				_timer = 0.0
				_stage = 4
		4:
			if _timer > 1.0 and not _service_checked:
				_service_checked = true
				_check("servicio en curso al detenerse en el box", _session.servicing)
				_check("auto frenado durante el servicio", not _session.car.controls_enabled)
				_check("compuesto propuesto: el que está montado", _session.pit_choice.id == "intermedio")
				# La leva derecha pasa al compuesto siguiente (intermedio -> lluvia).
				root.get_node("InputManager").shift_up_pressed.emit()
				_check("la leva cambia el compuesto elegido", _session.pit_choice.id == "lluvia")
			if _timer > 4.5:
				_check("parada contabilizada", _session.pit_stops == 1)
				_check("neumáticos nuevos", _session.car.tyres.get_average_wear() < 0.01)
				_check("compuesto cambiado en la parada (lluvia extrema)", _session.car.compound.id == "lluvia")
				_check("controles devueltos al piloto", _session.car.controls_enabled)
				# --- 3. Limitador ---
				var track = _session.track
				_session.car.teleport(track.get_pit_transform_at(track.pit_limit_start + 5.0, -2.0, 0.25), 15.0)
				_session.car.pit_limiter_on = true
				# Simula acelerador a fondo escribiendo en la fuente activa.
				_timer = 0.0
				_stage = 5
		5:
			# Mantiene el acelerador a fondo a través del InputManager.
			root.get_node("InputManager").get_source("keyboard").raw_throttle = 1.0
			root.get_node("InputManager").throttle = 1.0
			# Se mide mientras el auto sigue dentro de la zona con límite (en
			# los circuitos con pit lane corto sale antes de los 6 s).
			if _session.car.in_pit_lane:
				_limited_max_speed = maxf(_limited_max_speed, _session.car.speed)
			if _timer > 6.0 or (_timer > 1.0 and not _session.car.in_pit_lane):
				var limit: float = _session.get_pit_speed_limit()
				print("velocidad máxima con limitador: %.1f km/h (límite %.1f)" % [_limited_max_speed * 3.6, limit * 3.6])
				_check("el limitador mantiene la velocidad",
						_limited_max_speed < limit + 1.0 and _limited_max_speed > limit - 3.0)
				_check("sin nueva penalización con limitador", is_equal_approx(_session.penalty_seconds, 5.0))
				print("RESULTADO: %s" % ("TODO OK" if _failures == 0 else "%d FALLAS" % _failures))
				quit(_failures)
	return false


func _check(description: String, condition: bool) -> void:
	print("  [%s] %s" % ["OK" if condition else "FALLA", description])
	if not condition:
		_failures += 1
