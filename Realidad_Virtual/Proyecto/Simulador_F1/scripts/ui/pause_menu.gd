class_name PauseMenu
extends CanvasLayer
## Menú de pausa de los niveles.
##
## Al abrirse pone el árbol de escenas en pausa (se detienen la física y el
## cronómetro) y muestra las opciones. Este nodo y el InputManager siguen
## funcionando en pausa (PROCESS_MODE_ALWAYS) para poder volver al juego.

## El jugador pidió terminar la sesión y ver los resultados.
signal finish_requested

const CONTROLS_HELP := """CONTROLES (teclado)
Dirección: A / D  o  ← / →          Acelerar: W o ↑          Frenar: S o ↓
Subir marcha: E      Bajar marcha: Q      DRS: F      ERS (mantener): Espacio
Limitador de boxes: L      Volver a pista: R      Cámara: C      Pausa: Esc o P
Reparto de frenos: Re Pág / Av Pág"""

var _first_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_build()


## Abre el menú si está cerrado y lo cierra si está abierto.
func toggle() -> void:
	if visible:
		resume()
	else:
		open()


func open() -> void:
	visible = true
	get_tree().paused = true
	_first_button.grab_focus()


func resume() -> void:
	visible = false
	get_tree().paused = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.make_theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	# Página deslizable: si el menú no entra en la pantalla se puede deslizar.
	var center := UiTheme.make_scroll_page(root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := UiTheme.make_label("PAUSA", UiTheme.FONT_SIZE_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_first_button = _add_button(box, "Continuar", resume)
	_add_button(box, "Reiniciar nivel", GameState.retry_level)
	_add_button(box, "Terminar y ver resultados", _on_finish_pressed)
	_add_button(box, "Menú principal", GameState.goto_main_menu)

	var help := UiTheme.make_label(CONTROLS_HELP, UiTheme.FONT_SIZE_SMALL, UiTheme.COLOR_TEXT_DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := UiTheme.make_button(text)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _on_finish_pressed() -> void:
	resume()
	finish_requested.emit()
