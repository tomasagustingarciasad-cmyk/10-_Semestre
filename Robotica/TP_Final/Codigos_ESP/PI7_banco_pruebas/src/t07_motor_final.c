// =============================================================================
// t07_motor_final.c — T07 · Motor + final de carrera (SIN CORREAS, con el dedo)
// -----------------------------------------------------------------------------
//   parada <eje>   gira hacia su final; apretalo: tiene que parar. Política
//                  "cualquier final detiene todo": si dispara otro, cables cruzados.
//                  Mide la latencia flanco → parada (incluye el RC de la placa).
//   bloqueo <eje>  con el final apretado no avanza hacia él y sí se aleja.
//   homing <eje>   homing de un eje: rápida → retroceso → lenta → fijar home.
//   homing23       hombro y codo juntos a la misma velocidad articular hasta que
//                  dispara uno; el otro sigue solo (si el codo va solo con el
//                  hombro bajo, la biela del codo choca con el eje del hombro).
//   ruido [s]      motores girando sin tocar nada: disparos falsos.
// La lógica de homing está lista para reusarse con correa (con_dedo = false).
// Autor : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pi7_comun.h"
#include "pi7_finales.h"
#include "pi7_motores.h"
#include "pi7_tests.h"

// Latencia medida desde el primer flanco en el GPIO (ya pasado el RC): confirmación
// de 2 ms + un ciclo de perfil. El retardo del RC (~14 ms) se suma antes y no se ve acá.
static const uint32_t LATENCIA_MAX_US = 10000;

typedef enum { DISPARO, GUARDA, ABORTO, OTRO_FINAL, TIEMPO } espera_t;

static void servicio(void) {}

static float grados_art(int e, int32_t pasos) { return pasos / pasos_grado_art(e); }

static espera_t esperar_final(int e, float recorrido_max, uint32_t timeout_ms, mot_evento_t *ev) {
  int32_t p0 = mot_posicion(e), guarda = (int32_t)(recorrido_max * pasos_grado_art(e));
  uint32_t t0 = com_ms();
  while (true) {
    com_servicio();
    if (mot_leer_evento(ev)) {
      if (ev->final_eje == e) return DISPARO;
      mot_parar_todo();
      return OTRO_FINAL;
    }
    if (labs(mot_posicion(e) - p0) > guarda) { mot_parar_todo(); return GUARDA; }
    if (com_ms() - t0 > timeout_ms) { mot_parar_todo(); return TIEMPO; }
    if (com_hay_tecla()) { mot_parar_todo(); return ABORTO; }
    vTaskDelay(1);
  }
}

static void explicar(espera_t r, int e, const mot_evento_t *ev, float recorrido) {
  if (r == GUARDA) printf("  FALLA: recorrió %.1f° sin disparo. Final roto, cable cortado o polaridad invertida.\n", recorrido);
  else if (r == OTRO_FINAL) printf("  FALLA: disparó el final del eje %d buscando el del eje %d. Cables cruzados.\n", ev->final_eje + 1, e + 1);
  else if (r == TIEMPO) printf("  FALLA: se agotó el tiempo.\n");
  else if (r == ABORTO) printf("  abortado.\n");
}

static void ayuda(void) {
  printf("T07 · generador %s\n", mot_nombre_generador());
  printf("  parada <eje>   gira hacia el final; apretalo con el dedo\n");
  printf("  bloqueo <eje>  con el final apretado: no avanza hacia él, sí se aleja\n");
  printf("  homing <eje>   homing de un eje, con el dedo\n");
  printf("  homing23       homing conjunto hombro + codo, con el dedo\n");
  printf("  ruido [s]      motores girando sin tocar nada (por defecto 20 s)\n");
  printf("  estado · x · reset\n");
}

static void estado(void) {
  for (int e = 0; e < N_EJES; e++)
    printf("  eje %d %-10s %8.2f° art. · final %s (activaciones %lu, flancos %lu)\n", e + 1, NOMBRE_EJE[e],
           mot_grados_art(e), fin_activo(e) ? "APRETADO" : "suelto", (unsigned long)fin_activaciones(e),
           (unsigned long)fin_flancos_crudos(e));
}

static void esperar_suelto(int e, uint32_t ms) {
  uint32_t t0 = com_ms();
  while (fin_activo(e) && com_ms() - t0 < ms) com_esperar(5, false);
}

