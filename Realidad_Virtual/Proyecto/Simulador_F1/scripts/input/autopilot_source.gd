class_name AutopilotSource
extends InputSource
## Fuente de entrada: piloto automático (modo demostración y pruebas).
##
## Conduce el auto del jugador "apretando" los mismos controles virtuales que
## usaría una persona: genera dirección, acelerador y freno y los entrega por
## la misma interfaz que el teclado o el volante. Sirve para:
##   - probar toda la cadena InputManager -> auto -> cronometraje sin manos;
##   - dejar el simulador en modo demostración (por ejemplo para filmar el
##     volante físico mostrando shift lights y vibración);
##   - las pruebas automáticas de `tools/godot/`.
##
## Algoritmo: persecución pura ("pure pursuit") de un punto adelantado sobre
## la LÍNEA DE CARRERA del circuito + control proporcional de velocidad contra
## el perfil de velocidad, que se calcula con la capacidad real del auto (su
## CarSetup): ver Track.build_speed_profile.

# Distancia de mira: base [m] + segundos de anticipación x velocidad.
const LOOKAHEAD_BASE := 7.0
const LOOKAHEAD_TIME := 0.28
# Ganancias de los controladores.
const STEER_GAIN := 1.4
# Anticipación de la curvatura de la línea [s] y batalla del auto [m].
const CURVATURE_PREVIEW_TIME := 0.12
const WHEELBASE := 3.4
# Corrección por error lateral: ganancia [1/s] y velocidad mínima del cálculo [m/s].
const CROSS_TRACK_GAIN := 1.2
const CROSS_TRACK_MIN_SPEED := 10.0
# Anticipación del freno [s] y comando mínimo de freno (por debajo, no frena).
const BRAKE_PREVIEW_TIME := 0.3
const BRAKE_MIN_COMMAND := 0.03
const THROTTLE_GAIN := 0.5
const BRAKE_GAIN := 0.22
# Margen de velocidad [m/s] antes de empezar a frenar.
const BRAKE_DEADBAND := 0.8
# Anticipación con la que se lee el perfil de velocidad [s].
const SPEED_PREVIEW_TIME := 0.12
# Parámetros del perfil de velocidad del piloto automático.
const PROFILE_TOP_SPEED := 95.0
# El ERS se usa en recta cuando la velocidad objetivo es alta.
const ERS_MIN_TARGET_SPEED := 70.0
# Tiempo entre intentos de abrir el DRS dentro de una zona [s].
const DRS_RETRY_INTERVAL := 0.5
# Tránsito: distancia a la que reacciona ante otro auto [m] (más un extra por
# velocidad [s]), separación lateral para considerarlo "al costado" [m],
# corrimiento con el que lo pasa [m] y distancia mínima de seguimiento.
const TRAFFIC_LOOK_AHEAD := 30.0
const TRAFFIC_LOOK_AHEAD_TIME := 0.35
const TRAFFIC_LATERAL_CLEARANCE := 2.6
const TRAFFIC_PASS_LATERAL := 3.3
const TRAFFIC_MIN_GAP := 8.0
const TRAFFIC_GAP_TIME := 0.25
const TRAFFIC_MAX_LATERAL := 4.6
# Distancia mínima del eje del auto al borde del asfalto al pasar [m] y
# distancia de seguimiento cuando no hay lugar para pasar [m].
const TRAFFIC_EDGE_MARGIN := 1.6
const TRAFFIC_FOLLOW_GAP := 14.0
# Trabado: por debajo de esta velocidad [m/s] durante este tiempo [s], queriendo
# ir al menos a la velocidad indicada [m/s], pide el reset.
const STUCK_SPEED := 1.0
const STUCK_TIME := 4.0
const STUCK_MIN_TARGET_SPEED := 5.0
# Tiempo para pasar de la línea de carrera al carril de sobrepaso (y volver) [s].
const AVOID_BLEND_TIME := 0.9

## Multiplicador del perfil de velocidad (1 = usa todo el agarre estimado).
var pace: float = 1.0
## Factor de agarre por neumático y clima (1 = slick en seco).
var grip_scale: float = 1.0
## Aquaplaning para el perfil de velocidad (ver Track.build_speed_profile).
var aquaplaning: Vector3 = Vector3.ZERO
## Corrimiento lateral respecto del eje [m] (positivo = derecha).
var lateral_offset: float = 0.0

var _car: Node3D = null      # En la práctica, un F1Car.
var _track: Track = null
var _profile: PackedFloat32Array = PackedFloat32Array()
var _drs_timer: float = 0.0
var _obstacles: Array = []
var _lateral_current: float = 0.0
var _avoid_lane: float = 0.0
var _avoid_blend: float = 0.0
var _stuck_timer: float = 0.0
var _offset: float = 0.0
var _has_offset: bool = false


func get_id() -> String:
	return Settings.SOURCE_AUTOPILOT


