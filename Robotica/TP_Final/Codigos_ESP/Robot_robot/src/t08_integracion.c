// =============================================================================
// t08_integracion.c — T08 · Todo junto, sin carga (SIN CORREAS)
// -----------------------------------------------------------------------------
// Qué hace : ensayo de quemado. Los tres motores van y vienen, el servo abre y
//            cierra (si está calibrado), los encoders se leen sin parar y los
//            finales se vigilan. Cada 5 s: frecuencia del lazo, lecturas y
//            errores I2C, error de seguimiento, disparos falsos, perfil y heap.
//            Al final vuelve a cero y compara comando contra encoder.
// Requiere : T06 aprobado (ENC_INVERTIDO y MICROPASOS correctos).
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "pi7_comun.h"
#include "pi7_finales.h"
#include "pi7_encoders.h"
#include "pi7_motores.h"
#include "pi7_servo.h"
#include "pi7_tests.h"

static const float AMPLITUD_DEG[N_EJES] = {60.0f, 45.0f, 30.0f};  // [°art]
static const int32_t TOL_RETORNO = 4;                            // [cuentas]

static void servicio(void) {
  enc_actualizar_todos();
  srv_actualizar();
}

static float error_seg(int e) { return enc_cuentas(e) / cuentas_grado_motor() - mot_posicion(e) / pasos_grado_motor(e); }

static void ayuda(void) {
  printf("T08 · generador %s\n", mot_nombre_generador());
  printf("  correr [s]   ensayo de quemado (por defecto 120 s); cualquier tecla lo corta\n");
  printf("  estado · x · reset\n");
}

static void estado(void) {
  for (int e = 0; e < N_EJES; e++)
    printf("  eje %d: cmd %.2f° mot · enc %.2f° mot · dif %.2f° · final %s\n", e + 1, mot_grados_motor(e),
           enc_grados_motor(e), error_seg(e), fin_activo(e) ? "APRETADO" : "suelto");
}

