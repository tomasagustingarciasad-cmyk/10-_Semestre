class_name TrackLayout
extends RefCounted
## Acceso a los datos de diseño de los circuitos y funciones comunes.
##
## Cada circuito es un recurso `CircuitData` en `assets/circuits/<id>.tres`.
## Este archivo ya no tiene un trazado fijo: sabe listar y cargar esos
## recursos, y convertir una lista de puntos en una curva suave (`Curve3D`).
## Lo usan el generador de escenas (`tools/godot/track_builder.gd`), el menú
## de selección de circuito y las sesiones.

## Carpeta de los recursos de circuito y de las escenas generadas.
const CIRCUITS_DIR := "res://assets/circuits/"
const SCENES_DIR := "res://scenes/track/circuitos/"
## Circuito que se usa si la selección guardada no existe.
const DEFAULT_CIRCUIT := "los_aromos"

# --- Medidas comunes a todos los circuitos [m] --------------------------------
## Distancia entre filas de la grilla y desplazamiento lateral de cada cajón.
const GRID_ROW_SPACING := 10.0
const GRID_FIRST_ROW_DISTANCE := 12.0
const GRID_LATERAL := 2.8
const GRID_SLOTS := 5
## Cantidad de boxes (el primero es el del jugador) y tamaño máximo de un box.
const PIT_BOX_COUNT := 5
const PIT_BOX_SIZE := Vector2(10.0, 4.2)
## Desplazamiento lateral del carril de boxes respecto del eje del pit lane,
## como fracción de la mitad del ancho del pit lane.
const PIT_BOX_LATERAL_FRACTION := 0.49

# Fracción de la distancia al punto vecino que se usa como manija de Bézier.
const HANDLE_FRACTION := 1.0 / 3.0


## Identificadores de todos los circuitos disponibles, en el orden del menú:
## primero el circuito original y después el calendario.
static func list_ids() -> PackedStringArray:
	var entries: Array = []
	var dir := DirAccess.open(CIRCUITS_DIR)
	if dir == null:
		return PackedStringArray()
	for file_name in dir.get_files():
		# En un juego exportado los recursos figuran como "<nombre>.tres.remap".
		var clean := file_name.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var data := load(CIRCUITS_DIR + clean) as CircuitData
			if data != null:
				entries.append([data.calendar_round, data.id])
	entries.sort()
	var ids := PackedStringArray()
	for entry: Array in entries:
		ids.append(entry[1])
	return ids


## Carga los datos de un circuito. Devuelve null si no existe.
static func load_circuit(id: String) -> CircuitData:
	var path := CIRCUITS_DIR + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as CircuitData


## Ruta de la escena generada de un circuito.
static func scene_path(id: String) -> String:
	return SCENES_DIR + id + ".tscn"


## Convierte una lista de puntos (x, z) en una Curve3D suave que pasa por
## todos ellos.
##
## Cada tramo entre dos puntos es una curva de Bézier cúbica. Para que la
## unión sea suave (tangente continua) la dirección de las manijas de cada
## punto es la de la cuerda que une a sus dos vecinos (como en una spline de
## Catmull-Rom), y su longitud es 1/3 de la distancia al vecino de ese lado.
## Si `closed` es true se repite el primer punto al final para cerrar el lazo.
static func build_curve(points: PackedVector2Array, closed: bool, bake_interval: float = 1.0) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = bake_interval
	var count := points.size()
	var total := count + 1 if closed else count
	for i in total:
		var index := i % count
		var current := points[index]
		var previous: Vector2
		var next: Vector2
		if closed:
			previous = points[(index - 1 + count) % count]
			next = points[(index + 1) % count]
		else:
			previous = points[maxi(index - 1, 0)]
			next = points[mini(index + 1, count - 1)]
		var tangent := (next - previous).normalized()
		var handle_in := -tangent * current.distance_to(previous) * HANDLE_FRACTION
		var handle_out := tangent * current.distance_to(next) * HANDLE_FRACTION
		curve.add_point(
				Vector3(current.x, 0.0, current.y),
				Vector3(handle_in.x, 0.0, handle_in.y),
				Vector3(handle_out.x, 0.0, handle_out.y))
	return curve