static void parada(int e) {
  if (fin_activo(e)) { printf("El final ya está apretado. Soltalo y repetí.\n"); return; }
  mot_fijar_politica(FINAL_DETIENE_TODO);
  ay_vaciar_eventos();
  printf("PARADA · eje %d gira hacia su final a %.1f °/s art. APRETÁ el final del eje %d (30 s).\n", e + 1,
         HOMING_VEL_RAPIDA_DEG_S, e + 1);
  mot_jog(e, SENTIDO_FINAL[e] * HOMING_VEL_RAPIDA_DEG_S * pasos_grado_art(e));
  mot_evento_t ev;
  espera_t r = esperar_final(e, 1e6f, 30000, &ev);
  if (r == DISPARO) {
    uint32_t lat = ev.t_deteccion_us - ev.t_flanco_us;
    bool valida = lat < 1000000;
    float despl = fabsf(ev.vel[e]) / pasos_grado_art(e) * lat * 1e-6f;
    printf("  Paró el eje %d. Latencia primer flanco → parada: %lu µs (%.3f° art. recorridos)\n", e + 1,
           (unsigned long)lat, despl);
    printf("  (al primer flanco crudo hay que sumarle el retardo del RC desde la palanca: ~14 ms)\n");
    printf((ev.ejes_detenidos & (1 << e)) && valida && lat < LATENCIA_MAX_US ? "  PASA.\n" : "  NO PASA.\n");
  } else explicar(r, e, &ev, 0);
  ay_esperar_quieto(10000);
  printf("  Soltá el final.\n");
  esperar_suelto(e, 15000);
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
}

static void bloqueo(int e) {
  int8_t s = SENTIDO_FINAL[e];
  float ppa = pasos_grado_art(e);
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  printf("BLOQUEO · apretá y MANTENÉ el final del eje %d (20 s)...\n", e + 1);
  uint32_t t0 = com_ms();
  while (!fin_activo(e) && com_ms() - t0 < 20000) com_esperar(5, false);
  if (!fin_activo(e)) { printf("  No se detectó el final apretado.\n"); return; }
  ay_vaciar_eventos();
  int32_t p0 = mot_posicion(e);
  mot_jog(e, s * 5.0f * ppa);
  com_esperar(500, false);
  mot_parar_ya(e);
  int32_t d = mot_posicion(e) - p0;
  printf("  Hacia el final: %ld upasos → %s\n", (long)d, labs(d) <= 2 ? "PASA (bloqueado)" : "NO PASA");
  p0 = mot_posicion(e);
  mot_jog(e, -s * 5.0f * ppa);
  com_esperar(500, false);
  mot_detener(e);
  ay_esperar_quieto(10000);
  d = mot_posicion(e) - p0;
  printf("  Alejándose: %.2f° art. → %s\n", grados_art(e, d), d * s < -(int32_t)ppa ? "PASA" : "NO PASA");
  printf("  Soltá el final.\n");
}

static bool salir_del_final(int e, bool con_dedo) {
  if (!fin_activo(e)) return true;
  int8_t s = SENTIDO_FINAL[e];
  printf("  [eje %d] arranca con el final apretado: se aleja%s\n", e + 1, con_dedo ? " (soltalo)" : "");
  mot_jog(e, -s * HOMING_VEL_LENTA_DEG_S * pasos_grado_art(e));
  esperar_suelto(e, 15000);
  mot_detener(e);
  ay_esperar_quieto(10000);
  if (fin_activo(e)) { printf("  FALLA: no se liberó.\n"); return false; }
  mot_mover_rel_grados_art(e, -s * HOMING_RETROCESO_DEG);
  return ay_esperar_quieto(30000);
}

