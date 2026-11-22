class_name AiCar
extends AnimatableBody3D
## Auto rival con IA simple (nivel Carrera).
##
## No usa física de vehículo: es un cuerpo cinemático que avanza sobre el eje
## del circuito (Path3D) siguiendo un perfil de velocidad por tramo calculado
## a partir de la curvatura (Track.build_speed_profile). Cada rival tiene:
##   - una "habilidad" que escala ese perfil (qué tan cerca del límite va);
##   - una pequeña variación de ritmo en el tiempo (no son relojes);
##   - un carril preferido (corrimiento lateral) para no ir todos en fila;
##   - una parada en boxes en la vuelta que le asigna la carrera.
## Además esquiva al jugador: si lo alcanza se corre de carril y, si no hay
## lugar, levanta para no embestirlo.

enum State { ON_TRACK, IN_PIT_LANE, PIT_STOPPED }

const GRAVITY := 9.81
# Modelo de aceleración: a = min(tracción, potencia/masa / v) - arrastre·v².
# Frenado: fracción del agarre del perfil y carga aerodinámica por masa.
# Anticipación con la que se lee el perfil [s].
const PROFILE_PREVIEW_TIME := 0.1
# Variación de ritmo: amplitud relativa y velocidad angular [rad/s].
const PACE_VARIATION := 0.015
const PACE_VARIATION_SPEED := 0.21
# Velocidad de cambio de carril [m/s].
const LATERAL_SPEED := 6.0
# Esquive del jugador.
const AVOID_LOOK_AHEAD := 30.0        ## Distancia a la que empieza a reaccionar [m]
const AVOID_LATERAL_CLEARANCE := 2.6  ## Separación lateral para considerarlo "al costado" [m]
const AVOID_PASS_LATERAL := 3.2       ## Corrimiento respecto del jugador al pasarlo [m]
const AVOID_MIN_GAP := 7.0            ## Distancia mínima de seguimiento [m]
const AVOID_GAP_TIME := 0.25          ## Distancia extra por velocidad [s]
const MAX_LATERAL := 4.6              ## Corrimiento máximo dentro del asfalto [m]
const LATERAL_EDGE_MARGIN := 1.5      ## Distancia mínima del eje del auto al borde [m]
const REFERENCE_HALF_WIDTH := 6.5     ## Medio ancho para el que se definieron los carriles [m]
# Boxes.
## Cuánto se aparta de la línea de carrera hacia su carril preferido (0..1).
const LANE_SCALE := 0.35
## Velocidad mínima para el cálculo potencia / velocidad [m/s].
const MIN_POWER_SPEED := 10.0

const PIT_SPEED_LIMIT := 80.0 / 3.6
const PIT_APPROACH_DISTANCE := 160.0  ## Antes de la entrada se abre hacia boxes [m]
const PIT_APPROACH_LATERAL := 3.4     ## Carril del lado de boxes (derecha) [m]
const PIT_BOX_APPROACH := 28.0        ## Distancia al box en la que cambia de carril [m]
const PIT_STOP_TIME := 2.8
const PIT_BRAKE := 14.0
const PIT_ACCELERATION := 7.0
# Ritmo relativo después de terminar la carrera (vuelta de honor).
const COOLDOWN_PACE := 0.6
# Altura del origen sobre el eje de la pista (espesor del asfalto).
const ROAD_HEIGHT := 0.03

## Se emite al completar una vuelta. lap = número de vuelta completada.
signal lap_completed(car: AiCar, lap: int)
## Se emite al terminar una parada en boxes (ya con el compuesto nuevo).
signal pit_stop_completed(car: AiCar)

@export var driver_name: String = "Rival"
@export var primary_color: Color = Color(0.8, 0.1, 0.1)
@export var secondary_color: Color = Color(1.0, 1.0, 1.0)
## Habilidad: fracción del perfil de velocidad que usa (0.8 lento .. 1.0 al límite).
@export_range(0.7, 1.05) var skill: float = 0.93
## Multiplicador de ritmo por la dificultad elegida en Opciones.
var difficulty: float = 1.0
## Carril preferido [m] (positivo = derecha del eje).
@export var lane: float = 0.0

