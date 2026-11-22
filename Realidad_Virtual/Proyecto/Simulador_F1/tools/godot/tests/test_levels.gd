extends SceneTree
## Prueba automática de un nivel completo (sin ventana).
##
## Carga la escena real del nivel, pone al piloto automático como fuente del
## InputManager y deja correr la simulación. Imprime lo que informan el
## cronómetro y la sesión, y al final la tabla de resultados.
##
## Uso (todos los parámetros son opcionales, con la forma clave=valor):
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_levels.gd -- nivel=clasificacion segundos=140
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_levels.gd -- nivel=carrera circuito=monaco clima=lluvia neumatico=lluvia vueltas=3 segundos=400
## Parámetros: nivel (clasificacion|carrera), circuito, clima (seco|lluvia|variable),
## neumatico, vueltas, segundos, ritmo (del piloto automático).

const REPORT_INTERVAL := 10.0

# Sin tipos estáticos de clases del juego: este script se compila antes de
# que existan los autoloads.
var _session
var _level := "clasificacion"
var _duration := 140.0
var _time := 0.0
var _next_report := 0.0
var _stage := 0
var _finished_reported := false
var _options := {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=")
		if parts.size() == 2:
			_options[parts[0]] = parts[1]
	_level = _options.get("nivel", _level)
	_duration = float(_options.get("segundos", _duration))


func _physics_process(delta: float) -> bool:
	match _stage:
		0:
			# Configuración en memoria (no se guarda en disco).
			var settings := root.get_node("Settings")
			settings.input_source = "autopilot"
			settings.auto_gearbox = true
			settings.sel_circuit = _options.get("circuito", "los_aromos")
			settings.sel_weather = _options.get("clima", "seco")
			settings.sel_compound = _options.get("neumatico", "medio")
			if _options.has("vueltas"):
				settings.race_laps = int(_options["vueltas"])
			var input_manager := root.get_node("InputManager")
			input_manager.set_source("autopilot")
			if _options.has("ritmo"):
				input_manager.get_source("autopilot").pace = float(_options["ritmo"])
			var path := "res://scenes/levels/%s.tscn" % _level
			print("Cargando %s (%s, %s, %s)" % [path, settings.sel_circuit, settings.sel_weather, settings.sel_compound])
			change_scene_to_file(path)
			_stage = 1
		1:
			if current_scene != null and current_scene.get("lap_timer") != null:
				_session = current_scene
				_connect_signals()
				_stage = 2
		2:
			_time += delta
			_report()
			if _session.finished and not _finished_reported:
				_finished_reported = true
				_print_results()
				quit()
			elif _time >= _duration:
				print("--- tiempo de prueba cumplido: se termina la sesión ---")
				_session.finish_session()
				_print_results()
				quit()
	return false


func _connect_signals() -> void:
	var timer = _session.lap_timer
	timer.lap_started.connect(func(n): print("[%6.1f] empieza la vuelta %d" % [_time, n]))
	timer.sector_completed.connect(func(i, t, best): print("[%6.1f]   sector %d: %.3f (mejor previo %.3f)" % [_time, i + 1, t, best]))
	timer.lap_completed.connect(func(t, valid, is_best): print("[%6.1f] VUELTA %.3f válida=%s mejor=%s" % [_time, t, valid, is_best]))
	timer.lap_invalidated.connect(func(reason): print("[%6.1f] vuelta invalidada: %s" % [_time, reason]))


func _report() -> void:
	if _time < _next_report:
		return
	_next_report += REPORT_INTERVAL
	var car = _session.car
	var line := "[%6.1f] v=%5.1f km/h marcha=%s s=%6.0f %s desgaste=%4.1f%% agua=%.2f aqua=%.2f delta=%s" % [
		_time, car.speed_kmh, car.get_gear_text(), _session.car_offset, car.compound.letter,
		car.tyres.get_average_wear() * 100.0, _session.weather.water_level, car.aquaplaning_factor,
		("%+.3f" % _session.lap_timer.delta) if _session.lap_timer.has_delta else "n/d"]
	if _session.get("rivals") != null:
		line += " fase=%d pos=%d/%d dist=%.0f" % [_session.phase, _session.player_position, _session.car_count, _session.player_distance]
		for rival in _session.rivals:
			line += " | %s%s d=%.0f v=%.0f e%d" % [rival.driver_name.substr(6, 3), rival.compound.letter, rival.total_distance, rival.speed * 3.6, rival.state]
	print(line)


func _print_results() -> void:
	var results: Dictionary = _session._build_results()
	print("=== ", results.get("title", ""), " ===")
	print("  ", " | ".join(PackedStringArray(results.get("headers", []))))
	for row in results.get("rows", []):
		print("  ", " | ".join(PackedStringArray(row)))
	print("  ", results.get("footer", ""))
