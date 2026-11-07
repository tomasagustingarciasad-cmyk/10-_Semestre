// =============================================================================
// t04_encoders.c — T04 · Encoders AS5600 solos (no mueve nada)
// -----------------------------------------------------------------------------
// Qué hace : lee los tres AS5600 lo más rápido posible (para no perder vueltas),
//            muestra crudo / acumulado / vueltas / grados, estado del imán, ruido
//            en reposo, tiempo de lectura (fija la frecuencia máxima del lazo),
//            conteo de una vuelta a mano y cambia la frecuencia del I2C en caliente.
// Salidas  : NINGUNA. ENA no está cableado: para girar los motores a mano hay que
//            CORTAR LOS 24 V de los DM556 (si no, mantienen el par de retención).
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pi7_comun.h"
#include "pi7_encoders.h"
#include "pi7_tests.h"

static void servicio(void) { enc_actualizar_todos(); }

static void ayuda(void) {
  printf("T04 · comandos:\n");
  printf("  estado           crudo, acumulado, vueltas, grados, errores\n");
  printf("  diag             estado del imán de cada encoder\n");
  printf("  monitor [hz]     una línea por muestra (por defecto 10 Hz)\n");
  printf("  cero             acumulados a cero\n");
  printf("  vuelta <eje>     girá a mano UNA vuelta de motor y volvé a la marca\n");
  printf("  ruido <eje> [n]  n lecturas quieto: media, desvío, pico a pico\n");
  printf("  tiempo [n]       n ciclos de lectura de los tres: µs y errores\n");
  printf("  frec <hz>        frecuencia del I2C (100000 / 400000)\n");
  printf("  i2c · reset      (cualquier tecla corta 'monitor')\n");
}

static void estado(void) {
  printf("  eje          crudo  acumulado  vueltas   ° motor    ° art.  lecturas errores saltos t_lect[µs]\n");
  for (int e = 0; e < N_EJES; e++) {
    int32_t c = enc_cuentas(e);
    printf("  %d %-10s  %4u  %9ld  %7.3f  %8.2f  %8.3f  %8lu %7lu %6lu %4lu/%lu\n", e + 1, NOMBRE_EJE[e],
           enc_ultimo_crudo(e), (long)c, c / (float)CUENTAS_ENC_REV, enc_grados_motor(e), enc_grados_art(e),
           (unsigned long)enc_lecturas(e), (unsigned long)enc_errores(e), (unsigned long)enc_saltos(e),
           (unsigned long)enc_tiempo_ultima_us(e), (unsigned long)enc_tiempo_max_us(e));
  }
  printf("  'saltos' = más de 1/4 de vuelta entre dos lecturas: no debería pasar girando a mano.\n");
}

static void diag(void) {
  for (int e = 0; e < N_EJES; e++) {
    enc_diag_t d;
    if (!enc_leer_diag(e, &d)) { printf("  eje %d: no responde (canal %u)\n", e + 1, CANAL_MUX[e]); continue; }
    printf("  eje %d: MD=%d ML=%d MH=%d AGC=%3u magnitud=%4u → ", e + 1, d.md, d.ml, d.mh, d.agc, d.magnitud);
    if (!d.md) printf("NO DETECTA IMÁN (¿pegado? ¿polarización diametral?)\n");
    else if (d.ml) printf("campo DÉBIL: imán lejos del chip\n");
    else if (d.mh) printf("campo FUERTE: imán demasiado cerca\n");
    else if (d.agc < 10 || d.agc > 118) printf("AGC cerca del límite (rango 0–128 a 3,3 V)\n");
    else printf("OK\n");
  }
  printf("  A 3,3 V el AS5600 pide VDD5V puenteado con VDD3V3 (hoja de datos ams); si salta con imán OK, revisar eso.\n");
}

static void monitor(float hz) {
  uint32_t periodo = (uint32_t)(1000.0f / (hz > 0 ? hz : 10));
  printf("t_s,q1_mot_deg,t2_mot_deg,t3_mot_deg,q1_art_deg,t2_art_deg,t3_art_deg,errores\n");
  com_vaciar_entrada();
  uint32_t t0 = 0;
  while (!com_hay_tecla()) {
    com_servicio();
    if (com_ms() - t0 >= periodo) {
      t0 = com_ms();
      printf("%.3f,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%lu\n", com_s(), enc_grados_motor(0), enc_grados_motor(1),
             enc_grados_motor(2), enc_grados_art(0), enc_grados_art(1), enc_grados_art(2),
             (unsigned long)(enc_errores(0) + enc_errores(1) + enc_errores(2)));
    }
    vTaskDelay(1);
  }
}