## false = quieto en la grilla esperando la largada.
var active: bool = false
var track: Track = null
var profile: PackedFloat32Array = PackedFloat32Array()
## Puesta a punto del auto (la misma del jugador) y factor de agarre por
## compuesto y agua con los que se construyó el perfil.
var setup: CarSetup = null
var grip_scale: float = 1.0
## Desgaste simplificado de los neumáticos (0..1): crece con la distancia.
## `tyre_life` es la vida del medio [m] (0 = sin desgaste) y
## `wear_multiplier` el del compuesto montado.
var wear: float = 0.0
var tyre_life: float = 0.0
var wear_multiplier: float = 1.0
## Auto del jugador (para esquivarlo). Puede ser null.
var player: Node3D = null

var state: State = State.ON_TRACK
var speed: float = 0.0
## Distancia total recorrida desde la línea de largada (negativa en la grilla).
var total_distance: float = 0.0
var track_offset: float = 0.0
var lateral: float = 0.0
var laps_completed: int = 0
## Vuelta (1 = la primera) en la que entra a boxes. 0 = no para.
var pit_on_lap: int = 0
var pit_stops: int = 0
var pit_box_index: int = 1
## Compuesto montado y el que va a montar en la próxima parada.
var compound: TyreCompound = null
var next_compound: TyreCompound = null
## Progreso del jugador sobre el trazado (lo informa la carrera en cada tick).
var player_offset: float = -1.0
## true cuando ya cruzó la meta en la última vuelta.
var finished: bool = false
var finish_time: float = 0.0
var best_lap_time: float = 0.0
var last_lap_start_time: float = 0.0

var _pace_phase: float = 0.0
var _pit_offset: float = 0.0
var _pit_distance_at_entry: float = 0.0
var _pit_timer: float = 0.0
var _pit_served: bool = false
var _elapsed: float = 0.0
var _max_lateral: float = MAX_LATERAL


func _ready() -> void:
	_pace_phase = randf() * TAU
	var model := get_node_or_null("Modelo") as CarVisual
	if model != null:
		model.set_livery(primary_color, secondary_color)


## Coloca al rival en un cajón de la grilla.
func place_on_grid(circuit: Track, slot: int) -> void:
	track = circuit
	var grid_distance := track.grid_first_row_distance + track.grid_row_spacing * slot
	total_distance = -grid_distance
	track_offset = track.wrap_offset(total_distance)
	lateral = -track.grid_lateral if slot % 2 == 0 else track.grid_lateral
	# En pistas angostas los carriles se acercan al eje.
	_max_lateral = track.half_width - LATERAL_EDGE_MARGIN
	lane = clampf(lane * track.half_width / REFERENCE_HALF_WIDTH, -_max_lateral, _max_lateral)
	speed = 0.0
	state = State.ON_TRACK
	_apply_transform()


func _physics_process(delta: float) -> void:
	if track == null or not active:
		constant_linear_velocity = Vector3.ZERO
		return
	_elapsed += delta
	match state:
		State.ON_TRACK:
			_drive_on_track(delta)
		State.IN_PIT_LANE, State.PIT_STOPPED:
			_drive_in_pits(delta)
	_apply_transform()


