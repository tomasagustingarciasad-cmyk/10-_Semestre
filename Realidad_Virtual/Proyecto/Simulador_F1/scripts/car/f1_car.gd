class_name F1Car
extends VehicleBody3D
## Auto del jugador: VehicleBody3D + 4 VehicleWheel3D (física Jolt).
##
## Este script es la capa de "lógica de interacción con el mundo" del auto:
## toma las entradas ya procesadas del InputManager (nunca del teclado) y las
## convierte en fuerzas sobre el vehículo, pasando por los modelos de
## motor/caja (Drivetrain) y los sistemas de F1 (DRS, ERS, neumáticos).
##
## Convención de ejes: el auto mira hacia -Z (el "adelante" de Godot), +X es
## su derecha. En VehicleBody3D una `engine_force` positiva empuja hacia +Z y
## un `steering` positivo gira a la izquierda; por eso más abajo ambas
## magnitudes se aplican con el signo cambiado.

## Choque detectado. strength: 0..1 según la violencia del golpe.
signal crashed(strength: float)
## El auto quedó volcado durante un rato (la sesión lo reubica).
signal flipped

# Índices de las ruedas.
const WHEEL_FL := 0   ## Delantera izquierda
const WHEEL_FR := 1   ## Delantera derecha
const WHEEL_RL := 2   ## Trasera izquierda
const WHEEL_RR := 3   ## Trasera derecha
const WHEEL_COUNT := 4

const GRAVITY := 9.81
const MS_TO_KMH := 3.6
const RPM_TO_RAD_S := TAU / 60.0

# Con el freno por encima de este valor se corta la tracción del motor.
const BRAKE_OVERRIDE_THRESHOLD := 0.05
# Caja automática: tiempo frenando en parado para engranar marcha atrás [s].
const AUTO_REVERSE_HOLD_TIME := 0.45
# Velocidad por debajo de la cual el auto se considera detenido [m/s].
const STOPPED_SPEED := 1.0
# Limitador de boxes: banda [m/s] en la que el acelerador se reduce suavemente
# y freno máximo que aplica solo si se lo activa pasado de velocidad.
const PIT_LIMITER_BAND := 2.0
const PIT_LIMITER_MAX_BRAKE := 0.3
# Freno aplicado cuando los controles están deshabilitados (largada, boxes).
const HOLD_BRAKE := 1.0
# Choque: cambio de velocidad horizontal en un tick [m/s] a partir del cual
# se considera golpe, y cambio que corresponde a la intensidad máxima.
const CRASH_MIN_DELTA_V := 2.5
const CRASH_FULL_DELTA_V := 14.0
# Vuelco: el eje vertical del auto apunta menos que esto hacia arriba.
const FLIP_UP_THRESHOLD := 0.25
const FLIP_TIME := 1.5
# Velocidad mínima [m/s] para generar vibraciones de piano/pasto.
const VIBRATION_MIN_SPEED := 6.0
# Velocidad [m/s] a la que la vibración de superficie llega a su máximo.
const VIBRATION_FULL_SPEED := 60.0
# Ángulo de apertura del flap del alerón con DRS [grados] y su velocidad.
const DRS_FLAP_OPEN_DEG := -32.0
const DRS_FLAP_SPEED_DEG := 240.0
# Ayuda de dirección: fracción del agarre nominal del tren delantero a la que
# apunta la dirección a fondo (un poco por encima de lo que el auto sostiene,
# para tener toda la capacidad de giro), y velocidad mínima del cálculo [m/s].
const STEER_ASSIST_MARGIN := 1.0
const STEER_ASSIST_MIN_SPEED := 5.0
# Por debajo de este factor se considera que el auto está aquaplaneando.
const AQUAPLANING_WARNING_FACTOR := 0.88
# Tiempo entre avisos de vibración mientras dura el aquaplaning [s].
const AQUAPLANING_VIBRATION_INTERVAL := 0.4

