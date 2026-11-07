// =============================================================================
// t02_finales.c — T02 · Finales de carrera solos (no mueve nada)
// -----------------------------------------------------------------------------
// Qué hace : informa cada apretada/soltada con los flancos crudos que la
//            acompañaron. Con el filtro RC de la placa debería ser 1 por
//            transición: más de 1 = el flanco lento cruza el umbral varias veces
//            (por eso el firmware igual confirma 2 ms). 'calibrar' mide la
//            polaridad real, detecta pines flotantes y cables cruzados.
// Salidas  : NINGUNA.
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pi7_comun.h"
#include "pi7_finales.h"
#include "pi7_tests.h"

static bool previo[N_EJES];
static uint32_t flancos_previos[N_EJES];
static uint32_t t_mues = 0;
static uint32_t t_cambio[N_EJES];

// Sin motores, el muestreo a 1 kHz lo hace el propio test
static void servicio(void) {
  uint32_t t = com_us();
  if ((int32_t)(t - t_mues) >= 0) {
    t_mues = t + PERIODO_PERFIL_US;
    fin_muestrear();
  }
}

static void ayuda(void) {
  printf("T02 · comandos:\n");
  printf("  estado     nivel, estado y contadores\n");
  printf("  calibrar   polaridad de cada final y cables cruzados\n");
  printf("  plot       una línea cada 20 ms para graficar (cualquier tecla sale)\n");
  printf("  reset      volver al menú\n");
  printf("  cero       contadores a cero\n");
  printf("Cada apretada y soltada se informa sola.\n");
}

static void estado(void) {
  printf("  eje          GPIO  nivel  estado     activaciones  flancos crudos\n");
  for (int e = 0; e < N_EJES; e++)
    printf("  %d %-10s  %3d   %-5s  %-9s  %12lu  %14lu\n", e + 1, NOMBRE_EJE[e], PIN_FINAL[e],
           fin_nivel_crudo(e) ? "ALTO" : "BAJO", fin_activo(e) ? "APRETADO" : "suelto",
           (unsigned long)fin_activaciones(e), (unsigned long)fin_flancos_crudos(e));
}

static void informar(void) {
  for (int e = 0; e < N_EJES; e++) {
    bool a = fin_activo(e);
    if (a == previo[e]) continue;
    uint32_t fl = fin_flancos_crudos(e), extra = fl - flancos_previos[e];
    uint32_t dt = com_ms() - t_cambio[e];
    flancos_previos[e] = fl;
    previo[e] = a;
    t_cambio[e] = com_ms();
    printf("[t=%8.3f s] final %d (%s): %-9s nivel %s · flancos crudos: %lu%s · %lu ms desde el cambio anterior\n",
           com_s(), e + 1, NOMBRE_EJE[e], a ? "APRETADO" : "suelto", fin_nivel_crudo(e) ? "ALTO" : "BAJO",
           (unsigned long)extra, extra > 1 ? " (más de 1: el RC no alcanza solo)" : "", (unsigned long)dt);
  }
}

static void plot(void) {
  printf("t_s,F1,F2,F3,C1,C2,C3\n");
  com_vaciar_entrada();
  uint32_t t0 = 0;
  while (!com_hay_tecla()) {
    com_servicio();
    if (com_ms() - t0 >= 20) {
      t0 = com_ms();
      printf("%.3f,%d,%d,%d,%d,%d,%d\n", com_s(), fin_activo(0), fin_activo(1), fin_activo(2), fin_nivel_crudo(0),
             fin_nivel_crudo(1), fin_nivel_crudo(2));
    }
    vTaskDelay(1);
  }
}

static int esperar_cambio(const bool reposo[], uint32_t timeout_ms) {
  uint32_t t0 = com_ms(), tc[N_EJES] = {0};
  while (com_ms() - t0 < timeout_ms) {
    com_servicio();
    if (com_hay_tecla()) return -1;
    for (int e = 0; e < N_EJES; e++) {
      if (fin_nivel_crudo(e) != reposo[e]) {
        if (!tc[e]) tc[e] = com_ms();
        if (com_ms() - tc[e] >= 100) return e;
      } else tc[e] = 0;
    }
    vTaskDelay(1);
  }
  return -1;
}

