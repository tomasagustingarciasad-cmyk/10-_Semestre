// =============================================================================
// t09_generador_hw.c — T09 · Generador de pasos por HARDWARE (LEDC + PCNT)
// -----------------------------------------------------------------------------
// Qué hace : prueba el generador por periféricos que reemplaza al código de
//            referencia "mover_motor()" con LEDC. LEDC solo genera una
//            frecuencia y no sabe cuántos pasos dio; acá el PCNT cuenta los
//            pulsos en el mismo pin y corta el tren en el pulso N exacto.
//   frec <eje> <hz> [s]        frecuencia constante: medida por PCNT y por encoder
//   pulsos <eje> <n> [hz]      exactamente n pulsos a frecuencia constante
//   repetir <eje> <n> [k] [hz] k idas y vueltas de n pulsos: el encoder tiene que volver
//   rampa <eje> <°art>         movimiento con rampa trapezoidal (mismo perfil que software)
//   demo                       la secuencia del main.c de referencia, con los pines
//                              correctos y cambio de sentido seguro
// Salidas  : STEP, DIR. Usa los encoders (si responden) como verificación independiente.
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

static const float ACEL_INSTANTANEA = 1e7f;  // [upasos/s²] salto de frecuencia en un ciclo de perfil
static bool hay_enc = false;

static void servicio(void) {
  if (hay_enc) enc_actualizar_todos();
  ay_informar_eventos();
}

static void ayuda(void) {
  printf("T09 · generador %s · encoders %s\n", mot_nombre_generador(), hay_enc ? "disponibles" : "NO disponibles");
  printf("  frec <eje> <hz> [s]          frecuencia constante (por defecto 3 s)\n");
  printf("  pulsos <eje> <n> [hz]        exactamente n pulsos (por defecto 1000 Hz)\n");
  printf("  repetir <eje> <n> [k] [hz]   k idas y vueltas de n pulsos\n");
  printf("  rampa <eje> <°art>           movimiento con rampa\n");
  printf("  demo                         secuencia del main.c de referencia (cualquier tecla corta)\n");
  printf("  x · reset\n");
}

typedef struct { float v, a; } lim_t;
static lim_t constante(int e, float hz) {
  lim_t l = {mot_vel_max(e), mot_acel(e)};
  mot_fijar_vel_max(e, hz);
  mot_fijar_acel(e, ACEL_INSTANTANEA);
  return l;
}
static void restaurar(int e, lim_t l) { mot_fijar_vel_max(e, l.v); mot_fijar_acel(e, l.a); }

static void frec(int e, float hz, float seg) {
  if (seg <= 0) seg = 3;
  if (hz > FREC_HW_MAX_HZ) hz = FREC_HW_MAX_HZ;
  printf("FREC · eje %d a %.0f Hz (= %.2f rev/s de motor, %.1f °/s art.) durante %.1f s\n", e + 1, hz,
         hz / pasos_rev_motor(e), hz / pasos_grado_art(e), seg);
  lim_t l = constante(e, hz);
  mot_jog(e, hz);
  com_esperar(300, false);
  int32_t p0 = mot_posicion(e), c0 = hay_enc ? enc_cuentas(e) : 0;
  uint32_t t0 = com_us();
  com_esperar((uint32_t)(seg * 1000), true);
  float dt = (com_us() - t0) * 1e-6f;
  int32_t dp = mot_posicion(e) - p0, dc = hay_enc ? enc_cuentas(e) - c0 : 0;
  mot_parar_ya(e);
  restaurar(e, l);
  printf("  PCNT: %ld pulsos en %.3f s → %.1f Hz (error %.2f %%)\n", (long)dp, dt, dp / dt, 100.0f * (dp / dt - hz) / hz);
  if (hay_enc)
    printf("  Encoder: %ld cuentas → %.1f pasos/s equivalentes (relación %.4f con lo contado)\n", (long)dc,
           dc / cuentas_por_paso(e) / dt, dp ? dc / cuentas_por_paso(e) / dp : 0.0f);
}

static bool pulsos(int e, int32_t n, float hz, bool informar) {
  if (labs(n) > PASOS_HW_MAX_TRAMO) {
    printf("  n máximo con corte exacto: %ld (contador de 16 bits del PCNT)\n", (long)PASOS_HW_MAX_TRAMO);
    return false;
  }
  lim_t l = constante(e, hz);
  ay_esperar_quieto(30000);
  com_esperar(100, false);
  int32_t p0 = mot_posicion(e);
  float c0 = hay_enc ? (float)enc_cuentas(e) : 0;
  mot_mover_rel(e, n);
  bool ok = ay_esperar_quieto(120000);
  com_esperar(150, false);
  restaurar(e, l);
  if (!ok) return false;
  int32_t dp = mot_posicion(e) - p0;
  float dc = hay_enc ? enc_cuentas(e) - c0 : 0, esp = n * cuentas_por_paso(e);
  bool exacto = dp == n;
  if (informar) {
    printf("  pedidos %ld · contados por PCNT %ld → %s\n", (long)n, (long)dp, exacto ? "EXACTO" : "NO COINCIDE");
    if (hay_enc)
      printf("  encoder %.0f cuentas · esperadas %.1f · diferencia %.1f cuentas (%.2f pasos)\n", dc, esp, dc - esp,
             (dc - esp) / cuentas_por_paso(e));
  }
  return exacto;
}

