class_name Track
extends Node3D
## Circuito: consultas geométricas sobre el trazado.
##
## La escena `scenes/track/circuito.tscn` contiene la geometría (Path3D +
## CSGPolygon3D) y las zonas (Area3D). Este script agrega la "inteligencia"
## que necesita el resto del juego:
##   - progreso: a qué distancia de la línea de llegada está un punto;
##   - superficie: si un punto está sobre asfalto, piano, pasto o pit lane;
##   - transformaciones: posición/orientación sobre el eje con un
##     desplazamiento lateral (grilla, boxes, rivales, reinicios);
##   - perfil de velocidad: velocidad máxima razonable en cada tramo según
##     la curvatura (lo usan los rivales y el piloto automático).
##
## Toda distancia sobre el eje ("offset") se mide en metros desde la línea de
## largada, en el sentido de marcha.

enum Surface { ROAD, KERB, GRASS, PIT }

# Grupos de nodos que usa la lógica de juego para encontrar las zonas.
const GROUP_CHECKPOINT := &"checkpoint"
const GROUP_DRS_ZONE := &"zona_drs"
const GROUP_PIT_LANE := &"pit_lane"
const GROUP_PIT_BOX := &"pit_box"
## Metadato de cada checkpoint: 0 = línea de llegada, 1 = fin S1, 2 = fin S2.
const META_CHECKPOINT_INDEX := &"indice"

const GRAVITY := 9.81
# Distancia usada para estimar dirección y curvatura por diferencias finitas.
const TANGENT_SAMPLE_DISTANCE := 1.0
const CURVATURE_SAMPLE_DISTANCE := 5.0
# Perfil de velocidad con agua en pista: pérdida mínima para limitar la
# velocidad en recta, dónde cae ese tope dentro de la banda de aquaplaning,
# margen sobre la velocidad total [m/s] y pasadas del cálculo iterativo.
const PROFILE_AQUA_MIN_LOSS := 0.05
const PROFILE_AQUA_CAP_FRACTION := 0.5
const PROFILE_AQUA_CAP_MARGIN := 10.0
const PROFILE_BISECTION_STEPS := 18
# Por debajo de esta curvatura [1/m] el tramo se considera recto.
const PROFILE_MIN_CURVATURE := 0.0002
# Fracción de la capacidad de frenado y de tracción que usa el perfil.
const PROFILE_BRAKE_USAGE := 0.85
const PROFILE_TRACTION_USAGE := 0.85
# Velocidad mínima para el cálculo de potencia / velocidad [m/s].
const PROFILE_MIN_POWER_SPEED := 8.0
# Agarre longitudinal mínimo que deja el círculo de fricción.
const PROFILE_MIN_FREE_GRIP := 0.15
# Radio de referencia del margen para curvas cerradas [m]: con ese radio se
# usa la mitad del agarre; con 10 veces más, el 91 %.
const PROFILE_TIGHT_RADIUS := 4.0
# Línea de carrera: distancia mínima del eje del auto al borde del asfalto [m],
# lugar mínimo para que valga la pena calcularla [m], separación entre
# vecinos en cada etapa (en muestras, de grueso a fino), pasadas por etapa,
# cuánto se mueve cada punto por pasada y separación para medir la curvatura.
const LINE_EDGE_MARGIN := 1.8
const LINE_MIN_ROOM := 0.5
const LINE_CURVATURE_SPAN := 2
# Paso de muestreo del perfil de velocidad [m].
const PROFILE_STEP := 4.0
# Búsqueda local del progreso: ventana alrededor de la última posición
# conocida, paso grueso y paso fino [m].
const NEAR_WINDOW := 90.0
const NEAR_COARSE_STEP := 4.0
const NEAR_FINE_STEP := 0.5
# Si el punto quedó más lejos que esto del tramo esperado, se busca en toda la vuelta.
const NEAR_MAX_DISTANCE := 45.0
# Asfalto mojado: oscurecimiento, rugosidad y brillo con la pista empapada.
const WET_DARKEN := 0.4
const WET_ROUGHNESS := 0.2
const WET_METALLIC := 0.4

@export_group("Identificación")
## Identificador del circuito (nombre del recurso en assets/circuits/).
@export var circuit_id: String = ""
## Nombre para mostrar.
@export var display_name: String = ""
## Longitud oficial de la vuelta [m] (la medida real es `length`).
@export var official_length: float = 0.0

