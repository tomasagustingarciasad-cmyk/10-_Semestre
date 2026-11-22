extends SceneTree
## Prueba automática de los COMPUESTOS y del AQUAPLANING (sin ventana).
##
##   1. Tabla de compuestos: agarres, desgaste y velocidades de aquaplaning.
##   2. Fórmula de aquaplaning (por rueda): sin agua no hay; crece con la
##      velocidad y con el agua; el desgaste adelanta el inicio.
##   3. En el nivel Carrera con lluvia: con slicks a alta velocidad hay
##      aquaplaning (bandera del protocolo + evento de vibración); con
##      neumáticos de lluvia a la misma velocidad, no.
##   4. El desgaste depende del compuesto y del agua.
##   5. Estrategia: el blando rinde más en tandas cortas, el duro en tandas
##      largas y hay un punto de cruce razonable.
##
## Uso:
##   godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_tyres.gd

const FLAG_AQUAPLANING := 1 << 7
const KMH := 1.0 / 3.6
const TEST_SPEED := 68.0          # 245 km/h: por encima del aquaplaning total del slick
## Carrera de referencia para la verificación de estrategia y factor de vida
## del neumático (el mismo de RaceSession.RACE_TYRE_LIFE_FACTOR).
const STRATEGY_RACE_LAPS := 20
const RACE_TYRE_LIFE_FACTOR := 1.5
const STRAIGHT_OFFSET := 30.0     # recta principal, pasando la línea
## id, agarre seco, agarre mojado, desgaste en seco, inicio y total de aquaplaning [km/h].
const TABLE := [
	["blando", 1.03, 0.55, 2.0, 150.0, 220.0],
	["medio", 1.00, 0.55, 1.0, 150.0, 220.0],
	["duro", 0.97, 0.55, 0.55, 150.0, 220.0],
	["intermedio", 0.88, 0.80, 2.5, 230.0, 290.0],
	["lluvia", 0.78, 0.86, 4.0, 280.0, 340.0],
]

var _stage := 0
var _timer := 0.0
var _failures := 0
var _session
var _vibrations := 0
var _min_factor := 1.0
var _flag_seen := false
var _hud_warning := false


func _physics_process(delta: float) -> bool:
	_timer += delta
	match _stage:
		0:
			_check_table()
			var settings := root.get_node("Settings")
			settings.input_source = "keyboard"
			settings.sel_circuit = "los_aromos"
			settings.sel_weather = "lluvia"
			settings.sel_compound = "medio"
			settings.race_laps = 3
			root.get_node("InputManager").set_source("keyboard")
			root.get_node("TelemetryOut").vibration_sent.connect(_on_vibration)
			change_scene_to_file("res://scenes/levels/carrera.tscn")
			_stage = 1
		1:
			if current_scene != null and current_scene.get("lap_timer") != null:
				_session = current_scene
				_stage = 2
		2:
			if _session.phase == 2:
				print("3) Aquaplaning en pista con lluvia (agua %.2f)" % _session.weather.water_level)
				_launch()
				_stage = 3
		3:
			_sample()
			if _timer > 1.0:
				print("   slick medio a %.0f km/h: factor mínimo %.2f, vibraciones %d" % [TEST_SPEED * 3.6, _min_factor, _vibrations])
				_check("slick: aquaplaning a alta velocidad", _min_factor < 0.75)
				_check("bandera de aquaplaning en la telemetría (bit 7)", _flag_seen)
				_check("evento de vibración de aquaplaning", _vibrations >= 1)
				_check("aviso de aquaplaning en el HUD", _hud_warning)
				_session.car.set_compound(load("res://assets/tyres/lluvia.tres"))
				_launch()
				_stage = 4
		4:
			_sample()
			if _timer > 1.0:
				print("   lluvia extrema a %.0f km/h: factor mínimo %.2f" % [TEST_SPEED * 3.6, _min_factor])
				_check("lluvia extrema: sin aquaplaning a la misma velocidad", _min_factor > 0.99 and not _flag_seen)
				_check_wear()
				_check_strategy()
				print("RESULTADO: %s" % ("TODO OK" if _failures == 0 else "%d FALLAS" % _failures))
				quit(_failures)
	return false