## Puesta a punto del auto (recurso editable).
@export var setup: CarSetup
## true = lo maneja el jugador (lee InputManager y publica telemetría).
@export var is_player: bool = true

# --- Referencias y estado público ------------------------------------------------
## Circuito sobre el que corre (lo asigna la sesión). Sin circuito todo se
## considera asfalto.
var track: Track = null
## false = el auto ignora las entradas y queda frenado (semáforo, boxes).
var controls_enabled: bool = true
## Clima del nivel (lo asigna la sesión). Sin clima la pista está seca.
var weather: Weather = null
## Compuesto de neumático montado.
var compound: TyreCompound = null
## Menor factor de aquaplaning entre las cuatro ruedas (1 = sin aquaplaning).
var aquaplaning_factor: float = 1.0
## true mientras alguna rueda está aquaplaneando de forma apreciable.
var aquaplaning: bool = false
## Agua promedio bajo las ruedas (0..1).
var water_under_wheels: float = 0.0

var drivetrain: Drivetrain
var drs: F1Systems.Drs
var ers: F1Systems.Ers
var tyres: F1Systems.Tyres

## Limitador de boxes activado por el piloto.
var pit_limiter_on: bool = false
## El auto está dentro del pit lane (lo actualiza la sesión).
var in_pit_lane: bool = false
## La vuelta actual está invalidada (lo actualiza la sesión; viaja al volante).
var lap_invalid: bool = false
## Reparto de frenada hacia adelante (ajustable con el encoder).
var brake_bias: float = 0.58

## Velocidad longitudinal [m/s] (negativa marcha atrás) y rapidez [km/h].
var speed: float = 0.0
var speed_kmh: float = 0.0
## Aceleración lateral [m/s²], positiva en curvas a la derecha.
var lateral_accel: float = 0.0
## Entradas efectivamente aplicadas en el último tick (para el HUD).
var steer_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
## Superficie bajo cada rueda (valores de Track.Surface).
var wheel_surfaces: Array[int] = [0, 0, 0, 0]
## Cantidad de ruedas fuera de la pista (sobre el pasto).
var wheels_off_track: int = 0

# --- Internos --------------------------------------------------------------------
var _wheels: Array[VehicleWheel3D] = []
var _base_grip: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _slide: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _previous_velocity: Vector3 = Vector3.ZERO
var _reverse_hold_timer: float = 0.0
var _flip_timer: float = 0.0
var _skip_crash_check: bool = true
var _drs_flap: Node3D = null
var _engine_sound: Node = null
var _wheelbase: float = 3.4
var _aquaplaning_vibration_timer: float = 0.0


func _ready() -> void:
	if setup == null:
		setup = CarSetup.new()
	_wheels = [$RuedaDI, $RuedaDD, $RuedaTI, $RuedaTD]
	_drs_flap = get_node_or_null("Carroceria/AleronTrasero/FlapDRS")
	_engine_sound = get_node_or_null("SonidoMotor")
	_apply_setup()

	drivetrain = Drivetrain.new(setup)
	drs = F1Systems.Drs.new()
	ers = F1Systems.Ers.new(setup)
	tyres = F1Systems.Tyres.new(setup)
	brake_bias = setup.brake_bias
	if compound == null:
		compound = TyreCompound.load_compound(TyreCompound.DEFAULT_ID)

	if is_player:
		InputManager.shift_up_pressed.connect(_on_shift_up)
		InputManager.shift_down_pressed.connect(_on_shift_down)
		InputManager.drs_pressed.connect(_on_drs_pressed)
		InputManager.pit_limiter_pressed.connect(_on_pit_limiter_pressed)
		InputManager.encoder_turned.connect(_on_encoder_turned)


func _exit_tree() -> void:
	if is_player:
		TelemetryOut.stop()