@export_group("Medidas")
## Mitad del ancho del asfalto [m].
@export var half_width: float = 6.5
## Ancho de los pianos [m].
@export var kerb_width: float = 1.3
## Mitad del ancho del pit lane [m].
@export var pit_half_width: float = 4.5
## Tramos con piano: cada Vector2 es (offset inicial, offset final).
@export var kerb_ranges: PackedVector2Array = PackedVector2Array()

@export_group("Largada")
@export var grid_first_row_distance: float = 12.0
@export var grid_row_spacing: float = 10.0
@export var grid_lateral: float = 2.8

@export_group("Boxes")
## Offset del trazado principal donde nace y donde termina el pit lane.
@export var pit_entry_offset: float = 0.0
@export var pit_exit_offset: float = 0.0
## Offsets (sobre el eje del pit lane) de cada box. El índice 0 es el del jugador.
@export var pit_box_offsets: PackedFloat32Array = PackedFloat32Array()
## Lado del pit lane respecto del sentido de marcha: 1 = derecha, -1 = izquierda.
@export var pit_side: int = 1
## Desplazamiento lateral (con signo) de los boxes respecto del eje del pit lane.
@export var pit_box_lateral: float = 2.2
## Desplazamiento lateral (con signo) del carril rápido del pit lane.
@export var pit_fast_lane_lateral: float = -2.0
## Tramo del pit lane con límite de velocidad (offsets sobre el eje del pit lane).
@export var pit_limit_start: float = 0.0
@export var pit_limit_end: float = 0.0

@export_group("Sectores")
## Offsets donde terminan el sector 1 y el sector 2.
@export var sector_ends: PackedFloat32Array = PackedFloat32Array()

## Línea de carrera calculada al generar la escena: desplazamiento lateral
## [m] cada PROFILE_STEP metros (positivo = derecha). Vacía = se calcula al cargar.
@export var line_lateral: PackedFloat32Array = PackedFloat32Array()

@onready var main_path: Path3D = $Trazado
@onready var pit_path: Path3D = $TrazadoBoxes

## Curva del eje de la pista y su longitud total [m].
var curve: Curve3D
var length: float = 0.0
## Curva del eje del pit lane y su longitud [m].
var pit_curve: Curve3D
var pit_length: float = 0.0

# Línea de carrera: desplazamiento lateral y curvatura cada PROFILE_STEP metros.
var _line_lateral: PackedFloat32Array = PackedFloat32Array()
var _line_curvature: PackedFloat32Array = PackedFloat32Array()
# Materiales originales del asfalto (para volver a "seco").
var _dry_materials: Dictionary = {}


func _ready() -> void:
	curve = main_path.curve
	length = curve.get_baked_length()
	pit_curve = pit_path.curve
	pit_length = pit_curve.get_baked_length()


# ==============================================================================
# Progreso y transformaciones sobre el trazado principal
# ==============================================================================

## Lleva un offset cualquiera al rango [0, length).
func wrap_offset(offset: float) -> float:
	return fposmod(offset, length)


## Distancia recorrida hacia adelante para ir de `from_offset` a `to_offset`.
func distance_ahead(from_offset: float, to_offset: float) -> float:
	return fposmod(to_offset - from_offset, length)


## Diferencia con signo más corta entre dos offsets (resultado en ±length/2).
func signed_offset_difference(from_offset: float, to_offset: float) -> float:
	var diff := fposmod(to_offset - from_offset, length)
	if diff > length * 0.5:
		diff -= length
	return diff


## Offset del punto del eje más cercano a una posición global.
func get_closest_offset(global_point: Vector3) -> float:
	return curve.get_closest_offset(main_path.to_local(global_point))


