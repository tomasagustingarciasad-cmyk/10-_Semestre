class_name Weather
extends Node3D
## Clima del nivel: seco, lluvia o variable.
##
## Se configura AL INICIAR el nivel (`setup`), según lo elegido en el menú.
## Maneja dos magnitudes:
##   - `rain_intensity` (0..1): cuánto está lloviendo ahora;
##   - `water_level` (0..1): cuánta agua hay en la pista. Sigue a la lluvia
##     con retardo: la pista tarda en mojarse y tarda más en secarse.
## Y tres tipos de efecto:
##   - físico: el agua reduce el agarre y produce aquaplaning (lo aplican el
##     auto del jugador y el perfil de velocidad de los rivales);
##   - visual: partículas de lluvia que siguen a la cámara, niebla, cielo
##     cubierto y menos sol (se ajustan el Environment y la luz del nivel);
##   - aspecto del asfalto: lo cambia la sesión con Track.set_wet().

enum Mode { DRY, RAIN, VARIABLE }

## Identificadores (se guardan en las opciones y en el nombre de los fantasmas).
const MODE_IDS: Array[String] = ["seco", "lluvia", "variable"]
const MODE_LABELS: Array[String] = ["Seco", "Lluvia", "Variable"]
## Grupo para que otros nodos (por ejemplo el spray de los autos) lo encuentren.
const GROUP := &"clima"

# --- Agua en pista -------------------------------------------------------------
# Tiempo que tarda la pista en mojarse y en secarse por completo [s].
const WETTING_TIME := 45.0
const DRYING_TIME := 150.0
# Charcos: el agua no es pareja. Bajo cada rueda vale
#     agua = nivel · (PUDDLE_BASE + (1 - PUDDLE_BASE) · ruido(x, z))
# con un ruido de unos pocos metros de tamaño, así las ruedas de un lado
# pueden pisar más agua que las del otro.
const PUDDLE_BASE := 0.6
const PUDDLE_FREQUENCY := 0.12
const PUDDLE_SEED := 2026
# Clima variable: el cambio empieza y termina en estas fracciones de la
# duración esperada de la sesión.
const VARIABLE_CHANGE_START := 0.25
const VARIABLE_CHANGE_END := 0.5

# --- Aspecto ---------------------------------------------------------------------
const SKY_TOP_DRY := Color(0.18, 0.4, 0.8)
const SKY_TOP_RAIN := Color(0.3, 0.33, 0.38)
const SKY_HORIZON_DRY := Color(0.66, 0.8, 0.92)
const SKY_HORIZON_RAIN := Color(0.52, 0.55, 0.58)
const GROUND_BOTTOM_DRY := Color(0.2, 0.3, 0.2)
const GROUND_BOTTOM_RAIN := Color(0.2, 0.22, 0.24)
const FOG_COLOR := Color(0.55, 0.58, 0.62)
const FOG_DENSITY_RAIN := 0.006
const FOG_SKY_AFFECT := 0.6
const SUN_ENERGY_DRY := 1.25
const SUN_ENERGY_RAIN := 0.45
const SUN_COLOR_DRY := Color(1.0, 0.97, 0.9)
const SUN_COLOR_RAIN := Color(0.8, 0.85, 0.95)
# Con más lluvia que esto ya no hay sombras definidas.
const SHADOW_MAX_RAIN := 0.4
# Con menos lluvia que esto no se emiten partículas.
const RAIN_MIN_VISIBLE := 0.03

# --- Partículas --------------------------------------------------------------------
# Altura de la nube de partículas sobre la cámara [m].
const RAIN_HEIGHT_ABOVE_CAMERA := 9.0
# Adelanto de la nube en la dirección en que mira la cámara [m], más un extra
# proporcional a la velocidad de la cámara [s].
const RAIN_FORWARD_OFFSET := 10.0
const RAIN_FORWARD_PER_SPEED := 0.3
# Velocidad de caída de las gotas [m/s].
const RAIN_FALL_SPEED := 24.0
# Cuánto se "acuesta" la lluvia con la velocidad de la cámara (0 = nada).
const RAIN_WIND_FACTOR := 0.6

