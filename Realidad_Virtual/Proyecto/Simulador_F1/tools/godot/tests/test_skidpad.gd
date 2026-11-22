extends SceneTree
## Prueba automática de la capacidad del auto: SKIDPAD, recta y frenada.
##
## El auto del jugador sobre un plano grande, sin circuito, manejado por una
## fuente de entrada propia registrada en el InputManager (skidpad_source.gd).
##
##   1. Skidpad: a cada velocidad objetivo, dirección a tope y velocidad
##      constante; se mide la aceleración lateral media en régimen estacionario.
##   2. Recta: 0-100 y 0-200 km/h, velocidad máxima con DRS y ERS, y hundimiento
##      de la suspensión a máxima velocidad (no tiene que hacer tope).
##   3. Frenada: de 300 a 100 km/h (desaceleración media y máxima).
##   4. Compuestos: lateral de cada compuesto en seco a dos velocidades.
##
## Imprime las tablas, las escribe en docs/skidpad.md (junto a la medición de
## la Fase 1b, antes de subir la carga aerodinámica) y verifica los objetivos.
##
## Uso:
##   godot --headless --fixed-fps 120 --script res://tools/godot/tests/test_skidpad.gd
##   (agregando "-- medir" solo mide: no verifica objetivos ni escribe el documento)

const GRAVITY := 9.81
const MS_TO_KMH := 3.6
const SKIDPAD_SPEEDS: Array[float] = [15.0, 25.0, 35.0, 45.0, 55.0, 65.0, 75.0, 85.0]
const COMPOUND_SPEEDS: Array[float] = [25.0, 65.0]
const COMPOUNDS: Array[String] = ["blando", "medio", "duro", "intermedio", "lluvia"]
const REACH_TIMEOUT := 45.0       # tiempo máximo para llegar a una velocidad [s]
const REACH_MARGIN := 0.5         # [m/s]
const SETTLE_TIME := 5.0          # espera con la dirección a tope antes de medir [s]
const MEASURE_TIME := 4.0
const REST_TIME := 2.0            # asentamiento inicial de la suspensión [s]
const TOP_SPEED_TIMEOUT := 70.0
const TOP_SPEED_SETTLED_ACCEL := 0.03   # [m/s²]
const BRAKE_FROM := 300.0 / 3.6
const BRAKE_TO := 100.0 / 3.6
const SPAWN_HEIGHT := 0.3
const GROUND_SIZE := 60000.0
const GROUND_THICKNESS := 2.0
const OUTPUT := "res://docs/skidpad.md"

## Medición de la Fase 1b (downforce_coef = 1,30), con esta misma prueba:
## velocidad [m/s] -> lateral [g].
var BEFORE_LATERAL: Dictionary = {15.0: 1.91, 25.0: 2.10, 35.0: 2.34, 45.0: 2.63, 55.0: 2.99, 65.0: 3.40, 75.0: 3.89, 85.0: 4.00}
## Ídem para recta y frenada: clave -> valor.
var BEFORE_STRAIGHT: Dictionary = {"0-100": 2.31, "0-200": 4.78, "vmax": 344.6, "frenada_tiempo": 1.725,
	"frenada_distancia": 89.1, "frenada_media": 3.28, "frenada_maxima": 4.93, "hundimiento": 0.0636, "recorrido": 0.10}

# Objetivos de la Fase 1c (neumático medio, seco).
const TARGET_LOW_SPEED := 25.0
const TARGET_LOW_G := Vector2(1.9, 2.5)
const TARGET_HIGH_SPEED := 75.0          # 270 km/h
const TARGET_HIGH_G := Vector2(4.3, 5.6)
const TARGET_BRAKE_G := Vector2(3.8, 5.6)
const TARGET_TOP_SPEED_KMH := Vector2(328.0, 347.0)
## El perfil de la IA no puede suponer más que esta fracción de lo medido.
const PROFILE_MAX_FRACTION := 0.95
## Cuánto puede bajar el auto entre parado y velocidad máxima, como fracción
## del recorrido (el resto queda para el peso propio, los pianos y la frenada).
const MAX_SINK_FRACTION := 0.6

enum Step { SETUP, REST, REACH, SETTLE, MEASURE, LAUNCH, TOP_SPEED, BRAKE, DONE }

var _car
var _source
var _step := Step.SETUP
var _timer := 0.0
var _phase := 0                 # 0 = skidpad medio, 1 = recta, 2 = compuestos
var _speed_index := 0
var _compound_index := 0
var _only_measure := false
var _failures := 0

var _rest_height := 0.0
var _sum_lateral := 0.0
var _sum_speed := 0.0
var _samples := 0
var _lateral := {}              # velocidad objetivo -> [velocidad media, g, radio]
var _compound_lateral := {}     # compuesto -> {velocidad -> g}
var _straight := {}
var _launch_time := 0.0
var _previous_speed := 0.0
var _slow_accel_time := 0.0
var _max_sink := 0.0
var _brake_start_time := 0.0
var _brake_start_position := Vector3.ZERO
var _peak_decel := 0.0
var _braking := false


func _initialize() -> void:
	_only_measure = OS.get_cmdline_user_args().has("medir")
	# Piso: una caja enorme (el plano "infinito" de Jolt en realidad mide
	# 2 km de lado y el auto se cae al llegar al borde).
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, GROUND_THICKNESS, GROUND_SIZE)
	shape.shape = box
	shape.position.y = -GROUND_THICKNESS * 0.5
	ground.add_child(shape)
	root.add_child(ground)
	_car = (load("res://scenes/car/f1_car.tscn") as PackedScene).instantiate()
	root.add_child(_car)


func _physics_process(delta: float) -> bool:
	_timer += delta
	match _step:
		Step.SETUP:
			root.get_node("GameState").in_menu = false
			root.get_node("Settings").auto_gearbox = true
			_source = load("res://tools/godot/tests/skidpad_source.gd").new()
			_source.car = _car
			var input_manager := root.get_node("InputManager")
			input_manager.register_source(_source)
			input_manager.set_source(_source.get_id())
			_respawn()
			_go(Step.REST)
		Step.REST:
			if _timer > REST_TIME:
				_rest_height = _car.global_position.y
				print("1) Skidpad con neumático medio (seco)")
				_start_speed()
		Step.REACH:
			var target := _current_speeds()[_speed_index]
			if _car.speed >= target - REACH_MARGIN or _timer > REACH_TIMEOUT:
				_source.steer_command = 1.0
				_go(Step.SETTLE)
		Step.SETTLE:
			if _timer > SETTLE_TIME:
				_car.tyres.reset()
				_sum_lateral = 0.0
				_sum_speed = 0.0
				_samples = 0
				_go(Step.MEASURE)
		Step.MEASURE:
			_sum_lateral += absf(_car.lateral_accel)
			_sum_speed += _car.speed
			_samples += 1
			if _timer > MEASURE_TIME:
				_store_measure()
		Step.LAUNCH:
			_update_straight(delta)
		Step.TOP_SPEED:
			_update_straight(delta)
		Step.BRAKE:
			_update_brake(delta)
		Step.DONE:
			_finish()
			return true
	return false


# ------------------------------------------------------------------------------
# Skidpad
# ------------------------------------------------------------------------------
func _current_speeds() -> Array[float]:
	return SKIDPAD_SPEEDS if _phase == 0 else COMPOUND_SPEEDS


func _start_speed() -> void:
	_source.mode = _source.Mode.HOLD
	_source.target_speed = _current_speeds()[_speed_index]
	_source.steer_command = 0.0
	_source.reset_control()
	# Neumáticos nuevos en cada medición: que el desgaste de la anterior no influya.
	_car.tyres.reset()
	_go(Step.REACH)


func _store_measure() -> void:
	var target := _current_speeds()[_speed_index]
	var mean_speed := _sum_speed / _samples
	var lateral_g := _sum_lateral / _samples / GRAVITY
	var radius := mean_speed * mean_speed / maxf(lateral_g * GRAVITY, 0.01)
	if _phase == 0:
		_lateral[target] = [mean_speed, lateral_g, radius]
		print("   %5.0f km/h (real %5.0f)  lateral %.2f g  radio %5.0f m" % [
				target * MS_TO_KMH, mean_speed * MS_TO_KMH, lateral_g, radius])
	else:
		var id := COMPOUNDS[_compound_index]
		if not _compound_lateral.has(id):
			_compound_lateral[id] = {}
		_compound_lateral[id][target] = lateral_g
		print("   %-11s %4.0f km/h  lateral %.2f g" % [id, target * MS_TO_KMH, lateral_g])

	_speed_index += 1
	if _speed_index < _current_speeds().size():
		_start_speed()
		return
	_speed_index = 0
	if _phase == 0:
		_phase = 1
		print("2) Recta: aceleración, velocidad máxima y frenada")
		_respawn()
		_source.mode = _source.Mode.FLAT_OUT
		_launch_time = 0.0
		_go(Step.LAUNCH)
	else:
		_compound_index += 1
		_next_compound()


