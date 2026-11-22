class_name CarSetup
extends Resource
## Recurso con TODOS los parámetros ajustables del auto ("puesta a punto").
##
## Está separado del código para poder probar variantes sin tocar scripts:
## se edita `assets/setups/car_setup_default.tres` desde el Inspector de Godot
## (o se duplica el recurso y se asigna otro al auto).
## Unidades del Sistema Internacional salvo que se indique lo contrario.

const GRAVITY := 9.81
## Fracción del coeficiente de agarre nominal que el auto aprovecha en curva
## sostenida. Sale del skidpad (docs/skidpad.md): el eje delantero satura
## antes y parte del agarre se va en mantener la velocidad.
## En lento rinde ~0,89 y en rápido ~0,97 (medido); entre medio se interpola.
const GRIP_EFFICIENCY_LOW := 0.89
const GRIP_EFFICIENCY_HIGH := 0.96
const GRIP_EFFICIENCY_LOW_SPEED := 15.0    # [m/s]
const GRIP_EFFICIENCY_HIGH_SPEED := 60.0   # [m/s]
## Fracción de la capacidad medida que usan los perfiles de velocidad de los
## rivales y del piloto automático (margen para correcciones).
const PROFILE_USAGE := 0.9
## Piso de la sensibilidad a la carga (el agarre nunca cae por debajo de esto).
const MIN_LOAD_FACTOR := 0.55
## Muestras de la curva de par para buscar la potencia máxima.
const POWER_SAMPLES := 40
const RPM_TO_RAD_S := TAU / 60.0

@export_group("Chasis")
## Masa total del auto con piloto [kg].
@export var mass: float = 800.0
## Centro de masa respecto del origen del auto [m]. Bajo = menos rolido.
@export var center_of_mass: Vector3 = Vector3(0.0, 0.15, 0.09)
## Amortiguamiento de las rotaciones del chasis [1/s]. Un poco ayuda a que el
## auto no quede oscilando después de un trompo.
@export var angular_damp: float = 0.3
## Fracción del peso que apoya en el eje trasero (0..1).
@export_range(0.3, 0.7) var rear_weight_share: float = 0.54

@export_group("Motor")
## Régimen de ralentí [rpm].
@export var idle_rpm: float = 4000.0
## Régimen máximo (limitador) [rpm].
@export var max_rpm: float = 12000.0
## Par máximo del motor [N·m].
@export var peak_torque: float = 520.0
## Curva de par: X = rpm / max_rpm (0..1), Y = fracción del par máximo (0..1).
@export var torque_curve: Curve
## Par de freno motor al soltar el acelerador [N·m].
@export var engine_brake_torque: float = 70.0
## Régimen que sostiene el embrague al arrancar con acelerador a fondo [rpm].
@export var launch_rpm: float = 8000.0
## Rendimiento de la transmisión (0..1).
@export_range(0.5, 1.0) var drivetrain_efficiency: float = 0.92

@export_group("Caja de cambios")
## Relaciones de 1ª a 8ª (sin el diferencial).
@export var gear_ratios: Array[float] = [4.05, 2.96, 2.33, 1.92, 1.64, 1.42, 1.26, 1.115]
## Relación de marcha atrás.
@export var reverse_ratio: float = 4.2
## Relación final (diferencial). Relación total = marcha x final.
@export var final_drive: float = 4.0
## Tiempo de corte de par durante un cambio [s].
@export var shift_time: float = 0.06
## Caja automática: sube de marcha a este régimen [rpm].
@export var auto_upshift_rpm: float = 11600.0
## Caja automática: baja si en la marcha inferior el motor quedaría por
## debajo de este régimen [rpm].
@export var auto_downshift_rpm: float = 9400.0

@export_group("Ruedas y suspensión")
## Radio de la rueda [m].
@export var wheel_radius: float = 0.34
## Longitud en reposo del resorte [m].
@export var suspension_rest_length: float = 0.12
## Recorrido máximo de la suspensión [m].
@export var suspension_travel: float = 0.10
## Rigidez (en unidades de VehicleWheel3D: fuerza = rigidez x masa x compresión).
## Con la carga aerodinámica de un F1 (unas 3,7 veces el peso a 345 km/h)
## la suspensión tiene que ser dura para no hacer tope: con 300 el auto baja
## ~47 mm entre parado y velocidad máxima (medido en test_skidpad.gd), sobre
## 100 mm de recorrido.
@export var suspension_stiffness: float = 300.0
## Amortiguación en compresión y extensión (crítica ≈ raíz(4 x rigidez) / 2 ≈ 17).
@export var damping_compression: float = 10.0
@export var damping_relaxation: float = 16.0
## Fuerza máxima del resorte [N] (debe soportar peso + carga aerodinámica
## + transferencia de carga en frenada).
@export var suspension_max_force: float = 45000.0
## Cuánto inclina la carrocería la fuerza lateral (0 = nada, 1 = realista).
@export_range(0.0, 1.0) var roll_influence: float = 0.04

