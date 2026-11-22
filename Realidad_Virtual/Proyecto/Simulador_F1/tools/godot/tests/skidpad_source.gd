extends InputSource
## Fuente de entrada de la prueba de skidpad (tools/godot/tests/test_skidpad.gd).
##
## Se registra en el InputManager como cualquier otra fuente, así la prueba
## maneja el auto por el mismo camino que una persona. Tiene tres modos:
##   HOLD      mantiene una velocidad objetivo (control PI del acelerador);
##   FLAT_OUT  acelerador a fondo (opcionalmente con DRS y ERS);
##   BRAKE     freno a fondo.
## La dirección se fija aparte con `steer_command` (1 = a tope a la derecha).

enum Mode { HOLD, FLAT_OUT, BRAKE, IDLE }

const SOURCE_ID := "skidpad"
# Control PI de velocidad.
const SPEED_GAIN := 0.6
const SPEED_INTEGRAL_GAIN := 0.5
const INTEGRAL_LIMIT := 1.0
# Por encima de este exceso de velocidad [m/s] toca el freno.
const BRAKE_ERROR := 3.0
const BRAKE_GAIN := 0.15

var mode: Mode = Mode.IDLE
var target_speed: float = 0.0
var steer_command: float = 0.0
var use_ers: bool = false
var use_drs: bool = false
var car: Node3D = null

var _integral: float = 0.0


func get_id() -> String:
	return SOURCE_ID


func get_label() -> String:
	return "Prueba de skidpad"


func update(delta: float) -> void:
	raw_steer = steer_command
	raw_throttle = 0.0
	raw_brake = 0.0
	if car == null:
		return
	var speed: float = car.speed
	match mode:
		Mode.HOLD:
			var error := target_speed - speed
			_integral = clampf(_integral + error * SPEED_INTEGRAL_GAIN * delta, 0.0, INTEGRAL_LIMIT)
			raw_throttle = clampf(error * SPEED_GAIN + _integral, 0.0, 1.0)
			if error < -BRAKE_ERROR:
				raw_brake = clampf((-error - BRAKE_ERROR) * BRAKE_GAIN, 0.0, 1.0)
		Mode.FLAT_OUT:
			raw_throttle = 1.0
		Mode.BRAKE:
			raw_brake = 1.0
	_set_button(&"ers", use_ers and mode == Mode.FLAT_OUT)
	# El DRS es un pulsador: se aprieta hasta que el alerón abre.
	_set_button(&"drs", use_drs and mode == Mode.FLAT_OUT and not car.drs.open
			and Engine.get_physics_frames() % 20 < 10)


## Borra la memoria del control de velocidad (al cambiar de objetivo).
func reset_control() -> void:
	_integral = 0.0