## Offset del punto del eje más cercano, buscando solo cerca de `hint`.
##
## En los circuitos reales hay tramos que pasan muy cerca de otros (o se
## cruzan, como en Suzuka): el punto más cercano de TODA la curva puede estar
## en el tramo equivocado. Quien sigue a un auto recuerda su último offset y
## busca solo en una ventana alrededor de él.
func get_offset_near(global_point: Vector3, hint: float) -> float:
	var local := main_path.to_local(global_point)
	var best := hint
	var best_distance := INF
	var travelled := -NEAR_WINDOW
	while travelled <= NEAR_WINDOW:
		var distance := local.distance_squared_to(curve.sample_baked(wrap_offset(hint + travelled)))
		if distance < best_distance:
			best_distance = distance
			best = hint + travelled
		travelled += NEAR_COARSE_STEP
	if best_distance > NEAR_MAX_DISTANCE * NEAR_MAX_DISTANCE:
		return get_closest_offset(global_point)   # El auto fue reubicado lejos.
	var coarse := best
	travelled = -NEAR_COARSE_STEP
	while travelled <= NEAR_COARSE_STEP:
		var distance := local.distance_squared_to(curve.sample_baked(wrap_offset(coarse + travelled)))
		if distance < best_distance:
			best_distance = distance
			best = coarse + travelled
		travelled += NEAR_FINE_STEP
	return wrap_offset(best)


## Posición global del eje en un offset.
func get_center(offset: float) -> Vector3:
	return main_path.to_global(curve.sample_baked(wrap_offset(offset), true))


## Dirección de marcha (vector unitario horizontal) en un offset.
func get_direction(offset: float) -> Vector3:
	var ahead := get_center(offset + TANGENT_SAMPLE_DISTANCE)
	var behind := get_center(offset - TANGENT_SAMPLE_DISTANCE)
	var direction := ahead - behind
	direction.y = 0.0
	return direction.normalized()


## Vector unitario hacia la derecha del sentido de marcha en un offset.
func get_right(offset: float) -> Vector3:
	return get_direction(offset).cross(Vector3.UP).normalized()


## Transformación global sobre la pista: origen en el eje desplazado
## `lateral` metros a la derecha y `height` metros hacia arriba, con el eje
## -Z (el "adelante" de Godot) apuntando en el sentido de marcha.
## Agua aplicada al aspecto del asfalto (ver set_wet).
var wetness: float = 0.0


func get_transform_at(offset: float, lateral: float = 0.0, height: float = 0.0) -> Transform3D:
	var forward := get_direction(offset)
	var right := forward.cross(Vector3.UP).normalized()
	var origin := get_center(offset) + right * lateral + Vector3.UP * height
	return Transform3D(Basis(right, Vector3.UP, -forward), origin)


## Desplazamiento lateral con signo de un punto respecto del eje en `offset`
## (positivo = a la derecha del sentido de marcha).
func get_lateral(global_point: Vector3, offset: float) -> float:
	return (global_point - get_center(offset)).dot(get_right(offset))


## Curvatura con signo en un offset [1/m]: positiva = curva a la derecha.
## Se estima con el círculo que pasa por tres puntos del eje (curvatura de
## Menger): k = 4·Área / (a·b·c).
func get_curvature(offset: float) -> float:
	var p0 := get_center(offset - CURVATURE_SAMPLE_DISTANCE)
	var p1 := get_center(offset)
	var p2 := get_center(offset + CURVATURE_SAMPLE_DISTANCE)
	var a := Vector2(p1.x - p0.x, p1.z - p0.z)
	var b := Vector2(p2.x - p1.x, p2.z - p1.z)
	var c := Vector2(p2.x - p0.x, p2.z - p0.z)
	var denominator := a.length() * b.length() * c.length()
	if denominator < 0.0001:
		return 0.0
	return 2.0 * a.cross(b) / denominator


# ==============================================================================
# Superficies
# ==============================================================================

## Clasifica la superficie bajo un punto global.
func classify_point(global_point: Vector3) -> Surface:
	var offset := get_closest_offset(global_point)
	var lateral := absf(get_lateral(global_point, offset))
	if lateral <= half_width:
		return Surface.ROAD
	if lateral <= half_width + kerb_width and has_kerb_at(offset):
		return Surface.KERB
	# Fuera de la pista: puede ser el pit lane.
	var pit_local := pit_path.to_local(global_point)
	var pit_closest := pit_curve.get_closest_point(pit_local)
	if Vector2(pit_local.x - pit_closest.x, pit_local.z - pit_closest.z).length() <= pit_half_width:
		return Surface.PIT
	return Surface.GRASS


