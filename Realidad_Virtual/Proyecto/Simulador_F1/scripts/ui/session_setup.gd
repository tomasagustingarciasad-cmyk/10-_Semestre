extends Control
## Menú "Preparar sesión": circuito, clima, vueltas y neumático de salida.
##
## Es el paso entre elegir el nivel y empezar a correr:
##     Nivel -> Circuito -> Clima -> (Carrera: vueltas) -> Neumático -> Empezar
## Cada opción es un "selector" (un botón que muestra ◀ valor ▶):
##   - arriba/abajo (encoder del volante) pasa de un selector a otro;
##   - izquierda/derecha (levas del volante) cambia el valor;
##   - aceptar (botón DRS) sobre "Empezar" inicia la sesión;
##   - cancelar (botón Reset) vuelve al menú principal.
## La última selección queda guardada en las opciones.

const ROW_SIZE := Vector2(520.0, 46.0)
const PREVIEW_SIZE := Vector2(420.0, 300.0)
const INFO_WIDTH := 420.0
const LAPS_MIN := 1
const LAPS_MAX := 20
const RECOMMENDED_TEXT := "Recomendado para este clima: %s"
## Nivel de agua del modo Lluvia (igual al valor por defecto de Weather.rain_water_level).
const DEFAULT_RAIN_WATER := 0.7
const VARIABLE_HINT := "Clima variable: puede empezar seco y largarse a llover, o al revés."


## Botón selector: muestra "◀ valor ▶" y cambia de valor con izquierda/derecha.
class Selector:
	extends Button
	signal changed(index: int)
	var title: String = ""
	var options: PackedStringArray = PackedStringArray()
	var index: int = 0

	func configure(row_title: String, row_options: PackedStringArray, start_index: int) -> void:
		title = row_title
		options = row_options
		index = clampi(start_index, 0, maxi(options.size() - 1, 0))
		pressed.connect(step.bind(1))
		_refresh()

	## Avanza (1) o retrocede (-1) una opción, dando la vuelta al final.
	func step(direction: int) -> void:
		if options.is_empty():
			return
		index = posmod(index + direction, options.size())
		_refresh()
		changed.emit(index)

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			step(-1)
			accept_event()
		elif event.is_action_pressed("ui_right"):
			step(1)
			accept_event()

	func _refresh() -> void:
		text = "%s:   ◀  %s  ▶" % [title, options[index] if not options.is_empty() else "-"]


## Dibujo del trazado de un circuito (vista desde arriba, norte arriba).
class CircuitPreview:
	extends Control
	const MARGIN := 14.0
	const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
	const START_COLOR := Color(1.0, 0.25, 0.25)
	const ARROW_COLOR := Color(1.0, 0.85, 0.2)
	var _points: PackedVector2Array = PackedVector2Array()
	var _bounds: Rect2 = Rect2()

	func show_circuit(data: CircuitData) -> void:
		# Se dibuja la misma curva que usa el juego, muestreada cada pocos metros.
		var curve := TrackLayout.build_curve(data.points, true, 8.0)
		_points = PackedVector2Array()
		for point in curve.get_baked_points():
			_points.append(Vector2(point.x, point.z))
		_bounds = Rect2(_points[0], Vector2.ZERO)
		for point in _points:
			_bounds = _bounds.expand(point)
		queue_redraw()

	func _draw() -> void:
		if _points.size() < 2:
			return
		var mapped := PackedVector2Array()
		for point in _points:
			mapped.append(_to_screen(point))
		draw_polyline(mapped, LINE_COLOR, 3.0, true)
		# Línea de largada y flecha con el sentido de marcha.
		draw_circle(mapped[0], 6.0, START_COLOR)
		var ahead := mapped[mini(6, mapped.size() - 1)]
		var direction := (ahead - mapped[0]).normalized()
		var tip := mapped[0] + direction * 26.0
		var side := direction.orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([tip, tip - direction * 14.0 + side, tip - direction * 14.0 - side]), ARROW_COLOR)

	func _to_screen(point: Vector2) -> Vector2:
		var available := size - Vector2(MARGIN, MARGIN) * 2.0
		var scale_factor := minf(available.x / maxf(_bounds.size.x, 1.0), available.y / maxf(_bounds.size.y, 1.0))
		var drawn := _bounds.size * scale_factor
		return Vector2(MARGIN, MARGIN) + (available - drawn) * 0.5 + (point - _bounds.position) * scale_factor


var _circuit_ids: PackedStringArray = PackedStringArray()
var _circuits: Array[CircuitData] = []
var _is_race: bool = false

var _circuit_selector: Selector
var _weather_selector: Selector
var _laps_selector: Selector
var _compound_selector: Selector
var _preview: CircuitPreview
var _lbl_info: Label
var _lbl_times: Label
var _lbl_hint: Label
var _start_button: Button