# Lanza el auto por la recta principal a la velocidad de prueba.
func _launch() -> void:
	var track = _session.track
	_session.car.teleport(track.get_transform_at(STRAIGHT_OFFSET, 0.0, 0.25), TEST_SPEED)
	_session.car_offset = STRAIGHT_OFFSET
	_timer = 0.0
	_min_factor = 1.0
	_flag_seen = false
	_hud_warning = false
	_vibrations = 0


func _sample() -> void:
	var car = _session.car
	_min_factor = minf(_min_factor, car.aquaplaning_factor)
	if car.get_telemetry_flags() & FLAG_AQUAPLANING:
		_flag_seen = true
	for label in _session.hud.find_children("*", "Label", true, false):
		if label.visible and "AQUAPLANING" in label.text:
			_hud_warning = true


func _on_vibration(kind: StringName, _intensity: int, _duration_ms: int) -> void:
	if kind == &"aquaplaning":
		_vibrations += 1


func _check_table() -> void:
	print("1) Tabla de compuestos")
	for row: Array in TABLE:
		var compound = load("res://assets/tyres/%s.tres" % row[0])
		_check("%s: agarre %.2f / %.2f, desgaste x%.2f, aquaplaning %d-%d km/h" % [
				compound.display_name, row[1], row[2], row[3], row[4], row[5]],
				is_equal_approx(compound.grip_dry, row[1]) and is_equal_approx(compound.grip_wet, row[2])
				and is_equal_approx(compound.wear_dry, row[3])
				and is_equal_approx(compound.aquaplaning_start_kmh, row[4])
				and is_equal_approx(compound.aquaplaning_full_kmh, row[5]))

	print("2) Fórmula de aquaplaning")
	var slick = load("res://assets/tyres/medio.tres")
	var wet = load("res://assets/tyres/lluvia.tres")
	var inter = load("res://assets/tyres/intermedio.tres")
	_check("sin agua no hay aquaplaning", is_equal_approx(slick.get_aquaplaning_factor(300.0 * KMH, 0.0), 1.0))
	_check("por debajo de la velocidad de inicio no hay", is_equal_approx(slick.get_aquaplaning_factor(140.0 * KMH, 1.0), 1.0))
	_check("a la velocidad total con agua 1: queda el 30 %", is_equal_approx(slick.get_aquaplaning_factor(220.0 * KMH, 1.0), 0.3))
	_check("mitad de la banda con agua 1: 0,65 (smoothstep)", is_equal_approx(slick.get_aquaplaning_factor(185.0 * KMH, 1.0), 0.65))
	_check("la caída escala con el agua", is_equal_approx(slick.get_aquaplaning_factor(220.0 * KMH, 0.5), 0.65))
	_check("el desgaste adelanta el aquaplaning",
			slick.get_aquaplaning_factor(160.0 * KMH, 1.0, 1.0) < slick.get_aquaplaning_factor(160.0 * KMH, 1.0, 0.0))
	_check("en seco conviene el slick", slick.get_grip(0.0) > inter.get_grip(0.0) and inter.get_grip(0.0) > wet.get_grip(0.0))
	_check("en mojado conviene el de lluvia", wet.get_grip(0.7) > inter.get_grip(0.7) and inter.get_grip(0.7) > slick.get_grip(0.7))
	_check("elección automática: seco -> medio, lluvia -> lluvia extrema",
			slick.best_for(0.0).id == "medio" and slick.best_for(0.7).id == "lluvia")


func _check_wear() -> void:
	print("4) Desgaste según compuesto y agua")
	var wet = load("res://assets/tyres/lluvia.tres")
	var inter = load("res://assets/tyres/intermedio.tres")
	var slick = load("res://assets/tyres/medio.tres")
	_check("lluvia extrema en seco: desgaste x4", is_equal_approx(wet.get_wear_multiplier(0.0), 4.0))
	_check("intermedio en seco: desgaste x2,5", is_equal_approx(inter.get_wear_multiplier(0.0), 2.5))
	_check("en mojado, desgaste normal", is_equal_approx(wet.get_wear_multiplier(0.7), 1.0)
			and is_equal_approx(slick.get_wear_multiplier(0.7), 1.0))


