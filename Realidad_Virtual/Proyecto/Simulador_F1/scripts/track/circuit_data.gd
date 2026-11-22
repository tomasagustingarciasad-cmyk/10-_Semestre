class_name CircuitData
extends Resource
## Datos de diseño de UN circuito (un recurso `.tres` por circuito en
## `assets/circuits/`).
##
## Contiene todo lo que el generador (`tools/godot/track_builder.gd`) necesita
## para construir la escena del circuito: el eje como lista de puntos, las
## medidas y dónde van boxes, sectores y zonas de DRS. Los recursos de los
## circuitos reales los escribe `tools/circuits/convert_circuits.py` a partir
## de trazados en GeoJSON; el de "Los Aromos" sale de una tabla hecha a mano.
##
## Coordenadas: plano XZ en metros (Y es la altura; los circuitos son planos).
## +X = este, +Z = sur: visto desde arriba queda con el norte hacia arriba.
## Los puntos están en orden de marcha y el primero es la línea de largada.

@export_group("Identificación")
## Identificador corto (nombre del archivo y de la escena generada).
@export var id: String = ""
## Nombre para mostrar.
@export var display_name: String = ""
## Ciudad y país.
@export var location: String = ""
## Orden en el menú: 0 = circuito original; 1..24 = fecha del calendario 2026.
@export var calendar_round: int = 0
## Longitud oficial de la vuelta [m].
@export var official_length: float = 0.0
## true = sentido horario visto desde arriba.
@export var clockwise: bool = true
## De dónde salió el trazado (fuente y licencia).
@export var source: String = ""
## Aclaración si algún dato es aproximado (vacío = sin observaciones).
@export var notes: String = ""

@export_group("Trazado")
## Puntos de control (x, z) del eje, en orden de marcha. La curva se cierra
## sola volviendo al primero.
@export var points: PackedVector2Array = PackedVector2Array()
## Mitad del ancho del asfalto [m].
@export var half_width: float = 6.5
## Ancho de los pianos [m].
@export var kerb_width: float = 1.3
## Distancia del borde del asfalto al muro, a la izquierda y a la derecha
## del sentido de marcha [m]. En circuitos callejeros es muy chica.
@export var wall_margin_left: float = 10.5
@export var wall_margin_right: float = 8.0
## true = circuito callejero (muros pegados, sin tribuna ni arboleda cercana).
@export var is_street: bool = false

@export_group("Boxes")
## Lado del pit lane respecto del sentido de marcha: 1 = derecha, -1 = izquierda.
@export var pit_side: int = 1
## Eje del pit lane dado a mano (x, z). Vacío = se genera paralelo a la recta
## principal con las medidas de abajo.
@export var pit_points: PackedVector2Array = PackedVector2Array()
## Mitad del ancho del pit lane [m].
@export var pit_half_width: float = 4.5
## Separación entre el borde de la pista y el borde del pit lane [m].
@export var pit_gap: float = 3.0
## Largo máximo del pit lane antes y después de la línea de largada [m].
@export var pit_length_before: float = 300.0
@export var pit_length_after: float = 260.0
## Distancia desde cada extremo del pit lane hasta la línea de límite de velocidad [m].
@export var pit_limit_margin: float = 80.0
## Distancia del primer box a la línea de límite y separación entre boxes [m].
## En 0 se reparten solos dentro de la zona limitada.
@export var pit_box_first: float = 0.0
@export var pit_box_spacing: float = 0.0
## Distancia del eje de la pista al muro del lado de boxes [m]. 0 = automática.
@export var wall_offset_pit: float = 0.0

@export_group("Sectores y DRS")
## Distancia [m] donde terminan el sector 1 y el 2. Vacío = a 1/3 y 2/3 de la vuelta.
@export var sector_ends: PackedFloat32Array = PackedFloat32Array()
## Zonas de DRS como pares (distancia de inicio, distancia de fin).
## Vacío = se ubican solas en las rectas más largas.
@export var drs_zones: PackedVector2Array = PackedVector2Array()