static bool fase_fina(int e, bool con_dedo, int32_t *p_disparo) {
  int8_t s = SENTIDO_FINAL[e];
  mot_evento_t ev;
  printf("  [eje %d] retroceso de %.1f°%s\n", e + 1, HOMING_RETROCESO_DEG, con_dedo ? ": SOLTÁ el final" : "");
  mot_mover_rel_grados_art(e, -s * HOMING_RETROCESO_DEG);
  if (!ay_esperar_quieto(30000)) return false;
  esperar_suelto(e, con_dedo ? 10000 : 500);
  if (fin_activo(e)) { printf("  FALLA: el final no se liberó al retroceder (palanca trabada o señal en corto).\n"); return false; }
  ay_vaciar_eventos();
  float guarda = con_dedo ? 30.0f : 2.0f * HOMING_RETROCESO_DEG;
  printf("  [eje %d] pasada lenta a %.1f °/s%s\n", e + 1, HOMING_VEL_LENTA_DEG_S, con_dedo ? ": APRETÁ el final de nuevo" : "");
  mot_jog(e, s * HOMING_VEL_LENTA_DEG_S * pasos_grado_art(e));
  espera_t r = esperar_final(e, guarda, con_dedo ? 30000 : 20000, &ev);
  if (r != DISPARO) { explicar(r, e, &ev, guarda); return false; }
  ay_esperar_quieto(10000);
  *p_disparo = ev.pos[e];
  return true;
}

static void fijar_home(int e, int32_t p_disparo) {
  int32_t p_home = (int32_t)lroundf(HOME_ACT_DEG[e] * pasos_grado_art(e));
  mot_fijar_posicion(e, mot_posicion(e) + (p_home - p_disparo));
  printf("  [eje %d] home fijado: el disparo lento = %.2f° art. Posición actual %.2f°.\n", e + 1, HOME_ACT_DEG[e],
         mot_grados_art(e));
}

static bool homing_eje(int e, bool con_dedo) {
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  ay_vaciar_eventos();
  com_linea('=', 72);
  printf("HOMING · eje %d (%s). Cualquier tecla aborta.\n", e + 1, NOMBRE_EJE[e]);
  if (!salir_del_final(e, con_dedo)) return false;
  ay_vaciar_eventos();
  printf("  [eje %d] pasada rápida a %.1f °/s (guarda %.0f°)%s\n", e + 1, HOMING_VEL_RAPIDA_DEG_S,
         HOMING_RECORRIDO_MAX_DEG[e], con_dedo ? ": APRETÁ el final cuando quieras" : "");
  mot_jog(e, SENTIDO_FINAL[e] * HOMING_VEL_RAPIDA_DEG_S * pasos_grado_art(e));
  mot_evento_t ev;
  espera_t r = esperar_final(e, HOMING_RECORRIDO_MAX_DEG[e], 120000, &ev);
  if (r != DISPARO) { explicar(r, e, &ev, HOMING_RECORRIDO_MAX_DEG[e]); return false; }
  ay_esperar_quieto(10000);
  int32_t p1 = ev.pos[e], p2;
  if (!fase_fina(e, con_dedo, &p2)) return false;
  printf("  [eje %d] disparo rápido vs lento: %.3f° (con correa: repetibilidad + efecto del retardo del RC)\n", e + 1,
         grados_art(e, p2 - p1));
  fijar_home(e, p2);
  printf("HOMING PASA.\n");
  return true;
}