static void repetir(int e, int32_t n, int k, float hz) {
  if (k <= 0) k = 10;
  printf("REPETIR · eje %d: %d idas y vueltas de %ld pulsos a %.0f Hz\n", e + 1, k, (long)n, hz);
  int32_t c0 = hay_enc ? enc_cuentas(e) : 0, p0 = mot_posicion(e);
  for (int i = 0; i < k; i++) {
    if (!pulsos(e, n, hz, false) || !pulsos(e, -n, hz, false)) { printf("  cortado en el ciclo %d\n", i + 1); return; }
    if (com_hay_tecla()) { printf("  abortado\n"); return; }
  }
  int32_t dp = mot_posicion(e) - p0;
  printf("  posición contada al final: %+ld pulsos del inicio → %s\n", (long)dp, dp == 0 ? "PASA" : "NO PASA");
  if (hay_enc) {
    int32_t dc = enc_cuentas(e) - c0;
    printf("  encoder al final: %+ld cuentas del inicio (%.2f° motor) → %s\n", (long)dc, dc / cuentas_grado_motor(),
           labs(dc) <= 4 ? "PASA" : "NO PASA (el driver no recibió todos los pulsos o perdió pasos)");
  }
}

static void rampa(int e, float deg) {
  int32_t p0 = mot_posicion(e), c0 = hay_enc ? enc_cuentas(e) : 0;
  printf("RAMPA · eje %d %.1f° art. con vmax %.0f °/s y acel %.0f °/s²\n", e + 1, deg,
         mot_vel_max(e) / pasos_grado_art(e), mot_acel(e) / pasos_grado_art(e));
  uint32_t t0 = com_ms();
  mot_mover_rel_grados_art(e, deg);
  if (!ay_esperar_quieto(120000)) return;
  com_esperar(150, false);
  int32_t dp = mot_posicion(e) - p0, n = (int32_t)lroundf(deg * pasos_grado_art(e));
  printf("  %lu ms · pedidos %ld · contados %ld → %s\n", (unsigned long)(com_ms() - t0 - 150), (long)n, (long)dp,
         dp == n ? "EXACTO" : "NO COINCIDE");
  if (hay_enc) {
    int32_t dc = enc_cuentas(e) - c0;
    printf("  encoder: %.2f° art. (esperado %.2f°)\n", dc / cuentas_grado_motor() / RELACION_G[e], deg);
  }
}

// Misma secuencia que el main.c de referencia. Diferencias: pines de la hoja de
// hardware, el sentido sólo cambia con el tren cortado y DIR asentado, y se
// cuentan los pulsos. Sin rampas, igual que el original: con carga a 2000 Hz un
// arranque en seco puede perder pasos.
static void demo(void) {
  typedef struct { const char *texto; float hz[N_EJES]; uint32_t ms; } estado_t;
  const estado_t E[] = {
      {"Estado 1: motor 1 y 3 a 1500 Hz adelante, motor 2 quieto", {1500, 0, 1500}, 3000},
      {"Estado 2: motor 2 a 400 Hz atrás, 1 y 3 quietos", {0, -400, 0}, 2000},
      {"Estado 3: motor 1 a 2000 Hz atrás, 2 a 800 Hz, 3 a 100 Hz", {-2000, 800, 100}, 4000},
      {"Estado 4: todos detenidos", {0, 0, 0}, 2000},
  };
  lim_t l[N_EJES];
  for (int e = 0; e < N_EJES; e++) l[e] = constante(e, 2000);
  printf("DEMO · secuencia del main.c de referencia (cualquier tecla corta)\n");
  bool seguir = true;
  while (seguir) {
    for (int k = 0; k < 4 && seguir; k++) {
      printf("%s\n", E[k].texto);
      for (int e = 0; e < N_EJES; e++) {
        if (E[k].hz[e] == 0) mot_parar_ya(e);
        else mot_jog(e, E[k].hz[e]);
      }
      seguir = com_esperar(E[k].ms, true);
    }
    printf("  posiciones contadas: %ld / %ld / %ld pulsos\n", (long)mot_posicion(0), (long)mot_posicion(1),
           (long)mot_posicion(2));
  }
  mot_parar_todo();
  for (int e = 0; e < N_EJES; e++) restaurar(e, l[e]);
}

void t09_ejecutar(generador_t g) {
  if (g != GEN_HARDWARE) printf("T09 siempre usa el generador por HARDWARE.\n");
  com_uso_t uso = {true, true, true, false};
  if (!com_validar_pines(uso)) com_bloquear_por_error();
  fin_iniciar();
  hay_enc = enc_iniciar(I2C_FREC_HZ);
  if (!hay_enc) printf("Encoders no disponibles: sólo se verifica con el PCNT.\n");
  mot_iniciar(GEN_HARDWARE, true);
  mot_fijar_politica(FINAL_BLOQUEA_SU_EJE);
  com_fijar_servicio(servicio);
  ayuda();
  ay_listo("t09");
  char *tok[6];
  while (true) {
    com_servicio();
    int n = com_leer_comando(tok, 6);
    if (n == 0) { vTaskDelay(2); continue; }
    if (ay_comando_comun(n, tok)) continue;
    const char *c = tok[0];
    if (!strcmp(c, "demo")) { demo(); continue; }
    if (strcmp(c, "frec") && strcmp(c, "pulsos") && strcmp(c, "repetir") && strcmp(c, "rampa")) { ayuda(); continue; }
    int e = com_eje_desde_texto(n >= 2 ? tok[1] : NULL);
    if (e < 0 || n < 3) { ayuda(); continue; }
    if (!strcmp(c, "frec")) frec(e, atof(tok[2]), n >= 4 ? atof(tok[3]) : 3);
    else if (!strcmp(c, "pulsos")) pulsos(e, atol(tok[2]), n >= 4 ? atof(tok[3]) : 1000, true);
    else if (!strcmp(c, "repetir")) repetir(e, atol(tok[2]), n >= 4 ? atoi(tok[3]) : 10, n >= 5 ? atof(tok[4]) : 1000);
    else if (!strcmp(c, "rampa")) rampa(e, atof(tok[2]));
  }
}
