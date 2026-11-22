class_name Drivetrain
extends RefCounted
## Modelo de motor y caja de cambios.
##
## Idea central (ver docs/modelo_motor_caja.md):
##   1. Las RPM del motor NO son un estado libre: se calculan a partir de la
##      velocidad de las ruedas motrices y la relación de la marcha engranada.
##         rpm = (v / radio_rueda) x relación_total x 60 / (2·pi)
##   2. Con las RPM se busca el par en la curva de par y se multiplica por el
##      acelerador.
##   3. El par se lleva a la rueda: F = par x relación_total x rendimiento / radio.
##   4. Si las RPM llegan al máximo actúa el limitador (par = 0).
##
## No aplica fuerzas: solo las calcula. El auto (f1_car.gd) decide cómo usarlas.

signal gear_changed(gear: int)

const GEAR_REVERSE := -1
const GEAR_NEUTRAL := 0
const RPM_TO_RAD_S := TAU / 60.0
# Velocidad máxima [m/s] para permitir engranar marcha atrás o primera desde
# la marcha contraria.
const DIRECTION_CHANGE_MAX_SPEED := 2.0
# Qué tan rápido sube/baja el motor en punto muerto [rpm/s].
const FREE_REV_RATE := 18000.0
# Suavizado de la aguja de RPM (1/s). Evita saltos bruscos al cambiar.
const RPM_SMOOTHING := 22.0
# Tiempo mínimo entre dos cambios de la caja automática [s]: al subir y al
# bajar (las rebajas en una frenada fuerte tienen que ser rápidas).
const AUTO_UPSHIFT_COOLDOWN := 0.28
const AUTO_DOWNSHIFT_COOLDOWN := 0.12
# Margen por encima del régimen máximo que tolera una rebaja de marcha.
const OVERREV_TOLERANCE := 1.02
# Por debajo de este acelerador se considera "pie levantado".
const THROTTLE_OFF_THRESHOLD := 0.05

var setup: CarSetup

## Marcha engranada: -1 = R, 0 = N, 1..8.
var gear: int = 1
## Régimen actual del motor [rpm].
var rpm: float = 0.0
## true mientras el limitador está cortando.
var rev_limiter_active: bool = false
## Fuerza de freno motor disponible en este instante [N] (siempre >= 0).
var engine_brake_force: float = 0.0

var _shift_timer: float = 0.0
var _auto_cooldown: float = 0.0


func _init(car_setup: CarSetup) -> void:
	setup = car_setup
	rpm = setup.idle_rpm


## Régimen como porcentaje del máximo (0..100): es lo que viaja al volante.
func get_rpm_pct() -> float:
	return clampf(rpm / setup.max_rpm * 100.0, 0.0, 100.0)


## Régimen que tendría el motor en la marcha `g` a la velocidad `speed`.
func rpm_at_speed(g: int, speed: float) -> float:
	var wheel_rad_s := absf(speed) / setup.wheel_radius
	return wheel_rad_s * setup.get_total_ratio(g) / RPM_TO_RAD_S


## Velocidad [m/s] a la que la marcha `g` llega al régimen máximo.
func top_speed_of_gear(g: int) -> float:
	var ratio := setup.get_total_ratio(g)
	if ratio <= 0.0:
		return 0.0
	return setup.max_rpm * RPM_TO_RAD_S / ratio * setup.wheel_radius


## Sube una marcha (R -> N -> 1 -> ... -> 8). Devuelve true si cambió.
func shift_up(speed: float) -> bool:
	if gear >= setup.get_gear_count():
		return false
	# No se pasa de marcha atrás a primera con el auto yendo rápido hacia atrás.
	if gear == GEAR_NEUTRAL and speed < -DIRECTION_CHANGE_MAX_SPEED:
		return false
	_set_gear(gear + 1)
	return true