static void vuelta(int e) {
  printf("Eje %d: marcá un diente de la polea, girá a mano UNA vuelta del motor (cualquier sentido)\n", e + 1);
  printf("y volvé a la marca. Enter al terminar. (Los DM556 tienen que estar SIN 24 V.)\n");
  com_esperar(300, false);
  enc_cero(e);
  int32_t max_abs = 0;
  com_vaciar_entrada();
  while (!com_hay_tecla()) {
    com_servicio();
    int32_t c = labs(enc_cuentas(e));
    if (c > max_abs) max_abs = c;
    vTaskDelay(1);
  }
  int32_t c = enc_cuentas(e);
  printf("  recorrido máx. %ld cuentas (%.2f vueltas); al final %ld cuentas (%.1f° de motor)\n", (long)max_abs,
         max_abs / (float)CUENTAS_ENC_REV, (long)c, c / cuentas_grado_motor());
  if (max_abs < CUENTAS_ENC_REV * 0.8f) printf("  NO PASA: no vio una vuelta. ¿Encoder de otro eje? ¿Imán despegado?\n");
  else if (labs(c) > 60) printf("  OJO: no volvió a cero (±5°). Si volviste bien a la marca, se pierden vueltas.\n");
  else printf("  PASA.\n");
}

static void ruido(int e, int n) {
  if (n < 10) n = 500;
  double s = 0, s2 = 0;
  uint16_t mn = 4095, mx = 0;
  int ok = 0;
  for (int i = 0; i < n; i++) {
    uint16_t c;
    if (enc_leer_crudo(e, &c)) {
      s += c;
      s2 += (double)c * c;
      if (c < mn) mn = c;
      if (c > mx) mx = c;
      ok++;
    }
    if (i % 50 == 0) vTaskDelay(1);
  }
  if (ok < 2) { printf("  sin lecturas válidas\n"); return; }
  if (mx - mn > 2048) { printf("  el ángulo está en el cruce 4095→0: girá un poco el motor y repetí.\n"); return; }
  double m = s / ok, sd = sqrt(fmax(0.0, s2 / ok - m * m));
  printf("  media %.2f · desvío %.2f cuentas (%.3f° motor, %.4f° art.) · pico a pico %u · %d/%d ok\n", m, sd,
         sd / cuentas_grado_motor(), sd / cuentas_grado_motor() / RELACION_G[e], mx - mn, ok, n);
  printf(sd <= 1.0 ? "  PASA: ruido ≤ 1 cuenta.\n" : "  OJO: ruido > 1 cuenta; revisar entrehierro, centrado y cables.\n");
}

static void tiempo(int n) {
  if (n < 10) n = 1000;
  enc_reiniciar_estadisticas();
  uint32_t tmax = 0, t0 = com_us();
  for (int i = 0; i < n; i++) {
    uint32_t a = com_us();
    enc_actualizar_todos();
    uint32_t d = com_us() - a;
    if (d > tmax) tmax = d;
  }
  float prom = (com_us() - t0) / (float)n;
  uint32_t err = enc_errores(0) + enc_errores(1) + enc_errores(2);
  printf("  I2C a %lu Hz: %.0f µs promedio, %lu µs máx. por ciclo de 3 encoders → lazo de hasta ~%.0f Hz\n",
         (unsigned long)enc_frecuencia(), prom, (unsigned long)tmax, 1e6f / prom);
  printf("  errores: %lu de %d lecturas\n", (unsigned long)err, 3 * n);
  if (err) printf("  OJO: con errores, 'frec 100000', revisar pull-ups y largo de cables.\n");
}

void t04_ejecutar(generador_t g) {
  (void)g;
  com_uso_t uso = {false, false, true, false};
  if (!com_validar_pines(uso)) com_bloquear_por_error();
  printf("ENA no está cableado: para girar a mano, cortar los 24 V de los DM556.\n");
  if (!enc_iniciar(I2C_FREC_HZ)) printf("!! El PCA9548A no responde. Escaneo:\n");
  enc_escanear_bus();
  diag();
  com_fijar_servicio(servicio);
  com_esperar(50, false);
  enc_cero_todos();
  estado();
  ayuda();
  ay_listo("t04");
  char *tok[4];
  while (true) {
    com_servicio();
    int n = com_leer_comando(tok, 4);
    if (n == 0) { vTaskDelay(1); continue; }
    if (ay_comando_comun(n, tok)) continue;
    const char *c = tok[0];
    if (!strcmp(c, "estado")) estado();
    else if (!strcmp(c, "diag")) diag();
    else if (!strcmp(c, "monitor")) monitor(n >= 2 ? atof(tok[1]) : 10);
    else if (!strcmp(c, "cero")) { enc_cero_todos(); printf("Acumulados en cero.\n"); }
    else if (!strcmp(c, "vuelta")) { int e = com_eje_desde_texto(n >= 2 ? tok[1] : NULL); if (e >= 0) vuelta(e); }
    else if (!strcmp(c, "ruido")) { int e = com_eje_desde_texto(n >= 2 ? tok[1] : NULL); if (e >= 0) ruido(e, n >= 3 ? atoi(tok[2]) : 500); }
    else if (!strcmp(c, "tiempo")) tiempo(n >= 2 ? atoi(tok[1]) : 1000);
    else if (!strcmp(c, "frec") && n >= 2) { enc_fijar_frecuencia(atol(tok[1])); printf("I2C a %lu Hz\n", (unsigned long)enc_frecuencia()); }
    else if (!strcmp(c, "i2c")) enc_escanear_bus();
    else ayuda();
  }
}
