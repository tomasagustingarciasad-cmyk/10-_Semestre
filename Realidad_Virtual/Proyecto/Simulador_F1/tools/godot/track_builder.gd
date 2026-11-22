extends RefCounted
## Generador de las escenas de circuito: scenes/track/circuitos/<id>.tscn
##
## Convierte un recurso `CircuitData` (assets/circuits/<id>.tres) en una
## escena de Godot. El método es el mismo para todos los circuitos:
##   1. El eje de la pista es una curva en el espacio: un `Path3D` cuya
##      `Curve3D` pasa por los puntos de control.
##   2. El asfalto, los pianos, las líneas y los muros son superficies
##      generadas por EXTRUSIÓN: un polígono 2D (la sección transversal) que
##      `CSGPolygon3D` en modo PATH traslada y rota a lo largo de la curva.
##   3. Las zonas con lógica (checkpoints, DRS, pit lane, box) son `Area3D`.
##   4. El decorado (tribuna, boxes, pórtico, árboles, carteles) son
##      primitivas ubicadas con transformaciones.
##
## Como los circuitos reales tienen tramos que pasan muy cerca unos de otros
## (y Suzuka se cruza a sí mismo), antes de construir se mide el "despeje":
## para cada punto del eje, a qué distancia está el tramo vecino más cercano
## de cada lado. Con eso se achican o se interrumpen los muros, se angostan
## los checkpoints y se decide si entran la tribuna y el edificio de boxes.
##
## En la sección transversal, X positivo es la DERECHA del sentido de marcha
## e Y es la altura.

const Utils := preload("res://tools/godot/builder_utils.gd")

# --- Alturas de las superficies [m] (escalonadas para que no se superpongan) --
const ROAD_TOP := 0.03
const PIT_ROAD_TOP := 0.02
const LINE_TOP := 0.045
const KERB_INNER_TOP := 0.035
const KERB_OUTER_TOP := 0.07
const SLAB_BOTTOM := -0.25
const PAINT_HEIGHT := 0.01

# --- Extrusión -----------------------------------------------------------------
## Cada cuántos metros de curva se coloca una sección transversal.
const EXTRUDE_INTERVAL := 3.0
const EXTRUDE_SIMPLIFY_ANGLE := 0.2
## Largo de cada franja de color de los pianos [m] (rojo + blanco = 2 franjas).
const KERB_STRIPE_LENGTH := 2.0

# --- Despeje entre tramos --------------------------------------------------------
## Paso de muestreo del eje para medir el despeje y ubicar los muros [m].
const SAMPLE_STEP := 6.0
## Dos puntos del eje son "del mismo tramo" si están a menos de esta distancia
## sobre la pista, o si el camino por la pista es casi tan corto como la línea recta.
const SAME_BRANCH_DISTANCE := 30.0
const SAME_BRANCH_DETOUR := 1.5
## Despeje máximo que interesa medir [m].
const CLEARANCE_LIMIT := 200.0
## Un vecino cuenta como "de ese lado" si su desplazamiento lateral supera
## esta fracción de su distancia.
const SIDE_FRACTION := 0.3

# --- Pianos ----------------------------------------------------------------------
## Hay piano donde el radio de curva es menor que este valor [m].
const KERB_MAX_RADIUS := 130.0
## Los tramos de piano separados por menos de esto se unen [m].
const KERB_MERGE_GAP := 30.0
## Cuánto se extiende el piano antes y después de la curva [m].
const KERB_EXTENSION := 14.0
const KERB_SAMPLE_STEP := 4.0

# --- Muros -----------------------------------------------------------------------
const WALL_HEIGHT := 1.1
const WALL_THICKNESS := 0.8
## Separación mínima entre el borde del asfalto y el muro para que haya muro [m].
const WALL_MIN_MARGIN := 0.6
## Del lado interno de una curva el muro no se aleja más que esta fracción del radio.
const WALL_MAX_RADIUS_FRACTION := 0.8
## Longitud de la transición del muro hacia/desde la zona de boxes [m].
const WALL_PIT_RAMP := 45.0
## Mínimo de puntos para que un tramo de muro valga la pena.
const WALL_MIN_POINTS := 4

# --- Líneas blancas de borde ------------------------------------------------------
const EDGE_LINE_WIDTH := 0.25
const EDGE_LINE_INSET := 0.2

# --- Boxes generados automáticamente ----------------------------------------------
## Radio mínimo de la recta de boxes y longitud mínima de cada mitad [m].
const PIT_MIN_RADIUS := 45.0
const PIT_MIN_HALF_LENGTH := 90.0
const PIT_RAMP_LENGTH := 60.0
# Largo de cada caja de la zona del pit lane [m]: cortas, para seguir un pit lane curvo sin pisar la pista.
const PIT_ZONE_CHUNK_LENGTH := 8.0
# Separación mínima entre el borde del pit lane y el de la pista para que rija el límite [m].
const PIT_ZONE_CLEARANCE := 0.5
# Línea de carrera: si el muro está a menos de esta distancia del asfalto [m], se suma este margen [m].
const LINE_WALL_NEAR := 3.0
const LINE_WALL_EXTRA_MARGIN := 0.8
const PIT_SAMPLE_STEP := 8.0
## Profundidad del edificio de boxes y espacio que necesita detrás del pit lane [m].
const PIT_BUILDING_DEPTH := 10.0
const PIT_BUILDING_ROOM := 14.0
const PIT_BOX_MAX_SPACING := 22.0
const PIT_SEPARATOR_MIN_GAP := 1.5

# --- Zonas -------------------------------------------------------------------------
const AREA_HEIGHT := 4.0
const CHECKPOINT_THICKNESS := 3.0
## Margen lateral de los checkpoints más allá del asfalto [m].
const CHECKPOINT_MARGIN := 12.0
## Capa de colisión del auto del jugador (la que detectan las zonas).
const LAYER_PLAYER := 2
## Largo máximo de cada caja de una zona que sigue la pista [m].
const ZONE_CHUNK_LENGTH := 60.0

# --- DRS automático -----------------------------------------------------------------
## Una "recta" admite hasta esta curvatura (radio mínimo en metros).
## Criterios sucesivos: Vector2(radio mínimo, largo mínimo), del más exigente al menos.
const DRS_CRITERIA := [Vector2(320.0, 380.0), Vector2(220.0, 300.0), Vector2(140.0, 220.0)]
const DRS_MAX_ZONES := 2
## La zona empieza un poco después de la salida de la curva [m].
const DRS_START_DELAY := 70.0

# --- Suelo y decorado ----------------------------------------------------------------
const GROUND_MARGIN := 320.0
## Un árbol cada tantos metros cuadrados de terreno, con tope.
const TREE_AREA_PER_TREE := 5200.0
const TREE_MIN_COUNT := 140
const TREE_MAX_COUNT := 420
const TREE_TRACK_MARGIN := 30.0
const TREE_SEED := 20261116
## Distancias de los carteles de frenado antes de cada frenada fuerte [m].
const BRAKE_BOARD_DISTANCES := [150, 100, 50]
const GRANDSTAND_SEGMENT_LENGTH := 44.0
const GRANDSTAND_SEGMENTS := 5
const GRANDSTAND_ROOM := 26.0


## Datos de trabajo de un circuito mientras se lo construye.
class Build:
	extends RefCounted
	var data: CircuitData
	var root: Node3D
	var curve: Curve3D
	var length: float
	var materials: Dictionary
	# Muestras del eje cada SAMPLE_STEP: posición, derecha y despeje por lado.
	var sample_count: int
	var positions: PackedVector2Array
	var rights: PackedVector2Array
	var clear_left: PackedFloat32Array
	var clear_right: PackedFloat32Array
	var clear_any: PackedFloat32Array
	# Boxes.
	var pit_curve: Curve3D
	var pit_points: PackedVector2Array
	var pit_entry_offset: float
	var pit_exit_offset: float
	var pit_lateral: float          # Distancia del eje del pit lane al eje de la pista.
	var pit_limit_start: float
	var pit_limit_end: float
	var pit_box_offsets: PackedFloat32Array
	var pit_box_length: float
	var has_pit_building: bool
	var wall_offset_pit: float


