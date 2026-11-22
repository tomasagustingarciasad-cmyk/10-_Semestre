class_name TyreCompound
extends Resource
## Compuesto de neumático (un recurso `.tres` por compuesto en `assets/tyres/`).
##
## Define cómo responde el neumático según el agua que haya en la pista:
##   - agarre: se interpola entre el valor en seco y el valor en mojado;
##   - desgaste: un neumático de lluvia sobre pista seca se destruye rápido;
##   - aquaplaning: por encima de cierta velocidad el neumático no llega a
##     evacuar el agua y "flota"; cada compuesto tiene su banda de velocidades.
##
## El modelo completo está explicado en docs/neumaticos_y_aquaplaning.md.

const DIR := "res://assets/tyres/"
## Identificadores de todos los compuestos, en el orden de los menús.
const IDS: Array[String] = ["blando", "medio", "duro", "intermedio", "lluvia"]
const DEFAULT_ID := "medio"
## Nivel de agua (0..1) a partir del cual rige por completo el agarre "en mojado".
const WET_REFERENCE_WATER := 0.5
## Fracción del agarre que queda con aquaplaning total y la pista empapada.
const AQUAPLANING_MIN_GRIP := 0.3
## Un neumático gastado tiene menos dibujo: aquaplanea a menor velocidad.
## Con desgaste total las velocidades de la banda bajan esta fracción.
const AQUAPLANING_WEAR_PENALTY := 0.25
## Velocidad de referencia para elegir el mejor compuesto [m/s].
const REFERENCE_SPEED := 55.0
const KMH_TO_MS := 1.0 / 3.6
## Agarre en mojado a partir del cual un compuesto se considera "de lluvia".
const WET_TYRE_MIN_GRIP := 0.7

## Identificador (nombre del archivo).
@export var id: String = ""
## Nombre para mostrar.
@export var display_name: String = ""
## Letra y color con que se lo identifica en el HUD.
@export var letter: String = "M"
@export var color: Color = Color.WHITE
## Multiplicador de agarre con la pista seca y con la pista mojada.
@export var grip_dry: float = 1.0
@export var grip_wet: float = 0.55
## Multiplicador de desgaste con la pista seca y con la pista mojada.
@export var wear_dry: float = 1.0
@export var wear_wet: float = 1.0
## Aquaplaning: velocidad a la que empieza y velocidad a la que es total [km/h].
@export var aquaplaning_start_kmh: float = 150.0
@export var aquaplaning_full_kmh: float = 220.0


## Qué tan "mojado" se comporta el neumático para un nivel de agua (0..1).
static func get_wetness(water: float) -> float:
	return clampf(water / WET_REFERENCE_WATER, 0.0, 1.0)


## Multiplicador de agarre del compuesto para un nivel de agua.
func get_grip(water: float) -> float:
	return lerpf(grip_dry, grip_wet, get_wetness(water))


## Multiplicador de desgaste del compuesto para un nivel de agua.
func get_wear_multiplier(water: float) -> float:
	return lerpf(wear_dry, wear_wet, get_wetness(water))


## Factor de aquaplaning de UNA rueda (1 = agarre completo).
##   speed: velocidad de la rueda [m/s]
##   water: agua bajo esa rueda (0..1)
##   wear:  desgaste de esa rueda (0..1)
## Entre la velocidad de inicio y la total el agarre cae con una curva suave
## (smoothstep); la profundidad de la caída es proporcional al agua.
func get_aquaplaning_factor(speed: float, water: float, wear: float = 0.0) -> float:
	if water <= 0.0:
		return 1.0
	var band_scale := 1.0 - AQUAPLANING_WEAR_PENALTY * clampf(wear, 0.0, 1.0)
	var start := aquaplaning_start_kmh * KMH_TO_MS * band_scale
	var full := aquaplaning_full_kmh * KMH_TO_MS * band_scale
	var loss := clampf(water, 0.0, 1.0) * (1.0 - AQUAPLANING_MIN_GRIP)
	return 1.0 - loss * smoothstep(start, full, absf(speed))


## Datos de aquaplaning para Track.build_speed_profile():
## Vector3(velocidad de inicio [m/s], velocidad total [m/s], pérdida 0..1).
func get_profile_aquaplaning(water: float) -> Vector3:
	if water <= 0.0:
		return Vector3.ZERO
	return Vector3(aquaplaning_start_kmh * KMH_TO_MS, aquaplaning_full_kmh * KMH_TO_MS,
			clampf(water, 0.0, 1.0) * (1.0 - AQUAPLANING_MIN_GRIP))


## Agarre efectivo a la velocidad de referencia (para comparar compuestos).
func get_score(water: float) -> float:
	return get_grip(water) * get_aquaplaning_factor(REFERENCE_SPEED, water)


## Carga un compuesto por su identificador (o el medio si no existe).
static func load_compound(compound_id: String) -> TyreCompound:
	var path := DIR + compound_id + ".tres"
	if not ResourceLoader.exists(path):
		path = DIR + DEFAULT_ID + ".tres"
	return load(path) as TyreCompound


## El compuesto con más agarre efectivo para un nivel de agua.
static func best_for(water: float) -> TyreCompound:
	var best: TyreCompound = null
	for compound_id in IDS:
		var compound := load_compound(compound_id)
		# Entre los de seco se elige el medio (el blando y el duro son
		# decisiones de estrategia, no de clima).
		if compound.grip_wet < WET_TYRE_MIN_GRIP and compound_id != DEFAULT_ID:
			continue
		if best == null or compound.get_score(water) > best.get_score(water):
			best = compound
	return best
