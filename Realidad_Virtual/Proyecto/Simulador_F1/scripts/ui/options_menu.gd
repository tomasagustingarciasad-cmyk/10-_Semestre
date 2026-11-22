extends Control
## Menú de opciones.
##
## Permite elegir la fuente de entrada (teclado, gamepad, volante UDP o piloto
## automático), ajustar la respuesta de la dirección (sensibilidad, curva y
## zona muerta), la caja automática/manual y los datos del volante.
## Cada cambio se aplica y se guarda en el momento (Settings.save()), y la
## barra "Prueba de dirección" muestra en vivo cómo queda la entrada.

const LABEL_WIDTH := 300.0
const CONTROL_WIDTH := 320.0
const VALUE_WIDTH := 90.0

var _source_ids: Array[String] = []
var _lbl_source_status: Label
var _bar_steer_left: ProgressBar
var _bar_steer_right: ProgressBar
var _bar_throttle: ProgressBar
var _bar_brake: ProgressBar
var _grid: GridContainer


func _ready() -> void:
	GameState.in_menu = true
	theme = UiTheme.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self)

	# Página deslizable: si el menú no entra en la pantalla se puede deslizar.
	var center := UiTheme.make_scroll_page(self)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := UiTheme.make_label("OPCIONES", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 10)
	box.add_child(_grid)

	# --- Fuente de entrada ---------------------------------------------------
	var source_option := OptionButton.new()
	source_option.custom_minimum_size.x = CONTROL_WIDTH
	for entry: Array in InputManager.get_source_list():
		_source_ids.append(entry[0])
		source_option.add_item(entry[1])
	source_option.select(maxi(_source_ids.find(Settings.input_source), 0))
	source_option.item_selected.connect(_on_source_selected)
	_lbl_source_status = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL)
	_add_row("Fuente de entrada", source_option, _lbl_source_status)

	# --- Dirección -------------------------------------------------------------
	_add_slider("Sensibilidad de dirección", Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX, 0.05,
			Settings.steer_sensitivity, "x%.2f",
			func(value: float) -> void: Settings.steer_sensitivity = value)
	_add_slider("Curva de dirección (1 = lineal)", Settings.CURVE_MIN, Settings.CURVE_MAX, 0.1,
			Settings.steer_curve, "%.1f",
			func(value: float) -> void: Settings.steer_curve = value)
	_add_slider("Zona muerta", 0.0, Settings.DEADZONE_MAX, 0.01,
			Settings.deadzone, "%.2f",
			func(value: float) -> void: Settings.deadzone = value)

	var assist_option := OptionButton.new()
	assist_option.custom_minimum_size.x = CONTROL_WIDTH
	for label in Settings.STEER_ASSIST_LABELS:
		assist_option.add_item(label)
	assist_option.select(maxi(Settings.STEER_ASSIST_IDS.find(Settings.steer_assist), 0))
	assist_option.item_selected.connect(func(index: int) -> void:
		Settings.steer_assist = Settings.STEER_ASSIST_IDS[index]
		Settings.save())
	_add_row("Ayuda de dirección", assist_option, UiTheme.make_label(
			"Limita el giro a lo que el agarre permite", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM))

	# --- Conducción ---------------------------------------------------------------
	var auto_check := CheckButton.new()
	auto_check.text = "Automática"
	auto_check.button_pressed = Settings.auto_gearbox
	auto_check.toggled.connect(func(pressed: bool) -> void:
		Settings.auto_gearbox = pressed
		Settings.save())
	_add_row("Caja de cambios", auto_check, UiTheme.make_label("Apagado = manual (levas)", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM))

	var difficulty_option := OptionButton.new()
	difficulty_option.custom_minimum_size.x = CONTROL_WIDTH
	for label in Settings.AI_DIFFICULTY_LABELS:
		difficulty_option.add_item(label)
	difficulty_option.select(Settings.ai_difficulty)
	difficulty_option.item_selected.connect(func(index: int) -> void:
		Settings.ai_difficulty = index
		Settings.save())
	_add_row("Dificultad de los rivales", difficulty_option, Control.new())

	_add_slider("Vueltas de la carrera", Settings.RACE_LAPS_MIN, Settings.RACE_LAPS_MAX, 1.0,
			Settings.race_laps, "%d",
			func(value: float) -> void: Settings.race_laps = int(value))
	_add_slider("Volumen general", 0.0, 1.0, 0.05, Settings.master_volume, "%.2f",
			func(value: float) -> void: Settings.master_volume = value)

	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = "Pantalla completa"
	fullscreen_check.button_pressed = Settings.fullscreen
	fullscreen_check.toggled.connect(func(pressed: bool) -> void:
		Settings.fullscreen = pressed
		Settings.save())
	_add_row("Video", fullscreen_check, Control.new())

	# --- Volante UDP ----------------------------------------------------------------
	var host_edit := LineEdit.new()
	host_edit.text = Settings.wheel_host
	host_edit.custom_minimum_size.x = CONTROL_WIDTH
	host_edit.text_submitted.connect(func(text: String) -> void:
		Settings.wheel_host = text.strip_edges()
		Settings.save())
	host_edit.focus_exited.connect(func() -> void:
		Settings.wheel_host = host_edit.text.strip_edges()
		Settings.save())
	_add_row("IP del volante (telemetría)", host_edit,
			UiTheme.make_label("Puerto %d" % WheelProtocol.PORT_PC_TO_WHEEL, UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM))

	var log_check := CheckButton.new()
	log_check.text = "Imprimir en consola"
	log_check.button_pressed = Settings.telemetry_debug_log
	log_check.toggled.connect(func(pressed: bool) -> void:
		Settings.telemetry_debug_log = pressed
		Settings.save())
	_add_row("Log de telemetría", log_check, Control.new())

	# --- Prueba en vivo ---------------------------------------------------------------
	var test_row := HBoxContainer.new()
	test_row.add_theme_constant_override("separation", 0)
	_bar_steer_left = UiTheme.make_bar(UiTheme.COLOR_ACCENT_BRIGHT, Vector2(CONTROL_WIDTH * 0.5, 16.0))
	_bar_steer_left.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_bar_steer_right = UiTheme.make_bar(UiTheme.COLOR_ACCENT_BRIGHT, Vector2(CONTROL_WIDTH * 0.5, 16.0))
	test_row.add_child(_bar_steer_left)
	test_row.add_child(_bar_steer_right)
	var pedal_row := HBoxContainer.new()
	_bar_brake = UiTheme.make_bar(UiTheme.COLOR_BAD, Vector2(VALUE_WIDTH * 0.5, 16.0))
	_bar_throttle = UiTheme.make_bar(UiTheme.COLOR_GOOD, Vector2(VALUE_WIDTH * 0.5, 16.0))
	pedal_row.add_child(_bar_brake)
	pedal_row.add_child(_bar_throttle)
	_add_row("Prueba de dirección y pedales", test_row, pedal_row)

	# --- Botones ----------------------------------------------------------------------
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)
	var calibrate := UiTheme.make_button("Calibrar volante")
	calibrate.custom_minimum_size.x = 280.0
	calibrate.pressed.connect(func() -> void: GameState.goto_scene(GameState.SCENE_CALIBRATION))
	buttons.add_child(calibrate)
	var back := UiTheme.make_button("Volver")
	back.custom_minimum_size.x = 280.0
	back.pressed.connect(_on_back_pressed)
	buttons.add_child(back)

	source_option.grab_focus()