@export_group("Agarre")
## Coeficiente de agarre de los neumáticos delanteros y traseros en seco.
@export var grip_front: float = 2.15
@export var grip_rear: float = 2.36
## Sensibilidad a la carga: cuánto baja el coeficiente de agarre por cada
## "peso del auto" extra de carga aerodinámica. Un neumático real rinde
## menos (en proporción) cuanto más cargado está; sin esto, con la carga
## de un F1 el auto doblaría a más de 6 g.
@export var tyre_load_sensitivity: float = 0.115
## Multiplicadores de agarre según la superficie.
@export var grip_kerb: float = 0.92
@export var grip_grass: float = 0.45
## Resistencia extra por cada rueda en el pasto [N por m/s].
@export var grass_drag_per_wheel: float = 22.0
## Fracción del agarre teórico que deja usar el control de tracción.
@export var traction_control_factor: float = 1.15

@export_group("Dirección")
## Ángulo máximo de las ruedas a baja velocidad [grados].
@export var steer_angle_max_deg: float = 24.0
## Velocidad a la que el ángulo máximo se reduce a la mitad [m/s].
@export var steer_speed_ref: float = 30.0
## Velocidad de giro del volante [grados de rueda por segundo].
@export var steer_rate_deg: float = 110.0

@export_group("Frenos")
## Fuerza total máxima de frenado [N].
@export var max_brake_force: float = 34000.0
## Reparto de frenada hacia adelante (0.5 = parejo).
@export_range(0.4, 0.75) var brake_bias: float = 0.58
## Paso de ajuste del reparto con el encoder del volante.
@export var brake_bias_step: float = 0.01
## Fracción del agarre disponible que usa el freno (tipo ABS).
@export var brake_grip_usage: float = 0.95

@export_group("Aerodinámica")
## Resistencia: F = drag_coef x v² [N].
@export var drag_coef: float = 0.78
## Carga aerodinámica: F = downforce_coef x v² [N].
## ½·ρ·(CL·A) con ρ = 1,225 kg/m³ y CL·A ≈ 5,2 m² (F1 con carga media).
@export var downforce_coef: float = 3.2
## Resistencia a la rodadura constante [N].
@export var rolling_resistance: float = 150.0
## Con DRS abierto la resistencia se multiplica por este factor.
@export var drs_drag_factor: float = 0.74
## Con DRS abierto la carga se multiplica por este factor.
@export var drs_downforce_factor: float = 0.88

@export_group("ERS")
## Capacidad de la batería [J].
@export var ers_capacity: float = 4.0e6
## Carga inicial (0..1).
@export_range(0.0, 1.0) var ers_initial_charge: float = 0.6
## Potencia extra al desplegar [W].
@export var ers_deploy_power: float = 160000.0
## Fuerza máxima de empuje del ERS [N] (limita el efecto a baja velocidad).
@export var ers_max_force: float = 3200.0
## Potencia de recarga con el freno a fondo [W].
@export var ers_regen_power: float = 260000.0
## Potencia de recarga al levantar el acelerador [W].
@export var ers_lift_regen_power: float = 40000.0

@export_group("Neumáticos")
## Distancia para llegar al 100 % de desgaste rodando derecho con el
## compuesto medio [m]. En Carrera la sesión la acorta en proporción a la
## distancia de la carrera (ver RaceSession), para que el desgaste importe
## también en carreras de pocas vueltas.
@export var tyre_life_distance: float = 120000.0
## Desgaste extra por exigencia lateral (por cada g de aceleración lateral).
@export var tyre_wear_lateral_factor: float = 0.35
## Desgaste por segundo de una rueda que patina por completo.
@export var tyre_wear_slide_rate: float = 0.005
## Pérdida de agarre con el neumático 100 % gastado (0.30 = -30 %). No es
## lineal: hasta el "acantilado" se pierde poco y después cae rápido (ver
## F1Systems.Tyres.get_loss_share).
@export var tyre_max_grip_loss: float = 0.30