## Genera todos los circuitos, o solo los indicados.
static func build_all(only_ids: PackedStringArray = PackedStringArray()) -> void:
	var ids := only_ids if not only_ids.is_empty() else TrackLayout.list_ids()
	for id in ids:
		var data := TrackLayout.load_circuit(id)
		if data == null:
			push_error("No existe el circuito '%s' en %s" % [id, TrackLayout.CIRCUITS_DIR])
			continue
		build_circuit(data)


static func build_circuit(data: CircuitData) -> void:
	var b := Build.new()
	b.data = data
	b.root = Node3D.new()
	b.root.name = "Circuito"
	b.root.set_script(load("res://scripts/track/track.gd"))
	b.materials = _make_materials()

	# ------------------------------------------------------------------ 1. Curvas
	b.curve = TrackLayout.build_curve(data.points, true)
	b.length = b.curve.get_baked_length()
	var main_path := _add_path(b.root, "Trazado", b.curve)
	_measure_clearance(b)
	_plan_pit_lane(b)
	var pit_path := _add_path(b.root, "TrazadoBoxes", b.pit_curve)

	# ------------------------------------------------------------------ 2. Suelo
	var bounds := Rect2(data.points[0], Vector2.ZERO)
	for point in data.points:
		bounds = bounds.expand(point)
	bounds = bounds.grow(GROUND_MARGIN)
	_build_ground(b, bounds)

	# ------------------------------------------------------------------ 3. Extrusiones
	var half_width := data.half_width
	_add_extrusion(b.root, "AsfaltoBoxes", pit_path, b.materials["pit_asphalt"], true,
			_slab(-data.pit_half_width, data.pit_half_width, PIT_ROAD_TOP))
	_add_extrusion(b.root, "Asfalto", main_path, b.materials["asphalt"], true,
			_slab(-half_width, half_width, ROAD_TOP))
	var line_outer := half_width - EDGE_LINE_INSET
	var line_inner := line_outer - EDGE_LINE_WIDTH
	_add_extrusion(b.root, "LineaBordeDerecha", main_path, b.materials["white"], false,
			_slab_between(line_inner, line_outer, ROAD_TOP, LINE_TOP))
	_add_extrusion(b.root, "LineaBordeIzquierda", main_path, b.materials["white"], false,
			_slab_between(-line_outer, -line_inner, ROAD_TOP, LINE_TOP))

	var kerb_ranges := _find_kerb_ranges(b)
	var kerbs := Node3D.new()
	kerbs.name = "Pianos"
	b.root.add_child(kerbs)
	for i in kerb_ranges.size():
		_build_kerb(b, kerbs, i, kerb_ranges[i])

	var walls := Node3D.new()
	walls.name = "Muros"
	b.root.add_child(walls)
	var wall_pieces := _build_walls(b, walls, 1.0) + _build_walls(b, walls, -1.0)

	# ------------------------------------------------------------------ 4. Zonas
	var zones := Node3D.new()
	zones.name = "Zonas"
	b.root.add_child(zones)
	var sector_ends := _build_checkpoints(b, zones)
	var drs_zones := _build_drs_zones(b, zones)
	_build_pit_zones(b, zones)

	# ------------------------------------------------------------------ 5. Decorado
	var scenery := Node3D.new()
	scenery.name = "Decorado"
	b.root.add_child(scenery)
	_build_start_area(b, scenery)
	_build_pit_buildings(b, scenery)
	_build_grandstand(b, scenery)
	_build_brake_boards(b, scenery, drs_zones)
	_build_trees(b, scenery, bounds)

	# ------------------------------------------------------------------ 6. Datos para track.gd
	var root := b.root
	root.set("circuit_id", data.id)
	root.set("display_name", data.display_name)
	root.set("official_length", data.official_length)
	root.set("half_width", half_width)
	root.set("kerb_width", data.kerb_width)
	root.set("pit_half_width", data.pit_half_width)
	root.set("kerb_ranges", PackedVector2Array(kerb_ranges))
	root.set("grid_first_row_distance", TrackLayout.GRID_FIRST_ROW_DISTANCE)
	root.set("grid_row_spacing", TrackLayout.GRID_ROW_SPACING)
	root.set("grid_lateral", minf(TrackLayout.GRID_LATERAL, half_width - 1.6))
	root.set("pit_entry_offset", b.pit_entry_offset)
	root.set("pit_exit_offset", b.pit_exit_offset)
	root.set("pit_box_offsets", b.pit_box_offsets)
	root.set("pit_box_lateral", data.pit_side * data.pit_half_width * TrackLayout.PIT_BOX_LATERAL_FRACTION)
	root.set("pit_fast_lane_lateral", -data.pit_side * data.pit_half_width * 0.45)
	root.set("pit_side", data.pit_side)
	root.set("pit_limit_start", b.pit_limit_start)
	root.set("pit_limit_end", b.pit_limit_end)
	root.set("sector_ends", sector_ends)
	root.set("line_lateral", _racing_line(b))

	print("  %-12s %7.1f m (oficial %.0f)  pianos %d  muros %d  DRS %d  boxes %.0f m%s" % [
		data.id, b.length, data.official_length, kerb_ranges.size(), wall_pieces, drs_zones.size(),
		b.pit_curve.get_baked_length(), "  +edificio" if b.has_pit_building else ""])
	Utils.save_scene(root, TrackLayout.scene_path(data.id))
	root.free()


# ==============================================================================
# Consultas sobre el eje
# ==============================================================================
# Línea de carrera (desplazamiento lateral cada Track.PROFILE_STEP metros).
# Se calcula acá, al generar la escena, porque tarda alrededor de medio
# segundo por circuito; el juego la lee ya resuelta (ver RacingLine).
static func _racing_line(b: Build) -> PackedFloat32Array:
	var count := int(ceil(b.curve.get_baked_length() / Track.PROFILE_STEP))
	var centers := PackedVector2Array()
	var rights := PackedVector2Array()
	centers.resize(count)
	rights.resize(count)
	for i in count:
		var xform := _xform(b, i * Track.PROFILE_STEP)
		centers[i] = Vector2(xform.origin.x, xform.origin.z)
		rights[i] = Vector2(xform.basis.x.x, xform.basis.x.z)
	# Con muros pegados a la pista (callejeros) la línea deja más margen.
	var margin := Track.LINE_EDGE_MARGIN
	if minf(b.data.wall_margin_left, b.data.wall_margin_right) < LINE_WALL_NEAR:
		margin += LINE_WALL_EXTRA_MARGIN
	return RacingLine.compute(centers, rights, b.data.half_width - margin)


static func _center(b: Build, offset: float) -> Vector3:
	return b.curve.sample_baked(fposmod(offset, b.length), true)


static func _forward(b: Build, offset: float) -> Vector3:
	var direction := _center(b, offset + 1.0) - _center(b, offset - 1.0)
	direction.y = 0.0
	return direction.normalized()


# Transformación sobre el eje: -Z apunta en el sentido de marcha, +X a la derecha.
static func _xform(b: Build, offset: float, lateral: float = 0.0, height: float = 0.0) -> Transform3D:
	var forward := _forward(b, offset)
	var right := forward.cross(Vector3.UP).normalized()
	return Transform3D(Basis(right, Vector3.UP, -forward), _center(b, offset) + right * lateral + Vector3.UP * height)


