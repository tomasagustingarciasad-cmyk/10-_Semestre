extends SceneTree
## Prueba automática de los menús en la resolución base 1280 × 720 (sin ventana).
##
## Para cada pantalla de menú verifica que:
##   - el contenido esté dentro de una página deslizable (ScrollContainer);
##   - si no entra en 720 px de alto, la barra vertical permita llegar al final;
##   - al darle el foco al primer y al último control (como al navegar con
##     teclado, gamepad o el encoder del volante) la vista se deslice sola y el
##     control quede completamente visible.
##
## Uso:
##   godot --headless --script res://tools/godot/tests/test_menus.gd

const BASE_SIZE := Vector2i(1280, 720)
## Cuadros que se esperan después de cada cambio para que se acomode el layout.
const SETTLE_FRAMES := 4
const SCENES := [
	"res://scenes/main_menu.tscn",
	"res://scenes/session_setup.tscn",
	"res://scenes/options_menu.tscn",
	"res://scenes/calibration.tscn",
	"res://scenes/ui/pause_menu.tscn",
]

var _index := 0
var _node: Node = null
var _frames := 0
var _step := 0
var _scroll: ScrollContainer = null
var _focusables: Array[Control] = []
var _failures := 0
# Vista fija de 1280 × 720 donde se monta cada menú (sin pantalla, la ventana
# raíz de Godot no respeta el tamaño del proyecto).
var _view: SubViewport = null


func _initialize() -> void:
	_view = SubViewport.new()
	_view.size = BASE_SIZE
	_view.gui_disable_input = false
	root.add_child(_view)


func _process(_delta: float) -> bool:
	if _node == null:
		if _index >= SCENES.size():
			print("RESULTADO: %s" % ("TODO OK" if _failures == 0 else "%d FALLAS" % _failures))
			quit(_failures)
			return true
		_node = load(SCENES[_index]).instantiate()
		_view.add_child(_node)
		_frames = 0
		_step = 0
		return false
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	_frames = 0
	match _step:
		0:
			_inspect()
		1:
			_focus_and_check(_focusables.back() if not _focusables.is_empty() else null, "último")
		2:
			_check_visible(_focusables.back() if not _focusables.is_empty() else null, "último")
			_focus_and_check(_focusables.front() if not _focusables.is_empty() else null, "primero")
		3:
			_check_visible(_focusables.front() if not _focusables.is_empty() else null, "primero")
			_node.queue_free()
			_node = null
			_index += 1
			return false
	_step += 1
	return false


func _inspect() -> void:
	# El menú de pausa está oculto hasta que se pausa: se lo muestra.
	if _node is CanvasLayer:
		(_node as CanvasLayer).visible = true
	_scroll = _find_scroll(_node)
	print("== %s" % SCENES[_index])
	_check("tiene página deslizable", _scroll != null)
	if _scroll == null:
		return
	var content := (_scroll.get_child(0) as Control).get_combined_minimum_size()
	var bar := _scroll.get_v_scroll_bar()
	var needs_scroll := content.y > _scroll.size.y + 1.0
	print("   alto del contenido %.0f px, alto visible %.0f px -> %s" % [
			content.y, _scroll.size.y, "se desliza" if needs_scroll else "entra sin deslizar"])
	if needs_scroll:
		_check("la barra vertical alcanza todo el contenido",
				bar.max_value - bar.page >= content.y - _scroll.size.y - 1.0)
	_focusables.clear()
	_collect_focusables(_scroll, _focusables)
	_check("hay controles para navegar", not _focusables.is_empty())


func _focus_and_check(control: Control, label: String) -> void:
	if control != null:
		control.grab_focus()


func _check_visible(control: Control, label: String) -> void:
	if control == null or _scroll == null:
		return
	var view := _scroll.get_global_rect()
	var rect := control.get_global_rect()
	_check("con el foco en el %s control, se ve entero" % label,
			rect.position.y >= view.position.y - 1.0 and rect.end.y <= view.end.y + 1.0)


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null


func _collect_focusables(node: Node, out: Array[Control]) -> void:
	if node is Control and (node as Control).focus_mode == Control.FOCUS_ALL \
			and (node as Control).is_visible_in_tree() and not node is ScrollBar:
		out.append(node)
	for child in node.get_children():
		_collect_focusables(child, out)


func _check(description: String, condition: bool) -> void:
	print("  [%s] %s" % ["OK" if condition else "FALLA", description])
	if not condition:
		_failures += 1