func _next_compound() -> void:
	if _compound_index >= COMPOUNDS.size():
		_go(Step.DONE)
		return
	_respawn()
	_car.set_compound(load("res://assets/tyres/%s.tres" % COMPOUNDS[_compound_index]))
	_start_speed()


# ------------------------------------------------------------------------------
# Recta y frenada
# ------------------------------------------------------------------------------
func _update_straight(delta: float) -> void:
	_launch_time += delta
	var speed: float = _car.speed
	if int(_launch_time * 120.0) % 240 == 0 and OS.get_cmdline_user_args().has("traza"):
		print("   t=%.1f v=%.1f km/h marcha=%s y=%.3f paso=%d" % [_launch_time, speed * MS_TO_KMH,
				_car.get_gear_text(), _car.global_position.y, _step])
	var speed_kmh := speed * MS_TO_KMH
	_max_sink = maxf(_max_sink, _rest_height - _car.global_position.y)
	if not _straight.has("0-100") and speed_kmh >= 100.0:
		_straight["0-100"] = _launch_time
	if not _straight.has("0-200") and speed_kmh >= 200.0:
		_straight["0-200"] = _launch_time
		# A partir de acá, todo: DRS (como si fuera una zona) y ERS.
		_source.use_ers = true
		_source.use_drs = true
		_go(Step.TOP_SPEED)
	if _step == Step.TOP_SPEED:
		_car.drs.in_zone = true
		var accel := (speed - _previous_speed) / delta
		_slow_accel_time = _slow_accel_time + delta if absf(accel) < TOP_SPEED_SETTLED_ACCEL else 0.0
		if _slow_accel_time > 2.0 or _timer > TOP_SPEED_TIMEOUT:
			_straight["vmax"] = speed_kmh
			_straight["hundimiento"] = _max_sink
			_straight["recorrido"] = _car.setup.suspension_travel
			_source.mode = _source.Mode.BRAKE
			_braking = false
			_go(Step.BRAKE)
	_previous_speed = speed


func _update_brake(delta: float) -> void:
	var speed: float = _car.speed
	var decel := (_previous_speed - speed) / delta
	_previous_speed = speed
	if not _braking and speed <= BRAKE_FROM:
		_braking = true
		_brake_start_time = _timer
		_brake_start_position = _car.global_position
		_peak_decel = 0.0
	if _braking:
		_peak_decel = maxf(_peak_decel, decel)
		if speed <= BRAKE_TO:
			var time := _timer - _brake_start_time
			_straight["frenada_tiempo"] = time
			_straight["frenada_distancia"] = _car.global_position.distance_to(_brake_start_position)
			_straight["frenada_media"] = (BRAKE_FROM - BRAKE_TO) / time / GRAVITY
			_straight["frenada_maxima"] = _peak_decel / GRAVITY
			_print_straight()
			_phase = 2
			_compound_index = 0
			print("3) Lateral por compuesto (seco)")
			_next_compound()


func _print_straight() -> void:
	print("   0-100 km/h: %.2f s   0-200 km/h: %.2f s" % [_straight["0-100"], _straight["0-200"]])
	print("   velocidad máxima (DRS + ERS): %.0f km/h" % _straight["vmax"])
	print("   hundimiento máximo de la suspensión: %.0f mm de %.0f mm de recorrido" % [
			_straight["hundimiento"] * 1000.0, _straight["recorrido"] * 1000.0])
	print("   frenada 300-100 km/h: %.2f s, %.0f m, media %.2f g, máxima %.2f g" % [
			_straight["frenada_tiempo"], _straight["frenada_distancia"],
			_straight["frenada_media"], _straight["frenada_maxima"]])


