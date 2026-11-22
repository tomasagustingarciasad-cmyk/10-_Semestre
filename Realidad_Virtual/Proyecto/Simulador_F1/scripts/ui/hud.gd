class_name Hud
extends CanvasLayer
## HUD: toda la información que el piloto ve en pantalla.
##
## Se arma por código con nodos Control. Distribución:
##   - arriba a la izquierda: tiempos (vuelta, sectores, delta) y, en carrera,
##     posición y vuelta;
##   - arriba al centro: semáforo de largada, mensajes y avisos;
##   - arriba a la derecha: neumáticos, estado del dispositivo de entrada;
##   - abajo al centro: shift lights, marcha, velocidad, RPM, ERS, DRS, pedales;
##   - abajo a la izquierda: minimapa; abajo a la derecha: clasificación.
##
## El HUD solo LEE datos del auto, del cronómetro y de la sesión; no decide nada.

const MARGIN := 16.0
const TYRE_BOX_SIZE := Vector2(58.0, 30.0)
const SECTOR_BOX_SIZE := Vector2(92.0, 28.0)
const VALUE_COLUMN_WIDTH := 110.0
const MINIMAP_SIZE := Vector2(230.0, 170.0)
const BAR_WIDTH := 430.0
const COLOR_SECTOR_PENDING := Color(1.0, 1.0, 1.0, 0.12)
const COLOR_INDICATOR_OFF := Color(1.0, 1.0, 1.0, 0.12)
# Frecuencia de parpadeo de los avisos [Hz].
const WARNING_BLINK_HZ := 2.0
# Tiempo de desvanecimiento final de los mensajes [s].
const MESSAGE_FADE_TIME := 0.4
# Nombres de las ruedas en el orden del auto.
const TYRE_LABELS := ["DI", "DD", "TI", "TD"]


## Fila de luces rojas del semáforo de largada (dibujada con círculos).
class LightRow:
	extends Control
	const COUNT := 5
	const GAP := 10.0
	const COLOR_OFF := Color(0.2, 0.03, 0.03, 0.85)
	const COLOR_ON := Color(1.0, 0.1, 0.1)
	var lit: int = 0:
		set(value):
			lit = value
			queue_redraw()

	func _draw() -> void:
		var diameter := size.y
		for i in COUNT:
			var center := Vector2(diameter * 0.5 + i * (diameter + GAP), size.y * 0.5)
			draw_circle(center, diameter * 0.5, COLOR_ON if i < lit else COLOR_OFF)


var _session: SessionBase = null
var _car: F1Car = null
var _timer: LapTimer = null
var _race: RaceSession = null

var _root: Control
# Tiempos.
var _lbl_header: Label
var _lbl_current: Label
var _lbl_last: Label
var _lbl_best: Label
var _lbl_reference_name: Label
var _lbl_reference: Label
var _lbl_delta: Label
var _sector_boxes: Array[PanelContainer] = []
var _sector_labels: Array[Label] = []
# Centro.
var _light_row: LightRow
var _lbl_message: Label
var _lbl_warning: Label
var _message_time_left: float = 0.0
# Derecha.
var _lbl_input: Label
var _tyre_boxes: Array[ColorRect] = []
var _tyre_labels: Array[Label] = []
var _lbl_bias: Label
var _lbl_conditions: Label
var _lbl_compound: Label
var _box_compound: PanelContainer
var _lbl_pit: Label
# Abajo.
var _shift_lights: ShiftLights
var _lbl_speed: Label
var _lbl_gear: Label
var _lbl_rpm: Label
var _bar_rpm: ProgressBar
var _bar_ers: ProgressBar
var _lbl_ers: Label
var _box_drs: PanelContainer
var _lbl_drs: Label
var _box_limiter: PanelContainer
var _bar_throttle: ProgressBar
var _bar_brake: ProgressBar
var _minimap: Minimap
var _lbl_standings: Label


func _ready() -> void:
	_build()


## Conecta el HUD con la sesión en curso.
func bind(session: SessionBase) -> void:
	_session = session
	_car = session.car
	_timer = session.lap_timer
	_race = session as RaceSession
	_timer.sector_completed.connect(_on_sector_completed)
	_timer.lap_started.connect(_on_lap_started)
	var rivals: Array = _race.rivals if _race != null else []
	_minimap.setup(session.track, _car, rivals)
	_lbl_pit.visible = _race != null
	_lbl_standings.get_parent().visible = _race != null
	_light_row.visible = _race != null
	_lbl_reference_name.text = "Récord" if _race == null else "Penaliz."


