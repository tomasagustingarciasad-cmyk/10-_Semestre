#!/usr/bin/env python3
"""Volante simulado: permite probar toda la cadena UDP sin hardware.

Hace exactamente lo que hará el ESP32:
  - envía ~100 veces por segundo el mensaje W (dirección, pedales, botones,
    encoder) al puerto 4210 de la PC donde corre el simulador;
  - escucha en el puerto 4211 la telemetría (T) y los eventos de vibración
    (V) y los muestra: shift lights, marcha, estados y "vibración".

Modos de uso (elegir en Godot: Opciones -> Fuente de entrada -> Volante UDP):

    python fake_wheel.py                 Ventana con control por TECLADO
    python fake_wheel.py --gamepad       Ventana con control por GAMEPAD
    python fake_wheel.py --auto          Sin ventana: mueve el volante solo
                                         (onda senoidal) e imprime lo recibido

Teclas (con la ventana del volante simulado en foco):
    Dirección: A/D o flechas      Acelerador: W o flecha arriba
    Freno: S o flecha abajo       Subir/bajar marcha: E / Q
    DRS: F    ERS: Espacio    Limitador: L    Reset: R    Cámara: C
    Pausa/menú: P    Encoder: Re Pág / Av Pág    Salir: Esc

Opciones útiles para probar la calibración del juego:
    --center 120 --range 800   simula un sensor descentrado y con menos
                               recorrido (el juego debe corregirlo al calibrar)
"""

from __future__ import annotations

import argparse
import math
import socket
import sys
import time

import wheel_protocol as wp

# Suavizado del teclado (recorridos completos por segundo).
STEER_RATE = 2.6
STEER_RETURN_RATE = 4.5
PEDAL_RATE = 4.0
PEDAL_RELEASE_RATE = 7.0
# Cada cuánto se imprime el estado en consola [s].
PRINT_INTERVAL = 0.5
# Modo automático: período de la onda de dirección [s].
AUTO_STEER_PERIOD = 4.0
# Ventana.
WINDOW_SIZE = (560, 330)
BACKGROUND = (18, 22, 31)
TEXT_COLOR = (235, 238, 245)
DIM_COLOR = (130, 138, 150)
LED_OFF = (50, 54, 62)


class WheelState:
    """Estado del volante simulado (lo que se envía en el mensaje W)."""

    def __init__(self) -> None:
        self.steer = 0.0
        self.throttle = 0.0
        self.brake = 0.0
        self.buttons = 0
        self.encoder_pending = 0


class Link:
    """Sockets UDP: uno para enviar al juego y otro para recibir telemetría."""

    def __init__(self, host: str, send_port: int, listen_port: int) -> None:
        self.target = (host, send_port)
        self.tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.rx.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.rx.bind(("0.0.0.0", listen_port))
        self.rx.setblocking(False)
        self.telemetry = wp.Telemetry()
        self.last_telemetry_time = 0.0
        self.vibration_until = 0.0
        self.vibration_intensity = 0
        self.packets_sent = 0
        self.packets_received = 0

    def send(self, state: WheelState, center: int, span: int) -> None:
        """Envía un mensaje W. `center` y `span` simulan un sensor sin calibrar."""
        raw_steer = (center + state.steer * span) / wp.STEER_SCALE
        packet = wp.format_wheel_packet(raw_steer, state.throttle, state.brake,
                                        state.buttons, state.encoder_pending)
        state.encoder_pending = 0
        try:
            self.tx.sendto(packet, self.target)
            self.packets_sent += 1
        except OSError:
            pass   # El juego todavía no está escuchando: se sigue intentando.

    def receive(self) -> list[wp.Vibration]:
        """Lee todo lo pendiente. Devuelve los eventos de vibración nuevos."""
        events: list[wp.Vibration] = []
        while True:
            try:
                data, _address = self.rx.recvfrom(1024)
            except (BlockingIOError, ConnectionResetError):
                break
            for line in data.decode("ascii", errors="ignore").splitlines():
                message = wp.parse_pc_message(line)
                if isinstance(message, wp.Telemetry):
                    self.telemetry = message
                    self.last_telemetry_time = time.monotonic()
                    self.packets_received += 1
                elif isinstance(message, wp.Vibration):
                    self.vibration_intensity = message.intensity
                    self.vibration_until = time.monotonic() + message.duration_ms / 1000.0
                    events.append(message)
                    self.packets_received += 1
        return events

    def is_connected(self) -> bool:
        return time.monotonic() - self.last_telemetry_time < wp.TIMEOUT_MS / 1000.0

    def is_vibrating(self) -> bool:
        return time.monotonic() < self.vibration_until


