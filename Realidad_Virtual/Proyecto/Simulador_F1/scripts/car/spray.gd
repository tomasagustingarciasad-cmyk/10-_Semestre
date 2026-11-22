extends GPUParticles3D
## Spray: la nube de agua que levanta un auto sobre pista mojada.
##
## Va como hijo de cualquier auto (jugador o rival) que tenga la propiedad
## `speed`. La cantidad de partículas crece con la velocidad y con el agua
## en pista; en seco no emite. Sirve para que se vea menos al seguir de
## cerca a otro auto bajo la lluvia.

# Velocidad a la que empieza a levantar agua y a la que el spray es máximo [m/s].
const MIN_SPEED := 12.0
const FULL_SPEED := 70.0
# Agua en pista a la que el spray es máximo.
const FULL_WATER := 0.5
const MIN_STRENGTH := 0.03

var _car: Node = null
var _weather: Weather = null


func _ready() -> void:
	_car = get_parent()
	emitting = false


func _process(_delta: float) -> void:
	if _weather == null:
		_weather = get_tree().get_first_node_in_group(Weather.GROUP) as Weather
		if _weather == null:
			return
	var speed := absf(float(_car.get("speed")))
	var strength := clampf(_weather.water_level / FULL_WATER, 0.0, 1.0) \
			* clampf(inverse_lerp(MIN_SPEED, FULL_SPEED, speed), 0.0, 1.0)
	emitting = strength > MIN_STRENGTH
	amount_ratio = maxf(strength, MIN_STRENGTH)
