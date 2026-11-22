#!/usr/bin/env python3
"""Puente USB serie <-> UDP para usar el volante por cable.

Cuando el ESP32 está conectado por USB (sin WiFi), el firmware escribe por
el puerto serie las mismas líneas que mandaría por UDP. Este programa:

    serie  -> UDP : reenvía cada línea "W,..." al juego (puerto 4210)
    UDP    -> serie: reenvía la telemetría "T,..." y "V,..." al ESP32

Para el juego no cambia nada: sigue usando la fuente "Volante UDP".

Uso:
    python serial_bridge.py --list              Lista los puertos serie
    python serial_bridge.py --port COM5         Windows
    python serial_bridge.py --port /dev/ttyUSB0 Linux
"""

from __future__ import annotations

import argparse
import socket
import sys
import time

import wheel_protocol as wp

DEFAULT_BAUD = 115200
# Tiempo máximo de espera de una lectura serie [s] (mantiene ágil el bucle).
SERIAL_TIMEOUT = 0.005
# Espera antes de reintentar abrir el puerto si se desconecta [s].
RECONNECT_DELAY = 1.0
STATS_INTERVAL = 2.0
# Largo máximo de una línea válida (protección contra basura en el puerto).
MAX_LINE_LENGTH = 64


def list_ports() -> None:
    from serial.tools import list_ports as serial_list_ports
    ports = list(serial_list_ports.comports())
    if not ports:
        print("No se encontraron puertos serie.")
        return
    for port in ports:
        print(f"{port.device:15s} {port.description}")


def run_bridge(args: argparse.Namespace) -> None:
    import serial

    game_address = (args.host, args.udp_port)
    tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    rx.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    rx.bind(("0.0.0.0", args.listen_port))
    rx.setblocking(False)

    forwarded_to_game = 0
    forwarded_to_wheel = 0
    discarded = 0
    next_stats = time.monotonic() + STATS_INTERVAL

    while True:
        # --- Apertura (y reapertura) del puerto serie -------------------------
        try:
            port = serial.Serial(args.port, args.baud, timeout=SERIAL_TIMEOUT)
        except serial.SerialException as error:
            print(f"No se pudo abrir {args.port}: {error}. Reintentando...")
            time.sleep(RECONNECT_DELAY)
            continue
        print(f"Puente activo: {args.port} @ {args.baud} baudios  <->  "
              f"UDP {args.host}:{args.udp_port} (telemetría en el puerto {args.listen_port})")

        buffer = b""
        try:
            while True:
                # --- Serie -> UDP ---------------------------------------------
                buffer += port.read(256)
                while b"\n" in buffer:
                    raw_line, buffer = buffer.split(b"\n", 1)
                    line = raw_line.decode("ascii", errors="ignore").strip()
                    if wp.is_wheel_packet(line):
                        tx.sendto((line + "\n").encode("ascii"), game_address)
                        forwarded_to_game += 1
                    elif line:
                        # Cualquier otra cosa es texto de depuración del firmware.
                        discarded += 1
                        if args.verbose:
                            print(f"[ESP32] {line}")
                if len(buffer) > MAX_LINE_LENGTH:
                    buffer = b""   # Línea demasiado larga: se descarta.

                # --- UDP -> serie ---------------------------------------------
                while True:
                    try:
                        data, _address = rx.recvfrom(1024)
                    except (BlockingIOError, ConnectionResetError):
                        break
                    for text in data.decode("ascii", errors="ignore").splitlines():
                        if wp.parse_pc_message(text) is not None:
                            port.write((text.strip() + "\n").encode("ascii"))
                            forwarded_to_wheel += 1

                now = time.monotonic()
                if now >= next_stats:
                    next_stats = now + STATS_INTERVAL
                    print(f"volante->juego: {forwarded_to_game}   juego->volante: {forwarded_to_wheel}   "
                          f"líneas ignoradas: {discarded}", flush=True)
                if args.duration > 0.0 and now >= args.start_time + args.duration:
                    port.close()
                    return
        except serial.SerialException as error:
            print(f"Se perdió el puerto serie ({error}). Reintentando...")
            try:
                port.close()
            except serial.SerialException:
                pass
            time.sleep(RECONNECT_DELAY)


def main() -> None:
    parser = argparse.ArgumentParser(description="Puente USB serie <-> UDP para el volante del Simulador F1.")
    parser.add_argument("--list", action="store_true", help="listar los puertos serie y salir")
    parser.add_argument("--port", help="puerto serie del ESP32 (COM5, /dev/ttyUSB0, ...)")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD, help="velocidad en baudios")
    parser.add_argument("--host", default="127.0.0.1", help="IP de la PC donde corre el juego")
    parser.add_argument("--udp-port", type=int, default=wp.PORT_WHEEL_TO_PC, help="puerto del juego (W)")
    parser.add_argument("--listen-port", type=int, default=wp.PORT_PC_TO_WHEEL, help="puerto de telemetría (T/V)")
    parser.add_argument("--verbose", action="store_true", help="mostrar las líneas de depuración del ESP32")
    parser.add_argument("--duration", type=float, default=0.0, help="segundos antes de salir; 0 = sin límite")
    args = parser.parse_args()
    args.start_time = time.monotonic()

    try:
        import serial  # noqa: F401  (se verifica que pyserial esté instalado)
    except ImportError:
        print("Falta pyserial. Instalalo con:  pip install -r requirements.txt")
        sys.exit(1)

    if args.list:
        list_ports()
        return
    if not args.port:
        parser.error("indicá el puerto con --port (o usá --list para verlos)")
    try:
        run_bridge(args)
    except KeyboardInterrupt:
        print("\nInterrumpido.")


if __name__ == "__main__":
    main()
