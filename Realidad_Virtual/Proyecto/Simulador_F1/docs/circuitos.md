# Los 24 circuitos reales: de dónde salen y cómo se generan

Agregado en la **Fase 1b**. El juego tiene 25 circuitos: el original **Autódromo Los Aromos** y los
**24 del calendario 2026** de Fórmula 1. Solo se usan nombres de circuitos y ciudades: no hay logos
ni marcas.

## 1. Cadena completa

```
tools/circuits/geojson/*.geojson     trazado real (latitud/longitud)        ← bacinger/f1-circuits (MIT)
tools/circuits/circuits.json         catálogo: nombre, longitud oficial, sentido, anchos
        │  python tools/circuits/convert_circuits.py
        ▼
assets/circuits/<id>.tres            recurso CircuitData (uno por circuito)
        │  godot --headless --script res://tools/godot/build_scenes.gd -- circuito <id>
        ▼
scenes/track/circuitos/<id>.tscn     escena del circuito (Path3D, CSG, zonas, decorado)
        │  la sesión carga SOLO el circuito elegido (SessionBase._load_circuit)
        ▼
nivel Clasificación / Carrera
```

`scripts/track/track_layout.gd` es el punto de acceso: `list_ids()`, `load_circuit(id)`,
`scene_path(id)` y `build_curve(points)`.

## 2. Fuente de los trazados

