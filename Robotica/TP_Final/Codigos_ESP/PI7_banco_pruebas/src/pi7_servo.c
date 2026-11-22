// =============================================================================
// pi7_servo.c — Implementación. Ver el .h.
// Autor: Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include "pi7_servo.h"
#include <math.h>
#include "driver/ledc.h"
#include "esp_timer.h"

#define SRV_TIMER LEDC_TIMER_3
#define SRV_CANAL LEDC_CHANNEL_3
static const uint32_t FREC_HZ = 50;
static const uint32_t MAX_DUTY = (1u << 16) - 1;

static bool emitiendo = false;
static float us_act = 1500, us_obj = 1500, rampa = 2000;
static int64_t t_ant = 0;

static void escribir(float us) {
  uint32_t duty = (us <= 0) ? 0 : (uint32_t)(us * MAX_DUTY / (1e6f / FREC_HZ));
  ledc_set_duty(LEDC_LOW_SPEED_MODE, SRV_CANAL, duty);
  ledc_update_duty(LEDC_LOW_SPEED_MODE, SRV_CANAL);
}

void srv_iniciar(void) {
  if (PIN_SERVO < 0) return;
  ledc_timer_config_t t = {
      .speed_mode = LEDC_LOW_SPEED_MODE,
      .duty_resolution = LEDC_TIMER_16_BIT,
      .timer_num = SRV_TIMER,
      .freq_hz = FREC_HZ,
      .clk_cfg = LEDC_AUTO_CLK,
  };
  ledc_timer_config(&t);
  ledc_channel_config_t c = {
      .gpio_num = PIN_SERVO,
      .speed_mode = LEDC_LOW_SPEED_MODE,
      .channel = SRV_CANAL,
      .intr_type = LEDC_INTR_DISABLE,
      .timer_sel = SRV_TIMER,
      .duty = 0,  // sin pulsos: servo suelto
      .hpoint = 0,
  };
  ledc_channel_config(&c);
  us_act = us_obj = SERVO_US_INICIO;
  rampa = SERVO_RAMPA_US_S;
  emitiendo = false;
}

void srv_ir_us(uint16_t us, bool con_rampa) {
  if (PIN_SERVO < 0) return;
  if (us < SERVO_US_MIN) us = SERVO_US_MIN;
  if (us > SERVO_US_MAX) us = SERVO_US_MAX;
  us_obj = us;
  if (!emitiendo || !con_rampa || rampa <= 0) {  // al arrancar no se sabe dónde está: salto
    us_act = us;
    escribir(us_act);
  }
  emitiendo = true;
  t_ant = esp_timer_get_time();
}

void srv_soltar(void) {
  emitiendo = false;
  escribir(0);
}

void srv_actualizar(void) {
  if (!emitiendo || us_act == us_obj) return;
  int64_t t = esp_timer_get_time();
  float paso = rampa * (t - t_ant) * 1e-6f;
  t_ant = t;
  if (fabsf(us_obj - us_act) <= paso) us_act = us_obj;
  else us_act += (us_obj > us_act) ? paso : -paso;
  escribir(us_act);
}

void srv_fijar_rampa(float r) { rampa = r; }
bool srv_activo(void) { return emitiendo; }
bool srv_en_movimiento(void) { return emitiendo && us_act != us_obj; }
uint16_t srv_us_actual(void) { return (uint16_t)(us_act + 0.5f); }
uint16_t srv_us_objetivo(void) { return (uint16_t)(us_obj + 0.5f); }
bool srv_calibrado(void) { return SERVO_US_PSI_CERRADO > 0 && SERVO_US_PSI_ABIERTO > 0; }

uint16_t srv_us_desde_psi(float psi) {
  float m = ((float)SERVO_US_PSI_ABIERTO - SERVO_US_PSI_CERRADO) / (PSI_ABIERTO_DEG - PSI_CERRADO_DEG);
  float us = SERVO_US_PSI_CERRADO + m * (psi - PSI_CERRADO_DEG);
  if (us < SERVO_US_MIN) us = SERVO_US_MIN;
  if (us > SERVO_US_MAX) us = SERVO_US_MAX;
  return (uint16_t)us;
}