def move_toward(value: float, target: float, max_step: float) -> float:
    """Acerca `value` a `target` sin pasarse, como máximo `max_step`."""
    if abs(target - value) <= max_step:
        return target
    return value + math.copysign(max_step, target - value)


def print_status(link: Link, state: WheelState) -> None:
    """Imprime una línea con lo enviado y lo recibido."""
    telemetry = link.telemetry
    leds = wp.leds_for_rpm(telemetry.rpm_pct)
    bar = "#" * leds + "." * (wp.SHIFT_LED_COUNT - leds)
    status = "CONECTADO" if link.is_connected() else "sin telemetría"
    print(f"[{status}] tx: dir {state.steer:+.2f} acel {state.throttle:.2f} freno {state.brake:.2f} "
          f"bot {state.buttons:3d} | rx: rpm {telemetry.rpm_pct:3d}% [{bar}] "
          f"marcha {wp.gear_text(telemetry.gear)} estado: {wp.flags_text(telemetry.flags)}",
          flush=True)


# ==============================================================================
# Modo automático (sin ventana)
# ==============================================================================
def run_auto(link: Link, args: argparse.Namespace) -> None:
    """Mueve el volante con una onda senoidal y mantiene algo de acelerador."""
    state = WheelState()
    period = 1.0 / args.rate
    start = time.monotonic()
    next_print = start
    print("Modo automático. Ctrl+C para salir.")
    while True:
        now = time.monotonic()
        elapsed = now - start
        if args.duration > 0.0 and elapsed >= args.duration:
            break
        state.steer = math.sin(elapsed * 2.0 * math.pi / AUTO_STEER_PERIOD) * args.auto_steer
        state.throttle = args.auto_throttle
        state.brake = 0.0
        # Cada 5 s "aprieta" medio segundo el botón de cámara (prueba de botones).
        state.buttons = wp.BTN_CAMERA if (elapsed % 5.0) < 0.5 and args.auto_buttons else 0
        link.send(state, args.center, args.range)
        for event in link.receive():
            print(f"  >> VIBRACIÓN intensidad {event.intensity} durante {event.duration_ms} ms", flush=True)
        if now >= next_print:
            next_print = now + PRINT_INTERVAL
            print_status(link, state)
        time.sleep(period)
    print(f"Fin. Enviados: {link.packets_sent}, recibidos: {link.packets_received}")