func _physics_process(delta: float) -> void:
	var forward := -global_basis.z
	speed = linear_velocity.dot(forward)
	speed_kmh = absf(speed) * MS_TO_KMH
	lateral_accel = -angular_velocity.y * speed

	_read_inputs()
	_update_steering(delta)
	_update_surfaces()
	var load_total := _apply_aerodynamics(forward)
	_update_powertrain(delta, load_total)
	_update_systems(delta)
	_detect_crash_and_flip(delta)
	_update_visuals(delta)
	if is_player:
		_publish_telemetry()


# ==============================================================================
# API pública
# ==============================================================================

## Ángulo máximo de las ruedas directrices a la velocidad actual [rad].
## Disminuye con la velocidad para que el auto no sea nervioso en recta:
##     ángulo = ángulo_máx / (1 + (v / v_ref)²)
##
## Con la AYUDA DE DIRECCIÓN (teclado, o siempre si se elige en Opciones) el
## tope es además el ángulo que el agarre puede aprovechar a esa velocidad
## (ver get_grip_steer_angle): apretar la tecla a fondo pide "lo máximo que
## el auto puede doblar" en vez de saturar el tren delantero.
func get_max_steer_angle() -> float:
	var ratio := absf(speed) / setup.steer_speed_ref
	var angle := deg_to_rad(setup.steer_angle_max_deg) / (1.0 + ratio * ratio)
	if is_player and InputManager.uses_steer_assist():
		angle = minf(angle, get_grip_steer_angle())
	return angle


## Ángulo de dirección que aprovecha todo el agarre disponible ahora [rad].
## Modelo de bicicleta: aceleración lateral = v² · tan(ángulo) / batalla, así
## que   ángulo = atan(batalla · lateral_disponible / v²).
## La lateral disponible usa el agarre ACTUAL del tren delantero (compuesto,
## desgaste, agua, superficie) y la carga aerodinámica a esta velocidad.
func get_grip_steer_angle() -> float:
	var speed_squared := maxf(speed * speed, STEER_ASSIST_MIN_SPEED * STEER_ASSIST_MIN_SPEED)
	var front_grip := minf(_wheels[WHEEL_FL].wheel_friction_slip, _wheels[WHEEL_FR].wheel_friction_slip)
	var available := STEER_ASSIST_MARGIN * front_grip \
			* (GRAVITY + setup.get_aero_per_mass() * speed * speed)
	return atan(_wheelbase * available / speed_squared)


## Reubica el auto (largada, reinicio, vuelta a pista) y lo deja en reposo o
## con una velocidad inicial hacia adelante.
func teleport(target: Transform3D, initial_speed: float = 0.0) -> void:
	global_transform = target
	linear_velocity = -target.basis.z * initial_speed
	angular_velocity = Vector3.ZERO
	steering = 0.0
	_previous_velocity = linear_velocity
	_skip_crash_check = true
	_flip_timer = 0.0
	_reverse_hold_timer = 0.0
	drs.reset()
	# Marcha acorde a la velocidad inicial.
	var gear := 1
	while gear < setup.get_gear_count() and drivetrain.rpm_at_speed(gear, initial_speed) > setup.auto_upshift_rpm:
		gear += 1
	drivetrain.set_gear(gear)


## Servicio completo en boxes: neumáticos nuevos del compuesto indicado
## (o del mismo que llevaba si no se indica ninguno).
func service_in_pits(new_compound: TyreCompound = null) -> void:
	if new_compound != null:
		compound = new_compound
	tyres.reset()


## Monta un juego nuevo del compuesto indicado.
func set_compound(new_compound: TyreCompound) -> void:
	if new_compound != null:
		compound = new_compound
	if tyres != null:
		tyres.reset()


## Marcha engranada (-1 = R, 0 = N, 1..8).
func get_gear() -> int:
	return drivetrain.gear


## Texto de la marcha para mostrar ("R", "N", "1".."8").
func get_gear_text() -> String:
	match drivetrain.gear:
		Drivetrain.GEAR_REVERSE: return "R"
		Drivetrain.GEAR_NEUTRAL: return "N"
	return str(drivetrain.gear)


