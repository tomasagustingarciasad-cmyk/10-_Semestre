"""Protocolo UDP entre el volante (ESP32) y el simulador.

Este módulo es la versión en Python de `scripts/input/wheel_protocol.gd`.
Lo usan `fake_wheel.py` y `serial_bridge.py`. La especificación completa
está en `docs/protocolo.md`.

Mensajes (texto ASCII, uno por línea, terminados en '\\n'):

    Volante -> PC (puerto 4210, ~100 Hz):
        W,<steer>,<throttle>,<brake>,<buttons_bitmask>,<encoder_delta>

    PC -> Volante (puerto 4211, ~30 Hz):
        T,<rpm_pct>,<gear>,<flags_bitmask>
        V,<intensidad>,<duracion_ms>
"""

from __future__ import annotations

from dataclasses import dataclass

# --- Puertos y tiempos --------------------------------------------------------
PORT_WHEEL_TO_PC = 4210      # La PC escucha acá los paquetes del volante
PORT_PC_TO_WHEEL = 4211      # El volante escucha acá la telemetría
WHEEL_SEND_HZ = 100.0        # Frecuencia de envío del volante
TELEMETRY_SEND_HZ = 30.0     # Frecuencia de la telemetría
TIMEOUT_MS = 500             # Sin paquetes en este tiempo = desconectado

# --- Escalas de los ejes ------------------------------------------------------
STEER_SCALE = 1000           # Dirección: -1000 (izquierda) .. 1000 (derecha)
PEDAL_SCALE = 1000           # Pedales: 0 .. 1000

# --- Bits de botones (mensaje W) ---------------------------------------------
BTN_SHIFT_UP = 1 << 0
BTN_SHIFT_DOWN = 1 << 1
BTN_DRS = 1 << 2
BTN_ERS = 1 << 3
BTN_PIT_LIMITER = 1 << 4
BTN_RESET = 1 << 5
BTN_CAMERA = 1 << 6
BTN_PAUSE = 1 << 7

BUTTON_NAMES = {
    BTN_SHIFT_UP: "shift_up",
    BTN_SHIFT_DOWN: "shift_down",
    BTN_DRS: "drs",
    BTN_ERS: "ers",
    BTN_PIT_LIMITER: "pit_limiter",
    BTN_RESET: "reset",
    BTN_CAMERA: "camera_next",
    BTN_PAUSE: "pause",
}

# --- Bits de estado (mensaje T) ----------------------------------------------
FLAG_DRS_AVAILABLE = 1 << 0
FLAG_DRS_OPEN = 1 << 1
FLAG_PIT_LIMITER = 1 << 2
FLAG_ERS_DEPLOY = 1 << 3
FLAG_REV_LIMIT = 1 << 4
FLAG_IN_PIT_LANE = 1 << 5
FLAG_LAP_INVALID = 1 << 6
FLAG_AQUAPLANING = 1 << 7     # Agregado en la Fase 1b

FLAG_NAMES = {
    FLAG_DRS_AVAILABLE: "DRS disponible",
    FLAG_DRS_OPEN: "DRS abierto",
    FLAG_PIT_LIMITER: "limitador",
    FLAG_ERS_DEPLOY: "ERS",
    FLAG_REV_LIMIT: "corte",
    FLAG_IN_PIT_LANE: "pit lane",
    FLAG_LAP_INVALID: "vuelta inválida",
    FLAG_AQUAPLANING: "aquaplaning",
}

# --- Marchas especiales --------------------------------------------------------
GEAR_REVERSE = -1
GEAR_NEUTRAL = 0

# --- Shift lights (misma regla que el HUD de Godot) ---------------------------
SHIFT_LED_COUNT = 10
SHIFT_LED_START_PCT = 62.0
SHIFT_LED_FULL_PCT = 94.0
SHIFT_LED_FLASH_PCT = 97.0
SHIFT_LED_GREEN = 4
SHIFT_LED_RED = 3

VIBRATION_MAX = 255


def format_wheel_packet(steer: float, throttle: float, brake: float,
                        buttons: int, encoder_delta: int) -> bytes:
    """Arma el mensaje W a partir de valores normalizados.

    steer: -1..1 (negativo = izquierda); throttle y brake: 0..1.
    """
    steer_units = int(round(max(-1.0, min(1.0, steer)) * STEER_SCALE))
    throttle_units = int(round(max(0.0, min(1.0, throttle)) * PEDAL_SCALE))
    brake_units = int(round(max(0.0, min(1.0, brake)) * PEDAL_SCALE))
    text = f"W,{steer_units},{throttle_units},{brake_units},{buttons},{encoder_delta}\n"
    return text.encode("ascii")


@dataclass
class Telemetry:
    """Contenido de un mensaje T."""
    rpm_pct: int = 0
    gear: int = 0
    flags: int = 0


@dataclass
class Vibration:
    """Contenido de un mensaje V."""
    intensity: int = 0
    duration_ms: int = 0


def parse_pc_message(line: str) -> Telemetry | Vibration | None:
    """Interpreta una línea enviada por la PC. Devuelve None si no es válida."""
    parts = line.strip().split(",")
    try:
        if parts[0] == "T" and len(parts) == 4:
            return Telemetry(int(parts[1]), int(parts[2]), int(parts[3]))
        if parts[0] == "V" and len(parts) == 3:
            return Vibration(int(parts[1]), int(parts[2]))
    except ValueError:
        return None
    return None


def is_wheel_packet(line: str) -> bool:
    """True si la línea tiene el formato W,<int>,<int>,<int>,<int>,<int>."""
    parts = line.strip().split(",")
    if len(parts) != 6 or parts[0] != "W":
        return False
    try:
        for value in parts[1:]:
            int(value)
    except ValueError:
        return False
    return True


def leds_for_rpm(rpm_pct: float) -> int:
    """Cantidad de LEDs encendidos para un porcentaje de RPM."""
    if rpm_pct < SHIFT_LED_START_PCT:
        return 0
    span = SHIFT_LED_FULL_PCT - SHIFT_LED_START_PCT
    lit = int((rpm_pct - SHIFT_LED_START_PCT) / span * SHIFT_LED_COUNT) + 1
    return max(0, min(SHIFT_LED_COUNT, lit))


def led_color(index: int) -> tuple[int, int, int]:
    """Color RGB del LED número `index` (0 = el primero en encenderse)."""
    if index < SHIFT_LED_GREEN:
        return (40, 230, 60)
    if index < SHIFT_LED_GREEN + SHIFT_LED_RED:
        return (240, 40, 40)
    return (90, 115, 255)


def gear_text(gear: int) -> str:
    """Texto de la marcha: R, N o el número."""
    if gear == GEAR_REVERSE:
        return "R"
    if gear == GEAR_NEUTRAL:
        return "N"
    return str(gear)


def flags_text(flags: int) -> str:
    """Lista legible de los bits de estado activos."""
    names = [name for bit, name in FLAG_NAMES.items() if flags & bit]
    return ", ".join(names) if names else "-"