func _ready() -> void:
	GameState.in_menu = true
	_is_race = GameState.pending_level == GameState.SCENE_RACE
	theme = UiTheme.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self)

	_circuit_ids = TrackLayout.list_ids()
	var circuit_names := PackedStringArray()
	for id in _circuit_ids:
		var data := TrackLayout.load_circuit(id)
		_circuits.append(data)
		circuit_names.append(data.display_name)

	# Página deslizable: si el menú no entra en la pantalla se puede deslizar.
	var center := UiTheme.make_scroll_page(self)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	center.add_child(page)

	var title := UiTheme.make_label("CARRERA" if _is_race else "CLASIFICACIÓN", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 34)
	page.add_child(columns)

	# --- Columna izquierda: selectores -----------------------------------------
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	columns.add_child(rows)

	_circuit_selector = _add_selector(rows, "Circuito", circuit_names,
			maxi(_circuit_ids.find(Settings.sel_circuit), 0))
	_weather_selector = _add_selector(rows, "Clima", PackedStringArray(Weather.MODE_LABELS),
			maxi(Weather.MODE_IDS.find(Settings.sel_weather), 0))
	if _is_race:
		var lap_options := PackedStringArray()
		for laps in range(LAPS_MIN, LAPS_MAX + 1):
			lap_options.append(str(laps))
		_laps_selector = _add_selector(rows, "Vueltas", lap_options, Settings.race_laps - LAPS_MIN)
	var compound_names := PackedStringArray()
	for compound_id in TyreCompound.IDS:
		var compound := TyreCompound.load_compound(compound_id)
		compound_names.append("%s (%s)" % [compound.display_name, compound.letter])
	_compound_selector = _add_selector(rows, "Neumático de salida", compound_names,
			maxi(TyreCompound.IDS.find(Settings.sel_compound), 0))

	_lbl_hint = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_WARNING)
	_lbl_hint.custom_minimum_size.x = ROW_SIZE.x
	_lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_lbl_hint)

	_start_button = UiTheme.make_button("Empezar")
	_start_button.custom_minimum_size = ROW_SIZE
	_start_button.pressed.connect(_on_start_pressed)
	rows.add_child(_start_button)
	var back := UiTheme.make_button("Volver")
	back.custom_minimum_size = ROW_SIZE
	back.pressed.connect(GameState.goto_main_menu)
	rows.add_child(back)

	var help := UiTheme.make_label(
			"↑ ↓ elegir opción   ·   ← → cambiar valor   ·   Enter empezar\nVolante: encoder, levas, DRS = aceptar, Reset = volver",
			UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	rows.add_child(help)

	# --- Columna derecha: trazado, datos y mejores tiempos ----------------------
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	columns.add_child(side)
	var frame := UiTheme.make_panel()
	side.add_child(frame)
	_preview = CircuitPreview.new()
	_preview.custom_minimum_size = PREVIEW_SIZE
	frame.add_child(_preview)
	_lbl_info = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL)
	_lbl_info.custom_minimum_size.x = INFO_WIDTH
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_lbl_info)
	_lbl_times = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_ACCENT_BRIGHT)
	_lbl_times.custom_minimum_size.x = INFO_WIDTH
	side.add_child(_lbl_times)

	_refresh()
	_circuit_selector.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.goto_main_menu()


func _add_selector(parent: Control, title: String, options: PackedStringArray, start_index: int) -> Selector:
	var selector := Selector.new()
	selector.custom_minimum_size = ROW_SIZE
	selector.configure(title, options, start_index)
	selector.changed.connect(func(_index: int) -> void: _refresh())
	parent.add_child(selector)
	return selector


# Actualiza el dibujo, los datos del circuito, los tiempos y la sugerencia.
func _refresh() -> void:
	var data := _circuits[_circuit_selector.index]
	var weather_id := Weather.MODE_IDS[_weather_selector.index]
	_preview.show_circuit(data)

	var lines := PackedStringArray()
	lines.append("%s  (%d de %d)" % [data.display_name, _circuit_selector.index + 1, _circuits.size()])
	lines.append(data.location)
	lines.append("Longitud: %.3f km   ·   Sentido: %s" % [data.official_length / 1000.0,
			"horario" if data.clockwise else "antihorario"])
	if data.notes != "":
		lines.append("Nota: " + data.notes)
	_lbl_info.text = "\n".join(lines)

	var entries := BestTimes.get_list(data.id, weather_id)
	if entries.is_empty():
		_lbl_times.text = "Mejores tiempos (%s): todavía no hay" % Weather.MODE_LABELS[_weather_selector.index].to_lower()
	else:
		var time_lines := PackedStringArray(["Mejores tiempos (%s):" % Weather.MODE_LABELS[_weather_selector.index].to_lower()])
		for i in entries.size():
			var entry: Dictionary = entries[i]
			time_lines.append("  %d.  %s   %s   %s" % [i + 1, GameState.format_time(entry["time"]),
					TyreCompound.load_compound(entry["compound"]).display_name, entry["date"]])
		_lbl_times.text = "\n".join(time_lines)

	# Sugerencia de neumático según el clima elegido.
	if weather_id == "variable":
		_lbl_hint.text = VARIABLE_HINT
	else:
		var water := 0.0
		if weather_id == "lluvia":
			water = DEFAULT_RAIN_WATER
		_lbl_hint.text = RECOMMENDED_TEXT % TyreCompound.best_for(water).display_name


func _on_start_pressed() -> void:
	Settings.sel_circuit = _circuit_ids[_circuit_selector.index]
	Settings.sel_weather = Weather.MODE_IDS[_weather_selector.index]
	Settings.sel_compound = TyreCompound.IDS[_compound_selector.index]
	if _laps_selector != null:
		Settings.race_laps = LAPS_MIN + _laps_selector.index
	Settings.save()
	GameState.goto_scene(GameState.pending_level)