## true si en ese offset hay piano dibujado.
func has_kerb_at(offset: float) -> bool:
	for kerb_range in kerb_ranges:
		if offset >= kerb_range.x and offset <= kerb_range.y:
			return true
	return false


## Cambia el aspecto del asfalto según el agua en pista (0 = seco, 1 = empapado):
## más oscuro y más brillante cuanto más mojado.
func set_wet(water: float) -> void:
	wetness = water
	for node_name in ["Asfalto", "AsfaltoBoxes"]:
		var csg := get_node_or_null(node_name) as CSGPolygon3D
		if csg == null:
			continue
		if not _dry_materials.has(node_name):
			_dry_materials[node_name] = csg.material
		var dry := _dry_materials[node_name] as StandardMaterial3D
		if dry == null:
			continue
		if water <= 0.01:
			csg.material = dry
			continue
		# Se duplica para no modificar el recurso compartido de la escena.
		var material := dry.duplicate() as StandardMaterial3D
		material.albedo_color = dry.albedo_color.darkened(WET_DARKEN * water)
		material.roughness = lerpf(dry.roughness, WET_ROUGHNESS, water)
		material.metallic = lerpf(dry.metallic, WET_METALLIC, water)
		csg.material = material


# ==============================================================================
# Grilla y boxes
# ==============================================================================

## Transformación del cajón de grilla `slot` (0 = pole position).
func get_grid_transform(slot: int, height: float = 0.0) -> Transform3D:
	var offset := length - grid_first_row_distance - grid_row_spacing * slot
	var lateral := -grid_lateral if slot % 2 == 0 else grid_lateral
	return get_transform_at(offset, lateral, height)


## Transformación global sobre el eje del pit lane.
func get_pit_transform_at(pit_offset: float, lateral: float = 0.0, height: float = 0.0) -> Transform3D:
	var clamped := clampf(pit_offset, 0.0, pit_length)
	var ahead := pit_curve.sample_baked(minf(clamped + TANGENT_SAMPLE_DISTANCE, pit_length), true)
	var behind := pit_curve.sample_baked(maxf(clamped - TANGENT_SAMPLE_DISTANCE, 0.0), true)
	var forward := pit_path.to_global(ahead) - pit_path.to_global(behind)
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var origin := pit_path.to_global(pit_curve.sample_baked(clamped, true)) + right * lateral + Vector3.UP * height
	return Transform3D(Basis(right, Vector3.UP, -forward), origin)


## Transformación del box número `index` (0 = jugador).
func get_pit_box_transform(index: int, height: float = 0.0) -> Transform3D:
	var safe_index := clampi(index, 0, pit_box_offsets.size() - 1)
	return get_pit_transform_at(pit_box_offsets[safe_index], pit_box_lateral, height)


## Distancia (sobre el trazado principal) que "ahorra" o equivale el pit lane:
## del punto de entrada al de salida.
func get_pit_span() -> float:
	return distance_ahead(pit_entry_offset, pit_exit_offset)


# ==============================================================================
# Perfil de velocidad
# ==============================================================================

