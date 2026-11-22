extends Control
## Menú principal: elegir nivel, opciones, calibración o salir.
##
## Se navega con mouse, teclado, gamepad o con el propio volante (el
## InputManager traduce encoder y botones a acciones de interfaz).

const TITLE := "SIMULADOR F1"
const SUBTITLE := "Trabajo Integrador de Realidad Virtual — Sistema de Realidad Mixta"
const LEVEL_1_TEXT := "Nivel 1 — Clasificación (vuelta rápida contra el fantasma)"
const LEVEL_2_TEXT := "Nivel 2 — Carrera (rivales, estrategia y parada en boxes)"

var _lbl_status: Label


func _ready() -> void:
	GameState.in_menu = true
	get_tree().paused = false
	TelemetryOut.stop()
	theme = UiTheme.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self)

	# Página deslizable: si el menú no entra en la pantalla se puede deslizar.
	var center := UiTheme.make_scroll_page(self)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := UiTheme.make_label(TITLE, UiTheme.FONT_SIZE_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UiTheme.make_label(SUBTITLE, UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_spacer(18.0))

	var first := _add_button(box, LEVEL_1_TEXT, func() -> void: GameState.prepare_level(GameState.SCENE_QUALIFYING))
	_add_button(box, LEVEL_2_TEXT, func() -> void: GameState.prepare_level(GameState.SCENE_RACE))
	_add_button(box, "Opciones", func() -> void: GameState.goto_scene(GameState.SCENE_OPTIONS))
	_add_button(box, "Calibrar volante", func() -> void: GameState.goto_scene(GameState.SCENE_CALIBRATION))
	_add_button(box, "Salir", func() -> void: get_tree().quit())

	box.add_child(_spacer(10.0))
	_lbl_status = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL)
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lbl_status)

	first.grab_focus()


func _process(_delta: float) -> void:
	# Estado del dispositivo de entrada elegido (se actualiza en vivo).
	var connected := InputManager.is_device_connected()
	_lbl_status.text = "Entrada: %s — %s     Caja: %s" % [
		InputManager.get_source_label(), InputManager.get_status_text(),
		"automática" if Settings.auto_gearbox else "manual"]
	_lbl_status.add_theme_color_override("font_color",
			UiTheme.COLOR_GOOD if connected else UiTheme.COLOR_WARNING)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := UiTheme.make_button(text)
	button.custom_minimum_size.x = 640.0
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer
