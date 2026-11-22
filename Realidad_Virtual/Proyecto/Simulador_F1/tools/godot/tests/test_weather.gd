extends SceneTree
## Prueba automática del CLIMA elegible por nivel (sin ventana).
##
## Carga los dos niveles con cada clima y verifica que el nodo Clima configure
## todo al iniciar: modo, agua en pista, lluvia, niebla, asfalto mojado,
## neumático de los rivales y archivo del fantasma (uno por circuito y clima).
## Al final prueba el clima Variable: el agua tiene que cambiar con el tiempo.
##
## Uso:
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_weather.gd

const CIRCUIT := "monaco"
const RAIN_WATER := 0.7
const SETTLE_TIME := 0.5
const VARIABLE_TIME := 150.0
## nivel, clima, compuesto esperado en los rivales ("" = no hay rivales).
const CASES := [
	["clasificacion", "seco", ""],
	["clasificacion", "lluvia", ""],
	["carrera", "seco", "medio"],
	["carrera", "lluvia", "lluvia"],
	["carrera", "variable", ""],
]

var _case := 0
var _stage := 0
var _timer := 0.0
var _failures := 0
var _session
var _initial_water := 0.0


func _physics_process(delta: float) -> bool:
	_timer += delta
	var row: Array = CASES[_case]
	match _stage:
		0:
			var settings := root.get_node("Settings")
			settings.input_source = "keyboard"
			settings.sel_circuit = CIRCUIT
			settings.sel_weather = row[1]
			settings.sel_compound = "medio"
			settings.race_laps = 3
			root.get_node("InputManager").set_source("keyboard")
			change_scene_to_file("res://scenes/levels/%s.tscn" % row[0])
			_session = null
			_stage = 1
		1:
			if current_scene != null and current_scene.get("lap_timer") != null and current_scene != _session:
				_session = current_scene
				_timer = 0.0
				_stage = 2
		2:
			if _timer > SETTLE_TIME:
				_check_case(row)
				if row[1] == "variable":
					_initial_water = _session.weather.water_level
					_timer = 0.0
					_stage = 3
				else:
					_advance()
		3:
			# Variable: se fuerza el reloj del clima para no esperar la largada.
			_session.weather.clock_running = true
			_session.weather._expected_duration = VARIABLE_TIME
			if _timer > VARIABLE_TIME:
				var weather = _session.weather
				print("   agua: %.2f -> %.2f" % [_initial_water, weather.water_level])
				_check("variable: el agua en pista cambió", absf(weather.water_level - _initial_water) > 0.3)
				_check("variable: la pista sigue el agua", is_equal_approx(_session.track.wetness, weather.water_level)
						or absf(_session.track.wetness - weather.water_level) < 0.06)
				_advance()
	return false


func _check_case(row: Array) -> void:
	var weather = _session.weather
	var wet: bool = row[1] == "lluvia"
	print("%s con clima %s en %s" % [row[0], row[1], _session.track.display_name])
	_check("circuito cargado: " + CIRCUIT, _session.track.circuit_id == CIRCUIT)
	_check("modo de clima", weather.get_mode_id() == row[1])
	if row[1] == "variable":
		_check("variable: empieza seco o con lluvia", is_zero_approx(weather.water_level)
				or is_equal_approx(weather.water_level, RAIN_WATER))
		return
	_check("agua en pista", is_equal_approx(weather.water_level, RAIN_WATER if wet else 0.0))
	_check("partículas de lluvia", weather.get_node("Lluvia").emitting == wet)
	_check("niebla", _session.get_node("Ambiente").environment.fog_enabled == wet)
	_check("asfalto mojado", is_equal_approx(_session.track.wetness, weather.water_level))
	_check("agarre del auto según el clima",
			is_equal_approx(_session.car.compound.get_grip(weather.water_level), 0.55 if wet else 1.0))
	if row[0] == "clasificacion":
		_check("fantasma por circuito y clima",
				_session._ghost_file == "user://fantasmas/%s_%s.dat" % [CIRCUIT, row[1]])
	if row[2] != "":
		var rivals: Array = _session.rivals
		_check("hay rivales", rivals.size() > 0)
		for rival in rivals:
			if rival.compound.id != row[2]:
				_check("neumático de %s" % rival.driver_name, false)
				return
		_check("los rivales eligen %s" % row[2], true)


func _advance() -> void:
	_case += 1
	_stage = 0
	if _case >= CASES.size():
		print("RESULTADO: %s" % ("TODO OK" if _failures == 0 else "%d FALLAS" % _failures))
		quit(_failures)


func _check(description: String, condition: bool) -> void:
	print("  [%s] %s" % ["OK" if condition else "FALLA", description])
	if not condition:
		_failures += 1