## Nivel de agua en pista con lluvia sostenida (0..1). Es "la intensidad" del
## modo Lluvia: con 0.3 llovizna (intermedios), con 0.7 o más lluvia fuerte.
@export_range(0.1, 1.0) var rain_water_level: float = 0.7

var mode: Mode = Mode.DRY
## Cuánto llueve ahora (0..1).
var rain_intensity: float = 0.0
## Agua en pista ahora (0..1).
var water_level: float = 0.0
## El reloj del clima variable solo avanza con la sesión en marcha.
var clock_running: bool = false

@onready var _rain: GPUParticles3D = get_node_or_null("Lluvia")

var _environment: Environment = null
var _sky_material: ProceduralSkyMaterial = null
var _sun: DirectionalLight3D = null
var _puddles := FastNoiseLite.new()
var _elapsed: float = 0.0
var _expected_duration: float = 300.0
var _variable_from: float = 0.0
var _variable_to: float = 1.0
var _previous_camera_position: Vector3 = Vector3.ZERO
var _has_previous_position: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_puddles.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_puddles.frequency = PUDDLE_FREQUENCY
	_puddles.seed = PUDDLE_SEED
	# El cielo, la niebla y el sol son nodos hermanos en la escena del nivel.
	var world := get_node_or_null("../Ambiente") as WorldEnvironment
	if world != null and world.environment != null:
		# Se duplican para no modificar los recursos guardados en la escena.
		_environment = world.environment.duplicate() as Environment
		world.environment = _environment
		if _environment.sky != null:
			_environment.sky = _environment.sky.duplicate() as Sky
			_sky_material = (_environment.sky.sky_material.duplicate()) as ProceduralSkyMaterial
			_environment.sky.sky_material = _sky_material
	_sun = get_node_or_null("../Sol") as DirectionalLight3D
	_apply_visuals()


## Configura el clima al iniciar el nivel.
##   mode_id: "seco", "lluvia" o "variable"
##   expected_duration: duración estimada de la sesión [s] (para el modo variable)
func setup(mode_id: String, expected_duration: float = 300.0) -> void:
	mode = maxi(MODE_IDS.find(mode_id), 0) as Mode
	_expected_duration = maxf(expected_duration, 60.0)
	_elapsed = 0.0
	match mode:
		Mode.DRY:
			rain_intensity = 0.0
		Mode.RAIN:
			rain_intensity = 1.0
		Mode.VARIABLE:
			# Al azar: empieza seco y se larga a llover, o al revés.
			_variable_from = 0.0 if randf() < 0.5 else 1.0
			_variable_to = 1.0 - _variable_from
			rain_intensity = _variable_from
	water_level = rain_intensity * rain_water_level
	_apply_visuals()


func _process(delta: float) -> void:
	if mode == Mode.VARIABLE and clock_running:
		_update_variable(delta)
		_apply_visuals()
	_update_rain_particles(delta)


# ==============================================================================
# API pública
# ==============================================================================

## Identificador del modo ("seco", "lluvia", "variable").
func get_mode_id() -> String:
	return MODE_IDS[mode]


## Texto corto del clima actual (para mensajes y resultados).
func get_description() -> String:
	if mode == Mode.VARIABLE:
		return "variable"
	return "lluvia" if mode == Mode.RAIN else "seco"


## Agua bajo un punto de la pista (0..1): el nivel general modulado por los charcos.
func get_water_at(global_point: Vector3) -> float:
	if water_level <= 0.0:
		return 0.0
	var noise := _puddles.get_noise_2d(global_point.x, global_point.z) * 0.5 + 0.5
	return water_level * (PUDDLE_BASE + (1.0 - PUDDLE_BASE) * noise)


