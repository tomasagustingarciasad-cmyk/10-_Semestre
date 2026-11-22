extends SceneTree
## Prueba automática de UN circuito con el piloto automático (sin ventana).
##
## Carga el nivel Clasificación en el circuito y clima pedidos, y da una
## vuelta cronometrada completa con el piloto automático. Verifica que:
##   - la longitud del eje coincida con la oficial (±1 %);
##   - se cuenten los 3 sectores y la vuelta, y la vuelta sea válida;
##   - el auto no se quede trabado, no choque y no se salga con las 4 ruedas.
## Imprime una línea "FILA;..." que junta tools/godot/tests/run_circuits.py
## para armar la tabla de docs/resultados_circuitos.md.
##
## Uso:
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_circuit.gd -- monaco lluvia

const MAX_TIME := 420.0
const LENGTH_TOLERANCE := 0.01
const STUCK_SPEED := 2.0
const STUCK_TIME := 5.0
const START_GRACE := 6.0
## Neumático con el que sale según el clima.
const COMPOUNDS := {"seco": "medio", "lluvia": "lluvia"}

var _circuit := "los_aromos"
var _weather := "seco"
var _stage := 0
var _time := 0.0
var _session
var _load_start_ms := 0
var _load_ms := 0
var _off_track := 0.0
var _stuck := 0.0
var _max_stuck := 0.0
var _crashes := 0
var _max_speed := 0.0
var _sectors := 0
var _lap_time := 0.0
var _lap_valid := false
var _lap_done := false
var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() >= 1:
		_circuit = arguments[0]
	if arguments.size() >= 2:
		_weather = arguments[1]


func _physics_process(delta: float) -> bool:
	match _stage:
		0:
			var settings := root.get_node("Settings")
			settings.input_source = "autopilot"
			settings.auto_gearbox = true
			settings.sel_circuit = _circuit
			settings.sel_weather = _weather
			settings.sel_compound = COMPOUNDS.get(_weather, "medio")
			root.get_node("InputManager").set_source("autopilot")
			_load_start_ms = Time.get_ticks_msec()
			change_scene_to_file("res://scenes/levels/clasificacion.tscn")
			_stage = 1
		1:
			if current_scene != null and current_scene.get("lap_timer") != null:
				_session = current_scene
				_load_ms = Time.get_ticks_msec() - _load_start_ms
				# No se guardan récords ni fantasmas de las pruebas.
				_session.lap_timer.sector_completed.connect(func(_index, _sector_time, _best): _sectors += 1)
				_session.lap_timer.lap_completed.connect(_on_lap_completed)
				_session.car.crashed.connect(func(_strength): _crashes += 1)
				_stage = 2
		2:
			_time += delta
			var car = _session.car
			_max_speed = maxf(_max_speed, car.speed_kmh)
			if _session.lap_timer.lap_number > 0 and car.wheels_off_track >= 4:
				_off_track += delta
			if _time > START_GRACE and absf(car.speed) < STUCK_SPEED:
				_stuck += delta
				_max_stuck = maxf(_max_stuck, _stuck)
			else:
				_stuck = 0.0
			if _lap_done or _time > MAX_TIME or _max_stuck > STUCK_TIME:
				_finish()
	return false


func _on_lap_completed(lap_time: float, valid: bool, _is_best: bool) -> void:
	_lap_time = lap_time
	_lap_valid = valid
	_lap_done = true


func _finish() -> void:
	var track = _session.track
	var length_error: float = (track.length - track.official_length) / track.official_length
	if absf(length_error) > LENGTH_TOLERANCE:
		_failures.append("longitud")
	if not _lap_done:
		_failures.append("trabado" if _max_stuck > STUCK_TIME else "no completó la vuelta")
	else:
		if _sectors != 3:
			_failures.append("sectores=%d" % _sectors)
		if not _lap_valid:
			_failures.append("vuelta inválida")
	if _off_track > 0.0:
		_failures.append("fuera de pista %.1f s" % _off_track)
	if _crashes > 0:
		_failures.append("choques=%d" % _crashes)
	var status := "OK" if _failures.is_empty() else ", ".join(_failures)
	print("FILA;%s;%s;%s;%.1f;%.0f;%+.2f;%.3f;%d;%s;%.1f;%d;%.0f;%d;%s" % [
		_circuit, track.display_name, _weather, track.length, track.official_length,
		length_error * 100.0, _lap_time, _sectors, "sí" if _lap_valid else "no",
		_off_track, _crashes, _max_speed, _load_ms, status])
	print("RESULTADO: %s" % ("TODO OK" if _failures.is_empty() else status))
	quit(0 if _failures.is_empty() else 1)
