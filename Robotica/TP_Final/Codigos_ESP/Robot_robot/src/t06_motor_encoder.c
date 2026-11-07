// =============================================================================
// t06_motor_encoder.c — T06 · Motor contra encoder (SIN CORREAS)
// -----------------------------------------------------------------------------
// Qué hace : compara los pasos comandados con lo que mide el AS5600.
//   auto <eje>    encoder de otro eje (canal cruzado), signo del encoder,
//                 micropasos REALES del DIP del DM556, pasos perdidos.
//   lineal <eje>  una vuelta paso entero a paso entero: error del encoder con
//                 armónicos 1 y 2 (excentricidad / inclinación del imán). CSV.
//   seguir <eje>  error de seguimiento durante un movimiento. CSV.
//   velmax <eje>  velocidad a la que deja de seguir SIN CARGA (cota superior).
// Salidas  : STEP, DIR. Finales bloquean su eje.
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pi7_comun.h"
#include "pi7_finales.h"
#include "pi7_encoders.h"
#include "pi7_motores.h"
#include "pi7_tests.h"

static const int32_t TOL_RETORNO = 4;        // [cuentas] ida y vuelta al mismo punto
static const float TOL_RELACION = 0.03f;      // ±3 % cuentas medidas / esperadas
static const float PALANCA_M = 0.30f;         // [m] ≈ L2 + L3, para traducir a mm en el TCP
// DIP SW5–SW8 del DM556 [pulsos/rev] (manual Leadshine; verificar contra la etiqueta)
static const uint16_t PULSOS_DM556[] = {400, 800, 1600, 3200, 6400, 12800, 25600, 1000,
                                        2000, 4000, 5000, 8000, 10000, 20000, 25000};

typedef struct { float v, a; } limites_t;
static limites_t guardar(int e) { limites_t l = {mot_vel_max(e), mot_acel(e)}; return l; }
static void restaurar(int e, limites_t l) { mot_fijar_vel_max(e, l.v); mot_fijar_acel(e, l.a); }

static void servicio(void) {
  enc_actualizar_todos();
  ay_informar_eventos();
}

static float promedio(int e, int n) {
  double s = 0;
  for (int i = 0; i < n; i++) {
    enc_actualizar(e);
    s += enc_cuentas(e);
  }
  return (float)(s / n);
}

static void ayuda(void) {
  printf("T06 · generador %s\n", mot_nombre_generador());
  printf("  auto <eje>                 suite automática (signo, micropasos, pasos perdidos)\n");
  printf("  rel <eje> <°motor>         un movimiento y la comparación\n");
  printf("  lineal <eje>               linealidad del encoder en una vuelta (CSV)\n");
  printf("  seguir <eje> <°art> [°/s]  error de seguimiento (CSV)\n");
  printf("  velmax <eje>               barrido de velocidad sin carga\n");
  printf("  estado · cero · x · reset\n");
}

static void estado(void) {
  printf("  eje          cmd[°mot]  enc[°mot]  dif[°mot]  dif[°art]  errores I2C\n");
  for (int e = 0; e < N_EJES; e++) {
    float c = mot_grados_motor(e), en = enc_grados_motor(e);
    printf("  %d %-10s %9.2f  %9.2f  %9.2f  %9.3f  %lu\n", e + 1, NOMBRE_EJE[e], c, en, en - c, (en - c) / RELACION_G[e],
           (unsigned long)enc_errores(e));
  }
}

static void cero(void) {
  ay_esperar_quieto(60000);
  com_esperar(100, false);
  for (int e = 0; e < N_EJES; e++) mot_fijar_posicion(e, 0);
  enc_cero_todos();
  printf("Comando y encoder en cero.\n");
}