# ==============================================================================
# Conducción en pista
# ==============================================================================
func _drive_on_track(delta: float) -> void:
	# 1. Velocidad objetivo: perfil del tramo x habilidad x variación de ritmo.
	# El desgaste baja el agarre: la velocidad de curva va con su raíz.
	var worn_grip := 1.0 - setup.tyre_max_grip_loss * F1Systems.Tyres.get_loss_share(wear)
	var pace := skill * difficulty * sqrt(worn_grip) * (1.0 + PACE_VARIATION * sin(_elapsed * PACE_VARIATION_SPEED + _pace_phase))
	if finished:
		pace = COOLDOWN_PACE
	var target_speed := track.sample_profile(profile, track_offset + speed * PROFILE_PREVIEW_TIME) * pace
	# Sigue la línea de carrera, corrido hacia su carril preferido.
	var lane_target := track.get_line_lateral(track_offset) + lane * LANE_SCALE

	# 2. Si le toca parar, antes de la entrada se abre hacia el lado de boxes
	#    para no estorbar. Recién frena dentro del carril de entrada.
	var heading_to_pits := _should_pit()
	var approaching_pits := heading_to_pits \
			and track.distance_ahead(track_offset, track.pit_entry_offset) < PIT_APPROACH_DISTANCE
	if approaching_pits:
		lane_target = track.pit_side * PIT_APPROACH_LATERAL

	# 3. Tránsito: esquivar al jugador (salvo cuando ya está yendo a boxes).
	if player != null and is_instance_valid(player) and not approaching_pits:
		var avoidance := _avoid_player(target_speed, lane_target)
		target_speed = avoidance.x
		lane_target = avoidance.y

	# 4. Integración de la velocidad.
	#    Mismas cuentas que el perfil de velocidad, con la puesta a punto
	#    del auto: tracción y potencia para acelerar, frenos y resistencia
	#    para frenar.
	var drag := setup.get_drag_per_mass() * speed * speed
	if speed < target_speed:
		var acceleration := minf(Track.PROFILE_TRACTION_USAGE * setup.get_traction_capacity(speed, grip_scale),
				setup.get_peak_power() / setup.mass / maxf(speed, MIN_POWER_SPEED)) - drag
		speed = minf(speed + maxf(acceleration, 0.0) * delta, target_speed)
	else:
		var deceleration := Track.PROFILE_BRAKE_USAGE * setup.get_brake_capacity(speed, grip_scale) + drag
		speed = maxf(speed - deceleration * delta, target_speed)

	# 5. Avance sobre el trazado.
	var previous_distance := total_distance
	total_distance += speed * delta
	if tyre_life > 0.0:
		wear = minf(wear + speed * delta / tyre_life * wear_multiplier * F1Systems.Tyres.TYPICAL_LOAD_FACTOR, 1.0)
	track_offset = track.wrap_offset(total_distance)
	lateral = move_toward(lateral, clampf(lane_target, -_max_lateral, _max_lateral), LATERAL_SPEED * delta)
	_check_lap(previous_distance)

	# 6. Entrada a boxes.
	if heading_to_pits and _crossed_offset(previous_distance, track.pit_entry_offset):
		state = State.IN_PIT_LANE
		_pit_offset = 0.0
		_pit_distance_at_entry = total_distance
		_pit_served = false


# Devuelve Vector2(velocidad objetivo, carril objetivo) teniendo en cuenta al jugador.
func _avoid_player(target_speed: float, lane_target: float) -> Vector2:
	var target_offset := player_offset
	if target_offset < 0.0:
		target_offset = track.get_closest_offset(player.global_position)
	var gap := track.distance_ahead(track_offset, target_offset)
	if gap > AVOID_LOOK_AHEAD:
		return Vector2(target_speed, lane_target)
	var player_lateral := track.get_lateral(player.global_position, target_offset)
	var lateral_distance := absf(player_lateral - lateral)
	# Elige el lado con más lugar para pasar.
	var pass_side := 1.0 if player_lateral < 0.0 else -1.0
	var pass_lane := clampf(player_lateral + pass_side * AVOID_PASS_LATERAL, -_max_lateral, _max_lateral)
	if lateral_distance < AVOID_LATERAL_CLEARANCE:
		lane_target = pass_lane
		# Todavía está detrás del jugador y sin lugar: no lo embiste.
		var safe_gap := AVOID_MIN_GAP + speed * AVOID_GAP_TIME
		if gap < safe_gap:
			var player_speed := 0.0
			if player is RigidBody3D:
				player_speed = maxf((player as RigidBody3D).linear_velocity.dot(track.get_direction(target_offset)), 0.0)
			target_speed = minf(target_speed, player_speed)
	else:
		# Ya está al costado: mantiene el carril de sobrepaso hasta superarlo.
		lane_target = clampf(lateral, -_max_lateral, _max_lateral)
	return Vector2(target_speed, lane_target)