# ------------------------------------------------------------------------------
# Resultados
# ------------------------------------------------------------------------------
func _finish() -> void:
	if _only_measure:
		print("LATERAL ", JSON.stringify(_lateral_summary()))
		print("RECTA ", JSON.stringify(_straight))
		quit(0)
		return
	print("4) Objetivos")
	var low: float = _lateral[TARGET_LOW_SPEED][1]
	var high: float = _lateral[TARGET_HIGH_SPEED][1]
	_check("lateral en lento (%.0f km/h): %.2f g, entre %.1f y %.1f" % [TARGET_LOW_SPEED * MS_TO_KMH, low,
			TARGET_LOW_G.x, TARGET_LOW_G.y], low >= TARGET_LOW_G.x and low <= TARGET_LOW_G.y)
	_check("lateral en rápido (%.0f km/h): %.2f g, entre %.1f y %.1f" % [TARGET_HIGH_SPEED * MS_TO_KMH, high,
			TARGET_HIGH_G.x, TARGET_HIGH_G.y], high >= TARGET_HIGH_G.x and high <= TARGET_HIGH_G.y)
	var monotonic := true
	for i in range(1, SKIDPAD_SPEEDS.size()):
		if _lateral[SKIDPAD_SPEEDS[i]][1] < _lateral[SKIDPAD_SPEEDS[i - 1]][1]:
			monotonic = false
	_check("la lateral crece con la velocidad (carga aerodinámica)", monotonic)
	_check("frenada 300-100 km/h: media %.2f g, entre %.1f y %.1f" % [_straight["frenada_media"],
			TARGET_BRAKE_G.x, TARGET_BRAKE_G.y], _straight["frenada_media"] >= TARGET_BRAKE_G.x
			and _straight["frenada_media"] <= TARGET_BRAKE_G.y)
	_check("velocidad máxima %.0f km/h, entre %.0f y %.0f" % [_straight["vmax"], TARGET_TOP_SPEED_KMH.x,
			TARGET_TOP_SPEED_KMH.y], _straight["vmax"] >= TARGET_TOP_SPEED_KMH.x
			and _straight["vmax"] <= TARGET_TOP_SPEED_KMH.y)
	_check("la suspensión no hace tope a máxima velocidad (baja %.0f mm, menos del %.0f %% del recorrido)" % [
			_straight["hundimiento"] * 1000.0, MAX_SINK_FRACTION * 100.0],
			_straight["hundimiento"] < _straight["recorrido"] * MAX_SINK_FRACTION)
	# El perfil de velocidad de la IA tiene que caber en lo que el auto puede.
	var setup = _car.setup
	if setup.has_method("get_profile_lateral"):
		var fits := true
		for target: float in SKIDPAD_SPEEDS:
			var assumed: float = setup.get_profile_lateral(target) / GRAVITY
			if assumed > _lateral[target][1] * PROFILE_MAX_FRACTION:
				fits = false
				print("   a %.0f km/h el perfil supone %.2f g y el auto da %.2f g" % [
						target * MS_TO_KMH, assumed, _lateral[target][1]])
		_check("el perfil de la IA no supera el %.0f %% de lo medido" % (PROFILE_MAX_FRACTION * 100.0), fits)
	var soft: float = _compound_lateral["blando"][COMPOUND_SPEEDS[0]]
	var medium: float = _compound_lateral["medio"][COMPOUND_SPEEDS[0]]
	var hard: float = _compound_lateral["duro"][COMPOUND_SPEEDS[0]]
	_check("en seco: blando > medio > duro", soft > medium and medium > hard)
	_write_document()
	print("RESULTADO: %s" % ("TODO OK" if _failures == 0 else "%d FALLAS" % _failures))
	quit(_failures)


func _lateral_summary() -> Dictionary:
	var summary := {}
	for target: float in _lateral:
		summary[target] = snappedf(_lateral[target][1], 0.01)
	return summary


