// =============================================================================
// t03_servo.c — T03 · SG90 de la compuerta y calibración ψ ↔ µs
// -----------------------------------------------------------------------------
// Qué hace : mueve el SG90 por pulso con rampa, ajuste fino, soltar, barrer y
//            ciclar. 'marcar cerrado' / 'marcar abierto' registran los pulsos de
//            ψ = −3° y ψ = −30° e imprimen las líneas para el config.
// Salidas  : sólo el pin del servo.
// Seguridad: el PRIMER pulso es un salto. Primera vez: medio disco desmontado.
//            Tope mecánico en ψ = +3°: forzar contra él calienta el servo.
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pi7_comun.h"
#include "pi7_servo.h"
#include "pi7_tests.h"

static uint16_t marca_cerrado, marca_abierto;
static bool aviso_primer = false;

static void servicio(void) { srv_actualizar(); }

static void ayuda(void) {
  printf("T03 · comandos (pulso en µs, ψ en grados):\n");
  printf("  us <n>               ir a n µs (500–2500)\n");
  printf("  + [n] / - [n]        sumar/restar n µs (por defecto 10)\n");
  printf("  soltar               cortar pulsos (servo sin par)\n");
  printf("  rampa <µs/s>         velocidad de la rampa; 0 = salto\n");
  printf("  barrido <a> <b> [k]  ir y volver k veces\n");
  printf("  marcar cerrado       el pulso actual deja ψ = −3° (retiene)\n");
  printf("  marcar abierto       el pulso actual deja ψ = −30° (libera)\n");
  printf("  psi <grados>         ir a un ψ (requiere las dos marcas)\n");
  printf("  cerrar / abrir       ψ = −3° / −30°\n");
  printf("  ciclos <k>           abrir y cerrar k veces (resistencia y brownout)\n");
  printf("  estado · reset\n");
}

static bool hay_marcas(void) { return marca_cerrado > 0 && marca_abierto > 0; }
static float pendiente(void) {
  return ((float)marca_abierto - marca_cerrado) / (PSI_ABIERTO_DEG - PSI_CERRADO_DEG);
}
static uint16_t us_de_psi(float psi) {
  float us = marca_cerrado + pendiente() * (psi - PSI_CERRADO_DEG);
  if (us < SERVO_US_MIN) us = SERVO_US_MIN;
  if (us > SERVO_US_MAX) us = SERVO_US_MAX;
  return (uint16_t)us;
}
static float psi_de_us(uint16_t us) { return PSI_CERRADO_DEG + ((float)us - marca_cerrado) / pendiente(); }
static const char *zona(float psi) {
  if (psi > PSI_MAX_DEG) return "CONTRA EL TOPE (+3°)";
  if (psi >= -12.0f) return "retiene";
  if (psi > -16.0f) return "transición (no usar)";
  return "libera";
}

static void ir(int us) {
  if (us < SERVO_US_MIN) us = SERVO_US_MIN;
  if (us > SERVO_US_MAX) us = SERVO_US_MAX;
  if (!aviso_primer && !srv_activo()) {
    printf("  (primer pulso: el servo salta sin rampa)\n");
    aviso_primer = true;
  }
  srv_ir_us((uint16_t)us, true);
}

static void estado(void) {
  printf("  servo %s · actual %u µs · objetivo %u µs", srv_activo() ? "ACTIVO" : "suelto", srv_us_actual(),
         srv_us_objetivo());
  if (hay_marcas()) printf(" · ψ ≈ %.1f° (%s)", psi_de_us(srv_us_actual()), zona(psi_de_us(srv_us_actual())));
  printf("\n  marcas: cerrado = %u µs, abierto = %u µs\n", marca_cerrado, marca_abierto);
}

static bool esperar_servo(void) {
  while (srv_en_movimiento())
    if (!com_esperar(5, true)) return false;
  return true;
}

static void imprimir_calibracion(void) {
  if (!hay_marcas()) return;
  float m = pendiente();
  printf("Calibración: %.2f µs por grado de ψ.", m);
  // SG90 típico: ~180° con 500–2500 µs → ~11 µs/° (valor típico, no de hoja de datos)
  if (fabsf(m) < 7.0f || fabsf(m) > 16.0f) printf(" OJO: lejos de los ~11 µs/° típicos; revisar juego del horn o las marcas.");
  printf("\n  ψ = +2° (límite de retención) → %u µs ; ψ = −16° (empieza a liberar) → %u µs\n", us_de_psi(2.0f),
         us_de_psi(-16.0f));
  printf("Pegá esto en pi7_config.h:\n");
  printf("  static const uint16_t SERVO_US_PSI_CERRADO = %u;\n", marca_cerrado);
  printf("  static const uint16_t SERVO_US_PSI_ABIERTO = %u;\n", marca_abierto);
}