# ==============================================================================
# Boxes
# ==============================================================================
func _should_pit() -> bool:
	return pit_on_lap > 0 and laps_completed + 1 >= pit_on_lap and not finished


func _drive_in_pits(delta: float) -> void:
	var box_offset := track.pit_box_offsets[clampi(pit_box_index, 0, track.pit_box_offsets.size() - 1)]
	var lane_target := track.pit_fast_lane_lateral

	if state == State.PIT_STOPPED:
		speed = 0.0
		lane_target = track.pit_box_lateral
		_pit_timer -= delta
		if _pit_timer <= 0.0:
			state = State.IN_PIT_LANE
			_pit_served = true
			pit_stops += 1
			pit_on_lap = 0
			wear = 0.0
			if next_compound != null:
				compound = next_compound
				next_compound = null
			pit_stop_completed.emit(self)
	else:
		var target_speed := PIT_SPEED_LIMIT
		var distance_to_box := box_offset - _pit_offset
		if not _pit_served and distance_to_box < PIT_BOX_APPROACH:
			lane_target = track.pit_box_lateral
			# Frena para detenerse justo en el box: v = sqrt(2·a·d).
			target_speed = minf(target_speed, sqrt(maxf(2.0 * PIT_BRAKE * distance_to_box, 0.0)))
			if distance_to_box <= 0.3:
				state = State.PIT_STOPPED
				_pit_timer = PIT_STOP_TIME + randf() * 0.8
				speed = 0.0
		if speed < target_speed:
			speed = minf(speed + PIT_ACCELERATION * delta, target_speed)
		else:
			speed = maxf(speed - PIT_BRAKE * 2.0 * delta, target_speed)

	var previous_distance := total_distance
	_pit_offset += speed * delta
	lateral = move_toward(lateral, lane_target, LATERAL_SPEED * delta)
	# El progreso de carrera dentro de boxes se reparte proporcionalmente
	# entre la entrada y la salida del pit lane.
	total_distance = _pit_distance_at_entry + clampf(_pit_offset / track.pit_length, 0.0, 1.0) * track.get_pit_span()
	_check_lap(previous_distance)

	if _pit_offset >= track.pit_length:
		state = State.ON_TRACK
		total_distance = _pit_distance_at_entry + track.get_pit_span()
		track_offset = track.wrap_offset(total_distance)


# ==============================================================================
# Internos
# ==============================================================================

# Detecta el paso por la línea de llegada (múltiplos de la longitud del circuito).
func _check_lap(previous_distance: float) -> void:
	if total_distance < 0.0:
		return
	var lap_now := int(floor(total_distance / track.length))
	var lap_before := int(floor(previous_distance / track.length)) if previous_distance >= 0.0 else -1
	if lap_now > lap_before and lap_now > laps_completed:
		laps_completed = lap_now
		lap_completed.emit(self, laps_completed)


# true si en este tick se pasó por el offset indicado del trazado.
func _crossed_offset(previous_distance: float, offset: float) -> bool:
	var before := track.wrap_offset(previous_distance)
	var after := track.wrap_offset(total_distance)
	if after >= before:
		return before < offset and after >= offset
	return before < offset or after >= offset


func _apply_transform() -> void:
	var target: Transform3D
	if state == State.ON_TRACK:
		target = track.get_transform_at(track_offset, lateral, ROAD_HEIGHT)
	else:
		target = track.get_pit_transform_at(_pit_offset, lateral, ROAD_HEIGHT)
	global_transform = target
	# Informa su velocidad al motor de física para que un choque con el
	# jugador tenga en cuenta la velocidad relativa.
	constant_linear_velocity = -target.basis.z * speed
	var model := get_node_or_null("Modelo") as CarVisual
	if model != null:
		model.spin_wheels(speed * get_physics_process_delta_time())