## Bits de estado que viajan al volante (ver WheelProtocol.FLAG_*).
func get_telemetry_flags() -> int:
	var flags := 0
	if drs.is_available():
		flags |= WheelProtocol.FLAG_DRS_AVAILABLE
	if drs.open:
		flags |= WheelProtocol.FLAG_DRS_OPEN
	if pit_limiter_on:
		flags |= WheelProtocol.FLAG_PIT_LIMITER
	if ers.deploying:
		flags |= WheelProtocol.FLAG_ERS_DEPLOY
	if drivetrain.rev_limiter_active:
		flags |= WheelProtocol.FLAG_REV_LIMIT
	if in_pit_lane:
		flags |= WheelProtocol.FLAG_IN_PIT_LANE
	if lap_invalid:
		flags |= WheelProtocol.FLAG_LAP_INVALID
	if aquaplaning:
		flags |= WheelProtocol.FLAG_AQUAPLANING
	return flags


# ==============================================================================
# Pasos del tick de física
# ==============================================================================

# 1. Entradas: del InputManager si el jugador tiene el control.
func _read_inputs() -> void:
	if is_player and controls_enabled:
		steer_input = InputManager.steer
		throttle_input = InputManager.throttle
		brake_input = InputManager.brake
	else:
		steer_input = 0.0
		throttle_input = 0.0
		brake_input = HOLD_BRAKE


# 2. Dirección: ángulo máximo dependiente de la velocidad + giro progresivo.
func _update_steering(delta: float) -> void:
	# steer_input > 0 es derecha; en VehicleBody3D steering > 0 es izquierda.
	var target := -steer_input * get_max_steer_angle()
	steering = move_toward(steering, target, deg_to_rad(setup.steer_rate_deg) * delta)


# 3. Agarre de cada rueda:
#        agarre = base x carga x superficie x desgaste x compuesto(agua) x aquaplaning
#    - base: coeficiente del eje (delantero o trasero) de la puesta a punto;
#    - carga: sensibilidad a la carga (el coeficiente baja al crecer la
#      carga aerodinámica; ver CarSetup.get_load_factor);
#    - superficie: asfalto, piano o pasto bajo ESA rueda;
#    - desgaste: cuánto perdió ese neumático;
#    - compuesto: agarre del compuesto para el agua que hay bajo esa rueda;
#    - aquaplaning: caída por velocidad y agua, también por rueda (como el
#      agua tiene charcos, puede aquaplanear un solo lado del auto).
func _update_surfaces() -> void:
	wheels_off_track = 0
	aquaplaning_factor = 1.0
	water_under_wheels = 0.0
	var load_factor := setup.get_load_factor(speed)
	for i in WHEEL_COUNT:
		var wheel_position := _wheels[i].global_position
		var surface := Track.Surface.ROAD
		if track != null:
			surface = track.classify_point(wheel_position)
		wheel_surfaces[i] = surface

		var surface_grip := 1.0
		match surface:
			Track.Surface.KERB:
				surface_grip = setup.grip_kerb
			Track.Surface.GRASS:
				surface_grip = setup.grip_grass
				wheels_off_track += 1

		var water := weather.get_water_at(wheel_position) if weather != null else 0.0
		var wheel_aquaplaning := compound.get_aquaplaning_factor(speed, water, tyres.wear[i])
		water_under_wheels += water / WHEEL_COUNT
		aquaplaning_factor = minf(aquaplaning_factor, wheel_aquaplaning)
		_wheels[i].wheel_friction_slip = _base_grip[i] * surface_grip * load_factor \
				* tyres.get_grip_factor(i) * compound.get_grip(water) * wheel_aquaplaning
	aquaplaning = aquaplaning_factor < AQUAPLANING_WARNING_FACTOR