## Muestra un mensaje grande durante `seconds` segundos.
func show_message(text: String, color: Color, seconds: float) -> void:
	_lbl_message.text = text
	_lbl_message.add_theme_color_override("font_color", color)
	_lbl_message.modulate.a = 1.0
	_message_time_left = seconds


func _process(delta: float) -> void:
	if _car == null:
		return
	_update_driving()
	_update_timing()
	_update_status()
	_update_messages(delta)


# ==============================================================================
# Actualización
# ==============================================================================

func _update_driving() -> void:
	var rpm_pct := _car.drivetrain.get_rpm_pct()
	_shift_lights.rpm_pct = rpm_pct
	_lbl_speed.text = "%d" % int(round(_car.speed_kmh))
	_lbl_gear.text = _car.get_gear_text()
	_lbl_rpm.text = "%d rpm" % (int(round(_car.drivetrain.rpm / 100.0)) * 100)
	_bar_rpm.value = rpm_pct / 100.0
	_bar_ers.value = _car.ers.get_charge()
	_lbl_ers.text = "ERS %d %%" % int(round(_car.ers.get_charge() * 100.0))
	var ers_color := UiTheme.COLOR_TEXT
	if _car.ers.deploying:
		ers_color = UiTheme.COLOR_WARNING
	elif _car.ers.harvesting:
		ers_color = UiTheme.COLOR_GOOD
	_lbl_ers.add_theme_color_override("font_color", ers_color)

	# DRS: apagado = fuera de zona, borde verde = disponible, lleno = abierto.
	var drs_color := COLOR_INDICATOR_OFF
	var drs_text_color := UiTheme.COLOR_TEXT_DIM
	if _car.drs.open:
		drs_color = UiTheme.COLOR_GOOD
		drs_text_color = Color.BLACK
	elif _car.drs.is_available():
		drs_color = Color(UiTheme.COLOR_GOOD, 0.35)
		drs_text_color = UiTheme.COLOR_GOOD
	(_box_drs.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = drs_color
	_lbl_drs.add_theme_color_override("font_color", drs_text_color)

	(_box_limiter.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = \
			UiTheme.COLOR_WARNING if _car.pit_limiter_on else COLOR_INDICATOR_OFF
	_bar_throttle.value = _car.throttle_input
	_bar_brake.value = _car.brake_input


func _update_timing() -> void:
	# Encabezado.
	if _race != null:
		var lap_shown := clampi(_timer.lap_number, 1, _race.total_laps)
		_lbl_header.text = "CARRERA  ·  P %d/%d  ·  Vuelta %d/%d" % [
			_race.player_position, _race.car_count, lap_shown, _race.total_laps]
	else:
		_lbl_header.text = "CLASIFICACIÓN  ·  Vuelta %d" % _timer.lap_number \
				if _timer.lap_number > 0 else "CLASIFICACIÓN  ·  Vuelta de salida"

	_lbl_current.text = GameState.format_time(_timer.get_lap_elapsed()) if _timer.lap_number > 0 else "-:--.---"
	_lbl_current.add_theme_color_override("font_color",
			UiTheme.COLOR_TEXT if _timer.lap_valid else UiTheme.COLOR_BAD)
	_lbl_last.text = GameState.format_time(_timer.last_lap_time)
	_lbl_last.add_theme_color_override("font_color",
			UiTheme.COLOR_TEXT if _timer.last_lap_valid else UiTheme.COLOR_BAD)
	_lbl_best.text = GameState.format_time(_timer.best_lap_time)

	if _race != null:
		_lbl_reference.text = "+%d s" % int(_race.penalty_seconds) if _race.penalty_seconds > 0.0 else "—"
	else:
		var reference_time := _timer.reference.lap_time if _timer.reference != null else 0.0
		_lbl_reference.text = GameState.format_time(reference_time)

	# Delta en vivo: verde si se va ganando tiempo, rojo si se pierde.
	if _timer.has_delta and _timer.lap_number > 0:
		_lbl_delta.text = GameState.format_delta(_timer.delta)
		_lbl_delta.add_theme_color_override("font_color",
				UiTheme.COLOR_GOOD if _timer.delta <= 0.0 else UiTheme.COLOR_BAD)
	else:
		_lbl_delta.text = ""


func _update_status() -> void:
	# Dispositivo de entrada.
	var connected := InputManager.is_device_connected()
	_lbl_input.text = "%s: %s" % [InputManager.get_source_label(), InputManager.get_status_text()]
	_lbl_input.add_theme_color_override("font_color", UiTheme.COLOR_GOOD if connected else UiTheme.COLOR_BAD)

	# Neumáticos: verde (nuevo) -> amarillo -> rojo (gastado).
	for i in F1Car.WHEEL_COUNT:
		var wear := _car.tyres.wear[i]
		_tyre_boxes[i].color = Color.from_hsv(lerpf(0.33, 0.0, wear), 0.85, 0.85)
		_tyre_labels[i].text = "%s %d%%" % [TYRE_LABELS[i], int(round((1.0 - wear) * 100.0))]
	_lbl_bias.text = "Reparto de frenos: %d %% adelante" % int(round(_car.brake_bias * 100.0))

	# Circuito y clima; compuesto montado.
	var weather := _session.weather
	_lbl_conditions.text = "%s · %s · agua %d %%" % [_session.track.display_name,
			weather.get_description(), int(round(weather.water_level * 100.0))]
	var compound := _car.compound
	(_box_compound.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = compound.color
	(_box_compound.get_child(0) as Label).text = compound.letter
	_lbl_compound.text = "%s · desgaste %d %%" % [compound.display_name,
			int(round(_car.tyres.get_average_wear() * 100.0))]

	if _race != null:
		if not _race.is_pit_stop_mandatory():
			_lbl_pit.text = "Boxes: parada libre"
			_lbl_pit.add_theme_color_override("font_color", UiTheme.COLOR_TEXT_DIM)
		elif _race.pit_stops > 0:
			_lbl_pit.text = "Parada obligatoria: CUMPLIDA"
			_lbl_pit.add_theme_color_override("font_color", UiTheme.COLOR_GOOD)
		else:
			_lbl_pit.text = "Parada obligatoria: PENDIENTE"
			_lbl_pit.add_theme_color_override("font_color", UiTheme.COLOR_WARNING)
		_light_row.lit = _race.lights_lit
		_light_row.visible = _race.phase == RaceSession.Phase.COUNTDOWN or _race.phase == RaceSession.Phase.GRID
		_update_standings()

	# Avisos persistentes (parpadean).
	var warning := ""
	if not connected:
		warning = "%s DESCONECTADO" % InputManager.get_source_label().to_upper()
	elif _car.in_pit_lane and not _car.pit_limiter_on:
		warning = "PIT LANE: máx. %d km/h — activá el limitador" % int(_car.setup.pit_speed_limit_kmh)
	elif _session.servicing and _session.pit_choice != null:
		warning = "EN BOXES — neumático: ◀ %s ▶ (levas)" % _session.pit_choice.display_name
	elif _car.aquaplaning:
		warning = "AQUAPLANING"
	_lbl_warning.text = warning
	var blink_on := fmod(Time.get_ticks_msec() / 1000.0 * WARNING_BLINK_HZ, 1.0) < 0.6
	_lbl_warning.modulate.a = 1.0 if blink_on else 0.25


func _update_standings() -> void:
	var lines := PackedStringArray()
	var standings := _race.get_standings()
	var leader_distance: float = standings[0]["distance"]
	for i in standings.size():
		var entry := standings[i]
		var gap: float = leader_distance - entry["distance"]
		var gap_text := "líder" if i == 0 else "+%d m" % int(round(gap))
		var marker := "▶ " if entry["is_player"] else "   "
		lines.append("%s%d  %s   %s" % [marker, i + 1, entry["name"], gap_text])
	_lbl_standings.text = "\n".join(lines)


func _update_messages(delta: float) -> void:
	if _message_time_left <= 0.0:
		_lbl_message.modulate.a = 0.0
		return
	_message_time_left -= delta
	_lbl_message.modulate.a = clampf(_message_time_left / MESSAGE_FADE_TIME, 0.0, 1.0)


func _on_sector_completed(sector_index: int, time: float, best_time: float) -> void:
	if sector_index == 0:
		# Empieza una vuelta nueva en pantalla: se limpian S2 y S3.
		for i in [1, 2]:
			_set_sector(i, "S%d  --.---" % (i + 1), COLOR_SECTOR_PENDING)
	# Violeta: mejor sector de la sesión. Amarillo: más lento que el mejor.
	var improved := best_time <= 0.0 or time < best_time
	var color := UiTheme.COLOR_PURPLE if improved else UiTheme.COLOR_WARNING
	if not _timer.lap_valid:
		color = UiTheme.COLOR_BAD
	_set_sector(sector_index, "S%d  %.3f" % [sector_index + 1, time], Color(color, 0.75))


func _on_lap_started(_lap_number: int) -> void:
	_set_sector(0, "S1  --.---", COLOR_SECTOR_PENDING)


func _set_sector(index: int, text: String, color: Color) -> void:
	_sector_labels[index].text = text
	(_sector_boxes[index].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color


# ==============================================================================
# Construcción de la interfaz
# ==============================================================================

func _build() -> void:
	_root = Control.new()
	_root.name = "Raiz"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_timing_panel()
	_build_center_top()
	_build_status_panel()
	_build_driving_cluster()
	_build_minimap()
	_build_standings()


func _build_timing_panel() -> void:
	var panel := UiTheme.make_panel()
	_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	_lbl_header = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_ACCENT_BRIGHT)
	box.add_child(_lbl_header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	box.add_child(grid)
	_lbl_current = _add_time_row(grid, "Actual", 26)
	_lbl_last = _add_time_row(grid, "Última", UiTheme.FONT_SIZE_NORMAL)
	_lbl_best = _add_time_row(grid, "Mejor", UiTheme.FONT_SIZE_NORMAL)
	_lbl_reference_name = UiTheme.make_label("Récord", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	grid.add_child(_lbl_reference_name)
	_lbl_reference = UiTheme.make_label("-:--.---", UiTheme.FONT_SIZE_NORMAL)
	_lbl_reference.custom_minimum_size.x = VALUE_COLUMN_WIDTH
	grid.add_child(_lbl_reference)

	var sectors := HBoxContainer.new()
	sectors.add_theme_constant_override("separation", 4)
	box.add_child(sectors)
	for i in LapTimer.SECTOR_COUNT:
		var sector_box := PanelContainer.new()
		var style := UiTheme.make_box(COLOR_SECTOR_PENDING, 4.0)
		sector_box.add_theme_stylebox_override("panel", style)
		sector_box.custom_minimum_size = SECTOR_BOX_SIZE
		var label := UiTheme.make_label("S%d  --.---" % (i + 1), UiTheme.FONT_SIZE_SMALL)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sector_box.add_child(label)
		sectors.add_child(sector_box)
		_sector_boxes.append(sector_box)
		_sector_labels.append(label)

	_lbl_delta = UiTheme.make_label("", 30, UiTheme.COLOR_GOOD)
	_lbl_delta.custom_minimum_size.y = 40.0
	box.add_child(_lbl_delta)
	_anchor(panel, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)


func _add_time_row(grid: GridContainer, title: String, font_size: int) -> Label:
	grid.add_child(UiTheme.make_label(title, UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM))
	var value := UiTheme.make_label("-:--.---", font_size)
	value.custom_minimum_size.x = VALUE_COLUMN_WIDTH
	grid.add_child(value)
	return value


func _build_center_top() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)

	_light_row = LightRow.new()
	var light_diameter := 44.0
	_light_row.custom_minimum_size = Vector2(
			LightRow.COUNT * light_diameter + (LightRow.COUNT - 1) * LightRow.GAP, light_diameter)
	_light_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_light_row)

	_lbl_warning = UiTheme.make_label("", 22, UiTheme.COLOR_BAD)
	_lbl_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_outline(_lbl_warning)
	box.add_child(_lbl_warning)

	_lbl_message = UiTheme.make_label("", 32)
	_lbl_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_message.modulate.a = 0.0
	_add_outline(_lbl_message)
	box.add_child(_lbl_message)
	_anchor(box, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)


func _build_status_panel() -> void:
	var panel := UiTheme.make_panel()
	_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	_lbl_input = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL)
	box.add_child(_lbl_input)

	_lbl_conditions = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	box.add_child(_lbl_conditions)

	# Compuesto montado: recuadro con su letra y su color + nombre.
	var compound_row := HBoxContainer.new()
	compound_row.add_theme_constant_override("separation", 8)
	box.add_child(compound_row)
	_box_compound = PanelContainer.new()
	_box_compound.add_theme_stylebox_override("panel", UiTheme.make_box(Color.WHITE, 2.0))
	_box_compound.custom_minimum_size = Vector2(26.0, 24.0)
	var letter := UiTheme.make_label("M", UiTheme.FONT_SIZE_SMALL, Color.BLACK)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box_compound.add_child(letter)
	compound_row.add_child(_box_compound)
	_lbl_compound = UiTheme.make_label("Neumáticos", UiTheme.FONT_SIZE_SMALL)
	compound_row.add_child(_lbl_compound)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for i in F1Car.WHEEL_COUNT:
		var tyre := ColorRect.new()
		tyre.custom_minimum_size = TYRE_BOX_SIZE
		tyre.color = Color.GREEN
		var label := UiTheme.make_label("", 13, Color.BLACK)
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tyre.add_child(label)
		grid.add_child(tyre)
		_tyre_boxes.append(tyre)
		_tyre_labels.append(label)

	_lbl_bias = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	box.add_child(_lbl_bias)
	_lbl_pit = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL)
	box.add_child(_lbl_pit)
	_anchor(panel, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)


func _build_driving_cluster() -> void:
	var panel := UiTheme.make_panel()
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	_shift_lights = ShiftLights.new()
	_shift_lights.custom_minimum_size = Vector2(BAR_WIDTH, 30.0)
	box.add_child(_shift_lights)

	# Velocidad | marcha | rpm.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	box.add_child(row)
	var speed_box := VBoxContainer.new()
	speed_box.custom_minimum_size.x = 130.0
	_lbl_speed = UiTheme.make_label("0", 46)
	_lbl_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_box.add_child(_lbl_speed)
	var unit := UiTheme.make_label("km/h", UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_box.add_child(unit)
	row.add_child(speed_box)
	_lbl_gear = UiTheme.make_label("N", 84, UiTheme.COLOR_WARNING)
	_lbl_gear.custom_minimum_size.x = 70.0
	_lbl_gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_lbl_gear)
	_lbl_rpm = UiTheme.make_label("0 rpm", UiTheme.FONT_SIZE_NORMAL, UiTheme.COLOR_TEXT_DIM)
	_lbl_rpm.custom_minimum_size.x = 130.0
	_lbl_rpm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_lbl_rpm)

	_bar_rpm = UiTheme.make_bar(UiTheme.COLOR_ACCENT_BRIGHT, Vector2(BAR_WIDTH, 10.0))
	box.add_child(_bar_rpm)

	# ERS + DRS + limitador.
	var systems := HBoxContainer.new()
	systems.add_theme_constant_override("separation", 10)
	box.add_child(systems)
	_lbl_ers = UiTheme.make_label("ERS", UiTheme.FONT_SIZE_SMALL)
	_lbl_ers.custom_minimum_size.x = 84.0
	systems.add_child(_lbl_ers)
	_bar_ers = UiTheme.make_bar(UiTheme.COLOR_WARNING, Vector2(170.0, 14.0))
	_bar_ers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar_ers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	systems.add_child(_bar_ers)
	_box_drs = _make_indicator("DRS")
	_lbl_drs = _box_drs.get_child(0) as Label
	systems.add_child(_box_drs)
	_box_limiter = _make_indicator("LIM")
	systems.add_child(_box_limiter)

	# Pedales.
	var pedals := HBoxContainer.new()
	pedals.add_theme_constant_override("separation", 10)
	box.add_child(pedals)
	_bar_brake = UiTheme.make_bar(UiTheme.COLOR_BAD, Vector2(BAR_WIDTH * 0.5 - 5.0, 6.0))
	_bar_brake.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	pedals.add_child(_bar_brake)
	_bar_throttle = UiTheme.make_bar(UiTheme.COLOR_GOOD, Vector2(BAR_WIDTH * 0.5 - 5.0, 6.0))
	pedals.add_child(_bar_throttle)
	_anchor(panel, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)


