class_name ResultsScreen
extends CanvasLayer
## Pantalla de resultados (fin de la Clasificación o de la Carrera).
##
## Recibe un Dictionary armado por la sesión:
##   {"title": String, "headers": [String], "rows": [[String]], "footer": String}
## y lo muestra como tabla, con botones para reintentar o volver al menú.

const HIGHLIGHT_NAME := "Vos"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20


## Muestra la tabla y deja el juego en pausa detrás.
func show_results(results: Dictionary) -> void:
	get_tree().paused = true
	GameState.in_menu = true

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.make_theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	# Página deslizable: si el menú no entra en la pantalla se puede deslizar.
	var center := UiTheme.make_scroll_page(root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := UiTheme.make_label(results.get("title", "Resultados"), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Tabla (con barra de desplazamiento por si hay muchas vueltas).
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900.0, 300.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var headers: Array = results.get("headers", [])
	var rows: Array = results.get("rows", [])
	var grid := GridContainer.new()
	grid.columns = maxi(headers.size(), 1)
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for header: String in headers:
		grid.add_child(UiTheme.make_label(header, UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_ACCENT_BRIGHT))
	for row: Array in rows:
		var is_player := row.has(HIGHLIGHT_NAME)
		for cell: String in row:
			var color := UiTheme.COLOR_WARNING if is_player else UiTheme.COLOR_TEXT
			grid.add_child(UiTheme.make_label(cell, UiTheme.FONT_SIZE_NORMAL, color))
	if rows.is_empty():
		box.add_child(UiTheme.make_label("No se completó ninguna vuelta.", UiTheme.FONT_SIZE_NORMAL, UiTheme.COLOR_TEXT_DIM))

	var footer := UiTheme.make_label(results.get("footer", ""), UiTheme.FONT_SIZE_SUBTITLE, UiTheme.COLOR_GOOD)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(footer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)
	var retry := UiTheme.make_button("Reintentar")
	retry.custom_minimum_size.x = 260.0
	retry.pressed.connect(GameState.retry_level)
	buttons.add_child(retry)
	var menu := UiTheme.make_button("Menú principal")
	menu.custom_minimum_size.x = 260.0
	menu.pressed.connect(GameState.goto_main_menu)
	buttons.add_child(menu)
	retry.grab_focus()
