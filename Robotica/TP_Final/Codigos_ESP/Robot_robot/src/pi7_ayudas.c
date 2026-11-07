// =============================================================================
// pi7_ayudas.c — Ayudas compartidas por los tests. Ver pi7_tests.h.
// Autor: Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include "pi7_tests.h"
#include "pi7_comun.h"
#include "pi7_motores.h"

bool ay_esperar_quieto(uint32_t timeout_ms) {
  uint32_t t0 = com_ms();
  while (mot_alguno_en_movimiento()) {
    if (!com_esperar(1, true)) {
      mot_parar_todo();
      return false;
    }
    if (com_ms() - t0 > timeout_ms) {
      mot_parar_todo();
      printf("  timeout esperando el fin del movimiento\n");
      return false;
    }
  }
  return true;
}

void ay_vaciar_eventos(void) {
  mot_evento_t ev;
  while (mot_leer_evento(&ev)) {
  }
}

void ay_informar_eventos(void) {
  mot_evento_t ev;
  while (mot_leer_evento(&ev))
    printf("[t=%7.3f s] FINAL %d activado · en movimiento: %s%s%s · detenidos: %s%s%s\n", com_s(), ev.final_eje + 1,
           (ev.ejes_en_movimiento & 1) ? "1 " : "", (ev.ejes_en_movimiento & 2) ? "2 " : "",
           (ev.ejes_en_movimiento & 4) ? "3" : "", (ev.ejes_detenidos & 1) ? "1 " : "",
           (ev.ejes_detenidos & 2) ? "2 " : "", (ev.ejes_detenidos & 4) ? "3" : "");
}

bool ay_comando_comun(int n, char *tok[]) {
  if (n <= 0) return false;
  if (!strcmp(tok[0], "reset") || !strcmp(tok[0], "salir")) com_reiniciar();
  if (!strcmp(tok[0], "x")) {
    mot_parar_todo();
    printf("PARADA INMEDIATA de los tres ejes.\n");
    return true;
  }
  return false;
}

void ay_listo(const char *test) { printf("#LISTO %s\n", test); }