# Agarre medio de una tanda de `laps` vueltas en una carrera de
# STRATEGY_RACE_LAPS, con el desgaste proporcional a la carrera.
func _stint_grip(compound, laps: int) -> float:
	var tyres_class = load("res://scripts/car/f1_systems.gd").Tyres
	var setup = _session.car.setup
	var wear_per_lap: float = tyres_class.TYPICAL_LOAD_FACTOR * compound.get_wear_multiplier(0.0) \
			/ (RACE_TYRE_LIFE_FACTOR * STRATEGY_RACE_LAPS)
	var total := 0.0
	for lap in laps:
		var wear := minf((lap + 0.5) * wear_per_lap, 1.0)   # desgaste a mitad de la vuelta
		total += compound.get_grip(0.0) * (1.0 - setup.tyre_max_grip_loss * tyres_class.get_loss_share(wear))
	return total / laps


# Primera tanda (en vueltas) en la que `better` rinde más que `worse` en promedio.
func _crossover(worse, better) -> int:
	for laps in range(1, STRATEGY_RACE_LAPS + 1):
		if _stint_grip(better, laps) > _stint_grip(worse, laps):
			return laps
	return STRATEGY_RACE_LAPS + 1


func _check_strategy() -> void:
	print("5) Estrategia: agarre medio por tanda en una carrera de %d vueltas" % STRATEGY_RACE_LAPS)
	var soft = load("res://assets/tyres/blando.tres")
	var medium = load("res://assets/tyres/medio.tres")
	var hard = load("res://assets/tyres/duro.tres")
	print("   tanda | blando | medio | duro")
	for laps in range(1, STRATEGY_RACE_LAPS + 1):
		print("   %5d | %.3f  | %.3f | %.3f" % [laps, _stint_grip(soft, laps), _stint_grip(medium, laps), _stint_grip(hard, laps)])
	_check("tanda de 1 vuelta: blando > medio > duro",
			_stint_grip(soft, 1) > _stint_grip(medium, 1) and _stint_grip(medium, 1) > _stint_grip(hard, 1))
	_check("carrera entera sin parar: duro > medio > blando",
			_stint_grip(hard, STRATEGY_RACE_LAPS) > _stint_grip(medium, STRATEGY_RACE_LAPS)
			and _stint_grip(medium, STRATEGY_RACE_LAPS) > _stint_grip(soft, STRATEGY_RACE_LAPS))
	var soft_to_medium := _crossover(soft, medium)
	var medium_to_hard := _crossover(medium, hard)
	print("   el medio supera al blando desde tandas de %d vueltas; el duro al medio desde %d" % [soft_to_medium, medium_to_hard])
	_check("cruce blando/medio entre el 30 % y el 70 % de la carrera",
			soft_to_medium >= STRATEGY_RACE_LAPS * 0.3 and soft_to_medium <= STRATEGY_RACE_LAPS * 0.7)
	_check("cruce medio/duro después del blando/medio y antes del final",
			medium_to_hard > soft_to_medium and medium_to_hard <= STRATEGY_RACE_LAPS)
	var tyres_class = load("res://scripts/car/f1_systems.gd").Tyres
	_check("meseta: a mitad de la vida útil se perdió menos de un cuarto de la pérdida máxima",
			tyres_class.get_loss_share(0.5) < 0.25 and is_equal_approx(tyres_class.get_loss_share(1.0), 1.0))
	_check("desgaste proporcional a la carrera (vida = %.1f x distancia)" % RACE_TYRE_LIFE_FACTOR,
			is_equal_approx(_session.car.tyres.life_distance, minf(_session.car.setup.tyre_life_distance,
			RACE_TYRE_LIFE_FACTOR * _session.total_laps * _session.track.length)))


func _check(description: String, condition: bool) -> void:
	print("  [%s] %s" % ["OK" if condition else "FALLA", description])
	if not condition:
		_failures += 1