# Igual que _xform pero sobre el eje del pit lane (sin dar la vuelta).
static func _pit_xform(b: Build, pit_offset: float, lateral: float = 0.0, height: float = 0.0) -> Transform3D:
	var pit_length := b.pit_curve.get_baked_length()
	var clamped := clampf(pit_offset, 0.0, pit_length)
	var ahead := b.pit_curve.sample_baked(minf(clamped + 1.0, pit_length), true)
	var behind := b.pit_curve.sample_baked(maxf(clamped - 1.0, 0.0), true)
	var forward := (ahead - behind).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	return Transform3D(Basis(right, Vector3.UP, -forward),
			b.pit_curve.sample_baked(clamped, true) + right * lateral + Vector3.UP * height)


# Curvatura con signo (positiva = derecha) por el círculo que pasa por 3 puntos.
static func _curvature(b: Build, offset: float) -> float:
	var step := 5.0
	var p0 := _center(b, offset - step)
	var p1 := _center(b, offset)
	var p2 := _center(b, offset + step)
	var a := Vector2(p1.x - p0.x, p1.z - p0.z)
	var c := Vector2(p2.x - p1.x, p2.z - p1.z)
	var chord := Vector2(p2.x - p0.x, p2.z - p0.z)
	var denominator := a.length() * c.length() * chord.length()
	if denominator < 0.0001:
		return 0.0
	return 2.0 * a.cross(c) / denominator


# Distancia hacia adelante sobre la pista para ir de `from_offset` a `to_offset`.
static func _ahead(b: Build, from_offset: float, to_offset: float) -> float:
	return fposmod(to_offset - from_offset, b.length)


# ==============================================================================
# Despeje: distancia al tramo vecino más cercano, a cada lado
# ==============================================================================
static func _measure_clearance(b: Build) -> void:
	b.sample_count = int(ceil(b.length / SAMPLE_STEP))
	b.positions = PackedVector2Array()
	b.rights = PackedVector2Array()
	for i in b.sample_count:
		var offset := i * SAMPLE_STEP
		var center := _center(b, offset)
		var right := _forward(b, offset).cross(Vector3.UP).normalized()
		b.positions.append(Vector2(center.x, center.z))
		b.rights.append(Vector2(right.x, right.z))

	b.clear_left = PackedFloat32Array()
	b.clear_right = PackedFloat32Array()
	b.clear_any = PackedFloat32Array()
	for i in b.sample_count:
		var left := CLEARANCE_LIMIT
		var right_clear := CLEARANCE_LIMIT
		var any := CLEARANCE_LIMIT
		var here := b.positions[i]
		for j in b.sample_count:
			var along := absi(i - j)
			along = mini(along, b.sample_count - along)
			var track_distance := along * SAMPLE_STEP
			if track_distance < SAME_BRANCH_DISTANCE:
				continue
			var delta := b.positions[j] - here
			var distance := delta.length()
			if distance >= CLEARANCE_LIMIT or track_distance < distance * SAME_BRANCH_DETOUR:
				continue   # Lejos, o es el mismo tramo un poco más adelante.
			any = minf(any, distance)
			var lateral := delta.dot(b.rights[i])
			if lateral > distance * SIDE_FRACTION:
				right_clear = minf(right_clear, distance)
			elif lateral < -distance * SIDE_FRACTION:
				left = minf(left, distance)
		b.clear_left.append(left)
		b.clear_right.append(right_clear)
		b.clear_any.append(any)


# Despeje en un offset, del lado indicado (1 = derecha, -1 = izquierda, 0 = cualquiera).
static func _clearance(b: Build, offset: float, side: float) -> float:
	var index := int(round(fposmod(offset, b.length) / SAMPLE_STEP)) % b.sample_count
	if side > 0.0:
		return b.clear_right[index]
	if side < 0.0:
		return b.clear_left[index]
	return b.clear_any[index]


# Menor despeje de un lado dentro de un tramo [from_offset, from_offset + span].
static func _min_clearance(b: Build, from_offset: float, span: float, side: float) -> float:
	var result := CLEARANCE_LIMIT
	var travelled := 0.0
	while travelled <= span:
		result = minf(result, _clearance(b, from_offset + travelled, side))
		travelled += SAMPLE_STEP
	return result


# ==============================================================================
# Materiales
# ==============================================================================
static func _make_materials() -> Dictionary:
	var materials := {}

	# Asfalto y pasto llevan una textura de ruido proyectada en coordenadas de
	# mundo (triplanar): le da "grano" al piso y ayuda a percibir la velocidad.
	var asphalt := Utils.make_material(Color(0.2, 0.2, 0.22), 0.85)
	asphalt.albedo_texture = _noise_texture(0.08, Color(0.62, 0.62, 0.62), Color(1.0, 1.0, 1.0))
	asphalt.uv1_triplanar = true
	asphalt.uv1_world_triplanar = true
	asphalt.uv1_scale = Vector3(0.12, 0.12, 0.12)
	materials["asphalt"] = asphalt

	var pit_asphalt := asphalt.duplicate() as StandardMaterial3D
	pit_asphalt.albedo_color = Color(0.27, 0.27, 0.29)
	materials["pit_asphalt"] = pit_asphalt

	var grass := Utils.make_material(Color(0.26, 0.5, 0.2), 1.0)
	grass.albedo_texture = _noise_texture(0.03, Color(0.55, 0.6, 0.5), Color(1.0, 1.0, 1.0))
	grass.uv1_triplanar = true
	grass.uv1_world_triplanar = true
	grass.uv1_scale = Vector3(0.04, 0.04, 0.04)
	materials["grass"] = grass

	# Pianos: textura de 2 píxeles (rojo | blanco) repetida a lo largo de la curva.
	var kerb_image := Image.create(2, 1, false, Image.FORMAT_RGB8)
	kerb_image.set_pixel(0, 0, Color(0.85, 0.08, 0.08))
	kerb_image.set_pixel(1, 0, Color(0.95, 0.95, 0.95))
	var kerb := Utils.make_material(Color.WHITE, 0.7)
	kerb.albedo_texture = ImageTexture.create_from_image(kerb_image)
	kerb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	materials["kerb"] = kerb

	materials["white"] = Utils.make_material(Color(0.92, 0.92, 0.92), 0.6)
	materials["yellow"] = Utils.make_material(Color(0.95, 0.8, 0.1), 0.6)
	materials["green"] = Utils.make_material(Color(0.1, 0.8, 0.3), 0.6)
	materials["wall"] = Utils.make_material(Color(0.62, 0.63, 0.66), 0.9)
	materials["concrete"] = Utils.make_material(Color(0.5, 0.5, 0.52), 0.9)
	materials["building"] = Utils.make_material(Color(0.82, 0.83, 0.86), 0.8)
	materials["dark"] = Utils.make_material(Color(0.1, 0.1, 0.12), 0.7)
	materials["seat"] = Utils.make_material(Color(0.15, 0.3, 0.6), 0.8)
	materials["light_off"] = Utils.make_material(Color(0.12, 0.02, 0.02), 0.5)
	materials["board"] = Utils.make_material(Color(0.95, 0.95, 0.95), 0.7)
	return materials


static func _noise_texture(frequency: float, dark: Color, light: Color) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var gradient := Gradient.new()
	gradient.set_color(0, dark)
	gradient.set_color(1, light)
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = gradient
	return texture


# ==============================================================================
# Curvas y extrusiones
# ==============================================================================
static func _add_path(parent: Node, node_name: String, curve: Curve3D) -> Path3D:
	var path := Path3D.new()
	path.name = node_name
	path.curve = curve
	parent.add_child(path)
	return path


# Sección rectangular de una losa enterrada, con la cara superior en `top`.
static func _slab(x_left: float, x_right: float, top: float) -> PackedVector2Array:
	return _slab_between(x_left, x_right, SLAB_BOTTOM, top)