## Baja una marcha. Se rechaza si pasaría de vueltas al motor o si se quiere
## engranar la marcha atrás en movimiento. Devuelve true si cambió.
func shift_down(speed: float) -> bool:
	if gear <= GEAR_REVERSE:
		return false
	var target := gear - 1
	if target == GEAR_REVERSE and speed > DIRECTION_CHANGE_MAX_SPEED:
		return false
	if target >= 1 and rpm_at_speed(target, speed) > setup.max_rpm * OVERREV_TOLERANCE:
		return false
	_set_gear(target)
	return true


## Engrana directamente una marcha (usado por la caja automática y los reinicios).
func set_gear(new_gear: int) -> void:
	_set_gear(clampi(new_gear, GEAR_REVERSE, setup.get_gear_count()))


## Actualiza el modelo y devuelve la fuerza de tracción en las ruedas [N],
## positiva hacia adelante (negativa en marcha atrás).
##   speed:    velocidad longitudinal de las ruedas motrices [m/s]
##   throttle: 0..1
##   automatic: true = la caja cambia sola
func update(delta: float, speed: float, throttle: float, automatic: bool) -> float:
	_shift_timer = maxf(_shift_timer - delta, 0.0)
	_auto_cooldown = maxf(_auto_cooldown - delta, 0.0)
	engine_brake_force = 0.0

	# --- Punto muerto: el motor gira libre siguiendo al acelerador -----------
	if gear == GEAR_NEUTRAL:
		var free_target := lerpf(setup.idle_rpm, setup.max_rpm, throttle)
		rpm = move_toward(rpm, free_target, FREE_REV_RATE * delta)
		rev_limiter_active = rpm >= setup.max_rpm - 1.0 and throttle > 0.9
		return 0.0

	# --- 1. RPM a partir de la velocidad de rueda y la relación --------------
	var ratio := setup.get_total_ratio(gear)
	var coupled_rpm := rpm_at_speed(gear, speed)
	# Embrague simplificado: en la arrancada el motor no cae por debajo de un
	# régimen que depende del acelerador (si no, se "calaría").
	var clutch_rpm := lerpf(setup.idle_rpm, setup.launch_rpm, throttle)
	var target_rpm := maxf(coupled_rpm, clutch_rpm)
	rpm = lerpf(rpm, target_rpm, 1.0 - exp(-RPM_SMOOTHING * delta))

	# --- 2. Limitador de régimen ---------------------------------------------
	rev_limiter_active = coupled_rpm >= setup.max_rpm
	if rpm > setup.max_rpm:
		rpm = setup.max_rpm

	# --- 3. Caja automática ---------------------------------------------------
	if automatic and gear >= 1 and _auto_cooldown <= 0.0:
		if coupled_rpm > setup.auto_upshift_rpm and gear < setup.get_gear_count() and throttle > 0.2:
			_set_gear(gear + 1)
			_auto_cooldown = AUTO_UPSHIFT_COOLDOWN
		elif gear > 1 and rpm_at_speed(gear - 1, speed) < setup.auto_downshift_rpm:
			_set_gear(gear - 1)
			_auto_cooldown = AUTO_DOWNSHIFT_COOLDOWN
		ratio = setup.get_total_ratio(gear)

	# --- 4. Par motor -> fuerza en la rueda -----------------------------------
	var direction := -1.0 if gear == GEAR_REVERSE else 1.0
	var torque := 0.0
	if not rev_limiter_active and _shift_timer <= 0.0:
		torque = setup.peak_torque * setup.get_torque_factor(rpm / setup.max_rpm) * throttle

	# Freno motor: con el pie levantado el motor retiene al auto.
	if throttle < THROTTLE_OFF_THRESHOLD or rev_limiter_active:
		var retention := setup.engine_brake_torque * (rpm / setup.max_rpm)
		engine_brake_force = retention * ratio / setup.wheel_radius

	return direction * torque * ratio * setup.drivetrain_efficiency / setup.wheel_radius


func _set_gear(new_gear: int) -> void:
	if new_gear == gear:
		return
	gear = new_gear
	_shift_timer = setup.shift_time
	gear_changed.emit(gear)
