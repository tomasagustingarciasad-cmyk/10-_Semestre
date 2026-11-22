// =============================================================================
// t01_diagnostico.c — T01 · Diagnóstico general (no mueve nada)
// -----------------------------------------------------------------------------
// Qué hace : valida el pinout, muestra parámetros derivados, escanea el bus I2C
//            (bus principal y los 8 canales del PCA9548A), lee el estado del
//            imán de cada AS5600 y el nivel de cada final. 'sonda' informa qué
//            GPIO cambia de nivel: sirve para encontrar a qué pin quedó cada final.
// Salidas  : NINGUNA. STEP, DIR y servo no se configuran (los BC337 quedan
//            cortados por su pull-down de 10 kΩ).
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "pi7_comun.h"
#include "pi7_finales.h"
#include "pi7_encoders.h"
#include "pi7_tests.h"

static bool i2c_ok = false;

static void ayuda(void) {
  printf("T01 · comandos:\n");
  printf("  todo      repite el diagnóstico completo\n");
  printf("  param     parámetros derivados por eje\n");
  printf("  i2c       escaneo del bus y de los canales del multiplexor\n");
  printf("  enc       presencia y estado del imán de cada AS5600\n");
  printf("  finales   nivel de cada final de carrera\n");
  printf("  sonda     avisa qué GPIO cambia (apretá los finales de a uno)\n");
  printf("  reset     volver al menú\n");
}

static void parametros(void) {
  printf("Parámetros derivados (pi7_config.h):\n");
  printf("  eje          upasos  G     pasos/°art  °art/upaso  cuentas/°art  °art/cuenta\n");
  for (int e = 0; e < N_EJES; e++) {
    float ppa = pasos_grado_art(e), cpa = cuentas_grado_motor() * RELACION_G[e];
    printf("  %d %-10s %4u   %.2f  %9.2f   %9.4f   %10.2f   %9.4f\n", e + 1, NOMBRE_EJE[e], MICROPASOS[e],
           RELACION_G[e], ppa, 1.0f / ppa, cpa, 1.0f / cpa);
  }
  printf("  Generador software: tick %lu µs → paso máx. %.0f Hz. Hardware: hasta %lu Hz.\n",
         (unsigned long)PERIODO_TICK_US, 1e6f / PERIODO_TICK_US / 2, (unsigned long)FREC_HW_MAX_HZ);
  com_linea('-', 72);
}

static void diag_encoders(void) {
  if (!i2c_ok) {
    printf("Encoders: el multiplexor no responde; no se puede leer ningún AS5600.\n");
    com_linea('-', 72);
    return;
  }
  printf("Encoders AS5600:\n  eje          canal presente crudo  MD ML MH  AGC  magnitud  veredicto\n");
  for (int e = 0; e < N_EJES; e++) {
    bool p = enc_presente(e);
    uint16_t crudo = 0;
    enc_diag_t d = {0};
    bool ok = p && enc_leer_crudo(e, &crudo) && enc_leer_diag(e, &d);
    printf("  %d %-10s  %u     %-8s", e + 1, NOMBRE_EJE[e], CANAL_MUX[e], p ? "sí" : "NO");
    if (!ok) {
      printf(" no responde\n");
      continue;
    }
    const char *v = "OK";
    if (!d.md) v = "NO DETECTA IMÁN";
    else if (d.ml) v = "imán LEJOS (campo débil)";
    else if (d.mh) v = "imán CERCA (campo fuerte)";
    else if (d.agc < 10 || d.agc > 118) v = "AGC al límite: revisar entrehierro";
    printf("%4u   %d  %d  %d  %3u   %5u     %s\n", crudo, d.md, d.ml, d.mh, d.agc, d.magnitud, v);
  }
  com_linea('-', 72);
}

static void diag_finales(void) {
  printf("Finales de carrera (sin tocar nada deberían estar todos 'suelto'):\n");
  for (int e = 0; e < N_EJES; e++) {
    bool alto = fin_nivel_crudo(e);
    printf("  %d %-10s  GPIO%-2d  nivel %s  →  %s\n", e + 1, NOMBRE_EJE[e], PIN_FINAL[e], alto ? "ALTO" : "BAJO",
           (alto == FINAL_ACTIVO_ALTO[e]) ? "APRETADO (según el config)" : "suelto");
  }
  printf("  Si alguno figura APRETADO sin tocarlo: la polaridad del config está al revés (T02 'calibrar').\n");
  com_linea('-', 72);
}

