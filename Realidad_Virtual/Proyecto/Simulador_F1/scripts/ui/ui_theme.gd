class_name UiTheme
extends RefCounted
## Estilo visual común de menús y HUD (colores, tamaños y utilidades).
##
## La interfaz se construye por código con nodos Control estándar; este
## archivo concentra los colores y evita repetir la creación de estilos.

const COLOR_BACKGROUND := Color(0.05, 0.06, 0.09)
const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.6)
const COLOR_ACCENT := Color(0.12, 0.42, 0.95)
const COLOR_ACCENT_BRIGHT := Color(0.35, 0.62, 1.0)
const COLOR_TEXT := Color(0.94, 0.95, 0.97)
const COLOR_TEXT_DIM := Color(0.62, 0.66, 0.72)
const COLOR_GOOD := Color(0.3, 1.0, 0.45)
const COLOR_WARNING := Color(1.0, 0.8, 0.2)
const COLOR_BAD := Color(1.0, 0.35, 0.3)
const COLOR_PURPLE := Color(0.78, 0.45, 1.0)

const FONT_SIZE_NORMAL := 20
const FONT_SIZE_SMALL := 15
const FONT_SIZE_TITLE := 54
const FONT_SIZE_SUBTITLE := 22
const CORNER_RADIUS := 8
const MENU_BUTTON_SIZE := Vector2(420.0, 52.0)


## Tema para los menús: botones grandes con foco bien visible (se navega con
## teclado, gamepad o volante, no solo con el mouse).
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE_NORMAL
	theme.set_stylebox("normal", "Button", make_box(Color(0.13, 0.15, 0.2), 12.0))
	theme.set_stylebox("hover", "Button", make_box(Color(0.18, 0.22, 0.3), 12.0))
	theme.set_stylebox("pressed", "Button", make_box(COLOR_ACCENT.darkened(0.2), 12.0))
	var focus := make_box(COLOR_ACCENT, 12.0)
	focus.border_color = COLOR_ACCENT_BRIGHT
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_color", "Label", COLOR_TEXT)
	return theme


## Caja plana de color con esquinas redondeadas y margen interno.
static func make_box(color: Color, margin: float = 10.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(CORNER_RADIUS)
	box.set_content_margin_all(margin)
	return box


## Fondo oscuro a pantalla completa para los menús.
static func add_background(parent: Control) -> void:
	var background := ColorRect.new()
	background.name = "Fondo"
	background.color = COLOR_BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)
	# Franja de color decorativa en el borde superior.
	var stripe := ColorRect.new()
	stripe.name = "Franja"
	stripe.color = COLOR_ACCENT
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.custom_minimum_size = Vector2(0.0, 6.0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(stripe)


## Etiqueta de texto con tamaño y color.
## Página de menú deslizable: ScrollContainer (pantalla completa) con un
## CenterContainer adentro. Si el contenido entra en la pantalla se ve
## centrado, igual que antes; si no entra, aparece una barra y se puede
## deslizar con la rueda del mouse o arrastrando la barra. Con `follow_focus`,
## al moverse con teclado, gamepad o el encoder del volante la vista se desliza
## sola hasta la opción elegida. Devuelve el CenterContainer donde se agrega
## la columna del menú.
static func make_scroll_page(parent: Control) -> CenterContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Deslizable"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)
	var center := CenterContainer.new()
	# Ocupa todo el alto/ancho visible cuando el contenido es más chico (así
	# queda centrado) y crece más allá cuando es más grande (así se desliza).
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	return center


static func make_label(text: String, font_size: int = FONT_SIZE_NORMAL, color: Color = COLOR_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Botón de menú de tamaño uniforme.
static func make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = MENU_BUTTON_SIZE
	return button


## Panel semitransparente (para agrupar datos sobre la imagen 3D).
static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_box(COLOR_PANEL))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## Barra de progreso sin texto, con colores propios.
static func make_bar(fill: Color, minimum_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.custom_minimum_size = minimum_size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	background.set_corner_radius_all(3)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill_box)
	return bar