static void rel(int e, float deg) {
  ay_esperar_quieto(60000);
  com_esperar(150, false);
  float c0 = promedio(e, 8);
  int32_t p0 = mot_posicion(e);
  mot_mover_rel_grados_motor(e, deg);
  if (!ay_esperar_quieto(120000)) return;
  com_esperar(150, false);
  float dc = promedio(e, 8) - c0, esp = (mot_posicion(e) - p0) * cuentas_por_paso(e);
  printf("  comandado %.2f° motor (%.1f cuentas) · medido %.1f cuentas (%.2f°) · relación %.4f\n", deg, esp, dc,
         dc / cuentas_grado_motor(), esp != 0 ? dc / esp : 0.0f);
}

static void auto_eje(int e) {
  com_linea('=', 72);
  printf("AUTO · eje %d (%s). Correa AFUERA. Cualquier tecla aborta.\n", e + 1, NOMBRE_EJE[e]);
  limites_t lim = guardar(e);
  bool pasa = true, inv[N_EJES];
  for (int i = 0; i < N_EJES; i++) inv[i] = ENC_INVERTIDO[i];

  mot_fijar_limites_art(e, 20.0f, 100.0f);  // 90 °/s de motor
  ay_esperar_quieto(60000);
  com_esperar(200, false);
  int32_t c0[N_EJES], dc[N_EJES];
  for (int i = 0; i < N_EJES; i++) c0[i] = enc_cuentas(i);
  int32_t p0 = mot_posicion(e);
  printf("[1/3] +1 vuelta de motor a 90 °/s...\n");
  mot_mover_rel_grados_motor(e, 360.0f);
  if (!ay_esperar_quieto(60000)) { restaurar(e, lim); return; }
  com_esperar(200, false);
  for (int i = 0; i < N_EJES; i++) dc[i] = enc_cuentas(i) - c0[i];
  float esperado = (mot_posicion(e) - p0) * cuentas_por_paso(e);
  printf("      esperado %+.0f cuentas · medido: eje1 %+ld  eje2 %+ld  eje3 %+ld\n", esperado, (long)dc[0], (long)dc[1],
         (long)dc[2]);
  if (labs(dc[e]) < CUENTAS_ENC_REV / 4) {
    int otro = -1;
    for (int i = 0; i < N_EJES; i++)
      if (i != e && labs(dc[i]) > CUENTAS_ENC_REV / 4) otro = i;
    if (otro >= 0) printf("  NO PASA: se movió el encoder del eje %d, no el del %d → CANAL_MUX cruzado.\n", otro + 1, e + 1);
    else printf("  NO PASA: ningún encoder vio el giro. ¿La polea giró? Si giró: imán, encoder o canal.\n");
    mot_mover_rel_grados_motor(e, -360.0f);
    ay_esperar_quieto(60000);
    restaurar(e, lim);
    return;
  }
  for (int i = 0; i < N_EJES; i++)
    if (i != e && labs(dc[i]) > 20)
      printf("  OJO: el encoder del eje %d se movió %ld cuentas con su motor quieto.\n", i + 1, (long)dc[i]);
  if (dc[e] < 0) {
    inv[e] = !inv[e];
    pasa = false;
    printf("  Signo: el encoder cuenta al revés del comando → invertir ENC_INVERTIDO.\n");
  } else printf("  Signo: correcto.\n");
  float relacion = fabsf(dc[e] / esperado), up_real = MICROPASOS[e] / relacion;
  uint16_t mejor = PULSOS_DM556[0];
  for (unsigned k = 0; k < sizeof(PULSOS_DM556) / sizeof(PULSOS_DM556[0]); k++)
    if (fabsf(PULSOS_DM556[k] / 200.0f - up_real) < fabsf(mejor / 200.0f - up_real)) mejor = PULSOS_DM556[k];
  if (fabsf(relacion - 1.0f) <= TOL_RELACION)
    printf("  Micropasos: relación %.4f → el DM556 está en %u pulsos/rev, coincide con MICROPASOS = %u.\n", relacion,
           (unsigned)(PASOS_MOTOR_REV * MICROPASOS[e]), MICROPASOS[e]);
  else {
    printf("  Micropasos: relación %.4f → el DM556 parece estar en %u pulsos/rev, no en %u.\n", relacion, mejor,
           (unsigned)(PASOS_MOTOR_REV * MICROPASOS[e]));
    printf("  Corregí el DIP o MICROPASOS[%d] = %u en pi7_config.h.\n", e, mejor / 200);
    pasa = false;
  }

  printf("[2/3] -1 vuelta, vuelta al origen...\n");
  mot_mover_rel_grados_motor(e, -360.0f);
  if (!ay_esperar_quieto(60000)) { restaurar(e, lim); return; }
  com_esperar(200, false);
  int32_t err = enc_cuentas(e) - c0[e];
  bool ok = labs(err) <= TOL_RETORNO;
  printf("      error de retorno %+ld cuentas (%.2f° motor) → %s\n", (long)err, err / cuentas_grado_motor(),
         ok ? "PASA" : "NO PASA");
  pasa &= ok;

  printf("[3/3] 5 ciclos de ±720° de motor a 360 °/s...\n");
  mot_fijar_limites_art(e, 360.0f / RELACION_G[e], 1600.0f / RELACION_G[e]);
  for (int k = 0; k < 5; k++) {
    mot_mover_rel_grados_motor(e, 720.0f);
    if (!ay_esperar_quieto(60000)) { restaurar(e, lim); return; }
    mot_mover_rel_grados_motor(e, -720.0f);
    if (!ay_esperar_quieto(60000)) { restaurar(e, lim); return; }
  }
  com_esperar(200, false);
  err = enc_cuentas(e) - c0[e];
  ok = labs(err) <= TOL_RETORNO;
  printf("      error acumulado %+ld cuentas (%.2f° motor, %.3f° art.) → %s\n", (long)err, err / cuentas_grado_motor(),
         err / cuentas_grado_motor() / RELACION_G[e], ok ? "PASA" : "NO PASA");
  if (!ok) printf("      Pierde pasos sin carga: revisar corriente del DM556, transistores y masa común.\n");
  pasa &= ok;
  restaurar(e, lim);
  com_linea('-', 72);
  printf("AUTO eje %d: %s\n", e + 1, pasa ? "PASA" : "NO PASA");
  if (inv[e] != ENC_INVERTIDO[e])
    printf("Pegá esto en pi7_config.h y repetí 'auto':\n  static const bool ENC_INVERTIDO[N_EJES] = {%s, %s, %s};\n",
           inv[0] ? "true" : "false", inv[1] ? "true" : "false", inv[2] ? "true" : "false");
  com_linea('=', 72);
}

