class_name Minimap
extends Control
## Minimapa: el trazado visto desde arriba con la posición de cada auto.
##
## Se dibuja con primitivas 2D: una polilínea con puntos del eje del circuito
## (muestreados de la Curve3D) y un círculo por auto. La transformación de
## coordenadas de mundo (X, Z) a píxeles es una escala uniforme más una
## traslación que centra el circuito en el recuadro.

const SAMPLE_STEP := 12.0
const MARGIN := 10.0
const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const PIT_COLOR := Color(1.0, 1.0, 1.0, 0.4)
const START_COLOR := Color(1.0, 0.25, 0.25)
const PLAYER_COLOR := Color(1.0, 0.9, 0.2)
const TRACK_LINE_WIDTH := 3.0
const PIT_LINE_WIDTH := 1.5
const PLAYER_DOT_RADIUS := 5.0
const RIVAL_DOT_RADIUS := 4.0

var _track: Track = null
var _player: Node3D = null
var _rivals: Array = []
var _points: PackedVector2Array = PackedVector2Array()
var _pit_points: PackedVector2Array = PackedVector2Array()
var _bounds: Rect2 = Rect2()


## Indica qué circuito y qué autos mostrar.
func setup(track: Track, player: Node3D, rivals: Array) -> void:
	_track = track
	_player = player
	_rivals = rivals
	_points = PackedVector2Array()
	var offset := 0.0
	while offset < track.length:
		var point := track.get_center(offset)
		_points.append(Vector2(point.x, point.z))
		offset += SAMPLE_STEP
	_points.append(_points[0])   # Cierra el lazo.

	_pit_points = PackedVector2Array()
	offset = 0.0
	while offset < track.pit_length:
		var pit_point := track.get_pit_transform_at(offset).origin
		_pit_points.append(Vector2(pit_point.x, pit_point.z))
		offset += SAMPLE_STEP

	_bounds = Rect2(_points[0], Vector2.ZERO)
	for point in _points:
		_bounds = _bounds.expand(point)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _track == null or _points.is_empty():
		return
	var mapped := PackedVector2Array()
	for point in _points:
		mapped.append(_to_map(point))
	draw_polyline(mapped, TRACK_COLOR, TRACK_LINE_WIDTH, true)

	if _pit_points.size() >= 2:
		var mapped_pit := PackedVector2Array()
		for point in _pit_points:
			mapped_pit.append(_to_map(point))
		draw_polyline(mapped_pit, PIT_COLOR, PIT_LINE_WIDTH, true)

	# Línea de largada.
	draw_circle(_to_map(_points[0]), 3.0, START_COLOR)

	for rival in _rivals:
		if is_instance_valid(rival):
			var color: Color = rival.primary_color if "primary_color" in rival else Color.WHITE
			draw_circle(_to_map(_world_to_2d(rival.global_position)), RIVAL_DOT_RADIUS, color)
	if _player != null and is_instance_valid(_player):
		draw_circle(_to_map(_world_to_2d(_player.global_position)), PLAYER_DOT_RADIUS, PLAYER_COLOR)


func _world_to_2d(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z)


# Mundo (X, Z) -> píxeles del control, manteniendo la proporción.
func _to_map(point: Vector2) -> Vector2:
	var available := size - Vector2(MARGIN, MARGIN) * 2.0
	var scale_factor := minf(available.x / maxf(_bounds.size.x, 1.0), available.y / maxf(_bounds.size.y, 1.0))
	var drawn_size := _bounds.size * scale_factor
	var origin := Vector2(MARGIN, MARGIN) + (available - drawn_size) * 0.5
	return origin + (point - _bounds.position) * scale_factor
