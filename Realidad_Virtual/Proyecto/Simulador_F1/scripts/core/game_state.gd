extends Node
## Autoload "GameState": estado global liviano y navegación entre escenas.
##
## Centraliza las rutas de las escenas, recuerda qué nivel se eligió y
## transporta los resultados de una sesión hasta la pantalla de resultados.

# Rutas de escenas (un único lugar para cambiarlas).
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_OPTIONS := "res://scenes/options_menu.tscn"
const SCENE_CALIBRATION := "res://scenes/calibration.tscn"
const SCENE_SESSION_SETUP := "res://scenes/session_setup.tscn"
const SCENE_QUALIFYING := "res://scenes/levels/clasificacion.tscn"
const SCENE_RACE := "res://scenes/levels/carrera.tscn"

## true mientras se muestra un menú (habilita la navegación de menús con el
## volante: ver InputManager).
var in_menu: bool = true

## Nivel que se está preparando en el menú de selección de sesión.
var pending_level: String = SCENE_QUALIFYING

## Escena del último nivel jugado (para el botón "Reintentar").
var last_level_scene: String = SCENE_QUALIFYING


## Cambia de escena asegurando que el árbol no quede en pausa.
func goto_scene(path: String) -> void:
	get_tree().paused = false
	if path == SCENE_QUALIFYING or path == SCENE_RACE:
		last_level_scene = path
	get_tree().change_scene_to_file(path)


## Abre el menú "Preparar sesión" (circuito, clima, neumáticos) para un nivel.
func prepare_level(level_scene: String) -> void:
	pending_level = level_scene
	goto_scene(SCENE_SESSION_SETUP)


## Vuelve al menú principal.
func goto_main_menu() -> void:
	goto_scene(SCENE_MAIN_MENU)


## Reinicia el último nivel jugado.
func retry_level() -> void:
	goto_scene(last_level_scene)


## Formatea un tiempo en segundos como m:ss.mmm (o "-:--.---" si no hay tiempo).
static func format_time(seconds: float) -> String:
	if seconds <= 0.0 or is_inf(seconds) or is_nan(seconds):
		return "-:--.---"
	var total_ms := int(round(seconds * 1000.0))
	@warning_ignore("integer_division")
	var minutes := total_ms / 60000
	@warning_ignore("integer_division")
	var secs := (total_ms / 1000) % 60
	var ms := total_ms % 1000
	return "%d:%02d.%03d" % [minutes, secs, ms]


## Formatea una diferencia de tiempos con signo (+0.123 / -0.456).
static func format_delta(seconds: float) -> String:
	if is_inf(seconds) or is_nan(seconds):
		return ""
	return "%+.3f" % seconds