static float armonico(const float *x, int n, int k) {
  double re = 0, im = 0;
  for (int i = 0; i < n; i++) {
    re += x[i] * cos(2 * M_PI * k * i / n);
    im -= x[i] * sin(2 * M_PI * k * i / n);
  }
  return (float)(2.0 * sqrt(re * re + im * im) / n);
}

static float mm_tcp(int e, float deg_mot) { return deg_mot / RELACION_G[e] * (float)M_PI / 180.0f * PALANCA_M * 1000.0f; }

static void lineal(int e) {
  enum { N = 200 };
  static float err[N];
  limites_t lim = guardar(e);
  mot_fijar_limites_art(e, 10.0f, 100.0f);
  printf("LINEAL · eje %d: %d pasos enteros de 1,8°, midiendo el encoder en cada uno (~%d s).\n", e + 1, N, N / 8);
  ay_esperar_quieto(60000);
  com_esperar(300, false);
  float c0 = promedio(e, 16);
  char nombre[24];
  snprintf(nombre, sizeof(nombre), "lineal_eje%d", e + 1);
  com_csv_inicio(nombre, "paso,cmd_mot_deg,enc_mot_deg,error_mot_deg");
  for (int k = 0; k < N; k++) {
    float enc = (promedio(e, 8) - c0) / cuentas_grado_motor(), cmd = k * 360.0f / N;
    err[k] = enc - cmd;
    printf("%d,%.3f,%.4f,%.4f\n", k, cmd, enc, err[k]);
    mot_mover_rel(e, MICROPASOS[e]);
    if (!ay_esperar_quieto(10000)) { com_csv_fin(); restaurar(e, lim); return; }
    com_esperar(40, false);
  }
  com_csv_fin();
  float cierre = (promedio(e, 16) - c0) / cuentas_grado_motor() - 360.0f;
  restaurar(e, lim);
  float media = 0, mn = 1e9f, mx = -1e9f;
  for (int k = 0; k < N; k++) media += err[k] / N;
  for (int k = 0; k < N; k++) {
    err[k] -= media;
    if (err[k] < mn) mn = err[k];
    if (err[k] > mx) mx = err[k];
  }
  float a1 = armonico(err, N, 1), a2 = armonico(err, N, 2);
  com_linea('-', 72);
  printf("Error encoder − comando en una vuelta de motor (eje %d):\n", e + 1);
  printf("  pico a pico %.3f° motor → %.3f° art. → ~%.2f mm en el TCP (palanca %.2f m)\n", mx - mn,
         (mx - mn) / RELACION_G[e], mm_tcp(e, mx - mn), PALANCA_M);
  printf("  armónico 1 (excentricidad del imán): ±%.3f° motor (±%.2f mm en el TCP)\n", a1, mm_tcp(e, a1));
  printf("  armónico 2 (inclinación / campo no uniforme): ±%.3f° motor\n", a2);
  printf("  cierre de la vuelta: %.3f° (pasos perdidos si es > 0,2°)\n", cierre);
}