static void calibrar(void) {
  bool reposo[N_EJES], activo_alto[N_EJES] = {0}, medido[N_EJES] = {0}, cruzado = false;
  printf("CALIBRAR · 1/2: no toques ningún final durante 3 s.\n");
  com_esperar(500, false);
  fin_reiniciar_contadores();
  for (int e = 0; e < N_EJES; e++) reposo[e] = fin_nivel_crudo(e);
  com_esperar(3000, false);
  for (int e = 0; e < N_EJES; e++) {
    uint32_t fl = fin_flancos_crudos(e);
    printf("  final %d: reposo %s, %lu flancos en 3 s %s\n", e + 1, reposo[e] ? "ALTO" : "BAJO", (unsigned long)fl,
           fl ? "→ PIN FLOTANTE O CON RUIDO: revisar módulo, 3,3 V y masa" : "(estable)");
  }
  printf("CALIBRAR · 2/2: apretá y MANTENÉ cada final cuando se pida (cualquier tecla saltea).\n");
  for (int e = 0; e < N_EJES; e++) {
    printf("  → Apretá el final del eje %d (%s). 20 s.\n", e + 1, NOMBRE_EJE[e]);
    int quien = esperar_cambio(reposo, 20000);
    if (quien < 0) { printf("    salteado.\n"); continue; }
    if (quien != e) {
      printf("    !! Cambió el pin del eje %d (GPIO%d), no el del eje %d: cables cruzados o PIN_FINAL mal asignado.\n",
             quien + 1, PIN_FINAL[quien], e + 1);
      cruzado = true;
    }
    activo_alto[quien] = !reposo[quien];
    medido[quien] = true;
    printf("    final %d apretado: nivel %s. Soltalo.\n", quien + 1, activo_alto[quien] ? "ALTO" : "BAJO");
    uint32_t t0 = com_ms();
    while (fin_nivel_crudo(quien) != reposo[quien] && com_ms() - t0 < 10000) com_esperar(5, false);
  }
  com_linea('-', 72);
  bool coincide = true;
  for (int e = 0; e < N_EJES; e++) {
    if (!medido[e]) { printf("  final %d: sin medir\n", e + 1); continue; }
    bool ok = activo_alto[e] == FINAL_ACTIVO_ALTO[e];
    coincide &= ok;
    printf("  final %d: apretado = %s · config = %s → %s\n", e + 1, activo_alto[e] ? "ALTO" : "BAJO",
           FINAL_ACTIVO_ALTO[e] ? "ALTO" : "BAJO", ok ? "COINCIDE" : "NO COINCIDE");
  }
  if (!coincide || cruzado) {
    printf("Pegá esto en pi7_config.h:\n  static const bool FINAL_ACTIVO_ALTO[N_EJES] = {%s, %s, %s};\n",
           (medido[0] ? activo_alto[0] : FINAL_ACTIVO_ALTO[0]) ? "true" : "false",
           (medido[1] ? activo_alto[1] : FINAL_ACTIVO_ALTO[1]) ? "true" : "false",
           (medido[2] ? activo_alto[2] : FINAL_ACTIVO_ALTO[2]) ? "true" : "false");
    if (cruzado) printf("  y corregí PIN_FINAL según lo informado.\n");
  } else {
    printf("Polaridad correcta. PASA.\n");
  }
  printf("Seguridad: si se corta el cable de señal, el pin queda como lo deje el capacitor/módulo.\n");
  printf("Probalo desconectando un módulo: si se ve 'suelto', sólo la guarda de recorrido frena el homing.\n");
  com_linea('-', 72);
  for (int e = 0; e < N_EJES; e++) {
    previo[e] = fin_activo(e);
    flancos_previos[e] = fin_flancos_crudos(e);
  }
}

void t02_ejecutar(generador_t g) {
  (void)g;
  com_uso_t uso = {false, true, false, false};
  if (!com_validar_pines(uso)) com_bloquear_por_error();
  fin_iniciar();
  com_fijar_servicio(servicio);
  for (int e = 0; e < N_EJES; e++) {
    previo[e] = fin_activo(e);
    flancos_previos[e] = 0;
    t_cambio[e] = com_ms();
  }
  estado();
  printf("Si sin tocar nada aparece alguno APRETADO, corré 'calibrar'.\n");
  ayuda();
  ay_listo("t02");
  char *tok[4];
  while (true) {
    com_servicio();
    informar();
    int n = com_leer_comando(tok, 4);
    if (n == 0) { vTaskDelay(1); continue; }
    if (ay_comando_comun(n, tok)) continue;
    if (!strcmp(tok[0], "estado")) estado();
    else if (!strcmp(tok[0], "calibrar")) calibrar();
    else if (!strcmp(tok[0], "plot")) plot();
    else if (!strcmp(tok[0], "cero")) {
      fin_reiniciar_contadores();
      for (int e = 0; e < N_EJES; e++) flancos_previos[e] = 0;
      printf("Contadores en cero.\n");
    } else ayuda();
  }
}