static func _slab_between(x_left: float, x_right: float, bottom: float, top: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x_left, bottom), Vector2(x_left, top),
		Vector2(x_right, top), Vector2(x_right, bottom)])


# Crea un CSGPolygon3D que extruye `section` a lo largo de `path`.
static func _add_extrusion(parent: Node, node_name: String, path: Path3D, material: Material,
		with_collision: bool, section: PackedVector2Array) -> CSGPolygon3D:
	var csg := CSGPolygon3D.new()
	csg.name = node_name
	parent.add_child(csg)
	csg.polygon = section
	csg.mode = CSGPolygon3D.MODE_PATH
	# Ruta relativa al Path3D: es el padre del CSG o un nodo hermano.
	csg.path_node = NodePath("..") if path == parent else NodePath("../" + String(path.name))
	csg.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	csg.path_interval = EXTRUDE_INTERVAL
	csg.path_simplify_angle = EXTRUDE_SIMPLIFY_ANGLE
	# PATH_FOLLOW: la sección gira siguiendo la curva (queda siempre
	# perpendicular a la dirección de avance).
	csg.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	csg.path_local = false
	csg.path_continuous_u = true
	csg.path_u_distance = KERB_STRIPE_LENGTH * 2.0
	csg.path_joined = false
	csg.smooth_faces = true
	csg.material = material
	csg.use_collision = with_collision
	csg.collision_layer = 1
	csg.collision_mask = 0
	return csg


# Crea un Path3D con la curva paralela al eje entre dos offsets, desplazada
# `lateral` metros (positivo = derecha).
static func _add_offset_path(b: Build, parent: Node, node_name: String, from_offset: float, span: float,
		lateral: float, step: float) -> Path3D:
	var points := PackedVector2Array()
	var travelled := 0.0
	while travelled < span:
		var origin := _xform(b, from_offset + travelled, lateral).origin
		points.append(Vector2(origin.x, origin.z))
		travelled += step
	var last := _xform(b, from_offset + span, lateral).origin
	points.append(Vector2(last.x, last.z))
	return _add_path(parent, node_name, TrackLayout.build_curve(points, false))


# ==============================================================================
# Suelo
# ==============================================================================
static func _build_ground(b: Build, bounds: Rect2) -> void:
	var center := bounds.get_center()
	var ground := StaticBody3D.new()
	ground.name = "Suelo"
	ground.position = Vector3(center.x, 0.0, center.y)
	b.root.add_child(ground)
	var shape := BoxShape3D.new()
	shape.size = Vector3(bounds.size.x, 2.0, bounds.size.y)
	var collision := CollisionShape3D.new()
	collision.name = "Colision"
	collision.shape = shape
	collision.position = Vector3(0.0, -1.0, 0.0)
	ground.add_child(collision)
	var plane := PlaneMesh.new()
	plane.size = bounds.size
	plane.material = b.materials["grass"]
	var mesh := MeshInstance3D.new()
	mesh.name = "Pasto"
	mesh.mesh = plane
	ground.add_child(mesh)


# ==============================================================================
# Boxes: se planifican antes de construir porque condicionan muros y zonas
# ==============================================================================
static func _plan_pit_lane(b: Build) -> void:
	var data := b.data
	var side := float(data.pit_side)
	if not data.pit_points.is_empty():
		# Eje dado a mano (circuito original).
		b.pit_points = data.pit_points
	else:
		# Eje automático: paralelo a la pista alrededor de la línea de largada.
		b.pit_lateral = data.half_width + data.pit_gap + data.pit_half_width
		var needed := b.pit_lateral + data.pit_half_width + 1.0
		var before := _straight_reach(b, -1.0, data.pit_length_before, side, needed)
		var after := _straight_reach(b, 1.0, data.pit_length_after, side, needed)
		var ramp := minf(PIT_RAMP_LENGTH, minf(before, after) * 0.45)
		b.pit_points = PackedVector2Array()
		var s := -before
		while s <= after + 0.01:
			var weight := smoothstep(0.0, ramp, s + before) * smoothstep(0.0, ramp, after - s)
			var origin := _xform(b, s, side * b.pit_lateral * weight).origin
			b.pit_points.append(Vector2(origin.x, origin.z))
			s += PIT_SAMPLE_STEP
		var end := _center(b, after)
		var end_point := Vector2(end.x, end.z)
		if b.pit_points[b.pit_points.size() - 1].distance_to(end_point) > 1.0:
			b.pit_points.append(end_point)

	b.pit_curve = TrackLayout.build_curve(b.pit_points, false)
	var pit_length := b.pit_curve.get_baked_length()
	var first := b.pit_points[0]
	var last := b.pit_points[b.pit_points.size() - 1]
	b.pit_entry_offset = b.curve.get_closest_offset(Vector3(first.x, 0.0, first.y))
	b.pit_exit_offset = b.curve.get_closest_offset(Vector3(last.x, 0.0, last.y))

	# Distancia real del eje del pit lane al eje de la pista, a mitad de boxes.
	var middle := b.pit_curve.sample_baked(pit_length * 0.5, true)
	b.pit_lateral = middle.distance_to(b.curve.get_closest_point(middle))

	# Zona con límite de velocidad y boxes.
	# El límite rige solo donde el pit lane ya está separado de la pista: si
	# empezara antes, la zona pisaría la pista y penalizaría a quien pasa de largo.
	var margin := minf(data.pit_limit_margin, pit_length * 0.3)
	var separated := data.half_width + data.pit_half_width + PIT_ZONE_CLEARANCE
	b.pit_limit_start = margin
	while b.pit_limit_start < pit_length * 0.5 and _pit_distance_to_track(b, b.pit_limit_start) < separated:
		b.pit_limit_start += PIT_SAMPLE_STEP
	b.pit_limit_end = pit_length - margin
	while b.pit_limit_end > pit_length * 0.5 and _pit_distance_to_track(b, b.pit_limit_end) < separated:
		b.pit_limit_end -= PIT_SAMPLE_STEP
	var zone := b.pit_limit_end - b.pit_limit_start
	var count := TrackLayout.PIT_BOX_COUNT
	var spacing := data.pit_box_spacing
	if spacing <= 0.0:
		spacing = minf(PIT_BOX_MAX_SPACING, (zone - 24.0) / count)
	var first_box := data.pit_box_first
	if first_box <= 0.0:
		first_box = (zone - spacing * (count - 1)) * 0.5
	b.pit_box_offsets = PackedFloat32Array()
	for i in count:
		b.pit_box_offsets.append(b.pit_limit_start + first_box + spacing * i)
	b.pit_box_length = minf(TrackLayout.PIT_BOX_SIZE.x, spacing - 1.5)

	# Edificio de boxes: solo si hay lugar detrás del pit lane.
	var behind_pit := b.pit_lateral + data.pit_half_width
	if data.wall_offset_pit > 0.0:
		b.wall_offset_pit = data.wall_offset_pit
		b.has_pit_building = true
	else:
		var room := _min_clearance(b, b.pit_entry_offset, _ahead(b, b.pit_entry_offset, b.pit_exit_offset), side)
		b.has_pit_building = room > behind_pit + PIT_BUILDING_ROOM + data.half_width + 4.0
		b.wall_offset_pit = behind_pit + (PIT_BUILDING_ROOM if b.has_pit_building else 1.2)


# Distancia del eje del pit lane (en `pit_offset`) al eje de la pista [m].
static func _pit_distance_to_track(b: Build, pit_offset: float) -> float:
	var point := b.pit_curve.sample_baked(pit_offset, true)
	return point.distance_to(b.curve.get_closest_point(point))


