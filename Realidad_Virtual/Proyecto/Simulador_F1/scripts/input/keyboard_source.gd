class_name KeyboardSource
extends InputSource
## Fuente de entrada: teclado.
##
## Es el ÚNICO lugar del juego donde se consulta el teclado para conducir.
## Como una tecla es todo-o-nada, los ejes se "suavizan": la dirección y los
## pedales se mueven hacia su objetivo con una velocidad limitada, lo que
## imita el recorrido de un volante y de un pedal reales.

# Teclas de cada eje (se usan códigos físicos: la posición de la tecla es la
# misma en cualquier distribución de teclado).
const KEYS_STEER_LEFT: Array[Key] = [KEY_A, KEY_LEFT]
const KEYS_STEER_RIGHT: Array[Key] = [KEY_D, KEY_RIGHT]
const KEYS_THROTTLE: Array[Key] = [KEY_W, KEY_UP]
const KEYS_BRAKE: Array[Key] = [KEY_S, KEY_DOWN]

# Teclas de cada acción.
const KEYS_ACTIONS := {
	&"shift_up": [KEY_E],
	&"shift_down": [KEY_Q],
	&"drs": [KEY_F],
	&"ers": [KEY_SPACE],
	&"pit_limiter": [KEY_L],
	&"reset": [KEY_R],
	&"camera_next": [KEY_C],
	&"pause": [KEY_ESCAPE, KEY_P],
	&"take_control": [KEY_T],
}

# Teclas que simulan el encoder rotativo del volante.
const KEYS_ENCODER_UP: Array[Key] = [KEY_PAGEUP]
const KEYS_ENCODER_DOWN: Array[Key] = [KEY_PAGEDOWN]

# Velocidades de suavizado, en "recorridos completos por segundo".
const STEER_ATTACK_RATE := 2.6     ## Al girar hacia un lado
const STEER_RETURN_RATE := 4.5     ## Al soltar (vuelve al centro)
const STEER_REVERSE_RATE := 6.0    ## Al cambiar bruscamente de lado
const THROTTLE_ATTACK_RATE := 3.5
const THROTTLE_RELEASE_RATE := 6.0
const BRAKE_ATTACK_RATE := 4.5
const BRAKE_RELEASE_RATE := 8.0

var _encoder_up_was_pressed := false
var _encoder_down_was_pressed := false


func get_id() -> String:
	return Settings.SOURCE_KEYBOARD


func get_label() -> String:
	return "Teclado"


func wants_steer_assist() -> bool:
	return true


func update(delta: float) -> void:
	# --- Dirección ---------------------------------------------------------
	var target := 0.0
	if _any_pressed(KEYS_STEER_LEFT):
		target -= 1.0
	if _any_pressed(KEYS_STEER_RIGHT):
		target += 1.0
	var rate := STEER_ATTACK_RATE
	if is_zero_approx(target):
		rate = STEER_RETURN_RATE
	elif signf(target) != signf(raw_steer) and not is_zero_approx(raw_steer):
		rate = STEER_REVERSE_RATE
	raw_steer = move_toward(raw_steer, target, rate * delta)

	# --- Pedales -----------------------------------------------------------
	raw_throttle = _smooth_pedal(raw_throttle, _any_pressed(KEYS_THROTTLE),
			THROTTLE_ATTACK_RATE, THROTTLE_RELEASE_RATE, delta)
	raw_brake = _smooth_pedal(raw_brake, _any_pressed(KEYS_BRAKE),
			BRAKE_ATTACK_RATE, BRAKE_RELEASE_RATE, delta)

	# --- Botones -----------------------------------------------------------
	for action: StringName in KEYS_ACTIONS:
		var keys: Array = KEYS_ACTIONS[action]
		var pressed := false
		for key: Key in keys:
			if Input.is_physical_key_pressed(key):
				pressed = true
				break
		_set_button(action, pressed)

	# --- Encoder simulado (un paso por pulsación) --------------------------
	var up := _any_pressed(KEYS_ENCODER_UP)
	var down := _any_pressed(KEYS_ENCODER_DOWN)
	if up and not _encoder_up_was_pressed:
		_encoder_steps += 1
	if down and not _encoder_down_was_pressed:
		_encoder_steps -= 1
	_encoder_up_was_pressed = up
	_encoder_down_was_pressed = down


func release_all() -> void:
	super.release_all()
	_encoder_up_was_pressed = false
	_encoder_down_was_pressed = false


# true si alguna de las teclas de la lista está apretada.
func _any_pressed(keys: Array[Key]) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false


# Mueve un pedal hacia 1 (apretado) o 0 (suelto) con velocidades distintas.
func _smooth_pedal(value: float, pressed: bool, attack: float, release: float, delta: float) -> float:
	if pressed:
		return move_toward(value, 1.0, attack * delta)
	return move_toward(value, 0.0, release * delta)