func _process(_delta: float) -> void:
	_lbl_source_status.text = InputManager.get_status_text()
	_lbl_source_status.add_theme_color_override("font_color",
			UiTheme.COLOR_GOOD if InputManager.is_device_connected() else UiTheme.COLOR_WARNING)
	_bar_steer_left.value = maxf(-InputManager.steer, 0.0)
	_bar_steer_right.value = maxf(InputManager.steer, 0.0)
	_bar_throttle.value = InputManager.throttle
	_bar_brake.value = InputManager.brake


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


# Agrega una fila: nombre | control | información adicional.
func _add_row(title: String, control: Control, extra: Control) -> void:
	var label := UiTheme.make_label(title)
	label.custom_minimum_size.x = LABEL_WIDTH
	_grid.add_child(label)
	_grid.add_child(control)
	extra.custom_minimum_size.x = VALUE_WIDTH
	_grid.add_child(extra)


# Agrega una fila con un control deslizante y su valor numérico.
func _add_slider(title: String, minimum: float, maximum: float, step: float, value: float,
		format: String, setter: Callable) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(CONTROL_WIDTH, 24.0)
	# La rueda del mouse desliza la página, no cambia el valor (se cambia con
	# clic/arrastre, flechas, gamepad o las levas del volante).
	slider.scrollable = false
	var value_label := UiTheme.make_label(_format_value(format, value), UiTheme.FONT_SIZE_NORMAL, UiTheme.COLOR_ACCENT_BRIGHT)
	slider.value_changed.connect(func(new_value: float) -> void:
		setter.call(new_value)
		value_label.text = _format_value(format, new_value)
		Settings.save())
	_add_row(title, slider, value_label)


func _format_value(format: String, value: float) -> String:
	if format.contains("%d"):
		return format % int(round(value))
	return format % value


func _on_source_selected(index: int) -> void:
	Settings.input_source = _source_ids[index]
	Settings.save()   # El InputManager escucha Settings.changed y cambia de fuente.


func _on_back_pressed() -> void:
	Settings.save()
	GameState.goto_main_menu()