## Fuerza un estado (lo usan las pruebas automáticas).
func force_state(rain: float, water: float) -> void:
	rain_intensity = clampf(rain, 0.0, 1.0)
	water_level = clampf(water, 0.0, 1.0)
	_apply_visuals()


# ==============================================================================
# Internos
# ==============================================================================

# Clima variable: la lluvia cambia linealmente dentro de una ventana de
# tiempo y el agua en pista la sigue con retardo.
func _update_variable(delta: float) -> void:
	_elapsed += delta
	var progress := inverse_lerp(VARIABLE_CHANGE_START * _expected_duration,
			VARIABLE_CHANGE_END * _expected_duration, _elapsed)
	rain_intensity = lerpf(_variable_from, _variable_to, clampf(progress, 0.0, 1.0))
	var target := rain_intensity * rain_water_level
	var rate := 1.0 / WETTING_TIME if target > water_level else 1.0 / DRYING_TIME
	water_level = move_toward(water_level, target, rate * delta)


# Cielo, niebla, sol y partículas según la lluvia actual.
func _apply_visuals() -> void:
	var rain := rain_intensity
	if _sky_material != null:
		_sky_material.sky_top_color = SKY_TOP_DRY.lerp(SKY_TOP_RAIN, rain)
		_sky_material.sky_horizon_color = SKY_HORIZON_DRY.lerp(SKY_HORIZON_RAIN, rain)
		_sky_material.ground_horizon_color = SKY_HORIZON_DRY.lerp(SKY_HORIZON_RAIN, rain)
		_sky_material.ground_bottom_color = GROUND_BOTTOM_DRY.lerp(GROUND_BOTTOM_RAIN, rain)
	if _environment != null:
		_environment.fog_enabled = rain > RAIN_MIN_VISIBLE
		_environment.fog_light_color = FOG_COLOR
		_environment.fog_density = FOG_DENSITY_RAIN * rain
		_environment.fog_sky_affect = FOG_SKY_AFFECT
	if _sun != null:
		_sun.light_energy = lerpf(SUN_ENERGY_DRY, SUN_ENERGY_RAIN, rain)
		_sun.light_color = SUN_COLOR_DRY.lerp(SUN_COLOR_RAIN, rain)
		_sun.shadow_enabled = rain < SHADOW_MAX_RAIN
	if _rain != null:
		_rain.emitting = rain > RAIN_MIN_VISIBLE
		_rain.visible = rain > RAIN_MIN_VISIBLE
		_rain.amount_ratio = clampf(rain, 0.05, 1.0)


func _update_rain_particles(delta: float) -> void:
	if _rain == null or rain_intensity <= RAIN_MIN_VISIBLE:
		return
	# La lluvia se emite en una caja que acompaña a la cámara activa: así se ve
	# llover en todo el circuito con pocas partículas.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var camera_position := camera.global_position
	var camera_velocity := Vector3.ZERO
	if _has_previous_position and delta > 0.0:
		camera_velocity = (camera_position - _previous_camera_position) / delta
	_previous_camera_position = camera_position
	_has_previous_position = true
	camera_velocity.y = 0.0

	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var ahead := RAIN_FORWARD_OFFSET + camera_velocity.length() * RAIN_FORWARD_PER_SPEED
	_rain.global_position = camera_position + forward * ahead + Vector3.UP * RAIN_HEIGHT_ABOVE_CAMERA

	# Movimiento relativo: yendo rápido las gotas "vienen" hacia la cámara.
	# Velocidad de la gota respecto de la cámara = caída - velocidad de la cámara.
	var process := _rain.process_material as ParticleProcessMaterial
	if process != null:
		var relative := Vector3.DOWN * RAIN_FALL_SPEED - camera_velocity * RAIN_WIND_FACTOR
		process.direction = relative.normalized()
		process.initial_velocity_min = relative.length() * 0.92
		process.initial_velocity_max = relative.length() * 1.08