static void seguir(int e, float deg, float vel) {
  enum { NMAX = 1500 };
  static uint32_t ts[NMAX];
  static int32_t ps[NMAX], cs[NMAX];
  limites_t lim = guardar(e);
  if (vel > 0) mot_fijar_vel_max(e, vel * pasos_grado_art(e));
  float v = mot_vel_max(e) / pasos_grado_art(e), a = mot_acel(e) / pasos_grado_art(e);
  float dur = fabsf(deg) / v + v / a + 0.3f;
  uint32_t dt = (uint32_t)fmaxf(2000.0f, dur * 1e6f / NMAX);
  printf("SEGUIR · eje %d: %.1f° art. a %.1f °/s, muestreo cada %.1f ms\n", e + 1, deg, v, dt / 1000.0f);
  ay_esperar_quieto(60000);
  com_esperar(150, false);
  int32_t p0 = mot_posicion(e), c0 = enc_cuentas(e);
  int n = 0;
  uint32_t t0 = com_us(), prox = t0, t_fin = 0;
  mot_mover_rel_grados_art(e, deg);
  while (n < NMAX) {
    enc_actualizar(e);
    uint32_t t = com_us();
    if ((int32_t)(t - prox) >= 0) {
      prox += dt;
      ts[n] = t - t0;
      ps[n] = mot_posicion(e) - p0;
      cs[n] = enc_cuentas(e) - c0;
      n++;
    }
    if (!mot_en_movimiento(e) && !t_fin) t_fin = t;
    if (t_fin && t - t_fin > 300000) break;
    if (com_hay_tecla()) { mot_parar_todo(); break; }
    vTaskDelay(1);
  }
  restaurar(e, lim);
  char nombre[24];
  snprintf(nombre, sizeof(nombre), "seguir_eje%d", e + 1);
  com_csv_inicio(nombre, "t_s,cmd_mot_deg,enc_mot_deg,error_mot_deg,error_art_deg");
  float maxe = 0;
  for (int i = 0; i < n; i++) {
    float cmd = ps[i] / pasos_grado_motor(e), en = cs[i] / cuentas_grado_motor(), er = en - cmd;
    if (fabsf(er) > fabsf(maxe)) maxe = er;
    printf("%.4f,%.3f,%.3f,%.4f,%.5f\n", ts[i] * 1e-6f, cmd, en, er, er / RELACION_G[e]);
  }
  com_csv_fin();
  float efin = n > 0 ? cs[n - 1] / cuentas_grado_motor() - ps[n - 1] / pasos_grado_motor(e) : 0;
  printf("  error máx. %.3f° motor (%.4f° art.) · error final %.3f° motor\n", maxe, maxe / RELACION_G[e], efin);
  printf("  Crece y no vuelve = pasos perdidos. Oscila con la vuelta = imán (ver 'lineal').\n");
}