@export_group("Boxes")
## Velocidad máxima en el pit lane [km/h].
@export var pit_speed_limit_kmh: float = 80.0


## Carga aerodinámica por unidad de masa y de v² [1/m].
func get_aero_per_mass() -> float:
	return downforce_coef / mass


## Resistencia aerodinámica por unidad de masa y de v² [1/m].
func get_drag_per_mass() -> float:
	return drag_coef / mass


## Factor de agarre por sensibilidad a la carga a una velocidad (1 = sin carga aerodinámica).
func get_load_factor(speed: float) -> float:
	var extra_weights := downforce_coef * speed * speed / (mass * GRAVITY)
	return maxf(1.0 - tyre_load_sensitivity * extra_weights, MIN_LOAD_FACTOR)


## Aceleración lateral que el auto puede sostener a una velocidad [m/s²]
## (neumático nuevo; `grip_scale` = compuesto, agua, etc.).
func get_lateral_capacity(speed: float, grip_scale: float = 1.0) -> float:
	var efficiency := lerpf(GRIP_EFFICIENCY_LOW, GRIP_EFFICIENCY_HIGH, clampf(inverse_lerp(
			GRIP_EFFICIENCY_LOW_SPEED, GRIP_EFFICIENCY_HIGH_SPEED, speed), 0.0, 1.0))
	return efficiency * minf(grip_front, grip_rear) * grip_scale * get_load_factor(speed) \
			* (GRAVITY + get_aero_per_mass() * speed * speed)


## Aceleración lateral que suponen los perfiles de velocidad de la IA [m/s²].
func get_profile_lateral(speed: float, grip_scale: float = 1.0) -> float:
	return PROFILE_USAGE * get_lateral_capacity(speed, grip_scale)


## Desaceleración máxima de frenado a una velocidad [m/s²], sin contar la
## resistencia aerodinámica.
func get_brake_capacity(speed: float, grip_scale: float = 1.0) -> float:
	var average_grip := (grip_front + grip_rear) * 0.5 * grip_scale * get_load_factor(speed)
	var by_grip := brake_grip_usage * average_grip * (GRAVITY + get_aero_per_mass() * speed * speed)
	return minf(by_grip, max_brake_force / mass)


## Aceleración máxima por tracción (ruedas traseras) a una velocidad [m/s²].
func get_traction_capacity(speed: float, grip_scale: float = 1.0) -> float:
	return rear_weight_share * grip_rear * grip_scale * get_load_factor(speed) \
			* (GRAVITY + get_aero_per_mass() * speed * speed)


## Potencia máxima en las ruedas [W] (máximo de par x régimen sobre la curva).
func get_peak_power() -> float:
	var best := 0.0
	for i in range(1, POWER_SAMPLES + 1):
		var x := float(i) / POWER_SAMPLES
		best = maxf(best, peak_torque * get_torque_factor(x) * x * max_rpm * RPM_TO_RAD_S)
	return best * drivetrain_efficiency


## Fracción del par máximo disponible para un régimen normalizado (0..1).
func get_torque_factor(rpm_normalized: float) -> float:
	var x := clampf(rpm_normalized, 0.0, 1.0)
	if torque_curve != null:
		return clampf(torque_curve.sample_baked(x), 0.0, 1.0)
	# Curva de respaldo (si el recurso no trae una): sube hasta ~80 % del
	# régimen y cae suavemente hacia el limitador.
	if x < 0.8:
		return lerpf(0.55, 1.0, x / 0.8)
	return lerpf(1.0, 0.86, (x - 0.8) / 0.2)


## Relación total (marcha x diferencial) de una marcha. 0 = punto muerto.
func get_total_ratio(gear: int) -> float:
	if gear == 0:
		return 0.0
	if gear < 0:
		return reverse_ratio * final_drive
	var index := clampi(gear, 1, gear_ratios.size()) - 1
	return gear_ratios[index] * final_drive


## Cantidad de marchas hacia adelante.
func get_gear_count() -> int:
	return gear_ratios.size()


## Velocidad límite del pit lane en m/s.
func get_pit_speed_limit() -> float:
	return pit_speed_limit_kmh / 3.6