## Calcula la velocidad objetivo [m/s] cada PROFILE_STEP metros de pista,
## con la capacidad REAL del auto (CarSetup): carga aerodinámica, sensibilidad
## a la carga, frenos, potencia y resistencia salen de la puesta a punto.
##
## 1. Límite por curva: en cada punto se busca la velocidad a la que la
##    aceleración lateral necesaria (v²·k, k = curvatura de la línea) iguala a
##    la disponible (CarSetup.get_profile_lateral). Como la disponible depende
##    de la velocidad (carga aerodinámica, aquaplaning), se resuelve por bisección.
## 2. Pasada hacia atrás (frenar a tiempo antes de cada curva) y hacia
##    adelante (no acelerar más de lo que dan la tracción y la potencia). En
##    las dos se respeta el "círculo de fricción": lo que se usa para doblar
##    no está disponible para frenar ni para acelerar.
##
##   setup:        puesta a punto del auto
##   grip_scale:   factor de agarre del compuesto y el agua (1 = slick en seco)
##   top_speed:    velocidad máxima en recta [m/s]
##   aquaplaning:  Vector3(velocidad de inicio, velocidad total, pérdida 0..1).
##                 Vector3.ZERO = sin aquaplaning.
##   use_line:     true = curvatura de la línea de carrera; false = del eje
func build_speed_profile(setup: CarSetup, grip_scale: float, top_speed: float,
		aquaplaning: Vector3 = Vector3.ZERO, use_line: bool = true) -> PackedFloat32Array:
	var count := int(ceil(length / PROFILE_STEP))
	var profile := PackedFloat32Array()
	profile.resize(count)
	if use_line:
		_ensure_racing_line()

	# Con mucha agua tampoco se va a fondo en recta: tope de velocidad.
	var speed_cap := top_speed
	if aquaplaning.z > PROFILE_AQUA_MIN_LOSS:
		var half_way := aquaplaning.x + (aquaplaning.y - aquaplaning.x) * PROFILE_AQUA_CAP_FRACTION
		speed_cap = minf(top_speed, lerpf(aquaplaning.y + PROFILE_AQUA_CAP_MARGIN, half_way, aquaplaning.z))

	# 1. Límite por curvatura.
	var curvatures := PackedFloat32Array()
	curvatures.resize(count)
	for i in count:
		var curvature := absf(_line_curvature[i]) if use_line else absf(get_curvature(i * PROFILE_STEP))
		curvatures[i] = curvature
		profile[i] = _corner_speed(setup, grip_scale, aquaplaning, curvature, speed_cap)

	# 2. Pasada hacia atrás (frenadas) y hacia adelante (aceleraciones).
	#    Se dan dos vueltas para que el final de la vuelta "vea" la curva 1.
	#    En aceleración se supone lo mejor posible (ERS desplegado y DRS
	#    abierto): el perfil es un TECHO; si el auto no llega, simplemente va
	#    a fondo. Los puntos de frenada salen de la pasada hacia atrás.
	var power_per_mass := (setup.get_peak_power() + setup.ers_deploy_power) / setup.mass
	var drag_per_mass := setup.get_drag_per_mass()
	var drag_open_per_mass := drag_per_mass * setup.drs_drag_factor
	for lap in 2:
		for i in range(count - 1, -1, -1):
			var next_speed := profile[(i + 1) % count]
			var scale := grip_scale * _aquaplaning_factor(aquaplaning, next_speed)
			var free := _friction_circle(setup, scale, next_speed, curvatures[i])
			var decel := PROFILE_BRAKE_USAGE * setup.get_brake_capacity(next_speed, scale) * free \
					+ drag_per_mass * next_speed * next_speed
			profile[i] = minf(profile[i], sqrt(next_speed * next_speed + 2.0 * decel * PROFILE_STEP))
		for i in count:
			var prev_speed := profile[(i - 1 + count) % count]
			var scale := grip_scale * _aquaplaning_factor(aquaplaning, prev_speed)
			var free := _friction_circle(setup, scale, prev_speed, curvatures[i])
			var accel := minf(PROFILE_TRACTION_USAGE * setup.get_traction_capacity(prev_speed, scale) * free,
					power_per_mass / maxf(prev_speed, PROFILE_MIN_POWER_SPEED)) \
					- drag_open_per_mass * prev_speed * prev_speed
			profile[i] = minf(profile[i], sqrt(maxf(prev_speed * prev_speed + 2.0 * accel * PROFILE_STEP, 1.0)))
	return profile


# Velocidad máxima de paso por una curva de curvatura dada (bisección).
func _corner_speed(setup: CarSetup, grip_scale: float, aquaplaning: Vector3,
		curvature: float, speed_cap: float) -> float:
	if curvature < PROFILE_MIN_CURVATURE:
		return speed_cap
	if _lateral_margin(setup, grip_scale, aquaplaning, curvature, speed_cap) >= 0.0:
		return speed_cap
	var low := 0.0
	var high := speed_cap
	for iteration in PROFILE_BISECTION_STEPS:
		var middle := (low + high) * 0.5
		if _lateral_margin(setup, grip_scale, aquaplaning, curvature, middle) >= 0.0:
			low = middle
		else:
			high = middle
	return low


# Lateral disponible menos lateral necesaria a una velocidad (>= 0: pasa).
func _lateral_margin(setup: CarSetup, grip_scale: float, aquaplaning: Vector3,
		curvature: float, speed: float) -> float:
	# En curvas muy cerradas el auto no llega a rotar tan rápido como supone
	# un modelo de masa puntual: se usa menos agarre cuanto menor es el radio.
	var tight := 1.0 / (1.0 + curvature * PROFILE_TIGHT_RADIUS)
	return tight * setup.get_profile_lateral(speed, grip_scale * _aquaplaning_factor(aquaplaning, speed)) \
			- speed * speed * curvature