func get_label() -> String:
	return "Piloto automático (demo)"


func is_available() -> bool:
	return true


func get_status_text() -> String:
	return "Demo activa" if _is_ready() else "Sin auto"


## true si hay un auto y un circuito válidos para conducir.
func has_target() -> bool:
	return _is_ready()


## Define qué auto se conduce y sobre qué circuito.
func set_target(car: Node3D, track: Node3D) -> void:
	_car = car
	_track = track as Track
	grip_scale = 1.0
	aquaplaning = Vector3.ZERO
	_has_offset = false
	_profile = PackedFloat32Array()
	_obstacles = []
	_lateral_current = lateral_offset
	_avoid_blend = 0.0


## Condiciones de agarre (neumático + agua en pista). El perfil de velocidad
## se recalcula en el próximo tick.
func set_conditions(new_grip_scale: float, new_aquaplaning: Vector3) -> void:
	grip_scale = new_grip_scale
	aquaplaning = new_aquaplaning
	_profile = PackedFloat32Array()


## Otros autos en pista (Node3D con propiedad `speed`) que hay que esquivar.
func set_obstacles(obstacles: Array) -> void:
	_obstacles = obstacles


func update(delta: float) -> void:
	if not _is_ready():
		release_all()
		return
	if _profile.is_empty():
		# Perfil con la capacidad real del auto (su puesta a punto) sobre la
		# línea de carrera del circuito.
		_profile = _track.build_speed_profile(_car.setup, grip_scale, PROFILE_TOP_SPEED, aquaplaning)

	var forward: Vector3 = -_car.global_basis.z
	var velocity: Vector3 = _car.linear_velocity
	var speed := velocity.dot(forward)
	# Progreso con búsqueda local (ver Track.get_offset_near).
	if not _has_offset:
		_offset = _track.get_closest_offset(_car.global_position)
		_has_offset = true
	else:
		_offset = _track.get_offset_near(_car.global_position, _offset)
	var offset := _offset

	# --- Tránsito: elegir carril y, si no hay lugar, no pasar de la velocidad
	#     del auto de adelante ----------------------------------------------------
	var traffic := _check_traffic(offset, speed)
	var avoiding := is_finite(traffic.x)
	if avoiding:
		_avoid_lane = traffic.x
	_avoid_blend = move_toward(_avoid_blend, 1.0 if avoiding else 0.0, delta / AVOID_BLEND_TIME)

	# --- Dirección: apuntar a un punto adelantado de la línea de carrera ------
	#     (o del carril de sobrepaso mientras esquiva a otro auto)
	var lookahead := LOOKAHEAD_BASE + LOOKAHEAD_TIME * maxf(speed, 0.0)
	var line_lateral := _track.get_line_lateral(offset + lookahead) + lateral_offset
	_lateral_current = lerpf(line_lateral, _avoid_lane, _avoid_blend)
	var target_point := _track.get_transform_at(offset + lookahead, _lateral_current).origin
	var local_target: Vector3 = _car.global_transform.affine_inverse() * target_point
	# En coordenadas del auto: -Z es adelante y +X es la derecha.
	var angle_to_target := atan2(local_target.x, -local_target.z)
	# Anticipación: el ángulo que hace falta para seguir la curvatura de la
	# línea un instante más adelante (modelo de bicicleta: tan(ángulo) =
	# batalla x curvatura). Sin esto la persecución sola llega tarde a las
	# curvas cerradas.
	var curvature_ahead := _track.get_line_curvature(offset + maxf(speed, 0.0) * CURVATURE_PREVIEW_TIME)
	var feedforward := atan(WHEELBASE * curvature_ahead) * (1.0 - _avoid_blend)
	# Corrección por error lateral: cuánto se apartó el auto de la línea
	# (positivo = la línea quedó a su derecha). Pesa menos a alta velocidad.
	var lateral_error := lerpf(_track.get_line_lateral(offset) + lateral_offset, _avoid_lane, _avoid_blend) \
			- _track.get_lateral(_car.global_position, offset)
	var correction := atan(CROSS_TRACK_GAIN * lateral_error / maxf(speed, CROSS_TRACK_MIN_SPEED))
	var max_angle: float = _car.get_max_steer_angle()
	raw_steer = clampf((feedforward + correction + STEER_GAIN * angle_to_target) / maxf(max_angle, 0.001), -1.0, 1.0)

	# --- Velocidad: seguir el perfil del circuito ------------------------------
	#     El desgaste baja el agarre: la velocidad de curva va con su raíz.
	var worn_grip: float = _car.tyres.get_average_grip_factor()
	var target_speed := _track.sample_profile(_profile, offset + speed * SPEED_PREVIEW_TIME) \
			* pace * sqrt(worn_grip)
	target_speed = minf(target_speed, traffic.y)
	_update_stuck(delta, speed, target_speed)
	var error := target_speed - speed
	raw_throttle = clampf(error * THROTTLE_GAIN, 0.0, 1.0)
	# Freno: anticipación (la desaceleración que pide el perfil más adelante,
	# como fracción de la capacidad de frenado) + corrección por el exceso.
	var speed_ahead: float = _track.sample_profile(_profile, offset + maxf(speed, 0.0) * BRAKE_PREVIEW_TIME) \
			* pace * sqrt(worn_grip)
	var wanted_decel: float = (speed - minf(speed_ahead, traffic.y)) / BRAKE_PREVIEW_TIME \
			- _car.setup.get_drag_per_mass() * speed * speed
	var brake_capacity: float = maxf(_car.setup.get_brake_capacity(speed, grip_scale), 1.0)
	raw_brake = clampf(wanted_decel / brake_capacity + (-error - BRAKE_DEADBAND) * BRAKE_GAIN, 0.0, 1.0)
	if raw_brake > BRAKE_MIN_COMMAND:
		raw_throttle = 0.0
	else:
		raw_brake = 0.0

	# --- Botones: ERS en recta y DRS cuando está disponible --------------------
	_set_button(&"ers", target_speed > ERS_MIN_TARGET_SPEED and raw_throttle > 0.9)
	_drs_timer = maxf(_drs_timer - delta, 0.0)
	var wants_drs: bool = _car.drs.is_available() and not _car.drs.open and raw_brake <= 0.0
	if wants_drs and _drs_timer <= 0.0:
		# Pulso de un tick: aprieta y suelta el botón.
		_set_button(&"drs", true)
		_drs_timer = DRS_RETRY_INTERVAL
	else:
		_set_button(&"drs", false)


