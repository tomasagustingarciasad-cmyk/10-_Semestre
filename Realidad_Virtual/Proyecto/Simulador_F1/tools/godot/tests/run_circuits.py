#!/usr/bin/env python3
"""Corre test_circuit.gd en todos los circuitos, en seco y con lluvia.

Lanza una instancia de Godot sin ventana por cada combinación (varias en
paralelo), junta las líneas "FILA;..." y escribe la tabla de resultados en
docs/resultados_circuitos.md. Termina con "RESULTADO: TODO OK" si todas las
combinaciones pasaron.

Uso (desde la carpeta del proyecto):
    python tools/godot/tests/run_circuits.py [--godot RUTA] [--jobs N] [id ...]
"""
import argparse
import concurrent.futures
import datetime
import json
import os
import pathlib
import subprocess
import sys

PROJECT = pathlib.Path(__file__).resolve().parents[3]
CATALOG = PROJECT / "tools" / "circuits" / "circuits.json"
OUTPUT = PROJECT / "docs" / "resultados_circuitos.md"
TEST = "res://tools/godot/tests/test_circuit.gd"
WEATHERS = ["seco", "lluvia"]
LOCAL_CIRCUIT = "los_aromos"
# Poles de 2025 (tabla oficial de F1), para comparar el ritmo en seco.
# Madrid (circuito nuevo) y Los Aromos (inventado) no tienen referencia.
POLES_2025 = {
    "melbourne": "1:15.096", "shanghai": "1:30.641", "suzuka": "1:26.983", "sakhir": "1:29.841",
    "yeda": "1:27.294", "miami": "1:26.204", "montreal": "1:10.899", "monaco": "1:09.954",
    "barcelona": "1:11.546", "spielberg": "1:03.971", "silverstone": "1:24.892", "spa": "1:40.562",
    "hungaroring": "1:15.372", "zandvoort": "1:08.662", "monza": "1:18.792", "baku": "1:41.117",
    "singapur": "1:29.158", "austin": "1:32.510", "mexico": "1:15.586", "interlagos": "1:09.511",
    "las_vegas": "1:47.934", "lusail": "1:19.387", "yas_marina": "1:22.207",
}
TIMEOUT_S = 900


def run_one(godot, circuit, weather):
    """Devuelve los campos de la línea FILA (o una fila de error)."""
    command = [godot, "--headless", "--fixed-fps", "60", "--path", str(PROJECT),
               "--script", TEST, "--", circuit, weather]
    try:
        output = subprocess.run(command, capture_output=True, text=True,
                                timeout=TIMEOUT_S).stdout
    except subprocess.TimeoutExpired:
        output = ""
    for line in output.splitlines():
        if line.startswith("FILA;"):
            return line.split(";")[1:]
    return [circuit, circuit, weather, "0", "0", "0", "0", "0", "no", "0", "0", "0", "0",
            "la prueba no terminó"]


# Poles que se marcaron con pista mojada: no sirven como referencia en seco.
WET_POLES = {"las_vegas"}


def parse_time(text):
    minutes, seconds = text.split(":")
    return int(minutes) * 60 + float(seconds)


def pole_columns(circuit, weather, lap_seconds):
    """Devuelve (pole, diferencia en texto, diferencia en % o None)."""
    if circuit not in POLES_2025:
        return "—", "—", None
    pole = POLES_2025[circuit]
    lap = float(lap_seconds)
    if weather != "seco" or lap <= 0.0:
        return pole, "—", None
    gap = (lap / parse_time(pole) - 1.0) * 100.0
    if circuit in WET_POLES:
        return pole + " (mojado)", "%+.1f %% (*)" % gap, None
    return pole, "%+.1f %%" % gap, gap


def format_time(seconds):
    seconds = float(seconds)
    if seconds <= 0.0:
        return "—"
    return "%d:%06.3f" % (int(seconds // 60), seconds % 60)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2)))
    parser.add_argument("circuits", nargs="*")
    arguments = parser.parse_args()

    circuits = arguments.circuits
    if not circuits:
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        circuits = [LOCAL_CIRCUIT] + [entry["id"] for entry in catalog["circuitos"]]
    combos = [(circuit, weather) for circuit in circuits for weather in WEATHERS]

    rows = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=arguments.jobs) as pool:
        futures = [pool.submit(run_one, arguments.godot, *combo) for combo in combos]
        for combo, future in zip(combos, futures):
            row = future.result()
            rows.append(row)
            print("%-12s %-7s vuelta %s  %s" % (combo[0], combo[1], format_time(row[6]), row[13]))
            sys.stdout.flush()

    failures = [row for row in rows if row[13] != "OK"]
    lines = [
        "# Resultados del piloto automático en todos los circuitos",
        "",
        "Generado por `tools/godot/tests/run_circuits.py` el %s." % datetime.date.today().isoformat(),
        "Cada fila es una vuelta cronometrada del piloto automático en el nivel Clasificación",
        "(en seco con neumático medio; con lluvia, agua 0,70 y neumático de lluvia extrema).",
        "",
        "- **Longitud**: la del eje generado contra la oficial (tolerancia ±1 %).",
        "- **Pole 2025 / Dif. pole**: la pole real de 2025 (tabla oficial de F1) y cuánto más lenta es la vuelta",
        "  del piloto automático en seco. Madrid y Los Aromos no tienen referencia.",
        "  (*) La clasificación de Las Vegas 2025 se corrió con lluvia: esa pole no es una referencia en seco",
        "  y no entra en el promedio.",
        "- **Fuera**: segundos con las cuatro ruedas fuera de la pista durante la vuelta.",
        "- **Carga**: tiempo de carga del nivel con ese circuito en la máquina de pruebas (sin ventana).",
        "",
        "| Circuito | Clima | Longitud [m] | Oficial [m] | Dif. | Vuelta | Pole 2025 | Dif. pole | Sectores | Válida | Fuera [s] | Choques | Vel. máx [km/h] | Carga [ms] | Estado |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    gaps = []
    for row in rows:
        pole, gap_text, gap = pole_columns(row[0], row[2], row[6])
        if gap is not None:
            gaps.append((gap, row[1]))
        lines.append("| %s | %s | %s | %s | %s %% | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            row[1], row[2], row[3], row[4], row[5], format_time(row[6]), pole, gap_text, row[7], row[8],
            row[9], row[10], row[11], row[12], row[13]))
    lines += ["", "**Resumen:** %d de %d combinaciones OK." % (len(rows) - len(failures), len(rows))]
    if gaps:
        average = sum(gap for gap, _ in gaps) / len(gaps)
        best = min(gaps)
        worst = max(gaps)
        summary = "Diferencia media contra la pole 2025 (seco, %d circuitos con pole en seco): %+.1f %% (mejor: %s %+.1f %%; peor: %s %+.1f %%)." % (
            len(gaps), average, best[1], best[0], worst[1], worst[0])
        lines += ["", "**" + summary + "**"]
        print(summary)
    lines.append("")
    if not arguments.circuits:   # La tabla solo se reescribe con la corrida completa.
        OUTPUT.write_text("\n".join(lines), encoding="utf-8")
        print("Tabla escrita en", OUTPUT.relative_to(PROJECT))
    print("RESULTADO: %s" % ("TODO OK" if not failures else "%d FALLAS" % len(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