static void escaneo(void) {
  enc_escanear_bus();
  i2c_ok = enc_mux_presente();
  com_linea('-', 72);
}

static void todo(void) {
  parametros();
  escaneo();
  diag_encoders();
  diag_finales();
}

// GPIO sondeables: sin flash (6–11), UART0 (1, 3), I2C, ni los que el config usa como salida.
static const int8_t CANDIDATOS[] = {0, 2, 4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 23, 25, 26, 27, 32, 33, 34, 35, 36, 39};

static bool es_salida_config(int p) {
  for (int e = 0; e < N_EJES; e++)
    if (p == PIN_STEP[e] || p == PIN_DIR[e]) return true;
  return p == PIN_SERVO || p == PIN_SDA || p == PIN_SCL || p == PIN_LED;
}

static void sonda(void) {
  const int n = sizeof(CANDIDATOS);
  int nivel[sizeof(CANDIDATOS)];
  uint32_t t_ult[sizeof(CANDIDATOS)];
  printf("SONDA: GPIO libres como entrada, sin pull (los finales tienen su propio acondicionamiento).\n");
  printf("Los pines de STEP, DIR, servo, I2C y LED no se tocan. Apretá los finales de a uno.\n");
  printf("Cualquier tecla para salir.\n");
  for (int i = 0; i < n; i++) {
    int p = CANDIDATOS[i];
    t_ult[i] = 0;
    if (es_salida_config(p)) continue;
    gpio_reset_pin(p);
    gpio_set_direction(p, GPIO_MODE_INPUT);
    gpio_set_pull_mode(p, GPIO_FLOATING);
  }
  vTaskDelay(pdMS_TO_TICKS(5) + 1);
  printf("Niveles iniciales: ");
  for (int i = 0; i < n; i++) {
    nivel[i] = gpio_get_level(CANDIDATOS[i]);
    if (!es_salida_config(CANDIDATOS[i])) printf("%d=%d ", CANDIDATOS[i], nivel[i]);
  }
  printf("\n(los pines al aire pueden cambiar solos: ignorar los que no tienen nada conectado)\n");
  while (!com_hay_tecla()) {
    for (int i = 0; i < n; i++) {
      int p = CANDIDATOS[i];
      if (es_salida_config(p)) continue;
      int l = gpio_get_level(p);
      if (l != nivel[i] && com_ms() - t_ult[i] > 30) {
        nivel[i] = l;
        t_ult[i] = com_ms();
        const char *rol = "(no figura en el config)";
        for (int e = 0; e < N_EJES; e++)
          if (p == PIN_FINAL[e]) rol = NOMBRE_EJE[e];
        printf("  t=%7.3f s  GPIO%-2d → %s   %s\n", com_s(), p, l ? "ALTO" : "BAJO", rol);
      }
    }
    com_latido();
    vTaskDelay(1);
  }
  printf("Fin de la sonda. Se restauran los finales.\n");
  fin_iniciar();
}

void t01_ejecutar(generador_t g) {
  (void)g;
  com_uso_t uso = {true, true, true, true};
  com_validar_pines(uso);  // sólo informa: este test no maneja salidas
  fin_iniciar();
  i2c_ok = enc_iniciar(I2C_FREC_HZ);
  todo();
  ayuda();
  ay_listo("t01");
  char *tok[4];
  while (true) {
    com_servicio();
    int n = com_leer_comando(tok, 4);
    if (n == 0) { vTaskDelay(5); continue; }
    if (ay_comando_comun(n, tok)) continue;
    if (!strcmp(tok[0], "todo")) todo();
    else if (!strcmp(tok[0], "param")) parametros();
    else if (!strcmp(tok[0], "i2c")) escaneo();
    else if (!strcmp(tok[0], "enc")) diag_encoders();
    else if (!strcmp(tok[0], "finales")) diag_finales();
    else if (!strcmp(tok[0], "sonda")) sonda();
    else ayuda();
  }
}