# Cuánto se puede extender el pit lane desde la línea de largada en una
# dirección (-1 = hacia atrás, 1 = hacia adelante) antes de que la pista
# doble demasiado o no haya lugar de ese lado.
static func _straight_reach(b: Build, direction: float, maximum: float, side: float, needed: float) -> float:
	var reach := 0.0
	while reach < maximum:
		var offset := direction * (reach + SAMPLE_STEP)
		if absf(_curvature(b, offset)) > 1.0 / PIT_MIN_RADIUS:
			break
		if _clearance(b, offset, side) < needed + b.data.half_width + 1.0:
			break
		reach += SAMPLE_STEP
	return maxf(reach, PIT_MIN_HALF_LENGTH)


# ==============================================================================
# Pianos
# ==============================================================================

# Busca los tramos del circuito con curvatura suficiente como para llevar piano.
# Devuelve una lista de Vector2(offset inicial, offset final).
static func _find_kerb_ranges(b: Build) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	var start := -1.0
	var offset := 0.0
	while offset < b.length:
		var is_corner := absf(_curvature(b, offset)) > 1.0 / KERB_MAX_RADIUS
		if is_corner and start < 0.0:
			start = offset
		elif not is_corner and start >= 0.0:
			ranges.append(Vector2(start, offset))
			start = -1.0
		offset += KERB_SAMPLE_STEP
	if start >= 0.0:
		ranges.append(Vector2(start, b.length))

	# Extiende cada tramo y une los que quedan muy cerca.
	var merged: Array[Vector2] = []
	for kerb_range in ranges:
		var extended := Vector2(maxf(kerb_range.x - KERB_EXTENSION, 0.0),
				minf(kerb_range.y + KERB_EXTENSION, b.length))
		if not merged.is_empty() and extended.x - merged[merged.size() - 1].y < KERB_MERGE_GAP:
			merged[merged.size() - 1].y = extended.y
		else:
			merged.append(extended)
	return merged


# Un piano = un tramo de la curva principal (sub-curva) + dos extrusiones
# (lado derecho e izquierdo) con sección en cuña. Si de un lado hay otro
# tramo de pista pegado, ese lado no lleva piano.
static func _build_kerb(b: Build, parent: Node, index: int, kerb_range: Vector2) -> void:
	var span := kerb_range.y - kerb_range.x
	if span < KERB_SAMPLE_STEP:
		return
	var inner := b.data.half_width
	var outer := inner + b.data.kerb_width
	var needed := 2.0 * outer + 1.0
	var right_ok := _min_clearance(b, kerb_range.x, span, 1.0) > needed
	var left_ok := _min_clearance(b, kerb_range.x, span, -1.0) > needed
	if not right_ok and not left_ok:
		return
	var path := _add_offset_path(b, parent, "TramoPiano%d" % (index + 1), kerb_range.x, span, 0.0, KERB_SAMPLE_STEP)
	if right_ok:
		_add_extrusion(path, "PianoDerecho", path, b.materials["kerb"], true, PackedVector2Array([
			Vector2(inner, SLAB_BOTTOM), Vector2(inner, KERB_INNER_TOP),
			Vector2(outer, KERB_OUTER_TOP), Vector2(outer, SLAB_BOTTOM)]))
	if left_ok:
		_add_extrusion(path, "PianoIzquierdo", path, b.materials["kerb"], true, PackedVector2Array([
			Vector2(-outer, SLAB_BOTTOM), Vector2(-outer, KERB_OUTER_TOP),
			Vector2(-inner, KERB_INNER_TOP), Vector2(-inner, SLAB_BOTTOM)]))


# ==============================================================================
# Muros
# ==============================================================================

# Distancia del eje al muro del lado `side` en un offset. Devuelve 0 si en ese
# punto no puede haber muro (cruce de pista o tramos demasiado juntos).
static func _wall_offset(b: Build, offset: float, side: float) -> float:
	var data := b.data
	var margin := data.wall_margin_right if side > 0.0 else data.wall_margin_left
	var wanted := data.half_width + margin
	var is_pit_side := side == float(data.pit_side)

	# Frente a boxes el muro se aleja para dejar lugar al pit lane.
	var in_pit_zone := false
	if is_pit_side:
		var bulge_start := b.pit_entry_offset - WALL_PIT_RAMP
		var span := _ahead(b, b.pit_entry_offset, b.pit_exit_offset) + 2.0 * WALL_PIT_RAMP
		var into := _ahead(b, bulge_start, offset)
		if into <= span:
			var weight := smoothstep(0.0, WALL_PIT_RAMP, into) * smoothstep(0.0, WALL_PIT_RAMP, span - into)
			wanted = lerpf(wanted, maxf(b.wall_offset_pit, wanted), weight)
			in_pit_zone = weight > 0.02

	# Cruce a nivel: sin muros.
	if _clearance(b, offset, 0.0) < 2.0 * data.half_width + 2.0:
		return 0.0
	if not in_pit_zone:
		# No más lejos que la mitad de la distancia al tramo vecino de ese lado...
		wanted = minf(wanted, _clearance(b, offset, side) * 0.5 - 0.4)
		# ...ni más que el radio de la curva si el muro va por el lado interno.
		var curvature := _curvature(b, offset) * side
		if curvature > 0.0001:
			wanted = minf(wanted, WALL_MAX_RADIUS_FRACTION / curvature)
	if wanted < data.half_width + WALL_MIN_MARGIN:
		return 0.0
	return wanted


# Construye los muros de un lado como curvas paralelas al eje, extruidas con
# sección rectangular. Donde no puede haber muro queda un hueco, así que un
# lado puede terminar en varios tramos. Devuelve la cantidad de tramos.
static func _build_walls(b: Build, parent: Node, side: float) -> int:
	var side_name := "Derecho" if side > 0.0 else "Izquierdo"
	var count := b.sample_count
	var offsets := PackedFloat32Array()
	for i in count:
		offsets.append(_wall_offset(b, i * SAMPLE_STEP, side))
	# Suavizado: cada punto toma el mínimo de sus vecinos (evita dientes).
	var smooth := PackedFloat32Array()
	for i in count:
		var value := offsets[i]
		if value > 0.0:
			for k in [-2, -1, 1, 2]:
				var neighbour := offsets[(i + k + count) % count]
				if neighbour > 0.0:
					value = minf(value, neighbour + absf(k) * SAMPLE_STEP * 0.5)
		smooth.append(value)

	# Tramos contiguos con muro. Se empieza a recorrer desde un hueco (si hay).
	var first_gap := -1
	for i in count:
		if smooth[i] <= 0.0:
			first_gap = i
			break
	var half := WALL_THICKNESS * 0.5
	var section := PackedVector2Array([
		Vector2(-half, 0.0), Vector2(-half, WALL_HEIGHT),
		Vector2(half, WALL_HEIGHT), Vector2(half, 0.0)])
	var pieces := 0
	var run := PackedVector2Array()
	var start_index := maxi(first_gap, 0)
	for step in count + 1:
		var i := (start_index + step) % count
		var has_wall := step < count and smooth[i] > 0.0
		if has_wall:
			run.append(b.positions[i] + b.rights[i] * side * smooth[i])
			continue
		if run.size() >= WALL_MIN_POINTS:
			pieces += 1
			# Sin huecos el muro es un lazo cerrado.
			var path := _add_path(parent, "TrazadoMuro%s%d" % [side_name, pieces],
					TrackLayout.build_curve(run, first_gap < 0, 2.0))
			_add_extrusion(path, "Muro", path, b.materials["wall"], true, section)
		run = PackedVector2Array()
	return pieces


# ==============================================================================
# Zonas (Area3D)
# ==============================================================================

# Agrega a un Area3D una caja de colisión con la transformación indicada
# (expresada en coordenadas del circuito).
static func _add_area_shape(area: Area3D, size: Vector3, transform: Transform3D) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Forma%d" % (area.get_child_count() + 1)
	collision.shape = shape
	collision.transform = area.transform.affine_inverse() * transform
	area.add_child(collision)