- Repositorio **bacinger/f1-circuits** (<https://github.com/bacinger/f1-circuits>), licencia **MIT**,
  commit `8094e957` (16/10/2026). La licencia está copiada en `tools/circuits/geojson/LICENSE.md`.
- Cada archivo GeoJSON trae el eje de la pista como una línea de puntos latitud/longitud.
- Las **longitudes oficiales** del catálogo se cargaron a mano en `circuits.json` (datos públicos
  de cada Gran Premio).

## 3. Qué hace `convert_circuits.py`

1. **Proyección** a metros (equirectangular local centrada en el circuito; a escala de unos pocos
   kilómetros el error es despreciable). En el juego, +X es el este y −Z el norte.
2. **Sentido de giro:** se calcula el área con signo del polígono; si no coincide con el sentido
   real anotado en el catálogo, se invierte el orden conservando el punto de largada.
3. **Suavizado:** spline de Catmull-Rom centrípeta por los puntos originales, muestreada densa.
4. **Simplificación** de Douglas-Peucker (tolerancia 0,9 m): quedan pocos puntos en las rectas y
   muchos en las curvas.
5. **Escala:** se ajusta el tamaño para que la longitud de la curva sea exactamente la oficial, y
   se centra en el origen.
6. Escribe `assets/circuits/<id>.tres`. El script es determinista: volver a correrlo da los mismos
   archivos.

Los Aromos no pasa por esos pasos: sus puntos están escritos a mano dentro del script y da la
misma pista que en la Fase 1.

## 4. El recurso `CircuitData`

| Campo | Qué es |
|---|---|
| `id`, `display_name`, `location`, `calendar_round` | Identificación (el orden del menú es el del calendario). |
| `official_length`, `clockwise` | Longitud oficial [m] y sentido de giro. |
| `source`, `notes` | De dónde salió el trazado y aclaraciones (se muestran en el menú). |
| `points` | Puntos del eje (X, Z) en metros, en sentido de marcha; el primero es la línea de largada. |
| `half_width`, `kerb_width` | Medio ancho del asfalto y ancho de los pianos. |
| `wall_margin_left/right`, `is_street` | Distancia del borde del asfalto a los muros; callejero = muros pegados. |
| `pit_side` | Lado de boxes: 1 = derecha, −1 = izquierda (mirando en sentido de marcha). |
| `pit_points` | Eje del pit lane dado a mano (solo Los Aromos). Vacío = automático. |
| `pit_half_width`, `pit_gap`, `pit_length_before/after`, `pit_limit_margin`, `pit_box_*` | Medidas del pit lane automático. |
| `sector_ends` | Fin de los sectores 1 y 2 [m]. Vacío = tercios de la vuelta. |
| `drs_zones` | Zonas de DRS (inicio, fin) [m]. Vacío = automáticas. |

## 5. Qué genera `track_builder.gd` para cualquier circuito

Todo sale del eje y de las medidas del recurso:

- **Asfalto, pasto y muros:** extrusión de un perfil a lo largo de la curva (`CSGPolygon3D` en modo
  *path*), igual que en la Fase 1 (ver `circuito_path3d_csg.md`).
- **Separación entre tramos ("clearance"):** en cada punto se mide a qué distancia hay otro tramo
  de la misma pista. Con eso los muros se acercan o se interrumpen donde dos tramos pasan cerca
  (horquillas, Suzuka), los controles de paso no invaden el tramo vecino y se decide si entra la
  tribuna o el edificio de boxes.
- **Pianos:** en las curvas, detectadas por curvatura.
- **Sectores y controles de paso:** tercios de la vuelta, salvo que el recurso diga otra cosa.
- **DRS:** en las rectas más largas (hasta 2 zonas). Se busca primero rectas de más de 380 m; si no
  hay ninguna se va relajando el criterio (por eso Mónaco tiene una sola zona, corta).
- **Pit lane:** curva paralela a la recta principal del lado interno (`pit_side`), con rampas de
  entrada y salida; se acorta sola si la pista dobla o no hay lugar. La zona con límite de
  velocidad empieza recién donde el pit lane ya está separado de la pista.
- **Grilla, semáforo, carteles de frenada, tribuna, edificio de boxes y árboles.**

### Línea de carrera (Fase 1c)

`track_builder.gd` también calcula la línea de carrera de cada circuito (`RacingLine.compute`,
algoritmo K1999) y la guarda en la escena (`Track.line_lateral`: desplazamiento lateral cada 4 m).
La usan el piloto automático y los rivales, y el perfil de velocidad se calcula sobre su curvatura.
Detalle en `decisiones_diseno.md` §17.

### Progreso del auto en pistas que se cruzan o pasan cerca

Buscar "el punto más cercano del eje" falla cuando dos tramos están pegados o se cruzan (Suzuka).
`Track.get_offset_near(punto, anterior)` busca solo en una ventana alrededor del progreso anterior.
Lo usan el cronómetro, la sesión, el piloto automático y el minimapa.

## 6. Carga y CSG: ¿conviene "hornear" la malla?

Los `CSGPolygon3D` calculan su malla y su colisión al cargar la escena. Se midió el tiempo de carga
del nivel completo con cada circuito (columna *Carga* de `resultados_circuitos.md`): entre
**0,5 y 0,9 segundos** en la máquina de pruebas (2 núcleos, sin ventana y con dos pruebas corriendo
a la vez), incluso en los circuitos de 7 km. Como además cada
sesión carga **solo el circuito elegido**, se decidió **dejar el CSG sin hornear**: las escenas
siguen siendo editables en el editor (se puede mover un punto del `Path3D` y ver el resultado) y
pesan ~300 kB cada una. Si en tu PC la carga se notara, la alternativa está anotada en
`pendientes.md`.

## 7. Qué es real y qué es aproximado

**Real:** la forma del trazado en planta, la longitud oficial (error < 0,01 %), el sentido de giro
y la ubicación aproximada de la línea de largada (primer punto de la fuente).

**Aproximado en todos los circuitos:**

- **Son planos.** No hay desniveles ni peraltes (Eau Rouge, el peralte de Zandvoort, etc.).
- **Ancho constante** por circuito (9 a 15 m según el catálogo), no el ancho real de cada tramo.
- **Línea de largada:** es el primer punto del trazado de la fuente; no se verificó al metro.
- **Pit lane:** generado automáticamente sobre la recta principal. El lado se asume interno
  (derecha en los circuitos horarios, izquierda en los antihorarios) y su largo y sus entradas no
  son los reales.
- **Zonas de DRS y sectores:** automáticos (rectas más largas, tercios de vuelta), no los oficiales.
- **Muros, escapatorias, pianos y decorado:** genéricos.
- **Curvas lentas más cerradas que las reales.** En la fuente, las curvas lentas están dibujadas
  con pocos puntos y quedan con radios de 10 a 20 m sobre el eje. La línea de carrera lo compensa
  en parte; es una de las razones por las que el piloto automático no llega a los tiempos reales.

**Casos particulares:**

| Circuito | Aclaración |
|---|---|
| Suzuka | Trazado en ocho. En la realidad un tramo pasa por un puente sobre el otro; acá el **cruce es a nivel** y sin muros en el cruce. |
| Madrid ("Madring") | Circuito nuevo de 2026: el trazado de la fuente es el del proyecto publicado; puede diferir en detalles del construido. |
| Singapur | En la fuente los puntos venían en sentido horario; se invirtieron para respetar el sentido real (antihorario). |
| Mónaco | Pit lane muy corto (172 m) porque la recta principal es curva; una sola zona de DRS. El piloto automático, en Carrera, puede necesitar un "reset" en la largada por lo angosto de la pista. |
| Sakhir y Yeda | Incluidos como circuitos normales del calendario, sin marcas de "cancelado". |
| Los Aromos | Circuito original de la Fase 1, sin cambios de trazado. |

## 8. Cómo agregar un circuito

Ver el paso a paso en el `README.md` §8.
