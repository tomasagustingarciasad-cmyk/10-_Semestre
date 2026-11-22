class_name GamepadSource
extends InputSource
## Fuente de entrada: gamepad (control tipo Xbox/PlayStation).
##
## Dirección con el stick izquierdo, acelerador y freno con los gatillos.
## Usa el primer joypad conectado. La vibración del gamepad se aprovecha
## para probar los eventos hápticos antes de tener el volante.

const AXIS_STEER := JOY_AXIS_LEFT_X
const AXIS_THROTTLE := JOY_AXIS_TRIGGER_RIGHT
const AXIS_BRAKE := JOY_AXIS_TRIGGER_LEFT

# Botones de cada acción.
const BUTTONS_ACTIONS := {
	&"shift_up": JOY_BUTTON_RIGHT_SHOULDER,
	&"shift_down": JOY_BUTTON_LEFT_SHOULDER,
	&"drs": JOY_BUTTON_Y,
	&"ers": JOY_BUTTON_A,
	&"pit_limiter": JOY_BUTTON_X,
	&"reset": JOY_BUTTON_BACK,
	&"camera_next": JOY_BUTTON_B,
	&"pause": JOY_BUTTON_START,
	&"take_control": JOY_BUTTON_RIGHT_STICK,
}

# La cruceta simula el encoder del volante.
const BUTTON_ENCODER_UP := JOY_BUTTON_DPAD_UP
const BUTTON_ENCODER_DOWN := JOY_BUTTON_DPAD_DOWN

var _encoder_up_was_pressed := false
var _encoder_down_was_pressed := false


func get_id() -> String:
	return Settings.SOURCE_GAMEPAD


func get_label() -> String:
	return "Gamepad"


func is_analog() -> bool:
	return true


func is_available() -> bool:
	return not Input.get_connected_joypads().is_empty()


func get_status_text() -> String:
	if not is_available():
		return "Sin gamepad"
	return Input.get_joy_name(_device())


func update(_delta: float) -> void:
	if not is_available():
		release_all()
		return
	var device := _device()
	raw_steer = clampf(Input.get_joy_axis(device, AXIS_STEER), -1.0, 1.0)
	raw_throttle = clampf(Input.get_joy_axis(device, AXIS_THROTTLE), 0.0, 1.0)
	raw_brake = clampf(Input.get_joy_axis(device, AXIS_BRAKE), 0.0, 1.0)

	for action: StringName in BUTTONS_ACTIONS:
		_set_button(action, Input.is_joy_button_pressed(device, BUTTONS_ACTIONS[action]))

	var up := Input.is_joy_button_pressed(device, BUTTON_ENCODER_UP)
	var down := Input.is_joy_button_pressed(device, BUTTON_ENCODER_DOWN)
	if up and not _encoder_up_was_pressed:
		_encoder_steps += 1
	if down and not _encoder_down_was_pressed:
		_encoder_steps -= 1
	_encoder_up_was_pressed = up
	_encoder_down_was_pressed = down


func vibrate(intensity: float, duration_s: float) -> void:
	if is_available():
		# Motor "débil" para vibraciones finas y "fuerte" para golpes.
		Input.start_joy_vibration(_device(), intensity * 0.6, intensity, duration_s)


func release_all() -> void:
	super.release_all()
	_encoder_up_was_pressed = false
	_encoder_down_was_pressed = false


# Índice del primer joypad conectado.
func _device() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else 0