static func _new_area(parent: Node, node_name: String, origin: Transform3D, group: StringName) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.transform = origin
	area.collision_layer = 0
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.add_to_group(group, true)
	parent.add_child(area)
	return area


# Tres checkpoints: línea de llegada, fin del sector 1 y fin del sector 2.
# Devuelve los offsets donde terminan los sectores 1 y 2.
static func _build_checkpoints(b: Build, zones: Node) -> PackedFloat32Array:
	var data := b.data
	var sector_ends := data.sector_ends
	if sector_ends.size() < 2:
		sector_ends = PackedFloat32Array([
			_best_gate_offset(b, b.length / 3.0), _best_gate_offset(b, b.length * 2.0 / 3.0)])

	var names := ["LineaDeLlegada", "FinSector1", "FinSector2"]
	var offsets := [0.0, sector_ends[0], sector_ends[1]]
	for i in 3:
		var offset: float = offsets[i]
		# Cada mitad del checkpoint llega hasta CHECKPOINT_MARGIN más allá del
		# asfalto, pero nunca hasta el tramo vecino.
		var reach_right := _gate_reach(b, offset, 1.0)
		var reach_left := _gate_reach(b, offset, -1.0)
		if i == 0:
			# La línea de llegada abarca también el pit lane (quien cruza la
			# línea por boxes completa la vuelta).
			var pit_reach := b.pit_lateral + data.pit_half_width + 2.0
			if data.pit_side > 0:
				reach_right = pit_reach
			else:
				reach_left = pit_reach
		var width := reach_left + reach_right
		var lateral := (reach_right - reach_left) * 0.5
		var area := _new_area(zones, names[i], _xform(b, offset, lateral, AREA_HEIGHT * 0.5), Track.GROUP_CHECKPOINT)
		_add_area_shape(area, Vector3(width, AREA_HEIGHT, CHECKPOINT_THICKNESS), area.transform)
		area.set_meta(Track.META_CHECKPOINT_INDEX, i)
	return sector_ends


static func _gate_reach(b: Build, offset: float, side: float) -> float:
	var wanted := b.data.half_width + CHECKPOINT_MARGIN
	return clampf(_clearance(b, offset, side) * 0.45, b.data.half_width + 1.0, wanted)


# Busca cerca de `wanted` el offset con más despeje para poner un checkpoint.
static func _best_gate_offset(b: Build, wanted: float) -> float:
	var best := wanted
	var best_clearance := -1.0
	for step in range(-12, 13):
		var offset := wanted + step * SAMPLE_STEP * 2.0
		var clearance := minf(_clearance(b, offset, 0.0), 80.0) - absf(step) * 0.5
		if clearance > best_clearance:
			best_clearance = clearance
			best = offset
	return fposmod(best, b.length)


# Zonas de DRS. Devuelve la lista de zonas como Vector2(inicio, fin).
static func _build_drs_zones(b: Build, zones: Node) -> Array[Vector2]:
	var list: Array[Vector2] = []
	if b.data.drs_zones.is_empty():
		list = _find_straights(b)
	else:
		for zone in b.data.drs_zones:
			list.append(zone)

	for i in list.size():
		var zone := list[i]
		var span := _ahead(b, zone.x, zone.y)
		var area := _new_area(zones, "ZonaDRS%d" % (i + 1), _xform(b, zone.x, 0.0, AREA_HEIGHT * 0.5), Track.GROUP_DRS_ZONE)
		# La zona sigue a la pista: una caja por cada tramo corto.
		var chunks := int(ceil(span / ZONE_CHUNK_LENGTH))
		var chunk_length := span / chunks
		var width := 2.0 * b.data.half_width + 2.0
		for k in chunks:
			var middle := zone.x + (k + 0.5) * chunk_length
			_add_area_shape(area, Vector3(width, AREA_HEIGHT, chunk_length + 1.0), _xform(b, middle, 0.0, AREA_HEIGHT * 0.5))
		# Línea verde al inicio y al final, y cartel "DRS" a la entrada.
		_add_paint(b, area, "LineaInicio", zone.x, 0.0, Vector2(2.0 * b.data.half_width, 0.6), b.materials["green"])
		_add_paint(b, area, "LineaFin", zone.y, 0.0, Vector2(2.0 * b.data.half_width, 0.6), b.materials["green"])
		for side in [-1.0, 1.0]:
			var post_lateral: float = side * _sign_lateral(b, zone.x, side)
			var post := Node3D.new()
			post.name = "CartelDRS"
			post.transform = area.transform.affine_inverse() * _xform(b, zone.x, post_lateral)
			area.add_child(post)
			Utils.add_box(post, "Poste", Vector3(0.15, 2.4, 0.15), Vector3(0.0, 1.2, 0.0), b.materials["dark"])
			# El texto de un Label3D mira hacia +Z, que acá es hacia los autos que llegan.
			Utils.add_label(post, "Texto", "DRS", Vector3(0.0, 2.9, 0.0), 160, Color(0.2, 1.0, 0.4))
	return list


# Las rectas más largas del circuito (para el DRS automático). Si el circuito
# no tiene ninguna recta "de manual" (Mónaco), se va aflojando el criterio.
static func _find_straights(b: Build) -> Array[Vector2]:
	for attempt: Vector2 in DRS_CRITERIA:
		var zones := _find_straights_with(b, attempt.x, attempt.y)
		if not zones.is_empty():
			return zones
	return []


# Tramos seguidos con radio mayor que `min_radius` y de al menos `min_length` metros.
static func _find_straights_with(b: Build, min_radius: float, min_length: float) -> Array[Vector2]:
	# Se empieza a recorrer desde una curva para no partir una recta en dos.
	var step := KERB_SAMPLE_STEP
	var count := int(b.length / step)
	var start_index := 0
	for i in count:
		if absf(_curvature(b, i * step)) > 1.0 / min_radius:
			start_index = i
			break
	var found: Array[Vector2] = []
	var run_start := -1.0
	for k in count + 1:
		var offset := (start_index + k) * step
		var straight := k < count and absf(_curvature(b, offset)) <= 1.0 / min_radius
		if straight and run_start < 0.0:
			run_start = offset
		elif not straight and run_start >= 0.0:
			if offset - run_start >= min_length:
				var delay := minf(DRS_START_DELAY, (offset - run_start) * 0.2)
				found.append(Vector2(run_start + delay, offset - 10.0))
			run_start = -1.0
	found.sort_custom(func(a: Vector2, c: Vector2) -> bool: return a.y - a.x > c.y - c.x)
	var zones: Array[Vector2] = []
	for i in mini(found.size(), DRS_MAX_ZONES):
		zones.append(Vector2(fposmod(found[i].x, b.length), fposmod(found[i].y, b.length)))
	return zones


# Distancia lateral a la que se puede plantar un cartel de ese lado.
static func _sign_lateral(b: Build, offset: float, side: float) -> float:
	var wall := _wall_offset(b, offset, side)
	var wanted := b.data.half_width + 2.5
	if wall > 0.0:
		wanted = minf(wanted, wall - 0.6)
	return maxf(wanted, b.data.half_width + 0.4)


# Rectángulo pintado en el piso, centrado en el eje. size = (ancho, largo).
static func _add_paint(b: Build, parent: Node3D, node_name: String, offset: float, lateral: float,
		size: Vector2, material: Material) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	holder.transform = _relative(parent, _xform(b, offset, lateral, ROAD_TOP + PAINT_HEIGHT))
	parent.add_child(holder)
	Utils.add_box(holder, "Pintura", Vector3(size.x, 0.02, size.y), Vector3.ZERO, material)


