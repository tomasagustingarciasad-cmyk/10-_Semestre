// =============================================================================
// t05_motores.c — T05 · Motores en lazo abierto (SIN CORREAS)
// -----------------------------------------------------------------------------
// Qué hace : mueve cada NEMA 17 con rampas, en grados articulares, de motor o en
//            micropasos. 'sentido' verifica el giro contra la convención del
//            robot; 'vuelta' los micropasos a ojo con una marca en la polea.
//            No usa encoders: sirve aunque el I2C esté roto.
// Salidas  : STEP y DIR. Finales: bloquean el avance de su eje hacia el final.
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pi7_comun.h"
#include "pi7_finales.h"
#include "pi7_motores.h"
#include "pi7_tests.h"

static int eje = 0;
static bool moviendo_previo[N_EJES];

static const char *const SENTIDO_POSITIVO[N_EJES] = {
    "la polea del motor de la base gira ANTIHORARIO vista DESDE ARRIBA",
    "la polea gira en el sentido en que la rueda del hombro LEVANTARÍA el brazo",
    "la polea gira en el sentido en que la rueda del codo LEVANTARÍA el antebrazo"};

static void servicio(void) {
  ay_informar_eventos();
  for (int e = 0; e < N_EJES; e++) {
    bool m = mot_en_movimiento(e);
    if (moviendo_previo[e] && !m)
      printf("  [eje %d] detenido en %.2f° art. (%.1f° motor, %ld upasos)\n", e + 1, mot_grados_art(e),
             mot_grados_motor(e), (long)mot_posicion(e));
    moviendo_previo[e] = m;
  }
}

static void ayuda(void) {
  printf("T05 · eje activo %d (%s) · generador %s\n", eje + 1, NOMBRE_EJE[eje], mot_nombre_generador());
  printf("  eje <1|2|3>         elegir eje\n");
  printf("  m <°art>            mover relativo en grados ARTICULARES (el motor gira ×4,5)\n");
  printf("  mm <°motor>         mover relativo en grados de MOTOR\n");
  printf("  p <upasos>          mover relativo en micropasos\n");
  printf("  vuelta [n]          n vueltas exactas de motor (marca en la polea)\n");
  printf("  ida <°art> [k]      ir y volver k veces\n");
  printf("  jog <°art/s>        girar continuo; 's' frena con rampa\n");
  printf("  s · x               frenar con rampa (eje activo) · PARAR TODO\n");
  printf("  v <°art/s> | a <°art/s²>   límites del eje activo\n");
  printf("  sentido             verificación guiada del sentido +\n");
  printf("  todos <°art>        los tres ejes juntos, ida y vuelta\n");
  printf("  politica <0|1|2>    finales: 0 ignorar, 1 bloquean su eje, 2 detienen todo\n");
  printf("  carga               %% de CPU de la ISR de pasos (generador software)\n");
  printf("  estado · reset\n");
}

static void estado(void) {
  printf("  eje          pos[°art]  pos[°mot]   upasos   v[°art/s]  vmax  acel   final\n");
  for (int e = 0; e < N_EJES; e++) {
    float ppa = pasos_grado_art(e);
    printf("  %d %-10s %9.2f  %9.1f  %8ld  %9.2f  %4.0f  %5.0f  %s\n", e + 1, NOMBRE_EJE[e], mot_grados_art(e),
           mot_grados_motor(e), (long)mot_posicion(e), mot_velocidad(e) / ppa, mot_vel_max(e) / ppa,
           mot_acel(e) / ppa, fin_activo(e) ? "APRETADO" : "suelto");
  }
  printf("  política %d · perfil máx. %lu µs\n", (int)mot_politica(), (unsigned long)mot_perfil_max_us());
}

static void sentido(void) {
  int e = eje;
  printf("SENTIDO · eje %d (%s)\n  Sentido + esperado: %s.\n", e + 1, NOMBRE_EJE[e], SENTIDO_POSITIVO[e]);
  printf("  Polea y rueda giran para el mismo lado (correa abierta, ejes paralelos, vistas del mismo lado).\n");
  printf("  Mueve +30° articulares (= +135° de motor) despacio...\n");
  float v = mot_vel_max(e), a = mot_acel(e);
  mot_fijar_limites_art(e, 15.0f, 60.0f);
  com_esperar(1500, false);
  mot_mover_rel_grados_art(e, 30.0f);
  if (!ay_esperar_quieto(30000)) return;
  char r = com_preguntar("¿Giró en el sentido + esperado? (s/n)", 60000);
  mot_mover_rel_grados_art(e, -30.0f);
  ay_esperar_quieto(30000);
  mot_fijar_vel_max(e, v);
  mot_fijar_acel(e, a);
  if (r == 's') printf("  PASA: DIR_INVERTIDA[%d] = %s es correcto.\n", e, DIR_INVERTIDA[e] ? "true" : "false");
  else if (r == 'n') {
    bool nv[N_EJES];
    for (int i = 0; i < N_EJES; i++) nv[i] = DIR_INVERTIDA[i];
    nv[e] = !nv[e];
    printf("  Pegá esto en pi7_config.h (y repetí con los otros ejes):\n");
    printf("  static const bool DIR_INVERTIDA[N_EJES] = {%s, %s, %s};\n", nv[0] ? "true" : "false",
           nv[1] ? "true" : "false", nv[2] ? "true" : "false");
    printf("  Si se movió OTRO motor y no el del eje %d: los cables STEP/DIR están cruzados entre drivers.\n", e + 1);
  }
}

