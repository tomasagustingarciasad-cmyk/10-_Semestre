class_name RacingLine
extends RefCounted
## Cálculo de la LÍNEA DE CARRERA de un circuito.
##
## La pista se describe con una lista de puntos del eje (uno cada pocos
## metros) y, para cada uno, el vector unitario hacia la derecha. La línea es
## un desplazamiento lateral por punto (positivo = derecha), acotado a
## ±`limit` metros para no salirse del asfalto.
##
## Método (algoritmo "K1999", de Rémi Coulom, muy usado en simuladores):
## la trazada más rápida es, aproximadamente, la de MENOR CURVATURA. En una
## línea de curvatura mínima la curvatura cambia en forma pareja, así que
## cada punto se mueve a lo ancho hasta que la curvatura en él sea el promedio
## de la de sus vecinos. Repitiendo muchas veces, la línea se abre antes de la
## curva, toca el interior en el vértice y vuelve a abrirse.
## Se trabaja de grueso a fino: primero con vecinos lejanos (acomoda la forma
## general de cada curva) y después con vecinos cada vez más cercanos.

# Separación entre vecinos en cada etapa (en muestras) y pasadas por etapa.
const SPACINGS: Array[int] = [32, 16, 8, 4, 2, 1]
const PASSES_BASE := 24
# Paso lateral para estimar cómo cambia la curvatura al mover un punto [m].
const PROBE := 0.05
const MIN_SENSITIVITY := 0.000001
# Radio mínimo que tiene que quedar del lado interno de la línea [m], y
# ventana (en muestras) para buscar la curvatura más cerrada del eje.
const MIN_INNER_RADIUS := 9.0
const INNER_WINDOW := 3
const INNER_SPAN := 1


## Devuelve el desplazamiento lateral de la línea en cada punto.
static func compute(centers: PackedVector2Array, rights: PackedVector2Array, limit: float) -> PackedFloat32Array:
	var count := centers.size()
	var lateral := PackedFloat32Array()
	lateral.resize(count)
	lateral.fill(0.0)
	if limit <= 0.0 or count < 16:
		return lateral
	# Límite por lado en cada punto. En una horquilla más cerrada que el ancho
	# de la pista, los puntos del lado interno se amontonan (el borde interno
	# casi no tiene radio): ahí la línea no puede meterse tanto hacia adentro.
	var limit_right := PackedFloat32Array()
	var limit_left := PackedFloat32Array()
	limit_right.resize(count)
	limit_left.resize(count)
	for i in count:
		var tightest := 0.0   # Con signo: positiva = curva a la derecha.
		for shift in range(-INNER_WINDOW, INNER_WINDOW + 1):
			var j := (i + shift + count) % count
			var here := curvature(centers[(j - INNER_SPAN + count) % count], centers[j],
					centers[(j + INNER_SPAN) % count])
			if absf(here) > absf(tightest):
				tightest = here
		var inner := limit
		if absf(tightest) > MIN_SENSITIVITY:
			inner = clampf(1.0 / absf(tightest) - MIN_INNER_RADIUS, 0.0, limit)
		limit_right[i] = inner if tightest > 0.0 else limit
		limit_left[i] = inner if tightest < 0.0 else limit

	# Posición actual de cada punto de la línea.
	var points := PackedVector2Array(centers)
	for spacing: int in SPACINGS:
		if spacing * 8 > count:
			continue
		var passes := int(PASSES_BASE * sqrt(float(spacing)))
		for pass_index in passes:
			for i in count:
				var before := (i - spacing + count) % count
				var after := (i + spacing) % count
				var far_before := (i - 2 * spacing + count) % count
				var far_after := (i + 2 * spacing) % count
				# Curvatura objetivo: promedio de la de los dos vecinos.
				var target := 0.5 * (curvature(points[far_before], points[before], points[i])
						+ curvature(points[i], points[after], points[far_after]))
				# Punto de la sección transversal que cae sobre la cuerda
				# vecino-vecino: ahí la curvatura es cero.
				var chord := points[after] - points[before]
				var denominator := chord.cross(rights[i])
				if absf(denominator) < MIN_SENSITIVITY:
					continue
				var on_chord := -chord.cross(centers[i] - points[before]) / denominator
				# Cuánto cambia la curvatura por metro de corrimiento lateral.
				var probe_point := centers[i] + rights[i] * (on_chord + PROBE)
				var sensitivity := curvature(points[before], probe_point, points[after]) / PROBE
				if absf(sensitivity) < MIN_SENSITIVITY:
					continue
				var wanted := clampf(on_chord + target / sensitivity, -limit_left[i], limit_right[i])
				lateral[i] = wanted
				points[i] = centers[i] + rights[i] * wanted
	return lateral


## Curvatura con signo del círculo que pasa por tres puntos [1/m]
## (positiva = gira a la derecha con Z hacia abajo, igual que Track.get_curvature).
static func curvature(p0: Vector2, p1: Vector2, p2: Vector2) -> float:
	var a := p1 - p0
	var b := p2 - p1
	var denominator := a.length() * b.length() * (p2 - p0).length()
	if denominator < 0.0001:
		return 0.0
	return 2.0 * a.cross(b) / denominator