# Transformación `world` expresada respecto de `parent` (los nodos todavía no
# están en el árbol, así que se compone a mano subiendo por los padres).
static func _relative(parent: Node, world: Transform3D) -> Transform3D:
	var accumulated := Transform3D.IDENTITY
	var node := parent
	while node != null:
		if node is Node3D:
			accumulated = (node as Node3D).transform * accumulated
		node = node.get_parent()
	return accumulated.affine_inverse() * world


static func _build_pit_zones(b: Build, zones: Node) -> void:
	var data := b.data
	var side := float(data.pit_side)
	# Zona con límite de velocidad: sigue al pit lane con cajas cortas.
	var limit_span := b.pit_limit_end - b.pit_limit_start
	var area := _new_area(zones, "PitLane", _pit_xform(b, b.pit_limit_start, 0.0, AREA_HEIGHT * 0.5), Track.GROUP_PIT_LANE)
	var chunks := int(ceil(limit_span / PIT_ZONE_CHUNK_LENGTH))
	var chunk_length := limit_span / chunks
	for k in chunks:
		var middle := b.pit_limit_start + (k + 0.5) * chunk_length
		_add_area_shape(area, Vector3(data.pit_half_width * 2.0, AREA_HEIGHT, chunk_length + 0.5),
				_pit_xform(b, middle, 0.0, AREA_HEIGHT * 0.5))

	# Box del jugador (índice 0): la parada se cuenta al detenerse acá adentro.
	var box_lateral := side * data.pit_half_width * TrackLayout.PIT_BOX_LATERAL_FRACTION
	var box_width := minf(TrackLayout.PIT_BOX_SIZE.y, data.pit_half_width * 0.95)
	var box_area := _new_area(zones, "BoxJugador",
			_pit_xform(b, b.pit_box_offsets[0], box_lateral, AREA_HEIGHT * 0.5), Track.GROUP_PIT_BOX)
	_add_area_shape(box_area, Vector3(box_width, AREA_HEIGHT, b.pit_box_length), box_area.transform)

	# Pintura del piso de boxes.
	var paint := Node3D.new()
	paint.name = "PinturaBoxes"
	b.root.add_child(paint)
	for i in b.pit_box_offsets.size():
		var holder := Node3D.new()
		holder.name = "Box%d" % i
		holder.transform = _pit_xform(b, b.pit_box_offsets[i], box_lateral, PIT_ROAD_TOP + PAINT_HEIGHT)
		paint.add_child(holder)
		var material: Material = b.materials["yellow"] if i == 0 else b.materials["white"]
		_add_rectangle_outline(holder, Vector2(box_width, b.pit_box_length), material)
	# Cartel del box del jugador: detrás del box, mirando hacia el pit lane.
	var sign_holder := Node3D.new()
	sign_holder.name = "CartelBoxJugador"
	sign_holder.transform = _pit_xform(b, b.pit_box_offsets[0], side * (data.pit_half_width + 1.3), 4.3)
	paint.add_child(sign_holder)
	Utils.add_label(sign_holder, "Texto", "TU BOX", Vector3.ZERO, 220, Color(1.0, 0.85, 0.1),
			Vector3(0.0, -90.0 * side, 0.0))
	# Líneas de inicio y fin del límite de velocidad, con su cartel.
	for limit_offset in [b.pit_limit_start, b.pit_limit_end]:
		var line := Node3D.new()
		line.name = "LineaLimite"
		line.transform = _pit_xform(b, limit_offset, 0.0, PIT_ROAD_TOP + PAINT_HEIGHT)
		paint.add_child(line)
		Utils.add_box(line, "Pintura", Vector3(data.pit_half_width * 2.0, 0.02, 0.5), Vector3.ZERO, b.materials["white"])
	var limit_sign := Node3D.new()
	limit_sign.name = "CartelLimite"
	limit_sign.transform = _pit_xform(b, b.pit_limit_start, side * (data.pit_half_width + 0.8), 3.0)
	paint.add_child(limit_sign)
	Utils.add_label(limit_sign, "Texto", "80", Vector3.ZERO, 260, Color(1.0, 0.25, 0.2))


# Dibuja el contorno de un rectángulo en el piso con 4 cajas finas.
# size = (ancho a lo ancho del pit lane, largo en el sentido de marcha).
static func _add_rectangle_outline(holder: Node3D, size: Vector2, material: Material) -> void:
	var line := 0.18
	Utils.add_box(holder, "Frente", Vector3(size.x, 0.02, line), Vector3(0.0, 0.0, -size.y * 0.5), material)
	Utils.add_box(holder, "Fondo", Vector3(size.x, 0.02, line), Vector3(0.0, 0.0, size.y * 0.5), material)
	Utils.add_box(holder, "LadoIzquierdo", Vector3(line, 0.02, size.y), Vector3(-size.x * 0.5, 0.0, 0.0), material)
	Utils.add_box(holder, "LadoDerecho", Vector3(line, 0.02, size.y), Vector3(size.x * 0.5, 0.0, 0.0), material)


# ==============================================================================
# Decorado
# ==============================================================================

# Línea de largada, cajones de grilla y pórtico con el semáforo.
static func _build_start_area(b: Build, scenery: Node) -> void:
	var data := b.data
	var start_node := Node3D.new()
	start_node.name = "Largada"
	scenery.add_child(start_node)
	_add_paint(b, start_node, "LineaDeLargada", 0.0, 0.0, Vector2(data.half_width * 2.0, 1.0), b.materials["white"])

	# Cajones de grilla: una línea transversal por auto, un poco adelante de él.
	var grid_lateral := minf(TrackLayout.GRID_LATERAL, data.half_width - 1.6)
	for slot in TrackLayout.GRID_SLOTS:
		var distance := TrackLayout.GRID_FIRST_ROW_DISTANCE + TrackLayout.GRID_ROW_SPACING * slot
		# Cajones pares a la izquierda e impares a la derecha.
		var lateral := -grid_lateral if slot % 2 == 0 else grid_lateral
		_add_paint(b, start_node, "Cajon%d" % (slot + 1), -distance + 2.9, lateral, Vector2(2.6, 0.2), b.materials["white"])

	# Pórtico: dos columnas y una viga, unos metros después de la línea.
	var gantry := Node3D.new()
	gantry.name = "Portico"
	gantry.transform = _xform(b, 8.0)
	start_node.add_child(gantry)
	var left := _sign_lateral(b, 8.0, -1.0)
	var right := _sign_lateral(b, 8.0, 1.0)
	Utils.add_box(gantry, "ColumnaIzquierda", Vector3(0.5, 7.0, 0.5), Vector3(-left, 3.5, 0.0), b.materials["dark"])
	Utils.add_box(gantry, "ColumnaDerecha", Vector3(0.5, 7.0, 0.5), Vector3(right, 3.5, 0.0), b.materials["dark"])
	Utils.add_box(gantry, "Viga", Vector3(left + right + 0.5, 0.6, 0.6), Vector3((right - left) * 0.5, 7.0, 0.0), b.materials["dark"])

	# Semáforo de largada: 5 esferas que el script enciende de a una. En el
	# pórtico, +Z apunta hacia la grilla.
	var lights := Node3D.new()
	lights.name = "Semaforo"
	lights.position = Vector3(0.0, 6.0, 0.4)
	lights.set_script(load("res://scripts/track/start_lights.gd"))
	gantry.add_child(lights)
	Utils.add_box(lights, "Panel", Vector3(6.4, 1.1, 0.3), Vector3(0.0, 0.0, -0.15), b.materials["dark"])
	for i in 5:
		Utils.add_sphere(lights, "Luz%d" % (i + 1), 0.4, Vector3(-2.4 + 1.2 * i, 0.0, 0.1), b.materials["light_off"])