static void vuelta(int k) {
  if (k == 0) k = 1;
  printf("Marcá un diente de la polea del eje %d. %d vuelta(s) = %.0f upasos con MICROPASOS = %u.\n", eje + 1, k,
         k * pasos_rev_motor(eje), MICROPASOS[eje]);
  printf("Si la marca no vuelve al lugar: media vuelta → el DIP tiene el doble · dos vueltas → la mitad.\n");
  com_esperar(1500, false);
  mot_mover_rel_grados_motor(eje, 360.0f * k);
  ay_esperar_quieto(120000);
}

static void ida(float deg, int k) {
  if (k <= 0) k = 3;
  printf("Ida y vuelta de ±%.1f° art., %d veces. Cualquier tecla aborta.\n", deg, k);
  for (int i = 0; i < k; i++) {
    mot_mover_rel_grados_art(eje, deg);
    if (!ay_esperar_quieto(60000)) return;
    mot_mover_rel_grados_art(eje, -deg);
    if (!ay_esperar_quieto(60000)) return;
  }
}

static void todos(float deg) {
  printf("Los tres ejes +%.1f° y vuelta.\n", deg);
  for (int e = 0; e < N_EJES; e++) mot_mover_rel_grados_art(e, deg);
  if (!ay_esperar_quieto(60000)) return;
  for (int e = 0; e < N_EJES; e++) mot_mover_rel_grados_art(e, -deg);
  ay_esperar_quieto(60000);
}

void t05_ejecutar(generador_t g) {
  com_uso_t uso = {true, true, false, false};
  if (!com_validar_pines(uso)) com_bloquear_por_error();
  fin_iniciar();
  mot_iniciar(g, true);
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  com_fijar_servicio(servicio);
  estado();
  ayuda();
  ay_listo("t05");
  char *tok[4];
  while (true) {
    com_servicio();
    int n = com_leer_comando(tok, 4);
    if (n == 0) { vTaskDelay(2); continue; }
    if (ay_comando_comun(n, tok)) continue;
    const char *c = tok[0];
    float x = n >= 2 ? atof(tok[1]) : 0;
    float ppa = pasos_grado_art(eje);
    if (!strcmp(c, "eje")) {
      int e = com_eje_desde_texto(n >= 2 ? tok[1] : NULL);
      if (e >= 0) eje = e;
      printf("Eje activo: %d (%s)\n", eje + 1, NOMBRE_EJE[eje]);
    } else if (!strcmp(c, "m") && n >= 2) mot_mover_rel_grados_art(eje, x);
    else if (!strcmp(c, "mm") && n >= 2) mot_mover_rel_grados_motor(eje, x);
    else if (!strcmp(c, "p") && n >= 2) mot_mover_rel(eje, atol(tok[1]));
    else if (!strcmp(c, "vuelta")) vuelta(n >= 2 ? atoi(tok[1]) : 1);
    else if (!strcmp(c, "ida") && n >= 2) ida(x, n >= 3 ? atoi(tok[2]) : 3);
    else if (!strcmp(c, "jog") && n >= 2) mot_jog(eje, x * ppa);
    else if (!strcmp(c, "s")) mot_detener(eje);
    else if (!strcmp(c, "v") && n >= 2) { mot_fijar_vel_max(eje, x * ppa); printf("vmax = %.1f °art/s\n", mot_vel_max(eje) / ppa); }
    else if (!strcmp(c, "a") && n >= 2) { mot_fijar_acel(eje, x * ppa); printf("acel = %.1f °art/s²\n", mot_acel(eje) / ppa); }
    else if (!strcmp(c, "sentido")) sentido();
    else if (!strcmp(c, "todos") && n >= 2) todos(x);
    else if (!strcmp(c, "politica") && n >= 2) {
      int p = atoi(tok[1]);
      mot_fijar_politica(p <= 0 ? FINAL_IGNORAR : p == 1 ? FINAL_BLOQUEA_SU_EJE : FINAL_DETIENE_TODO);
      printf("Política = %d\n", (int)mot_politica());
    } else if (!strcmp(c, "carga")) {
      mot_carga_isr();
      com_esperar(2000, false);
      printf("Carga de la ISR de pasos: %.1f %% de un núcleo (%s)\n", mot_carga_isr(),
             mot_generador() == GEN_SOFTWARE ? "software, núcleo 1" : "hardware: no usa ISR por paso");
    } else if (!strcmp(c, "estado")) estado();
    else ayuda();
  }
}
