extends SceneTree
## Prueba automática de conducción (sin ventana).
##
## Carga el circuito y el auto, activa el piloto automático como fuente del
## InputManager y simula varias vueltas a máxima velocidad de cálculo.
## Informa telemetría periódica y el tiempo de cada vuelta.
##
## Uso:
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_drive.gd -- [circuito] [segundos] [ritmo]

const REPORT_INTERVAL := 20.0

# Sin tipos estáticos a propósito: este script se compila antes de que existan
# los autoloads, y los scripts del juego dependen de ellos.
var _car
var _track
var _time := 0.0
var _next_report := 0.0
var _duration := 150.0
var _last_offset := 0.0
var _lap_start := -1.0
var _laps := 0
var _max_speed := 0.0
var _off_track_time := 0.0
var _started := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var circuit := "los_aromos"
	if args.size() >= 1:
		circuit = args[0]
	if args.size() >= 2:
		_duration = args[1].to_float()
	_track = (load("res://scenes/track/circuitos/%s.tscn" % circuit) as PackedScene).instantiate()
	root.add_child(_track)
	_car = (load("res://scenes/car/f1_car.tscn") as PackedScene).instantiate()
	root.add_child(_car)


func _physics_process(delta: float) -> bool:
	if not _started:
		# Primer tick: el árbol ya está listo (autoloads incluidos).
		_started = true
		var input_manager := root.get_node("InputManager")
		var settings := root.get_node("Settings")
		root.get_node("GameState").in_menu = false
		settings.auto_gearbox = true
		input_manager.set_source("autopilot")
		input_manager.set_autopilot_target(_car, _track)
		var args := OS.get_cmdline_user_args()
		if args.size() >= 3:
			input_manager.get_source("autopilot").pace = args[2].to_float()
		_car.track = _track
		_car.teleport(_track.get_transform_at(_track.length - 60.0, 0.0, 0.2))
		_last_offset = _track.get_closest_offset(_car.global_position)
		print("circuito: %.1f m" % _track.length)
		return false

	_time += delta
	# Las zonas de DRS se consultan como lo hace la sesión real.
	var in_drs := false
	for zone in get_nodes_in_group(&"zona_drs"):
		if zone.overlaps_body(_car):
			in_drs = true
	_car.drs.in_zone = in_drs

	var offset: float = _track.get_offset_near(_car.global_position, _last_offset)
	_max_speed = maxf(_max_speed, _car.speed_kmh)
	if _car.wheels_off_track >= 4:
		_off_track_time += delta
	# Paso por la línea de llegada: el offset vuelve a cero.
	if offset < _last_offset - _track.length * 0.5:
		if _lap_start >= 0.0:
			_laps += 1
			print(">>> VUELTA %d: %.3f s (vel. máx %.0f km/h, fuera de pista %.2f s, desgaste %.1f %%, ERS %.0f %%)" % [
				_laps, _time - _lap_start, _max_speed, _off_track_time,
				_car.tyres.get_average_wear() * 100.0, _car.ers.get_charge() * 100.0])
		_lap_start = _time
		_max_speed = 0.0
		_off_track_time = 0.0
	_last_offset = offset

	if _time >= _next_report:
		_next_report += REPORT_INTERVAL
		print("t=%5.1f s=%6.0f v=%5.1f km/h marcha=%s rpm=%5.0f lat=%5.2f fuera=%d y=%.2f drs=%s" % [
			_time, offset, _car.speed_kmh, _car.get_gear_text(), _car.drivetrain.rpm,
			_track.get_lateral(_car.global_position, offset), _car.wheels_off_track,
			_car.global_position.y, _car.drs.open])
	if _time >= _duration:
		quit()
	return false