func _make_indicator(text: String) -> PanelContainer:
	var indicator := PanelContainer.new()
	indicator.add_theme_stylebox_override("panel", UiTheme.make_box(COLOR_INDICATOR_OFF, 4.0))
	indicator.custom_minimum_size = Vector2(62.0, 26.0)
	var label := UiTheme.make_label(text, UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.add_child(label)
	return indicator


func _build_minimap() -> void:
	var panel := UiTheme.make_panel()
	_root.add_child(panel)
	_minimap = Minimap.new()
	_minimap.custom_minimum_size = MINIMAP_SIZE
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_minimap)
	_anchor(panel, Control.PRESET_BOTTOM_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)


func _build_standings() -> void:
	var panel := UiTheme.make_panel()
	_root.add_child(panel)
	_lbl_standings = UiTheme.make_label("", UiTheme.FONT_SIZE_SMALL)
	panel.add_child(_lbl_standings)
	_anchor(panel, Control.PRESET_BOTTOM_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)


# Ubica un panel en una esquina o borde de la pantalla con margen.
# `preset` define el punto de anclaje; las direcciones de crecimiento hacen
# que, si el contenido cambia de tamaño, el panel crezca hacia adentro de la
# pantalla sin despegarse de su borde.
func _anchor(control: Control, preset: Control.LayoutPreset,
		grow_horizontal: Control.GrowDirection, grow_vertical: Control.GrowDirection) -> void:
	control.grow_horizontal = grow_horizontal
	control.grow_vertical = grow_vertical
	control.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(MARGIN))


# Contorno negro para que el texto se lea sobre cualquier fondo.
func _add_outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