static void correr(uint32_t seg) {
  if (seg == 0) seg = 120;
  bool con_servo = srv_calibrado();
  com_linea('=', 72);
  printf("QUEMADO · %lu s · ±%.0f/±%.0f/±%.0f° art. · servo %s · generador %s\n", (unsigned long)seg,
         AMPLITUD_DEG[0], AMPLITUD_DEG[1], AMPLITUD_DEG[2], con_servo ? "abre/cierra cada 2 s" : "QUIETO (sin calibrar)",
         mot_nombre_generador());
  ay_esperar_quieto(60000);
  com_esperar(200, false);
  for (int e = 0; e < N_EJES; e++) mot_fijar_posicion(e, 0);
  enc_cero_todos();
  enc_reiniciar_estadisticas();
  fin_reiniciar_contadores();
  mot_reiniciar_diagnostico();
  mot_fijar_politica(FINAL_IGNORAR);
  mot_carga_isr();

  int sentido[N_EJES] = {1, 1, 1};
  float err_v[N_EJES] = {0}, err_t[N_EJES] = {0};
  uint32_t lazos = 0, lect_prev = 0, err_prev = 0, heap_min = esp_get_free_heap_size();
  uint32_t t0 = com_ms(), t_inf = com_ms(), t_srv = 0;
  bool abierto = false, abortado = false;
  printf("  t[s] lazo[Hz] enc[lect/s] errI2C saltos err1[°m] err2[°m] err3[°m] fin1/2/3 perfil[µs] ISR[%%] heap\n");
  while (com_ms() - t0 < seg * 1000UL) {
    com_servicio();
    lazos++;
    for (int e = 0; e < N_EJES; e++) {
      if (!mot_en_movimiento(e)) {
        mot_mover_a(e, (int32_t)lroundf(sentido[e] * AMPLITUD_DEG[e] * pasos_grado_art(e)));
        sentido[e] = -sentido[e];
      }
      float er = fabsf(error_seg(e));
      if (er > err_v[e]) err_v[e] = er;
    }
    if (con_servo && com_ms() - t_srv > 2000) {
      t_srv = com_ms();
      abierto = !abierto;
      srv_ir_us(srv_us_desde_psi(abierto ? PSI_ABIERTO_DEG : PSI_CERRADO_DEG), true);
    }
    uint32_t h = esp_get_free_heap_size();
    if (h < heap_min) heap_min = h;
    if (com_ms() - t_inf >= 5000) {
      float dt = (com_ms() - t_inf) * 1e-3f;
      t_inf = com_ms();
      uint32_t lect = enc_lecturas(0) + enc_lecturas(1) + enc_lecturas(2);
      uint32_t err = enc_errores(0) + enc_errores(1) + enc_errores(2);
      uint32_t saltos = enc_saltos(0) + enc_saltos(1) + enc_saltos(2);
      printf("  %4.0f %8.0f %11.0f %6lu %6lu %8.2f %8.2f %8.2f %3lu/%lu/%lu %10lu %6.1f %lu\n", (com_ms() - t0) * 1e-3f,
             lazos / dt, (lect - lect_prev) / dt, (unsigned long)(err - err_prev), (unsigned long)saltos, err_v[0],
             err_v[1], err_v[2], (unsigned long)fin_activaciones(0), (unsigned long)fin_activaciones(1),
             (unsigned long)fin_activaciones(2), (unsigned long)mot_perfil_max_us(), mot_carga_isr(),
             (unsigned long)heap_min);
      for (int e = 0; e < N_EJES; e++) {
        if (err_v[e] > err_t[e]) err_t[e] = err_v[e];
        err_v[e] = 0;
      }
      lazos = 0;
      lect_prev = lect;
      err_prev = err;
    }
    if (com_hay_tecla()) { abortado = true; break; }
    vTaskDelay(1);
  }
  printf(abortado ? "Cortado. Volviendo a cero...\n" : "Tiempo cumplido. Volviendo a cero...\n");
  for (int e = 0; e < N_EJES; e++) mot_mover_a(e, 0);
  ay_esperar_quieto(60000);
  if (con_servo) srv_ir_us(srv_us_desde_psi(PSI_CERRADO_DEG), true);
  com_esperar(300, false);
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);

  com_linea('-', 72);
  bool pasa = true;
  for (int e = 0; e < N_EJES; e++) {
    int32_t ret = enc_cuentas(e) - (int32_t)lroundf(mot_posicion(e) * cuentas_por_paso(e));
    bool ok = labs(ret) <= TOL_RETORNO;
    pasa &= ok;
    printf("  eje %d: retorno %+ld cuentas (%.3f° art.) %s · seguimiento máx. %.2f° motor\n", e + 1, (long)ret,
           ret / cuentas_grado_motor() / RELACION_G[e], ok ? "PASA" : "NO PASA (pasos perdidos)", err_t[e]);
  }
  uint32_t ei = enc_errores(0) + enc_errores(1) + enc_errores(2), li = enc_lecturas(0) + enc_lecturas(1) + enc_lecturas(2);
  bool ok_i2c = li > 0 && ei * 1000 <= li;
  printf("  I2C: %lu errores en %lu lecturas → %s\n", (unsigned long)ei, (unsigned long)li, ok_i2c ? "PASA" : "NO PASA");
  uint32_t falsos = fin_activaciones(0) + fin_activaciones(1) + fin_activaciones(2);
  printf("  Finales: %lu disparos falsos → %s\n", (unsigned long)falsos, falsos == 0 ? "PASA" : "NO PASA");
  pasa &= ok_i2c && falsos == 0;
  printf("QUEMADO: %s\n", pasa ? "PASA" : "NO PASA");
  com_linea('=', 72);
}

void t08_ejecutar(generador_t g) {
  com_uso_t uso = {true, true, true, true};
  if (!com_validar_pines(uso)) com_bloquear_por_error();
  fin_iniciar();
  if (!enc_iniciar(I2C_FREC_HZ)) printf("!! El PCA9548A no responde: el ensayo va a dar NO PASA en I2C.\n");
  srv_iniciar();
  mot_iniciar(g, true);
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  com_fijar_servicio(servicio);
  ayuda();
  ay_listo("t08");
  char *tok[3];
  while (true) {
    com_servicio();
    int n = com_leer_comando(tok, 3);
    if (n == 0) { vTaskDelay(2); continue; }
    if (ay_comando_comun(n, tok)) continue;
    if (!strcmp(tok[0], "correr")) correr(n >= 2 ? atol(tok[1]) : 120);
    else if (!strcmp(tok[0], "estado")) estado();
    else ayuda();
  }
}