# 4. Aerodinámica: resistencia, carga y arrastre del pasto.
#    Devuelve la carga vertical total sobre las ruedas [N] (peso + carga aero).
func _apply_aerodynamics(forward: Vector3) -> float:
	var drag_coef := setup.drag_coef
	var downforce_coef := setup.downforce_coef
	if drs.open:
		drag_coef *= setup.drs_drag_factor
		downforce_coef *= setup.drs_downforce_factor

	var velocity := linear_velocity
	var velocity_length := velocity.length()
	if velocity_length > 0.1:
		var resistance := drag_coef * velocity_length * velocity_length + setup.rolling_resistance
		# El pasto frena: resistencia proporcional a la velocidad por cada rueda.
		resistance += wheels_off_track * setup.grass_drag_per_wheel * velocity_length
		apply_central_force(-velocity / velocity_length * resistance)

	# Carga aerodinámica: empuja el auto contra el piso (más agarre a alta
	# velocidad). Solo si el auto está "derecho".
	var downforce := 0.0
	if global_basis.y.y > 0.5:
		downforce = downforce_coef * speed * speed
		apply_central_force(-global_basis.y * downforce)
	return setup.mass * GRAVITY + downforce


# 5. Motor, caja y frenos.
func _update_powertrain(delta: float, load_total: float) -> void:
	var automatic := Settings.auto_gearbox or not is_player
	var throttle_cmd := throttle_input
	var brake_cmd := brake_input

	# --- Caja automática: marcha atrás -------------------------------------
	if automatic and controls_enabled:
		if drivetrain.gear >= 1:
			if absf(speed) < STOPPED_SPEED and brake_input > 0.5 and throttle_input < 0.1:
				_reverse_hold_timer += delta
				if _reverse_hold_timer >= AUTO_REVERSE_HOLD_TIME:
					drivetrain.set_gear(Drivetrain.GEAR_REVERSE)
			else:
				_reverse_hold_timer = 0.0
		elif drivetrain.gear == Drivetrain.GEAR_REVERSE:
			# En marcha atrás los pedales se invierten: el freno acelera hacia
			# atrás y el acelerador frena y vuelve a primera.
			throttle_cmd = brake_input
			brake_cmd = throttle_input
			if throttle_input > 0.1 and speed > -STOPPED_SPEED:
				drivetrain.set_gear(1)
				_reverse_hold_timer = 0.0
				throttle_cmd = throttle_input
				brake_cmd = 0.0
		elif drivetrain.gear == Drivetrain.GEAR_NEUTRAL and throttle_input > 0.1:
			drivetrain.set_gear(1)

	# --- Limitador de boxes ---------------------------------------------------
	if pit_limiter_on and drivetrain.gear >= 1:
		var limit := setup.get_pit_speed_limit()
		throttle_cmd *= clampf((limit - speed) / PIT_LIMITER_BAND, 0.0, 1.0)
		if speed > limit + PIT_LIMITER_BAND:
			brake_cmd = maxf(brake_cmd, minf((speed - limit) / 10.0, PIT_LIMITER_MAX_BRAKE))

	# --- Motor y caja ----------------------------------------------------------
	var braking := brake_cmd > BRAKE_OVERRIDE_THRESHOLD
	if braking:
		throttle_cmd = 0.0
	var drive_force := drivetrain.update(delta, _get_drive_wheel_speed(), throttle_cmd, automatic)

	# --- ERS: empuje extra -----------------------------------------------------
	var wants_ers := is_player and controls_enabled and InputManager.is_held(InputManager.ACTION_ERS)
	var ers_force := ers.update(delta, wants_ers and not pit_limiter_on, throttle_cmd, brake_cmd, speed)
	if drivetrain.gear >= 1:
		drive_force += ers_force

	# --- Control de tracción: no pedir más de lo que el neumático transmite ---
	var rear_load_per_wheel := load_total * setup.rear_weight_share * 0.5
	var rear_grip := minf(_wheels[WHEEL_RL].wheel_friction_slip, _wheels[WHEEL_RR].wheel_friction_slip)
	var max_drive_per_wheel := setup.traction_control_factor * rear_grip * rear_load_per_wheel
	var drive_per_wheel := clampf(drive_force * 0.5, -max_drive_per_wheel, max_drive_per_wheel)

	# --- Frenos (tipo ABS: nunca más que el agarre disponible) -----------------
	var average_grip := 0.0
	for wheel in _wheels:
		average_grip += wheel.wheel_friction_slip
	average_grip /= WHEEL_COUNT
	var max_brake := minf(setup.max_brake_force, setup.brake_grip_usage * average_grip * load_total)
	var brake_total := brake_cmd * max_brake
	var front_brake := brake_total * brake_bias * 0.5
	var rear_brake := brake_total * (1.0 - brake_bias) * 0.5 + drivetrain.engine_brake_force * 0.5

	# VehicleWheel3D.brake es un impulso por tick: fuerza x delta.
	_wheels[WHEEL_FL].brake = front_brake * delta
	_wheels[WHEEL_FR].brake = front_brake * delta
	_wheels[WHEEL_RL].brake = rear_brake * delta
	_wheels[WHEEL_RR].brake = rear_brake * delta
	# Signo cambiado: engine_force positivo empuja hacia +Z y el auto mira a -Z.
	_wheels[WHEEL_RL].engine_force = -drive_per_wheel
	_wheels[WHEEL_RR].engine_force = -drive_per_wheel

	if _engine_sound != null:
		_engine_sound.set_engine_state(drivetrain.rpm / setup.max_rpm, throttle_cmd)


