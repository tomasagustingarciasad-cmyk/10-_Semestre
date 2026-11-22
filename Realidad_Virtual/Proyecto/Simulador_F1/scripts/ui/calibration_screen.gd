extends Control
## Pantalla de calibración del volante.
##
## El sensor de dirección (AS5600) entrega un ángulo cuyo cero y cuyos topes
## dependen de cómo quedó montado el imán. Esta pantalla registra tres
## valores crudos del protocolo (-1000..1000):
##     1) volante a tope a la IZQUIERDA
##     2) volante a tope a la DERECHA
##     3) volante SUELTO (centro)
## y los guarda en `user://opciones.cfg`. Con ellos UdpWheelSource convierte
## cualquier lectura a -1..1 interpolando por separado a cada lado del centro.
##
## Mientras la pantalla está abierta se usa la fuente "Volante UDP" (sirve
## también con tools/fake_wheel.py); al salir se restaura la fuente elegida.

const STEP_LEFT := 0
const STEP_RIGHT := 1
const STEP_CENTER := 2
const STEP_REVIEW := 3

const STEP_INSTRUCTIONS := [
	"Paso 1 de 3 — Girá el volante A TOPE hacia la IZQUIERDA y presioná Capturar",
	"Paso 2 de 3 — Girá el volante A TOPE hacia la DERECHA y presioná Capturar",
	"Paso 3 de 3 — SOLTÁ el volante (centro) y presioná Capturar",
	"Revisá los valores y guardá la calibración",
]
# Recorrido mínimo aceptable entre el centro y cada tope (unidades crudas).
const MIN_SPAN := 100
const RAW_RANGE := 1000.0
const BAR_SIZE := Vector2(300.0, 22.0)

var _wheel: UdpWheelSource
var _step: int = STEP_LEFT
var _captured: Array[int] = [0, 0, 0]

var _lbl_instruction: Label
var _lbl_status: Label
var _lbl_raw: Label
var _lbl_values: Label
var _lbl_result: Label
var _bar_left: ProgressBar
var _bar_right: ProgressBar
var _btn_capture: Button
var _btn_save: Button


func _ready() -> void:
	GameState.in_menu = true
	theme = UiTheme.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self)

	# Durante la calibración se escucha al volante sin tocar la opción guardada.
	InputManager.set_source(Settings.SOURCE_UDP_WHEEL)
	_wheel = InputManager.get_source(Settings.SOURCE_UDP_WHEEL) as UdpWheelSource

	# Página deslizable: si el menú no entra en la pantalla se puede deslizar.
	var center := UiTheme.make_scroll_page(self)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := UiTheme.make_label("CALIBRACIÓN DEL VOLANTE", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_lbl_status = _add_centered_label(box, UiTheme.FONT_SIZE_SMALL)
	_lbl_instruction = _add_centered_label(box, UiTheme.FONT_SIZE_SUBTITLE)
	_lbl_instruction.add_theme_color_override("font_color", UiTheme.COLOR_WARNING)

	# Lectura cruda en vivo: barra partida al medio (izquierda | derecha).
	var bars := HBoxContainer.new()
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 0)
	_bar_left = UiTheme.make_bar(UiTheme.COLOR_ACCENT_BRIGHT, BAR_SIZE)
	_bar_left.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_bar_right = UiTheme.make_bar(UiTheme.COLOR_ACCENT_BRIGHT, BAR_SIZE)
	bars.add_child(_bar_left)
	bars.add_child(_bar_right)
	box.add_child(bars)
	_lbl_raw = _add_centered_label(box, 28)
	_lbl_values = _add_centered_label(box, UiTheme.FONT_SIZE_NORMAL)
	_lbl_result = _add_centered_label(box, UiTheme.FONT_SIZE_NORMAL)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_btn_capture = _add_button(buttons, "Capturar", _on_capture_pressed)
	_btn_save = _add_button(buttons, "Guardar", _on_save_pressed)
	_add_button(buttons, "Empezar de nuevo", _restart)
	_add_button(buttons, "Valores de fábrica", _on_factory_pressed)
	_add_button(buttons, "Volver", _on_back_pressed)

	var hint := UiTheme.make_label(
			"Con el volante: el botón DRS equivale a Capturar/Aceptar y el encoder mueve el foco.",
			UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	_restart()


func _exit_tree() -> void:
	# Se vuelve a la fuente que el usuario tiene elegida en las opciones.
	InputManager.set_source(Settings.input_source)


func _process(_delta: float) -> void:
	var connected := _wheel.is_available()
	_lbl_status.text = "Volante UDP (puerto %d): %s — paquetes recibidos: %d" % [
		WheelProtocol.PORT_WHEEL_TO_PC, _wheel.get_status_text(), _wheel.packets_received]
	_lbl_status.add_theme_color_override("font_color",
			UiTheme.COLOR_GOOD if connected else UiTheme.COLOR_WARNING)
	var raw := _wheel.raw_steer_units if connected else 0
	_lbl_raw.text = "Lectura cruda: %d" % raw
	_bar_left.value = maxf(-raw / RAW_RANGE, 0.0)
	_bar_right.value = maxf(raw / RAW_RANGE, 0.0)
	_btn_capture.disabled = not connected or _step == STEP_REVIEW


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _restart() -> void:
	_step = STEP_LEFT
	_captured = [0, 0, 0]
	_lbl_result.text = "Calibración actual: izquierda %d, centro %d, derecha %d%s" % [
		Settings.cal_steer_left, Settings.cal_steer_center, Settings.cal_steer_right,
		"" if Settings.cal_done else " (valores de fábrica)"]
	_lbl_result.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_DIM)
	_refresh()
	_btn_capture.grab_focus()