# Si quedó trabado (contra un muro o contra otro auto) pide el "reset", igual
# que haría un piloto con el botón del volante: la sesión lo devuelve a la pista.
func _update_stuck(delta: float, speed: float, target_speed: float) -> void:
	var stuck: bool = absf(speed) < STUCK_SPEED and target_speed > STUCK_MIN_TARGET_SPEED \
			and _car.controls_enabled
	_stuck_timer = _stuck_timer + delta if stuck else 0.0
	_set_button(&"reset", _stuck_timer > STUCK_TIME)
	if _stuck_timer > STUCK_TIME:
		_stuck_timer = 0.0
		_avoid_blend = 0.0


# Devuelve Vector2(carril de sobrepaso, velocidad máxima por tránsito).
# El carril es INF cuando no hay que esquivar a nadie (sigue la línea de carrera).
func _check_traffic(offset: float, speed: float) -> Vector2:
	var lane := INF
	var speed_cap := INF
	if _obstacles.is_empty():
		return Vector2(lane, speed_cap)
	var my_lateral := _track.get_lateral(_car.global_position, offset)
	var look_ahead := TRAFFIC_LOOK_AHEAD + maxf(speed, 0.0) * TRAFFIC_LOOK_AHEAD_TIME
	var nearest_gap := INF
	# En pistas angostas no se acerca tanto al borde.
	var max_lateral := minf(TRAFFIC_MAX_LATERAL, _track.half_width - TRAFFIC_EDGE_MARGIN)
	for obstacle in _obstacles:
		if not is_instance_valid(obstacle):
			continue
		# Los rivales (AiCar) ya conocen su posición sobre el trazado.
		var rival := obstacle as AiCar
		if rival == null or rival.state != AiCar.State.ON_TRACK:
			continue   # En boxes no estorba.
		var obstacle_offset := rival.track_offset
		var gap := _track.distance_ahead(offset, obstacle_offset)
		if gap > look_ahead or gap > nearest_gap:
			continue
		var obstacle_lateral := rival.lateral
		nearest_gap = gap
		if absf(obstacle_lateral - my_lateral) < TRAFFIC_LATERAL_CLEARANCE:
			# Está adelante en el mismo carril: lo pasa por el lado con más lugar.
			var side := 1.0 if obstacle_lateral < 0.0 else -1.0
			lane = clampf(obstacle_lateral + side * TRAFFIC_PASS_LATERAL, -max_lateral, max_lateral)
			var close := gap < TRAFFIC_MIN_GAP + speed * TRAFFIC_GAP_TIME
			if absf(lane - obstacle_lateral) < TRAFFIC_LATERAL_CLEARANCE:
				# Pista angosta: no hay lugar para pasarlo, lo sigue.
				lane = INF
				close = gap < TRAFFIC_FOLLOW_GAP + speed * TRAFFIC_GAP_TIME
			if close:
				speed_cap = maxf(float(obstacle.get("speed")), 0.0)
		else:
			# Ya está al costado: mantiene su carril hasta superarlo.
			lane = clampf(my_lateral, -max_lateral, max_lateral)
			speed_cap = INF
	return Vector2(lane, speed_cap)


func _is_ready() -> bool:
	return _car != null and is_instance_valid(_car) and _track != null and is_instance_valid(_track)
