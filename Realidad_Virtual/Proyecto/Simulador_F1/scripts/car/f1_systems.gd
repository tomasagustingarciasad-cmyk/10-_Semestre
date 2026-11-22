class_name F1Systems
extends RefCounted
## Sistemas propios de un Fórmula 1: DRS, ERS y desgaste de neumáticos.
##
## Son tres modelos chicos e independientes, agrupados en un solo archivo.
## Ninguno aplica fuerzas ni lee entradas: reciben datos del auto y devuelven
## factores o fuerzas que el auto usa (ver f1_car.gd).


# ==============================================================================
# DRS (alerón trasero móvil)
# ==============================================================================
class Drs:
	extends RefCounted
	## Reglas:
	##   - solo se puede abrir dentro de una zona de DRS (Area3D del circuito);
	##   - se cierra solo al frenar o al salir de la zona;
	##   - abierto reduce la resistencia (más velocidad final) y algo de carga.

	# Freno por encima del cual el alerón se cierra.
	const BRAKE_CLOSE_THRESHOLD := 0.08

	## La sesión puede deshabilitarlo (por ejemplo antes de la largada).
	var enabled: bool = true
	## true = alerón abierto.
	var open: bool = false
	## true mientras el auto está dentro de una zona de DRS. Lo actualiza la
	## sesión consultando las Area3D del circuito.
	var in_zone: bool = false

	## true si el piloto puede abrir el alerón ahora.
	func is_available() -> bool:
		return enabled and in_zone

	## El piloto apretó el botón: abre si puede, cierra si estaba abierto.
	func toggle(brake: float) -> void:
		if open:
			open = false
		elif is_available() and brake < BRAKE_CLOSE_THRESHOLD:
			open = true

	## Cierre automático. Llamar en cada tick.
	func update(brake: float) -> void:
		if open and (not is_available() or brake >= BRAKE_CLOSE_THRESHOLD):
			open = false

	## Cierra el alerón (al reubicar el auto).
	func reset() -> void:
		open = false
		in_zone = false


# ==============================================================================
# ERS (recuperación y despliegue de energía)
# ==============================================================================
class Ers:
	extends RefCounted
	## Batería que se carga al frenar (y un poco al levantar) y se gasta como
	## empuje extra mientras se mantiene el botón ERS con el acelerador pisado.

	# Velocidad mínima [m/s] para recuperar o desplegar energía.
	const MIN_SPEED := 8.0
	# Acelerador mínimo para desplegar.
	const DEPLOY_MIN_THROTTLE := 0.3
	# Freno mínimo para considerar que se está frenando.
	const REGEN_MIN_BRAKE := 0.05

	var setup: CarSetup
	## Energía almacenada [J].
	var energy: float = 0.0
	## true mientras se está entregando potencia extra.
	var deploying: bool = false
	## true mientras se está recargando.
	var harvesting: bool = false

	func _init(car_setup: CarSetup) -> void:
		setup = car_setup
		reset()

	## Carga de la batería 0..1.
	func get_charge() -> float:
		return clampf(energy / setup.ers_capacity, 0.0, 1.0)

	func reset() -> void:
		energy = setup.ers_capacity * setup.ers_initial_charge
		deploying = false
		harvesting = false

	## Devuelve la fuerza extra de empuje [N] para este tick.
	func update(delta: float, wants_deploy: bool, throttle: float, brake: float, speed: float) -> float:
		var force := 0.0
		var moving := speed > MIN_SPEED
		deploying = wants_deploy and throttle > DEPLOY_MIN_THROTTLE and energy > 0.0 and moving
		harvesting = false

		if deploying:
			# P = F x v  ->  F = P / v (acotada para no exagerar a baja velocidad).
			force = minf(setup.ers_deploy_power / speed, setup.ers_max_force) * throttle
			energy -= setup.ers_deploy_power * throttle * delta
		elif moving and brake > REGEN_MIN_BRAKE:
			energy += setup.ers_regen_power * brake * delta
			harvesting = true
		elif moving and throttle < DEPLOY_MIN_THROTTLE * 0.2:
			energy += setup.ers_lift_regen_power * delta
			harvesting = true

		energy = clampf(energy, 0.0, setup.ers_capacity)
		return force