# ==============================================================================
# Modo interactivo (ventana de pygame)
# ==============================================================================
def run_window(link: Link, args: argparse.Namespace) -> None:
    try:
        import pygame
    except ImportError:
        print("Falta pygame. Instalalo con:  pip install -r requirements.txt\n"
              "o usá el modo sin ventana:    python fake_wheel.py --auto")
        sys.exit(1)

    pygame.init()
    screen = pygame.display.set_mode(WINDOW_SIZE)
    pygame.display.set_caption("Volante simulado — Simulador F1")
    font = pygame.font.SysFont("consolas,dejavusansmono,monospace", 18)
    big_font = pygame.font.SysFont("consolas,dejavusansmono,monospace", 64, bold=True)
    clock = pygame.time.Clock()

    joystick = None
    if args.gamepad:
        pygame.joystick.init()
        if pygame.joystick.get_count() == 0:
            print("No se encontró ningún gamepad: se usa el teclado.")
        else:
            joystick = pygame.joystick.Joystick(0)
            joystick.init()
            print(f"Gamepad: {joystick.get_name()}")

    key_buttons = {
        pygame.K_e: wp.BTN_SHIFT_UP,
        pygame.K_q: wp.BTN_SHIFT_DOWN,
        pygame.K_f: wp.BTN_DRS,
        pygame.K_SPACE: wp.BTN_ERS,
        pygame.K_l: wp.BTN_PIT_LIMITER,
        pygame.K_r: wp.BTN_RESET,
        pygame.K_c: wp.BTN_CAMERA,
        pygame.K_p: wp.BTN_PAUSE,
    }
    # Botones del gamepad (numeración típica de un control tipo Xbox en SDL).
    pad_buttons = {
        5: wp.BTN_SHIFT_UP, 4: wp.BTN_SHIFT_DOWN, 3: wp.BTN_DRS, 0: wp.BTN_ERS,
        2: wp.BTN_PIT_LIMITER, 6: wp.BTN_RESET, 1: wp.BTN_CAMERA, 7: wp.BTN_PAUSE,
    }

    state = WheelState()
    next_print = 0.0
    running = True
    while running:
        delta = clock.tick(args.rate) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_PAGEUP:
                    state.encoder_pending += 1
                elif event.key == pygame.K_PAGEDOWN:
                    state.encoder_pending -= 1
            elif event.type == pygame.JOYHATMOTION and event.value[1] != 0:
                state.encoder_pending += event.value[1]

        keys = pygame.key.get_pressed()
        buttons = 0
        for key, bit in key_buttons.items():
            if keys[key]:
                buttons |= bit

        if joystick is not None:
            # Stick izquierdo = dirección; gatillos = pedales (van de -1 a 1).
            state.steer = joystick.get_axis(0)
            if joystick.get_numaxes() >= 6:
                state.throttle = (joystick.get_axis(5) + 1.0) / 2.0
                state.brake = (joystick.get_axis(4) + 1.0) / 2.0
            for index, bit in pad_buttons.items():
                if index < joystick.get_numbuttons() and joystick.get_button(index):
                    buttons |= bit
        else:
            target = 0.0
            if keys[pygame.K_a] or keys[pygame.K_LEFT]:
                target -= 1.0
            if keys[pygame.K_d] or keys[pygame.K_RIGHT]:
                target += 1.0
            rate = STEER_RETURN_RATE if target == 0.0 else STEER_RATE
            state.steer = move_toward(state.steer, target, rate * delta)
            accelerating = keys[pygame.K_w] or keys[pygame.K_UP]
            braking = keys[pygame.K_s] or keys[pygame.K_DOWN]
            state.throttle = move_toward(state.throttle, 1.0 if accelerating else 0.0,
                                         (PEDAL_RATE if accelerating else PEDAL_RELEASE_RATE) * delta)
            state.brake = move_toward(state.brake, 1.0 if braking else 0.0,
                                      (PEDAL_RATE if braking else PEDAL_RELEASE_RATE) * delta)
        state.buttons = buttons

        link.send(state, args.center, args.range)
        for event in link.receive():
            print(f"  >> VIBRACIÓN intensidad {event.intensity} durante {event.duration_ms} ms", flush=True)

        now = time.monotonic()
        if now >= next_print:
            next_print = now + PRINT_INTERVAL
            print_status(link, state)

        draw_window(pygame, screen, font, big_font, link, state)
        pygame.display.flip()

    pygame.quit()


