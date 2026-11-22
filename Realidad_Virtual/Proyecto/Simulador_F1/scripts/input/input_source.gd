class_name InputSource
extends RefCounted
## Clase base de todas las fuentes de entrada (teclado, gamepad, volante UDP...).
##
## Cada fuente traduce "su" dispositivo a un formato común y crudo:
##   - ejes: `raw_steer` (-1 izquierda .. 1 derecha), `raw_throttle` y
##     `raw_brake` (0..1);
##   - botones: se informan con `_set_button()`, que detecta flancos y encola
##     eventos de "recién apretado";
##   - encoder: pasos acumulados (positivo = horario).
##
## El InputManager es el único que conoce a las fuentes: las consulta una vez
## por tick de física, aplica zona muerta/curva/sensibilidad y publica el
## resultado al resto del juego.

var raw_steer: float = 0.0
var raw_throttle: float = 0.0
var raw_brake: float = 0.0

# Estado "mantenido" de cada botón: action -> bool.
var _held: Dictionary = {}
# Cola de acciones recién apretadas (flanco ascendente) desde la última lectura.
var _events: Array[StringName] = []
# Pasos de encoder acumulados desde la última lectura.
var _encoder_steps: int = 0


## Identificador interno (coincide con las constantes Settings.SOURCE_*).
func get_id() -> String:
	return ""


## Nombre para mostrar en menús y en el HUD.
func get_label() -> String:
	return ""


## true si los ejes son analógicos y hay que aplicarles zona muerta y curva.
func is_analog() -> bool:
	return false


## true si la fuente es "todo o nada" (teclas) y conviene limitar el ángulo
## de dirección a lo que el agarre puede usar (ayuda de dirección).
func wants_steer_assist() -> bool:
	return false


## true si el dispositivo está presente y entregando datos.
func is_available() -> bool:
	return true


## Texto corto de estado para el HUD ("Conectado", "Sin señal", ...).
func get_status_text() -> String:
	return "Conectado" if is_available() else "Desconectado"


## Se llama cuando la fuente pasa a ser la activa.
func start() -> void:
	pass


## Se llama cuando la fuente deja de ser la activa.
func stop() -> void:
	release_all()


## Actualiza ejes y botones. Se llama una vez por tick de física.
func update(_delta: float) -> void:
	pass


## Vibración local del dispositivo (si la tiene). intensity: 0..1.
func vibrate(_intensity: float, _duration_s: float) -> void:
	pass


## Devuelve y vacía la cola de acciones recién apretadas.
func take_events() -> Array[StringName]:
	var events := _events
	_events = []
	return events


## Devuelve y pone en cero los pasos de encoder acumulados.
func take_encoder_steps() -> int:
	var steps := _encoder_steps
	_encoder_steps = 0
	return steps


## true mientras el botón de esa acción sigue apretado.
func is_held(action: StringName) -> bool:
	return _held.get(action, false)


## Suelta todos los botones y centra los ejes (al cambiar de fuente o al
## perder la conexión).
func release_all() -> void:
	raw_steer = 0.0
	raw_throttle = 0.0
	raw_brake = 0.0
	_held.clear()
	_events.clear()
	_encoder_steps = 0


# Registra el estado de un botón y encola un evento si recién se apretó.
func _set_button(action: StringName, pressed: bool) -> void:
	var was_pressed: bool = _held.get(action, false)
	if pressed and not was_pressed:
		_events.append(action)
	_held[action] = pressed
