// =============================================================================
// main.c — Banco de pruebas del robot PI7: menú de tests
// -----------------------------------------------------------------------------
// Qué hace : al arrancar no inicializa NINGÚN periférico de potencia: sólo la
//            consola. Muestra el menú y espera que se elija un test. El test
//            inicializa únicamente lo que usa. Para cambiar de test: 'reset'.
// Uso      : t01 ... t09            (generador de pasos por defecto del config)
//            t05 hw / t05 sw        (fuerza generador por hardware / software)
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pi7_comun.h"
#include "pi7_tests.h"

typedef struct {
  const char *nombre;
  void (*fn)(generador_t);
  const char *descripcion;
} test_t;

static const test_t TESTS[] = {
    {"t01", t01_ejecutar, "diagnóstico: chip, pines, bus I2C, imanes, finales      (no mueve nada)"},
    {"t02", t02_ejecutar, "finales de carrera: polaridad, rebote, cables cruzados  (no mueve nada)"},
    {"t03", t03_ejecutar, "servo SG90: recorrido y calibración de la compuerta     (mueve el servo)"},
    {"t04", t04_ejecutar, "encoders AS5600: imán, ruido, tiempo de lectura         (no mueve nada)"},
    {"t05", t05_ejecutar, "motores en lazo abierto: sentido, micropasos, rampas    (MUEVE MOTORES)"},
    {"t06", t06_ejecutar, "motor contra encoder: signo, micropasos reales, pasos perdidos (MUEVE)"},
    {"t07", t07_ejecutar, "motor contra final: parada, bloqueo, homing             (MUEVE MOTORES)"},
    {"t08", t08_ejecutar, "integración: todo junto, ensayo de quemado              (MUEVE TODO)"},
    {"t09", t09_ejecutar, "generador por hardware LEDC + PCNT: frecuencia, pulsos exactos (MUEVE)"},
};
static const int N_TESTS = sizeof(TESTS) / sizeof(TESTS[0]);

static void menu(void) {
  com_linea('-', 72);
  printf("MENÚ · escribí el test y Enter. Correas AFUERA para todo lo que mueve motores.\n");
  for (int i = 0; i < N_TESTS; i++) printf("  %s  %s\n", TESTS[i].nombre, TESTS[i].descripcion);
  printf("  Generador de pasos por defecto: %s. Agregá 'hw' o 'sw' para forzarlo (ej.: t05 hw).\n",
         GENERADOR_POR_DEFECTO == GEN_SOFTWARE ? "software" : "hardware");
  printf("  Dentro de cada test: '?' ayuda · 'x' para motores · 'reset' vuelve a este menú.\n");
  com_linea('-', 72);
}

void app_main(void) {
  com_iniciar_consola();
  vTaskDelay(pdMS_TO_TICKS(300) + 1);
  com_banner();
  menu();
  printf("#LISTO menu\n");
  char *tok[4];
  while (true) {
    com_latido();
    int n = com_leer_comando(tok, 4);
    if (n == 0) {
      vTaskDelay(10);
      continue;
    }
    if (!strcmp(tok[0], "reset")) com_reiniciar();
    generador_t g = GENERADOR_POR_DEFECTO;
    if (n >= 2 && !strcmp(tok[1], "hw")) g = GEN_HARDWARE;
    if (n >= 2 && !strcmp(tok[1], "sw")) g = GEN_SOFTWARE;
    bool hallado = false;
    for (int i = 0; i < N_TESTS; i++) {
      if (!strcmp(tok[0], TESTS[i].nombre)) {
        hallado = true;
        com_linea('=', 72);
        printf("%s · %s\n", TESTS[i].nombre, TESTS[i].descripcion);
        com_linea('=', 72);
        TESTS[i].fn(g);  // no vuelve
      }
    }
    if (!hallado) menu();
  }
}