def draw_window(pygame, screen, font, big_font, link: Link, state: WheelState) -> None:
    """Dibuja el "tablero" del volante: LEDs, marcha, ejes y estado."""
    telemetry = link.telemetry
    # El fondo se enrojece mientras dura una vibración.
    background = BACKGROUND
    if link.is_vibrating():
        strength = link.vibration_intensity / wp.VIBRATION_MAX
        background = (int(18 + 120 * strength), 22, 31)
    screen.fill(background)

    # Shift lights.
    lit = wp.leds_for_rpm(telemetry.rpm_pct)
    flashing = telemetry.rpm_pct >= wp.SHIFT_LED_FLASH_PCT
    flash_on = int(time.monotonic() * 18) % 2 == 0
    for i in range(wp.SHIFT_LED_COUNT):
        color = LED_OFF
        if flashing:
            color = wp.led_color(wp.SHIFT_LED_COUNT - 1) if flash_on else LED_OFF
        elif i < lit:
            color = wp.led_color(i)
        pygame.draw.circle(screen, color, (60 + i * 48, 40), 18)

    # Marcha y RPM.
    gear_surface = big_font.render(wp.gear_text(telemetry.gear), True, (255, 205, 50))
    screen.blit(gear_surface, (WINDOW_SIZE[0] // 2 - gear_surface.get_width() // 2, 70))
    screen.blit(font.render(f"RPM {telemetry.rpm_pct:3d} %", True, TEXT_COLOR), (30, 95))
    status_text = "CONECTADO" if link.is_connected() else "SIN TELEMETRÍA"
    status_color = (80, 255, 115) if link.is_connected() else (255, 90, 80)
    screen.blit(font.render(status_text, True, status_color), (390, 95))
    screen.blit(font.render("Estado: " + wp.flags_text(telemetry.flags), True, TEXT_COLOR), (30, 150))

    # Dirección: barra con un cursor.
    bar = pygame.Rect(30, 195, 500, 16)
    pygame.draw.rect(screen, LED_OFF, bar, border_radius=4)
    cursor_x = bar.centerx + int(state.steer * bar.width / 2)
    pygame.draw.rect(screen, (90, 160, 255), (cursor_x - 5, bar.y - 4, 10, bar.height + 8), border_radius=3)
    # Pedales.
    pygame.draw.rect(screen, LED_OFF, (30, 230, 240, 12), border_radius=4)
    pygame.draw.rect(screen, (255, 90, 80), (30, 230, int(240 * state.brake), 12), border_radius=4)
    pygame.draw.rect(screen, LED_OFF, (290, 230, 240, 12), border_radius=4)
    pygame.draw.rect(screen, (80, 255, 115), (290, 230, int(240 * state.throttle), 12), border_radius=4)
    screen.blit(font.render("freno", True, DIM_COLOR), (30, 246))
    screen.blit(font.render("acelerador", True, DIM_COLOR), (290, 246))

    pressed = [name for bit, name in wp.BUTTON_NAMES.items() if state.buttons & bit]
    screen.blit(font.render("Botones: " + (", ".join(pressed) if pressed else "-"), True, TEXT_COLOR), (30, 275))
    screen.blit(font.render(f"-> {link.target[0]}:{link.target[1]}   tx {link.packets_sent}  rx {link.packets_received}",
                            True, DIM_COLOR), (30, 300))


def main() -> None:
    parser = argparse.ArgumentParser(description="Volante simulado para el Simulador F1 (protocolo UDP).")
    parser.add_argument("--host", default="127.0.0.1", help="IP de la PC donde corre el juego")
    parser.add_argument("--port", type=int, default=wp.PORT_WHEEL_TO_PC, help="puerto del juego (W)")
    parser.add_argument("--listen-port", type=int, default=wp.PORT_PC_TO_WHEEL, help="puerto de telemetría (T/V)")
    parser.add_argument("--rate", type=float, default=wp.WHEEL_SEND_HZ, help="paquetes por segundo")
    parser.add_argument("--gamepad", action="store_true", help="usar un gamepad en lugar del teclado")
    parser.add_argument("--auto", action="store_true", help="sin ventana: mueve el volante solo")
    parser.add_argument("--duration", type=float, default=0.0, help="(--auto) segundos antes de salir; 0 = sin límite")
    parser.add_argument("--auto-steer", type=float, default=0.6, help="(--auto) amplitud de la dirección 0..1")
    parser.add_argument("--auto-throttle", type=float, default=0.5, help="(--auto) acelerador fijo 0..1")
    parser.add_argument("--auto-buttons", action="store_true", help="(--auto) pulsar el botón de cámara cada 5 s")
    parser.add_argument("--center", type=int, default=0, help="valor crudo del centro (simula sensor descentrado)")
    parser.add_argument("--range", type=int, default=wp.STEER_SCALE, help="valor crudo del recorrido a cada lado")
    args = parser.parse_args()

    link = Link(args.host, args.port, args.listen_port)
    print(f"Enviando a {args.host}:{args.port} a {args.rate:.0f} Hz; escuchando telemetría en el puerto {args.listen_port}")
    try:
        if args.auto:
            run_auto(link, args)
        else:
            run_window(link, args)
    except KeyboardInterrupt:
        print("\nInterrumpido.")


if __name__ == "__main__":
    main()
