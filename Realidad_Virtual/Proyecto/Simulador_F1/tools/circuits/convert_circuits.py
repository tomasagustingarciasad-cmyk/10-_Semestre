#!/usr/bin/env python3
"""Convierte los trazados de los circuitos a recursos de Godot.

Entrada:
    circuits.json            catálogo: nombre, longitud oficial, sentido, anchos
    geojson/<archivo>.geojson  eje de cada circuito en latitud/longitud
                               (repositorio bacinger/f1-circuits, licencia MIT)
Salida:
    ../../assets/circuits/<id>.tres   un recurso CircuitData por circuito

Pasos para cada circuito real:
  1. Proyección local: latitud/longitud -> metros (equirectangular centrada
     en el circuito; el error es despreciable en unos pocos kilómetros).
  2. Sentido de giro: si el orden de los puntos no coincide con el sentido
     real del catálogo, se invierte (conservando el punto de largada).
  3. Suavizado: se pasa una spline de Catmull-Rom centrípeta por los puntos
     y se la muestrea densa.
  4. Simplificación (Douglas-Peucker): quedan pocos puntos en las rectas y
     muchos en las curvas, que es lo que necesita la curva de Bézier del juego.
  5. Escala: se ajusta para que la longitud de la curva del juego sea la
     longitud oficial.
El circuito original "Los Aromos" no pasa por esos pasos: sus puntos están
escritos a mano más abajo.

Uso:
    python convert_circuits.py              # todos
    python convert_circuits.py monaco spa   # solo algunos
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUTPUT_DIR = HERE.parent.parent / "assets" / "circuits"

# Metros por grado de latitud y de longitud (en el ecuador).
METERS_PER_DEG_LAT = 110_540.0
METERS_PER_DEG_LON = 111_320.0
# Paso de muestreo de la spline de suavizado [m].
DENSE_STEP = 2.0
# Tolerancia de la simplificación [m]: desvío máximo aceptado respecto de la spline.
SIMPLIFY_TOLERANCE = 0.9
# Distancia máxima entre puntos consecutivos después de simplificar [m].
MAX_POINT_SPACING = 260.0
# Fracción de la distancia al vecino usada como manija de Bézier (igual que
# TrackLayout.HANDLE_FRACTION en el juego).
HANDLE_FRACTION = 1.0 / 3.0
# Subdivisiones por tramo para medir la longitud de la curva de Bézier.
BEZIER_STEPS = 24

Point = tuple[float, float]


# ==============================================================================
# Geometría
# ==============================================================================
def project(coords: list[list[float]]) -> list[Point]:
    """Latitud/longitud -> (x, z) en metros. +X = este, +Z = sur."""
    lat0 = sum(c[1] for c in coords) / len(coords)
    lon0 = sum(c[0] for c in coords) / len(coords)
    scale_x = METERS_PER_DEG_LON * math.cos(math.radians(lat0))
    return [((lon - lon0) * scale_x, -(lat - lat0) * METERS_PER_DEG_LAT) for lon, lat in coords]


def is_clockwise(points: list[Point]) -> bool:
    """Sentido de giro visto desde arriba (norte arriba, +Z hacia abajo)."""
    area = 0.0
    for i, (x0, z0) in enumerate(points):
        x1, z1 = points[(i + 1) % len(points)]
        area += x0 * z1 - x1 * z0
    return area > 0.0   # Con Z hacia abajo, área positiva = horario.


def catmull_rom_closed(points: list[Point], step: float) -> list[Point]:
    """Muestrea una spline de Catmull-Rom centrípeta cerrada cada ~`step` metros."""
    n = len(points)
    dense: list[Point] = []
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        t0 = 0.0
        t1 = t0 + math.dist(p0, p1) ** 0.5
        t2 = t1 + math.dist(p1, p2) ** 0.5
        t3 = t2 + math.dist(p2, p3) ** 0.5
        count = max(1, int(math.dist(p1, p2) / step))
        for k in range(count):
            t = t1 + (t2 - t1) * k / count
            a1 = _lerp(p0, p1, (t - t0) / (t1 - t0))
            a2 = _lerp(p1, p2, (t - t1) / (t2 - t1))
            a3 = _lerp(p2, p3, (t - t2) / (t3 - t2))
            b1 = _lerp(a1, a2, (t - t0) / (t2 - t0))
            b2 = _lerp(a2, a3, (t - t1) / (t3 - t1))
            dense.append(_lerp(b1, b2, (t - t1) / (t2 - t1)))
    return dense


def _lerp(a: Point, b: Point, t: float) -> Point:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def simplify_closed(points: list[Point], tolerance: float) -> list[Point]:
    """Douglas-Peucker sobre un lazo cerrado, conservando el primer punto."""
    half = len(points) // 2
    first = _douglas_peucker(points[: half + 1], tolerance)
    second = _douglas_peucker(points[half:] + [points[0]], tolerance)
    return first[:-1] + second[:-1]


def _douglas_peucker(points: list[Point], tolerance: float) -> list[Point]:
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        start, end = stack.pop()
        worst, worst_index = 0.0, -1
        for i in range(start + 1, end):
            distance = _distance_to_segment(points[i], points[start], points[end])
            if distance > worst:
                worst, worst_index = distance, i
        too_long = math.dist(points[start], points[end]) > MAX_POINT_SPACING
        if worst > tolerance or (too_long and end - start > 1):
            if worst_index < 0:
                worst_index = (start + end) // 2
            keep[worst_index] = True
            stack.append((start, worst_index))
            stack.append((worst_index, end))
    return [p for p, k in zip(points, keep) if k]


def _distance_to_segment(p: Point, a: Point, b: Point) -> float:
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    length_sq = dx * dx + dz * dz
    if length_sq < 1e-9:
        return math.dist(p, a)
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / length_sq))
    return math.dist(p, (ax + dx * t, az + dz * t))


def bezier_length_closed(points: list[Point]) -> float:
    """Longitud de la curva que arma el juego (TrackLayout.build_curve)."""
    n = len(points)
    handles = []
    for i in range(n):
        prev_p, cur, next_p = points[i - 1], points[i], points[(i + 1) % n]
        tx, tz = next_p[0] - prev_p[0], next_p[1] - prev_p[1]
        norm = math.hypot(tx, tz) or 1.0
        tx, tz = tx / norm, tz / norm
        d_in = math.dist(cur, prev_p) * HANDLE_FRACTION
        d_out = math.dist(cur, next_p) * HANDLE_FRACTION
        handles.append(((cur[0] - tx * d_in, cur[1] - tz * d_in), (cur[0] + tx * d_out, cur[1] + tz * d_out)))
    total = 0.0
    for i in range(n):
        p0, p3 = points[i], points[(i + 1) % n]
        p1, p2 = handles[i][1], handles[(i + 1) % n][0]
        previous = p0
        for k in range(1, BEZIER_STEPS + 1):
            t = k / BEZIER_STEPS
            u = 1.0 - t
            x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
            z = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
            total += math.dist(previous, (x, z))
            previous = (x, z)
    return total


def convert_geojson(entry: dict) -> list[Point]:
    data = json.loads((HERE / "geojson" / f"{entry['geojson']}.geojson").read_text(encoding="utf-8"))
    coords = data["features"][0]["geometry"]["coordinates"]
    if coords[0] == coords[-1]:
        coords = coords[:-1]
    points = project(coords)

    # Sentido real. En un trazado en ocho (Suzuka) el área no es confiable:
    # se confía en el orden de la fuente.
    if entry["id"] != "suzuka" and is_clockwise(points) != entry["horario"]:
        points = [points[0]] + points[:0:-1]

    dense = catmull_rom_closed(points, DENSE_STEP)
    simplified = simplify_closed(dense, SIMPLIFY_TOLERANCE)

    # Escala a la longitud oficial (dos pasadas alcanzan).
    for _ in range(2):
        factor = entry["longitud"] / bezier_length_closed(simplified)
        simplified = [(x * factor, z * factor) for x, z in simplified]

    # Se centra el circuito en el origen.
    cx = (min(p[0] for p in simplified) + max(p[0] for p in simplified)) / 2.0
    cz = (min(p[1] for p in simplified) + max(p[1] for p in simplified)) / 2.0
    return [(x - cx, z - cz) for x, z in simplified]


# ==============================================================================
# Circuito original (hecho a mano)
# ==============================================================================
LOS_AROMOS = {
    "id": "los_aromos",
    "nombre": "Autódromo Los Aromos",
    "lugar": "Circuito original del proyecto",
    "longitud": 2951,
    "horario": True,
    "puntos": [
        (-100, 0), (150, 0), (360, 0),                                  # Recta principal
        (430, 14), (478, 62), (492, 130), (486, 195),                   # Curva 1
        (472, 243), (498, 290), (476, 340), (446, 425),                 # Chicana
        (398, 488), (322, 517), (240, 520), (0, 520), (-250, 520),      # Curva 4 y recta opuesta
        (-290, 520), (-311.2, 511.2), (-320, 490), (-311.2, 468.8), (-290, 460),   # Horquilla
        (-200, 460), (-157.6, 442.4), (-140, 400), (-140, 320),         # Curva 6
        (-150, 262), (-185, 215), (-240, 192), (-310, 186), (-375, 172),  # Enlazadas
        (-425, 135), (-442, 80),                                        # Curva 9
        (-440, 55), (-423.9, 16.1), (-385, 0), (-300, 0),               # Curva 10
    ],
    "pit": [(-300, 0), (-262, 4), (-228, 15), (-195, 20), (-100, 20), (0, 20), (140, 20),
            (172, 15), (206, 4), (245, 0)],
    "extra": {
        "half_width": 6.5, "wall_margin_left": 10.5, "wall_margin_right": 8.0,
        "pit_half_width": 4.5, "pit_limit_margin": 107.44, "pit_box_first": 155.0,
        "pit_box_spacing": 22.0, "wall_offset_pit": 42.0,
        "sector_ends": [987.0, 1945.0],
        "drs_zones": [(2741.0, 440.0), (1236.0, 1716.0)],
    },
}


# ==============================================================================
# Escritura del recurso .tres
# ==============================================================================
def _vec2_array(points: list[Point]) -> str:
    return "PackedVector2Array(" + ", ".join(f"{x:.2f}, {z:.2f}" for x, z in points) + ")"


def _quote(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_resource(fields: dict) -> Path:
    lines = [
        '[gd_resource type="Resource" script_class="CircuitData" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/track/circuit_data.gd" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
    ]
    for key, value in fields.items():
        if isinstance(value, bool):
            text = "true" if value else "false"
        elif isinstance(value, str):
            text = _quote(value)
        elif isinstance(value, (int, float)):
            text = repr(value)
        elif key in ("points", "pit_points", "drs_zones"):
            text = _vec2_array(value)
        else:
            text = "PackedFloat32Array(" + ", ".join(repr(float(v)) for v in value) + ")"
        lines.append(f"{key} = {text}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUTPUT_DIR / f"{fields['id']}.tres"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return path


def main() -> None:
    catalog = json.loads((HERE / "circuits.json").read_text(encoding="utf-8"))
    wanted = set(sys.argv[1:])
    source_text = catalog["fuente_geojson"]

    if not wanted or "los_aromos" in wanted:
        fields = {
            "id": LOS_AROMOS["id"], "display_name": LOS_AROMOS["nombre"], "location": LOS_AROMOS["lugar"],
            "official_length": float(LOS_AROMOS["longitud"]), "clockwise": True,
            "source": "Trazado original del proyecto (puntos escritos a mano)", "notes": "",
            "points": LOS_AROMOS["puntos"], "pit_side": 1, "pit_points": LOS_AROMOS["pit"],
        }
        fields.update(LOS_AROMOS["extra"])
        write_resource(fields)
        print(f"los_aromos      {len(LOS_AROMOS['puntos']):4d} puntos   (original)")

    for round_number, entry in enumerate(catalog["circuitos"], start=1):
        if wanted and entry["id"] not in wanted:
            continue
        points = convert_geojson(entry)
        street = bool(entry.get("callejero", False))
        margin = float(entry["margen_muro"])
        fields = {
            "id": entry["id"], "display_name": entry["nombre"], "location": entry["lugar"],
            "calendar_round": round_number, "official_length": float(entry["longitud"]), "clockwise": bool(entry["horario"]),
            "source": source_text, "notes": entry.get("notas", ""),
            "points": points, "half_width": float(entry["medio_ancho"]),
            "wall_margin_left": margin, "wall_margin_right": margin, "is_street": street,
            # El pit lane va del lado interior del circuito: a la derecha si
            # se gira en sentido horario y a la izquierda si no.
            "pit_side": int(entry.get("lado_boxes", 1 if entry["horario"] else -1)),
            "pit_half_width": 3.5 if street else 4.5,
            "pit_gap": 2.0 if street else 3.0,
        }
        write_resource(fields)
        print(f"{entry['id']:15s} {len(points):4d} puntos   {bezier_length_closed(points):8.1f} m "
              f"(oficial {entry['longitud']})")


if __name__ == "__main__":
    main()