static void velmax(int e) {
  static const float VELS[] = {0.5f, 1, 1.5f, 2, 3, 4, 5, 6, 7};  // [rev/s de motor]
  float tope = fminf(VEL_ABS_MAX_DEG_S * RELACION_G[e] / 360.0f, mot_paso_max() / pasos_rev_motor(e));
  limites_t lim = guardar(e);
  mot_fijar_acel(e, 3.0f * pasos_rev_motor(e));
  printf("VELMAX · eje %d SIN CARGA. Tope del banco: %.2f rev/s de motor (%.0f °/s art.).\n", e + 1, tope,
         tope * 360.0f / RELACION_G[e]);
  printf("  rev/s  °art/s   relación enc/cmd\n");
  float ultima = 0;
  bool pierde = false;
  for (unsigned k = 0; k < sizeof(VELS) / sizeof(VELS[0]); k++) {
    float vr = VELS[k];
    if (vr > tope + 1e-3f) break;
    mot_jog(e, vr * pasos_rev_motor(e));
    if (!com_esperar((uint32_t)(1000.0f * vr / 3.0f) + 400, true)) break;
    int32_t c0 = enc_cuentas(e), p0 = mot_posicion(e);
    if (!com_esperar(1000, true)) break;
    float r = (enc_cuentas(e) - c0) / cuentas_por_paso(e) / (float)(mot_posicion(e) - p0);
    printf("  %5.2f  %6.1f   %.4f\n", vr, vr * 360.0f / RELACION_G[e], r);
    if (fabsf(r - 1.0f) > TOL_RELACION) { pierde = true; break; }
    ultima = vr;
  }
  mot_detener(e);
  ay_esperar_quieto(30000);
  restaurar(e, lim);
  if (pierde) printf("  Pierde pasos por encima de %.2f rev/s (%.0f °/s art.) SIN carga.\n", ultima, ultima * 360.0f / RELACION_G[e]);
  else printf("  No perdió pasos hasta %.2f rev/s. Con brazo y correa el límite va a ser menor.\n", ultima);
}

void t06_ejecutar(generador_t g) {
  com_uso_t uso = {true, true, true, false};
  if (!com_validar_pines(uso)) com_bloquear_por_error();
  fin_iniciar();
  if (!enc_iniciar(I2C_FREC_HZ)) { printf("!! El PCA9548A no responde. Corré T01/T04 primero.\n"); enc_escanear_bus(); }
  mot_iniciar(g, true);
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  com_fijar_servicio(servicio);
  cero();
  ayuda();
  ay_listo("t06");
  char *tok[5];
  while (true) {
    com_servicio();
    int n = com_leer_comando(tok, 5);
    if (n == 0) { vTaskDelay(1); continue; }
    if (ay_comando_comun(n, tok)) continue;
    const char *c = tok[0];
    if (!strcmp(c, "estado")) { estado(); continue; }
    if (!strcmp(c, "cero")) { cero(); continue; }
    if (strcmp(c, "auto") && strcmp(c, "rel") && strcmp(c, "lineal") && strcmp(c, "seguir") && strcmp(c, "velmax")) {
      ayuda();
      continue;
    }
    int e = com_eje_desde_texto(n >= 2 ? tok[1] : NULL);
    if (e < 0) continue;
    if (!strcmp(c, "auto")) auto_eje(e);
    else if (!strcmp(c, "rel") && n >= 3) rel(e, atof(tok[2]));
    else if (!strcmp(c, "lineal")) lineal(e);
    else if (!strcmp(c, "seguir") && n >= 3) seguir(e, atof(tok[2]), n >= 4 ? atof(tok[3]) : 0);
    else if (!strcmp(c, "velmax")) velmax(e);
    else ayuda();
  }
}