func _refresh() -> void:
	_lbl_instruction.text = STEP_INSTRUCTIONS[_step]
	var parts := PackedStringArray()
	if _step > STEP_LEFT:
		parts.append("Izquierda: %d" % _captured[STEP_LEFT])
	if _step > STEP_RIGHT:
		parts.append("Derecha: %d" % _captured[STEP_RIGHT])
	if _step > STEP_CENTER:
		parts.append("Centro: %d" % _captured[STEP_CENTER])
	_lbl_values.text = "     ".join(parts)
	_btn_save.disabled = _step != STEP_REVIEW or not _is_valid()
	if _step == STEP_REVIEW:
		if _is_valid():
			_lbl_result.text = "Valores correctos. Presioná Guardar."
			_lbl_result.add_theme_color_override("font_color", UiTheme.COLOR_GOOD)
			_btn_save.grab_focus()
		else:
			_lbl_result.text = "Valores inválidos: el centro debe quedar entre los topes, con recorrido a ambos lados. Empezá de nuevo."
			_lbl_result.add_theme_color_override("font_color", UiTheme.COLOR_BAD)


# La calibración sirve si izquierda < centro < derecha con recorrido suficiente.
func _is_valid() -> bool:
	var left := _captured[STEP_LEFT]
	var right := _captured[STEP_RIGHT]
	var center := _captured[STEP_CENTER]
	return center - left >= MIN_SPAN and right - center >= MIN_SPAN


func _on_capture_pressed() -> void:
	if _step >= STEP_REVIEW:
		return
	_captured[_step] = _wheel.raw_steer_units
	_step += 1
	_refresh()


func _on_save_pressed() -> void:
	if _step != STEP_REVIEW or not _is_valid():
		return
	Settings.set_calibration(_captured[STEP_LEFT], _captured[STEP_CENTER], _captured[STEP_RIGHT])
	_restart()
	_lbl_result.text = "Calibración guardada."
	_lbl_result.add_theme_color_override("font_color", UiTheme.COLOR_GOOD)


func _on_factory_pressed() -> void:
	Settings.reset_calibration()
	_restart()


func _on_back_pressed() -> void:
	GameState.goto_main_menu()


func _add_centered_label(parent: Control, font_size: int) -> Label:
	var label := UiTheme.make_label("", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := UiTheme.make_button(text)
	button.custom_minimum_size.x = 210.0
	button.pressed.connect(action)
	parent.add_child(button)
	return button