# Fracción del agarre que queda para frenar o acelerar mientras se dobla
# (círculo de fricción): raíz(1 - (lateral usada / lateral disponible)²).
func _friction_circle(setup: CarSetup, grip_scale: float, speed: float, curvature: float) -> float:
	var available := setup.get_profile_lateral(speed, grip_scale)
	if available <= 0.0:
		return 0.0
	var used := clampf(speed * speed * curvature / available, 0.0, 1.0)
	return maxf(sqrt(1.0 - used * used), PROFILE_MIN_FREE_GRIP)


# ==============================================================================
# Línea de carrera
# ==============================================================================

## Desplazamiento lateral de la línea de carrera en un offset [m]
## (positivo = derecha del eje). 0 si todavía no se calculó.
func get_line_lateral(offset: float) -> float:
	_ensure_racing_line()
	return sample_profile(_line_lateral, offset)


## Curvatura con signo de la línea de carrera en un offset [1/m]
## (positiva = curva a la derecha).
func get_line_curvature(offset: float) -> float:
	_ensure_racing_line()
	return sample_profile(_line_curvature, offset)


# Prepara la línea de carrera una sola vez (la primera que se pide). Si la
# escena ya la trae calculada (`line_lateral`, la escribe el generador de
# circuitos) se usa esa; si no, se calcula acá (ver RacingLine).
func _ensure_racing_line() -> void:
	if not _line_lateral.is_empty():
		return
	var count := int(ceil(length / PROFILE_STEP))
	_line_lateral.resize(count)
	_line_lateral.fill(0.0)
	_line_curvature.resize(count)
	var centers := PackedVector2Array()
	var rights := PackedVector2Array()
	centers.resize(count)
	rights.resize(count)
	for i in count:
		var center := get_center(i * PROFILE_STEP)
		var right := get_right(i * PROFILE_STEP)
		centers[i] = Vector2(center.x, center.z)
		rights[i] = Vector2(right.x, right.z)

	var limit := half_width - LINE_EDGE_MARGIN
	if line_lateral.size() == count:
		_line_lateral = line_lateral.duplicate()   # Calculada al generar la escena.
	elif limit > LINE_MIN_ROOM:
		_line_lateral = RacingLine.compute(centers, rights, limit)

	# Curvatura de la línea (círculo por tres puntos), suavizada.
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in count:
		var p0 := _line_point(centers, rights, (i - LINE_CURVATURE_SPAN + count) % count)
		var p1 := _line_point(centers, rights, i)
		var p2 := _line_point(centers, rights, (i + LINE_CURVATURE_SPAN) % count)
		var a := p1 - p0
		var b := p2 - p1
		var denominator := a.length() * b.length() * (p2 - p0).length()
		raw[i] = 2.0 * a.cross(b) / denominator if denominator > 0.0001 else 0.0
	for i in count:
		_line_curvature[i] = (raw[(i - 1 + count) % count] + 2.0 * raw[i] + raw[(i + 1) % count]) * 0.25


func _line_point(centers: PackedVector2Array, rights: PackedVector2Array, index: int) -> Vector2:
	return centers[index] + rights[index] * _line_lateral[index]


# Factor de agarre por aquaplaning a una velocidad (1 = sin pérdida).
func _aquaplaning_factor(aquaplaning: Vector3, speed: float) -> float:
	if aquaplaning.z <= 0.0 or aquaplaning.y <= aquaplaning.x:
		return 1.0
	return 1.0 - aquaplaning.z * smoothstep(aquaplaning.x, aquaplaning.y, speed)


## Lee el perfil de velocidad en un offset (interpolando entre muestras).
func sample_profile(profile: PackedFloat32Array, offset: float) -> float:
	if profile.is_empty():
		return 0.0
	var position := wrap_offset(offset) / PROFILE_STEP
	var index := int(floor(position)) % profile.size()
	var next_index := (index + 1) % profile.size()
	return lerpf(profile[index], profile[next_index], position - floor(position))