static void ir_psi(float psi) {
  if (!hay_marcas()) { printf("Falta calibrar: 'marcar cerrado' y 'marcar abierto'.\n"); return; }
  if (psi > PSI_MAX_DEG || psi < PSI_MIN_DEG) {
    printf("ψ fuera de [%.0f°, %.0f°]: rechazado (tope mecánico en +3°).\n", PSI_MIN_DEG, PSI_MAX_DEG);
    return;
  }
  printf("  ψ = %.1f° → %u µs (%s)\n", psi, us_de_psi(psi), zona(psi));
  ir(us_de_psi(psi));
}

void t03_ejecutar(generador_t g) {
  (void)g;
  com_uso_t uso = {false, false, false, true};
  if (!com_validar_pines(uso)) com_bloquear_por_error();
  srv_iniciar();
  marca_cerrado = SERVO_US_PSI_CERRADO;
  marca_abierto = SERVO_US_PSI_ABIERTO;
  com_fijar_servicio(servicio);
  printf("El servo arranca SUELTO. Primer comando sugerido: us 1500\n");
  if (srv_calibrado()) printf("Hay calibración en el config: 'cerrar' y 'abrir' disponibles.\n");
  ayuda();
  ay_listo("t03");
  char *tok[5];
  while (true) {
    com_servicio();
    int n = com_leer_comando(tok, 5);
    if (n == 0) { vTaskDelay(2); continue; }
    if (ay_comando_comun(n, tok)) continue;
    const char *c = tok[0];
    if (!strcmp(c, "us") && n >= 2) ir(atoi(tok[1]));
    else if (c[0] == '+' || c[0] == '-') {
      int d = c[1] ? atoi(c + 1) : (n >= 2 ? atoi(tok[1]) : 10);
      int base = srv_activo() ? srv_us_objetivo() : SERVO_US_INICIO;
      ir(base + (c[0] == '+' ? d : -d));
      estado();
    } else if (!strcmp(c, "soltar")) { srv_soltar(); printf("  servo suelto.\n"); }
    else if (!strcmp(c, "rampa") && n >= 2) { srv_fijar_rampa(atof(tok[1])); printf("  rampa = %s µs/s\n", tok[1]); }
    else if (!strcmp(c, "barrido") && n >= 3) {
      int a = atoi(tok[1]), b = atoi(tok[2]), k = n >= 4 ? atoi(tok[3]) : 3;
      printf("  barrido %d ↔ %d µs, %d veces. Cualquier tecla aborta.\n", a, b, k);
      for (int i = 0; i < k; i++) {
        ir(a);
        if (!esperar_servo() || !com_esperar(300, true)) break;
        ir(b);
        if (!esperar_servo() || !com_esperar(300, true)) break;
      }
    } else if (!strcmp(c, "marcar") && n >= 2) {
      if (!srv_activo()) printf("  El servo está suelto: primero llevalo a la posición.\n");
      else if (!strcmp(tok[1], "cerrado")) { marca_cerrado = srv_us_actual(); printf("  cerrado = %u µs\n", marca_cerrado); }
      else if (!strcmp(tok[1], "abierto")) { marca_abierto = srv_us_actual(); printf("  abierto = %u µs\n", marca_abierto); }
      imprimir_calibracion();
    } else if (!strcmp(c, "psi") && n >= 2) ir_psi(atof(tok[1]));
    else if (!strcmp(c, "cerrar")) ir_psi(PSI_CERRADO_DEG);
    else if (!strcmp(c, "abrir")) ir_psi(PSI_ABIERTO_DEG);
    else if (!strcmp(c, "ciclos") && n >= 2) {
      if (!hay_marcas()) { printf("Falta calibrar.\n"); continue; }
      int k = atoi(tok[1]);
      printf("  %d ciclos abrir/cerrar. Cualquier tecla aborta.\n", k);
      for (int i = 0; i < k; i++) {
        ir_psi(PSI_ABIERTO_DEG);
        if (!esperar_servo() || !com_esperar(400, true)) break;
        ir_psi(PSI_CERRADO_DEG);
        if (!esperar_servo() || !com_esperar(400, true)) break;
        printf("  ciclo %d/%d\n", i + 1, k);
      }
    } else if (!strcmp(c, "estado")) estado();
    else ayuda();
  }
}