func _write_document() -> void:
	var setup = _car.setup
	var lines := PackedStringArray()
	lines.append("# Skidpad, recta y frenada: capacidad medida del auto")
	lines.append("")
	lines.append("Generado por `tools/godot/tests/test_skidpad.gd` (no editar a mano: se reescribe en cada corrida).")
	lines.append("El auto del jugador sobre un plano, con neumático medio nuevo en seco, manejado por una fuente")
	lines.append("de entrada propia registrada en el `InputManager`.")
	lines.append("")
	lines.append("Puesta a punto medida: `downforce_coef` = %.2f N/(m/s)², masa %.0f kg, agarre %.2f / %.2f (delante / detrás)," % [
			setup.downforce_coef, setup.mass, setup.grip_front, setup.grip_rear])
	lines.append("rigidez de suspensión %.0f, freno máximo %.0f N." % [setup.suspension_stiffness, setup.max_brake_force])
	lines.append("")
	lines.append("## 1. Skidpad: aceleración lateral máxima")
	lines.append("")
	lines.append("Dirección a tope y velocidad constante; media de %.0f s en régimen estacionario." % MEASURE_TIME)
	lines.append("\"Antes\" es la misma prueba con la puesta a punto de la Fase 1b (`downforce_coef` = 1,30).")
	lines.append("")
	lines.append("| Velocidad | Antes (Fase 1b) | Ahora | Radio del círculo | Carga aerodinámica / peso |")
	lines.append("|---|---|---|---|---|")
	for target: float in SKIDPAD_SPEEDS:
		var row: Array = _lateral[target]
		var before := "—"
		if BEFORE_LATERAL.has(target):
			before = "%.2f g" % BEFORE_LATERAL[target]
		var note := "" if row[0] > target - 2.0 else " (solo llegó a %.0f km/h)" % (row[0] * MS_TO_KMH)
		lines.append("| %.0f km/h%s | %s | **%.2f g** | %.0f m | %.2f |" % [target * MS_TO_KMH, note, before,
				row[1], row[2], setup.downforce_coef * target * target / (setup.mass * GRAVITY)])
	lines.append("")
	lines.append("## 2. Recta y frenada")
	lines.append("")
	lines.append("| Medición | Antes (Fase 1b) | Ahora |")
	lines.append("|---|---|---|")
	var rows := [
		["0-100 km/h", "0-100", "%.2f s"], ["0-200 km/h", "0-200", "%.2f s"],
		["Velocidad máxima (DRS + ERS)", "vmax", "%.0f km/h"],
		["Frenada 300-100 km/h: tiempo", "frenada_tiempo", "%.2f s"],
		["Frenada 300-100 km/h: distancia", "frenada_distancia", "%.0f m"],
		["Frenada 300-100 km/h: media", "frenada_media", "%.2f g"],
		["Frenada 300-100 km/h: máxima", "frenada_maxima", "%.2f g"],
	]
	for row: Array in rows:
		var before := "—"
		if BEFORE_STRAIGHT.has(row[1]):
			before = row[2] % BEFORE_STRAIGHT[row[1]]
		lines.append("| %s | %s | %s |" % [row[0], before, row[2] % _straight[row[1]]])
	lines.append("| Hundimiento de la suspensión a velocidad máxima | %s | %.0f mm de %.0f mm |" % [
			"%.0f mm de %.0f mm" % [BEFORE_STRAIGHT["hundimiento"] * 1000.0, BEFORE_STRAIGHT["recorrido"] * 1000.0]
			if BEFORE_STRAIGHT.has("hundimiento") else "—",
			_straight["hundimiento"] * 1000.0, _straight["recorrido"] * 1000.0])
	lines.append("")
	lines.append("## 3. Lateral por compuesto (neumático nuevo, seco)")
	lines.append("")
	var header := "| Compuesto |"
	var separator := "|---|"
	for target: float in COMPOUND_SPEEDS:
		header += " %.0f km/h |" % (target * MS_TO_KMH)
		separator += "---|"
	lines.append(header)
	lines.append(separator)
	for id: String in COMPOUNDS:
		var line := "| %s |" % id
		for target: float in COMPOUND_SPEEDS:
			line += " %.2f g |" % _compound_lateral[id][target]
		lines.append(line)
	lines.append("")
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Tabla escrita en ", OUTPUT)


# ------------------------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------------------------
func _respawn() -> void:
	_car.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, SPAWN_HEIGHT, 0.0)))
	_source.steer_command = 0.0
	_source.use_ers = false
	_source.use_drs = false
	_source.reset_control()
	_previous_speed = 0.0
	_slow_accel_time = 0.0


func _go(step: Step) -> void:
	_step = step
	_timer = 0.0


func _check(description: String, condition: bool) -> void:
	print("  [%s] %s" % ["OK" if condition else "FALLA", description])
	if not condition:
		_failures += 1