# 6. Sistemas de F1.
func _update_systems(delta: float) -> void:
	drs.update(brake_input)
	for i in WHEEL_COUNT:
		# get_skidinfo(): 1 = con agarre, 0 = patinando.
		_slide[i] = 1.0 - _wheels[i].get_skidinfo() if _wheels[i].is_in_contact() else 0.0
	tyres.update(delta, absf(speed) * delta * compound.get_wear_multiplier(water_under_wheels),
			lateral_accel, _slide)


# 7. Choques (cambio brusco de velocidad) y vuelco.
func _detect_crash_and_flip(delta: float) -> void:
	var velocity_change := linear_velocity - _previous_velocity
	velocity_change.y = 0.0
	_previous_velocity = linear_velocity
	if _skip_crash_check:
		_skip_crash_check = false
	elif velocity_change.length() > CRASH_MIN_DELTA_V:
		var strength := clampf(velocity_change.length() / CRASH_FULL_DELTA_V, 0.2, 1.0)
		crashed.emit(strength)
		if is_player:
			TelemetryOut.vibrate(TelemetryOut.VIB_CRASH, strength)

	if global_basis.y.y < FLIP_UP_THRESHOLD:
		_flip_timer += delta
		if _flip_timer >= FLIP_TIME:
			_flip_timer = 0.0
			flipped.emit()
	else:
		_flip_timer = 0.0


# 8. Detalles visuales: flap del DRS.
func _update_visuals(delta: float) -> void:
	if _drs_flap != null:
		var target := DRS_FLAP_OPEN_DEG if drs.open else 0.0
		_drs_flap.rotation_degrees.x = move_toward(
				_drs_flap.rotation_degrees.x, target, DRS_FLAP_SPEED_DEG * delta)