# ==============================================================================
# Neumáticos
# ==============================================================================
class Tyres:
	extends RefCounted
	## Desgaste progresivo por rueda (0 = nuevo, 1 = gastado). El agarre se
	## pierde en dos tramos: una MESETA en la que el neumático casi no cae y,
	## pasado el "acantilado", una caída rápida. Se restablece al parar en boxes.

	const WHEEL_COUNT := 4
	const GRAVITY := 9.81
	## Desgaste en el que termina la meseta y empieza el acantilado.
	const CLIFF_WEAR := 0.6
	## Parte de la pérdida máxima que ya se perdió al llegar al acantilado.
	const PLATEAU_LOSS_SHARE := 0.25
	## Desgaste extra medio por la exigencia lateral en una vuelta rápida
	## (medido con el piloto automático). Lo usan las estimaciones de
	## estrategia y el desgaste simplificado de los rivales.
	const TYPICAL_LOAD_FACTOR := 1.45

	var setup: CarSetup
	## Distancia para llegar al 100 % de desgaste rodando derecho con el
	## compuesto medio [m]. La fija la sesión (ver SessionBase).
	var life_distance: float = 120000.0
	## Desgaste por rueda, en el orden: del. izq., del. der., tras. izq., tras. der.
	var wear: Array[float] = [0.0, 0.0, 0.0, 0.0]

	func _init(car_setup: CarSetup) -> void:
		setup = car_setup
		life_distance = car_setup.tyre_life_distance

	## Fracción de la pérdida máxima de agarre para un desgaste (0..1):
	## meseta lineal hasta CLIFF_WEAR y después una caída cuadrática.
	static func get_loss_share(wear_value: float) -> float:
		var w := clampf(wear_value, 0.0, 1.0)
		if w <= CLIFF_WEAR:
			return PLATEAU_LOSS_SHARE * w / CLIFF_WEAR
		var beyond := (w - CLIFF_WEAR) / (1.0 - CLIFF_WEAR)
		return PLATEAU_LOSS_SHARE + (1.0 - PLATEAU_LOSS_SHARE) * beyond * beyond

	## Neumáticos nuevos (parada en boxes).
	func reset() -> void:
		for i in WHEEL_COUNT:
			wear[i] = 0.0

	## Multiplicador de agarre de la rueda `index` (1 = nuevo).
	func get_grip_factor(index: int) -> float:
		return 1.0 - setup.tyre_max_grip_loss * get_loss_share(wear[index])

	## Multiplicador de agarre promedio de las cuatro ruedas.
	func get_average_grip_factor() -> float:
		var total := 0.0
		for i in WHEEL_COUNT:
			total += get_grip_factor(i)
		return total / WHEEL_COUNT

	## Desgaste promedio de las cuatro ruedas (0..1).
	func get_average_wear() -> float:
		var total := 0.0
		for value in wear:
			total += value
		return total / WHEEL_COUNT

	## Acumula desgaste.
	##   distance:      metros recorridos en este tick
	##   lateral_accel: aceleración lateral del auto [m/s²] (con signo:
	##                  positiva = curva a la derecha, carga las ruedas izquierdas)
	##   slide:         por rueda, 0 = con agarre .. 1 = patinando del todo
	func update(delta: float, distance: float, lateral_accel: float, slide: Array[float]) -> void:
		var lateral_g := lateral_accel / GRAVITY
		for i in WHEEL_COUNT:
			var is_left := i % 2 == 0
			# La rueda exterior a la curva es la que más trabaja.
			var load_g := maxf(lateral_g if is_left else -lateral_g, 0.0) + absf(lateral_g) * 0.3
			var rolling := distance / life_distance * (1.0 + load_g * setup.tyre_wear_lateral_factor)
			var sliding := slide[i] * setup.tyre_wear_slide_rate * delta
			wear[i] = clampf(wear[i] + rolling + sliding, 0.0, 1.0)