static bool homing23(bool con_dedo) {
  const int H = 1, C = 2;
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  com_linea('=', 72);
  printf("HOMING CONJUNTO · hombro (eje 2) + codo (eje 3). Cualquier tecla aborta.\n");
  if (!salir_del_final(H, con_dedo) || !salir_del_final(C, con_dedo)) return false;
  ay_vaciar_eventos();
  float v = HOMING_VEL_RAPIDA_DEG_S;
  printf("  pasada rápida conjunta a %.1f °/s%s\n", v,
         con_dedo ? ": apretá UNO de los dos finales; el otro motor tiene que seguir girando" : "");
  int32_t p_ini[2] = {mot_posicion(H), mot_posicion(C)};
  mot_jog(H, SENTIDO_FINAL[H] * v * pasos_grado_art(H));
  mot_jog(C, SENTIDO_FINAL[C] * v * pasos_grado_art(C));
  bool listo[2] = {false, false};
  uint32_t t0 = com_ms();
  while (!(listo[0] && listo[1])) {
    com_servicio();
    mot_evento_t ev;
    while (mot_leer_evento(&ev)) {
      if (ev.final_eje == H && !listo[0]) {
        listo[0] = true;
        printf("  disparó el HOMBRO. Codo %s.\n", mot_en_movimiento(C) ? "sigue girando: correcto" : "detenido");
        if (con_dedo && !listo[1]) printf("  ahora apretá el del CODO\n");
      } else if (ev.final_eje == C && !listo[1]) {
        listo[1] = true;
        printf("  disparó el CODO. Hombro %s.\n", mot_en_movimiento(H) ? "sigue girando: correcto" : "detenido");
        if (con_dedo && !listo[0]) printf("  ahora apretá el del HOMBRO\n");
      } else if (ev.final_eje == 0) {
        mot_parar_todo();
        printf("  FALLA: disparó el final de la base durante el homing de hombro y codo. Cables cruzados.\n");
        return false;
      }
    }
    for (int k = 0; k < 2; k++) {
      int e = k ? C : H;
      if (!listo[k] && labs(mot_posicion(e) - p_ini[k]) > HOMING_RECORRIDO_MAX_DEG[e] * pasos_grado_art(e)) {
        mot_parar_todo();
        printf("  FALLA: el eje %d recorrió %.0f° sin disparo.\n", e + 1, HOMING_RECORRIDO_MAX_DEG[e]);
        return false;
      }
    }
    if (com_hay_tecla() || com_ms() - t0 > 120000) { mot_parar_todo(); printf("  abortado.\n"); return false; }
    vTaskDelay(1);
  }
  ay_esperar_quieto(10000);
  int32_t p2;
  // Retroceso de a uno: cada uno cambia el ángulo relativo del codo en 4°, lejos de sus límites.
  if (!fase_fina(H, con_dedo, &p2)) return false;
  fijar_home(H, p2);
  if (!fase_fina(C, con_dedo, &p2)) return false;
  fijar_home(C, p2);
  printf("HOMING CONJUNTO PASA.\n");
  return true;
}

static void ruido(uint32_t seg) {
  if (seg == 0) seg = 20;
  mot_fijar_politica(FINAL_IGNORAR);
  fin_reiniciar_contadores();
  ay_vaciar_eventos();
  printf("RUIDO · %lu s con los tres motores girando. NO toques los finales. Cualquier tecla aborta.\n", (unsigned long)seg);
  uint32_t t0 = com_ms(), t_cambio = 0;
  int s = 1;
  while (com_ms() - t0 < seg * 1000) {
    if (com_ms() - t_cambio > 2000) {
      t_cambio = com_ms();
      for (int e = 0; e < N_EJES; e++) mot_jog(e, s * VEL_TEST_DEG_S[e] * pasos_grado_art(e));
      s = -s;
    }
    if (!com_esperar(5, true)) break;
  }
  for (int e = 0; e < N_EJES; e++) mot_detener(e);
  ay_esperar_quieto(10000);
  ay_vaciar_eventos();
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  bool ok = true;
  for (int e = 0; e < N_EJES; e++) {
    ok &= fin_activaciones(e) == 0;
    printf("  final %d: %lu activaciones, %lu flancos crudos\n", e + 1, (unsigned long)fin_activaciones(e),
           (unsigned long)fin_flancos_crudos(e));
  }
  printf(ok ? "  PASA: ningún disparo falso.\n"
            : "  NO PASA: disparos falsos. Separar cables de motor y de finales, trenzar señal con GND, subir FINAL_FILTRO_MUESTRAS.\n");
}

void t07_ejecutar(generador_t g) {
  com_uso_t uso = {true, true, false, false};
  if (!com_validar_pines(uso)) com_bloquear_por_error();
  fin_iniciar();
  mot_iniciar(g, true);
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  com_fijar_servicio(servicio);
  estado();
  ayuda();
  ay_listo("t07");
  char *tok[4];
  while (true) {
    com_servicio();
    int n = com_leer_comando(tok, 4);
    if (n == 0) { vTaskDelay(2); continue; }
    if (ay_comando_comun(n, tok)) continue;
    const char *c = tok[0];
    if (!strcmp(c, "estado")) estado();
    else if (!strcmp(c, "homing23")) homing23(true);
    else if (!strcmp(c, "ruido")) ruido(n >= 2 ? atoi(tok[1]) : 20);
    else if (!strcmp(c, "parada") || !strcmp(c, "bloqueo") || !strcmp(c, "homing")) {
      int e = com_eje_desde_texto(n >= 2 ? tok[1] : NULL);
      if (e < 0) continue;
      if (c[0] == 'p') parada(e);
      else if (c[0] == 'b') bloqueo(e);
      else homing_eje(e, true);
    } else ayuda();
  }
}