# 9. Telemetría hacia el volante y vibraciones de superficie.
func _publish_telemetry() -> void:
	TelemetryOut.publish_state(drivetrain.get_rpm_pct(), drivetrain.gear, get_telemetry_flags())
	if absf(speed) < VIBRATION_MIN_SPEED:
		return
	var strength := clampf(absf(speed) / VIBRATION_FULL_SPEED, 0.3, 1.0)
	# Aquaplaning: un aviso al empezar y después uno cada tanto mientras dure.
	_aquaplaning_vibration_timer = maxf(_aquaplaning_vibration_timer - get_physics_process_delta_time(), 0.0)
	if not aquaplaning:
		_aquaplaning_vibration_timer = 0.0
	elif _aquaplaning_vibration_timer <= 0.0:
		_aquaplaning_vibration_timer = AQUAPLANING_VIBRATION_INTERVAL
		# Cuanto más agarre se pierde, más fuerte el aviso en el volante.
		TelemetryOut.vibrate(TelemetryOut.VIB_AQUAPLANING, clampf((1.0 - aquaplaning_factor) * 2.0, 0.3, 1.0))
	if wheels_off_track > 0:
		TelemetryOut.vibrate(TelemetryOut.VIB_GRASS, strength)
	elif wheel_surfaces.has(Track.Surface.KERB):
		TelemetryOut.vibrate(TelemetryOut.VIB_KERB, strength)


# ==============================================================================
# Internos
# ==============================================================================

# Copia la puesta a punto al cuerpo y a las ruedas.
func _apply_setup() -> void:
	mass = setup.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = setup.center_of_mass
	# Godot aplica por defecto un amortiguamiento lineal global (0.1 1/s) que a
	# 300 km/h frena tanto como toda la resistencia aerodinámica. Se lo
	# reemplaza por cero: la resistencia la modela este script.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = setup.angular_damp
	for i in WHEEL_COUNT:
		var wheel := _wheels[i]
		wheel.wheel_radius = setup.wheel_radius
		wheel.wheel_rest_length = setup.suspension_rest_length
		wheel.suspension_travel = setup.suspension_travel
		wheel.suspension_stiffness = setup.suspension_stiffness
		wheel.damping_compression = setup.damping_compression
		wheel.damping_relaxation = setup.damping_relaxation
		wheel.suspension_max_force = setup.suspension_max_force
		wheel.wheel_roll_influence = setup.roll_influence
		_base_grip[i] = setup.grip_front if i < WHEEL_RL else setup.grip_rear
		wheel.wheel_friction_slip = _base_grip[i]
	# Batalla (distancia entre ejes), para la ayuda de dirección.
	_wheelbase = absf(_wheels[WHEEL_FL].position.z - _wheels[WHEEL_RL].position.z)


# Velocidad lineal de las ruedas motrices [m/s] a partir de su velocidad de
# giro: v = omega x radio. Es la "velocidad de ruedas" que usa el motor.
func _get_drive_wheel_speed() -> float:
	var rpm_sum := 0.0
	var contacts := 0
	for index in [WHEEL_RL, WHEEL_RR]:
		if _wheels[index].is_in_contact():
			rpm_sum += absf(_wheels[index].get_rpm())
			contacts += 1
	if contacts == 0:
		return speed
	var wheel_speed := rpm_sum / contacts * RPM_TO_RAD_S * setup.wheel_radius
	return wheel_speed * signf(speed) if absf(speed) > 0.01 else 0.0


func _on_shift_up() -> void:
	if controls_enabled and not Settings.auto_gearbox:
		if drivetrain.shift_up(speed):
			TelemetryOut.vibrate(TelemetryOut.VIB_SHIFT)


func _on_shift_down() -> void:
	if controls_enabled and not Settings.auto_gearbox:
		if drivetrain.shift_down(speed):
			TelemetryOut.vibrate(TelemetryOut.VIB_SHIFT)


func _on_drs_pressed() -> void:
	if controls_enabled:
		drs.toggle(brake_input)


func _on_pit_limiter_pressed() -> void:
	if controls_enabled:
		pit_limiter_on = not pit_limiter_on


# El encoder del volante ajusta el reparto de frenada.
func _on_encoder_turned(steps: int) -> void:
	brake_bias = clampf(brake_bias + steps * setup.brake_bias_step, 0.4, 0.75)