# Muro que separa la pista del pit lane y edificio de boxes.
static func _build_pit_buildings(b: Build, scenery: Node) -> void:
	var data := b.data
	var side := float(data.pit_side)
	var gap := b.pit_lateral - data.pit_half_width - data.half_width
	if gap >= PIT_SEPARATOR_MIN_GAP:
		# Muro bajo entre la recta y el pit lane, a lo largo de la zona limitada.
		var from_point := b.pit_curve.sample_baked(b.pit_limit_start + 5.0, true)
		var to_point := b.pit_curve.sample_baked(b.pit_limit_end - 5.0, true)
		var from_offset := b.curve.get_closest_offset(from_point)
		var span := _ahead(b, from_offset, b.curve.get_closest_offset(to_point))
		var lateral := side * (data.half_width + gap * 0.5)
		var path := _add_offset_path(b, scenery, "TrazadoMuroDeBoxes", from_offset, span, lateral, PIT_SAMPLE_STEP)
		var half := minf(0.3, gap * 0.25)
		_add_extrusion(path, "MuroDeBoxes", path, b.materials["wall"], true, PackedVector2Array([
			Vector2(-half, 0.0), Vector2(-half, 1.0), Vector2(half, 1.0), Vector2(half, 0.0)]))

	if not b.has_pit_building:
		return
	# Edificio: un módulo con portón detrás de cada box.
	var building := Node3D.new()
	building.name = "EdificioBoxes"
	scenery.add_child(building)
	var spacing := b.pit_box_offsets[1] - b.pit_box_offsets[0]
	var front := data.pit_half_width + 1.5
	for i in b.pit_box_offsets.size():
		var module := Node3D.new()
		module.name = "Modulo%d" % i
		module.transform = _pit_xform(b, b.pit_box_offsets[i], side * (front + PIT_BUILDING_DEPTH * 0.5))
		building.add_child(module)
		Utils.add_static_box(module, "Garaje", Vector3(PIT_BUILDING_DEPTH, 5.0, spacing + 0.2), Vector3(0.0, 2.5, 0.0), b.materials["building"])
		Utils.add_box(module, "PisoSuperior", Vector3(PIT_BUILDING_DEPTH * 0.7, 3.0, spacing + 0.2), Vector3(0.0, 6.5, 0.0), b.materials["concrete"])
		# Portón: caja oscura apenas salida de la fachada que mira al pit lane.
		Utils.add_box(module, "Porton", Vector3(0.2, 3.4, minf(8.0, spacing - 3.0)),
				Vector3(-side * (PIT_BUILDING_DEPTH * 0.5 + 0.05), 1.7, 0.0), b.materials["dark"])


# Tribuna escalonada frente a la recta principal, del lado opuesto a boxes.
static func _build_grandstand(b: Build, scenery: Node) -> void:
	var data := b.data
	if data.is_street:
		return
	var side := -float(data.pit_side)
	var total := GRANDSTAND_SEGMENT_LENGTH * GRANDSTAND_SEGMENTS
	var from_offset := -total * 0.4
	var margin := data.wall_margin_right if side > 0.0 else data.wall_margin_left
	var base := data.half_width + margin + 6.0
	if _min_clearance(b, from_offset, total, side) < (base + GRANDSTAND_ROOM) * 2.0:
		return
	var stand := Node3D.new()
	stand.name = "Tribuna"
	scenery.add_child(stand)
	for segment in GRANDSTAND_SEGMENTS:
		var middle := from_offset + (segment + 0.5) * GRANDSTAND_SEGMENT_LENGTH
		if absf(_curvature(b, middle)) > 1.0 / 150.0:
			continue
		var holder := Node3D.new()
		holder.name = "Tramo%d" % (segment + 1)
		holder.transform = _xform(b, middle, side * base)
		stand.add_child(holder)
		var steps := 5
		for i in steps:
			# Cada escalón es una caja más alta y más alejada de la pista.
			var height := 1.2 * (i + 1)
			var x := side * 2.4 * i
			Utils.add_box(holder, "Escalon%d" % (i + 1), Vector3(2.4, height, GRANDSTAND_SEGMENT_LENGTH),
					Vector3(x, height * 0.5, 0.0), b.materials["concrete"])
			Utils.add_box(holder, "Asientos%d" % (i + 1), Vector3(1.2, 0.35, GRANDSTAND_SEGMENT_LENGTH - 2.0),
					Vector3(x, height + 0.17, 0.0), b.materials["seat"])
		Utils.add_box(holder, "Techo", Vector3(14.0, 0.3, GRANDSTAND_SEGMENT_LENGTH), Vector3(side * 5.0, 11.0, 0.0), b.materials["dark"])
		Utils.add_box(holder, "ColumnaTecho", Vector3(0.4, 11.0, 0.4), Vector3(side * 11.0, 5.5, 0.0), b.materials["dark"])


# Carteles de distancia (150 / 100 / 50) antes de la frenada de cada recta larga.
static func _build_brake_boards(b: Build, scenery: Node, straights: Array[Vector2]) -> void:
	var boards := Node3D.new()
	boards.name = "CartelesDeFrenado"
	scenery.add_child(boards)
	for zone in straights:
		# La frenada empieza donde termina la recta.
		var corner_offset := zone.y + 30.0
		# Del lado exterior de la curva que viene.
		var side := -signf(_curvature(b, corner_offset + 40.0))
		if side == 0.0:
			side = -1.0
		for distance: int in BRAKE_BOARD_DISTANCES:
			var offset := corner_offset - distance
			var lateral := _sign_lateral(b, offset, side) + 0.5
			# Si el muro está pegado a la pista, el cartel va por encima del muro.
			var raised := 1.3 if lateral < b.data.half_width + 2.0 else 0.0
			var board := Node3D.new()
			board.name = "Cartel%d" % distance
			board.transform = _xform(b, offset, side * lateral, raised)
			boards.add_child(board)
			Utils.add_box(board, "Poste", Vector3(0.12, 1.2, 0.12), Vector3(0.0, 0.6, 0.0), b.materials["dark"])
			Utils.add_box(board, "Placa", Vector3(2.2, 1.1, 0.08), Vector3(0.0, 1.75, 0.0), b.materials["board"])
			Utils.add_label(board, "Texto", str(distance), Vector3(0.0, 1.75, 0.06), 96, Color(0.05, 0.05, 0.05))


# Árboles: posiciones aleatorias pero repetibles (semilla fija), lejos de la
# pista y de boxes. El nodo "Arboleda" (tree_scatter.gd) los dibuja con
# MultiMesh a partir de esta lista.
static func _build_trees(b: Build, scenery: Node, bounds: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED + hash(b.data.id)
	var wanted := clampi(int(bounds.get_area() / TREE_AREA_PER_TREE), TREE_MIN_COUNT, TREE_MAX_COUNT)
	var keep_out := b.data.half_width + maxf(b.data.wall_margin_left, b.data.wall_margin_right) + TREE_TRACK_MARGIN
	var pit_keep_out := b.wall_offset_pit + TREE_TRACK_MARGIN
	var positions := PackedVector3Array()
	var rotations := PackedFloat32Array()
	var scales := PackedFloat32Array()
	var attempts := 0
	while positions.size() < wanted and attempts < wanted * 25:
		attempts += 1
		var point := Vector3(rng.randf_range(bounds.position.x + 40.0, bounds.end.x - 40.0), 0.0,
				rng.randf_range(bounds.position.y + 40.0, bounds.end.y - 40.0))
		if point.distance_to(b.curve.get_closest_point(point)) < keep_out:
			continue
		if point.distance_to(b.pit_curve.get_closest_point(point)) < pit_keep_out:
			continue
		positions.append(point)
		rotations.append(rng.randf() * TAU)
		scales.append(rng.randf_range(0.8, 1.6))

	var trees := Node3D.new()
	trees.name = "Arboleda"
	trees.set_script(load("res://scripts/track/tree_scatter.gd"))
	trees.set("positions", positions)
	trees.set("rotations", rotations)
	trees.set("scales", scales)
	scenery.add_child(trees)
