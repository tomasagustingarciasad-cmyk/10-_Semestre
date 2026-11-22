// =============================================================================
// pi7_motores.c — Implementación. Ver el .h.
//
// Perfil (esp_timer, 1 kHz), común a los dos generadores:
//   · muestrea finales y aplica la política;
//   · rampa trapezoidal "en línea": v_des = min(vmax, sqrt(2·a·d)), |dv| ≤ a·dt.
//     Resuelve movimientos cortos (triangulares), cambios de objetivo y reversas.
// Generador SOFTWARE (ISR de gptimer, cada PERIODO_TICK_US, núcleo 1):
//   · acumulador de fase de 32 bits por eje; un paso por desborde;
//   · pulso de un tick; la fase se acumula también en el tick que baja el pulso;
//   · DIR nunca en el mismo tick que un flanco de STEP, y TICKS_ESPERA_DIR sin pasos;
//   · en modo posición nunca da un paso más allá del objetivo.
// Generador HARDWARE (LEDC + PCNT):
//   · cada eje usa LEDC timer/canal i (10 bits, 50 %) y una unidad PCNT que cuenta
//     los flancos de bajada del MISMO pin (fin de cada pulso);
//   · arrancar = reiniciar el timer LEDC y conectar su señal al pin por la matriz GPIO;
//   · cortar   = conectar el pin al registro GPIO en bajo (función de ROM, apta para ISR);
//   · el corte exacto lo hace la interrupción del PCNT al llegar al pulso N, durante
//     el semiperíodo bajo: nunca recorta un pulso ni deja escapar el siguiente;
//   · posición = base del tramo + sentido · cuenta del PCNT.
//
// Autor: Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include "pi7_motores.h"
#include "pi7_finales.h"
#include <math.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "driver/gpio.h"
#include "driver/gptimer.h"
#include "driver/ledc.h"
#include "driver/pulse_cnt.h"
#include "esp_timer.h"
#include "esp_attr.h"
#include "esp_cpu.h"
#include "esp_rom_gpio.h"
#include "esp_rom_sys.h"
#include "soc/gpio_reg.h"
#include "soc/gpio_sig_map.h"
#include "soc/gpio_periph.h"
#include "soc/io_mux_reg.h"
#include "sdkconfig.h"

enum { REPOSO = 0, POSICION = 1, VELOCIDAD = 2 };

typedef struct {
  // Perfil
  volatile uint8_t modo;
  volatile float v, v_obj, vmax, a;
  volatile int32_t objetivo;
  volatile bool limitar;
  uint32_t n_bloqueos;
  // Software
  volatile int32_t pos;
  volatile uint32_t acc, inc;
  volatile int8_t dir, dir_pedida;
  volatile bool pulso_alto, paso_pendiente;
  volatile uint8_t espera_dir;
  // Hardware
  pcnt_unit_handle_t unidad;
  pcnt_channel_handle_t canal;
  volatile int32_t base;
  volatile int8_t hw_dir;
  volatile bool conectado;
  volatile int wp;          // punto de corte armado (pulsos del tramo), 0 = ninguno
  float f_aplicada;
} eje_t;

static eje_t ej[N_EJES];
static generador_t gen = GEN_SOFTWARE;
static portMUX_TYPE candado = portMUX_INITIALIZER_UNLOCKED;
static gptimer_handle_t timer_pasos = NULL;
static esp_timer_handle_t timer_perfil = NULL;
static bool muestrear_fin = true;
static volatile politica_final_t pol = FINAL_BLOQUEA_SU_EJE;
static volatile uint32_t perfil_max = 0;
static volatile uint32_t ciclos_isr = 0;
static int64_t t_carga = 0;
static bool final_previo[N_EJES];

static const float DT = PERIODO_PERFIL_US * 1e-6f;
static const float VEL_MIN = 40.0f;  // [upasos/s] para no quedar clavado al final
static const int HW_LIMITE_PCNT = 32000;

#define F_TICK (1e6f / PERIODO_TICK_US)
#define PASO_MAX_SW (F_TICK / 2.0f - 1.0f)

static const uint8_t TAM_COLA = 8;
static mot_evento_t cola[8];
static volatile uint8_t cola_ini = 0, cola_fin = 0;

// -----------------------------------------------------------------------------
// GPIO directo (pines 0–39)
// -----------------------------------------------------------------------------
static inline void IRAM_ATTR pin_nivel(int8_t pin, bool alto) {
  if (pin < 0) return;
  if (pin < 32) REG_WRITE(alto ? GPIO_OUT_W1TS_REG : GPIO_OUT_W1TC_REG, 1UL << pin);
  else REG_WRITE(alto ? GPIO_OUT1_W1TS_REG : GPIO_OUT1_W1TC_REG, 1UL << (pin - 32));
}
static inline bool IRAM_ATTR nivel_dir(int i, int8_t d) { return (d > 0) != DIR_INVERTIDA[i]; }
static inline bool IRAM_ATTR nivel_step(bool activo) { return activo == STEP_ACTIVO_ALTO; }

// =============================================================================
// Generador SOFTWARE
// =============================================================================
static bool IRAM_ATTR isr_pasos(gptimer_handle_t t, const gptimer_alarm_event_data_t *ed, void *ctx) {
  uint32_t c0 = esp_cpu_get_cycle_count();
  portENTER_CRITICAL_ISR(&candado);
  for (int i = 0; i < N_EJES; i++) {
    eje_t *e = &ej[i];
    bool recien_bajado = false;
    if (e->pulso_alto) {
      pin_nivel(PIN_STEP[i], nivel_step(false));
      e->pulso_alto = false;
      recien_bajado = true;
    }
    if (!recien_bajado && e->dir_pedida != e->dir) {
      pin_nivel(PIN_DIR[i], nivel_dir(i, e->dir_pedida));
      e->dir = e->dir_pedida;
      e->espera_dir = TICKS_ESPERA_DIR;
      e->paso_pendiente = false;
      continue;
    }
    if (e->espera_dir) {
      e->espera_dir--;
      continue;
    }
    uint32_t inc = e->inc;
    if (inc) {
      uint32_t nuevo = e->acc + inc;
      if (nuevo < e->acc) e->paso_pendiente = true;
      e->acc = nuevo;
    }
    if (!e->paso_pendiente || recien_bajado) continue;
    e->paso_pendiente = false;
    if (e->limitar && e->pos == e->objetivo) continue;
    pin_nivel(PIN_STEP[i], nivel_step(true));
    e->pulso_alto = true;
    e->pos += e->dir;
  }
  portEXIT_CRITICAL_ISR(&candado);
  ciclos_isr += esp_cpu_get_cycle_count() - c0;
  return false;
}

static SemaphoreHandle_t listo_sw = NULL;
static void tarea_crear_timer(void *arg) {
  // Se crea desde el núcleo 1 para que la ISR de 40 kHz corra ahí y no compita
  // con la consola, el I2C y el esp_timer (que viven en el núcleo 0).
  gptimer_config_t tc = {
      .clk_src = GPTIMER_CLK_SRC_DEFAULT,
      .direction = GPTIMER_COUNT_UP,
      .resolution_hz = 1000000,
  };
  ESP_ERROR_CHECK(gptimer_new_timer(&tc, &timer_pasos));
  gptimer_event_callbacks_t cbs = {.on_alarm = isr_pasos};
  ESP_ERROR_CHECK(gptimer_register_event_callbacks(timer_pasos, &cbs, NULL));
  ESP_ERROR_CHECK(gptimer_enable(timer_pasos));
  gptimer_alarm_config_t ac = {
      .alarm_count = PERIODO_TICK_US,
      .reload_count = 0,
      .flags.auto_reload_on_alarm = true,
  };
  ESP_ERROR_CHECK(gptimer_set_alarm_action(timer_pasos, &ac));
  ESP_ERROR_CHECK(gptimer_start(timer_pasos));
  xSemaphoreGive(listo_sw);
  vTaskDelete(NULL);
}

static void iniciar_software(void) {
  for (int i = 0; i < N_EJES; i++) {
    gpio_config_t c = {
        .pin_bit_mask = (1ULL << PIN_STEP[i]) | (1ULL << PIN_DIR[i]),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    gpio_config(&c);
    gpio_set_level(PIN_STEP[i], nivel_step(false));
    gpio_set_level(PIN_DIR[i], nivel_dir(i, +1));
  }
  listo_sw = xSemaphoreCreateBinary();
  xTaskCreatePinnedToCore(tarea_crear_timer, "pi7_timer", 4096, NULL, 10, NULL, 1);
  xSemaphoreTake(listo_sw, portMAX_DELAY);
}

// =============================================================================
// Generador HARDWARE
// =============================================================================
static inline void IRAM_ATTR hw_cortar(int i) {
  pin_nivel(PIN_STEP[i], nivel_step(false));
  esp_rom_gpio_connect_out_signal(PIN_STEP[i], SIG_GPIO_OUT_IDX, false, false);
  ej[i].conectado = false;
}

static void hw_conectar(int i) {
  ledc_timer_rst(LEDC_LOW_SPEED_MODE, (ledc_timer_t)i);  // el primer pulso sale completo
  esp_rom_gpio_connect_out_signal(PIN_STEP[i], LEDC_LS_SIG_OUT0_IDX + i, !STEP_ACTIVO_ALTO, false);
  ej[i].conectado = true;
}

static bool IRAM_ATTR hw_al_llegar(pcnt_unit_handle_t u, const pcnt_watch_event_data_t *ed, void *ctx) {
  int i = (int)(intptr_t)ctx;
  if (ej[i].wp > 0 && ed->watch_point_value == ej[i].wp) hw_cortar(i);
  return false;
}

static int32_t hw_cuenta(int i) {
  int c = 0;
  pcnt_unit_get_count(ej[i].unidad, &c);
  return c;
}

// Punto de corte deseado para el tramo actual: >0 pulsos, 0 = ya llegó, -1 = sin corte
static int hw_wp_deseado(int i) {
  eje_t *e = &ej[i];
  if (!e->limitar) return -1;
  int32_t rem = e->objetivo - e->base;
  if (rem == 0) return 0;
  bool hacia = (rem > 0) == (e->hw_dir > 0);
  if (!hacia) return -1;
  int32_t n = labs(rem);
  return (n <= PASOS_HW_MAX_TRAMO) ? (int)n : -1;
}

static void hw_cambiar_wp(int i, int nuevo) {
  eje_t *e = &ej[i];
  if (nuevo == e->wp) return;
  if (e->wp > 0) pcnt_unit_remove_watch_point(e->unidad, e->wp);
  e->wp = 0;
  if (nuevo > 0) {
    if (e->conectado && hw_cuenta(i) >= nuevo) {  // ya lo pasó mientras se cambiaba
      hw_cortar(i);
      return;
    }
    pcnt_unit_add_watch_point(e->unidad, nuevo);
    e->wp = nuevo;
  }
}

static void hw_aplicar(int i, float v) {
  eje_t *e = &ej[i];
  float f = fabsf(v);
  int8_t s = (v > 0) ? 1 : -1;
  if (f < FREC_HW_MIN_HZ) {
    if (e->conectado) hw_cortar(i);
    return;
  }
  if (e->conectado && s != e->hw_dir) hw_cortar(i);  // no debería pasar: el perfil pasa por cero
  if (!e->conectado) {
    // Nuevo tramo: consolidar posición, sentido y punto de corte
    int32_t c = hw_cuenta(i);
    e->base += e->hw_dir * c;
    pcnt_unit_clear_count(e->unidad);
    if (s != e->hw_dir) {
      e->hw_dir = s;
      gpio_set_level(PIN_DIR[i], nivel_dir(i, s));
      esp_rom_delay_us(20);  // DM556: DIR ≥ 5 µs antes del pulso
    }
    int wp = hw_wp_deseado(i);
    if (wp == 0) return;
    hw_cambiar_wp(i, wp > 0 ? wp : 0);
    ledc_set_freq(LEDC_LOW_SPEED_MODE, (ledc_timer_t)i, (uint32_t)f);
    e->f_aplicada = f;
    hw_conectar(i);
  } else {
    if (fabsf(f - e->f_aplicada) >= 1.0f) {
      ledc_set_freq(LEDC_LOW_SPEED_MODE, (ledc_timer_t)i, (uint32_t)f);
      e->f_aplicada = f;
    }
    int wp = hw_wp_deseado(i);
    hw_cambiar_wp(i, wp > 0 ? wp : 0);
    if (wp == 0) hw_cortar(i);
  }
}

static void iniciar_hardware(void) {
  for (int i = 0; i < N_EJES; i++) {
    eje_t *e = &ej[i];
    gpio_config_t c = {
        .pin_bit_mask = 1ULL << PIN_DIR[i],
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    gpio_config(&c);
    gpio_set_level(PIN_DIR[i], nivel_dir(i, +1));

    // 1) PCNT: cuenta el fin de cada pulso (flanco que apaga el optoacoplador)
    pcnt_unit_config_t uc = {.low_limit = -HW_LIMITE_PCNT, .high_limit = HW_LIMITE_PCNT, .flags.accum_count = 1};
    ESP_ERROR_CHECK(pcnt_new_unit(&uc, &e->unidad));
    pcnt_glitch_filter_config_t fc = {.max_glitch_ns = 1000};
    ESP_ERROR_CHECK(pcnt_unit_set_glitch_filter(e->unidad, &fc));
    pcnt_chan_config_t cc = {.edge_gpio_num = PIN_STEP[i], .level_gpio_num = -1};
    ESP_ERROR_CHECK(pcnt_new_channel(e->unidad, &cc, &e->canal));
    if (STEP_ACTIVO_ALTO)
      pcnt_channel_set_edge_action(e->canal, PCNT_CHANNEL_EDGE_ACTION_HOLD, PCNT_CHANNEL_EDGE_ACTION_INCREASE);
    else
      pcnt_channel_set_edge_action(e->canal, PCNT_CHANNEL_EDGE_ACTION_INCREASE, PCNT_CHANNEL_EDGE_ACTION_HOLD);
    pcnt_unit_add_watch_point(e->unidad, HW_LIMITE_PCNT);   // necesarios para accum_count
    pcnt_unit_add_watch_point(e->unidad, -HW_LIMITE_PCNT);
    pcnt_event_callbacks_t cbs = {.on_reach = hw_al_llegar};
    ESP_ERROR_CHECK(pcnt_unit_register_event_callbacks(e->unidad, &cbs, (void *)(intptr_t)i));
    ESP_ERROR_CHECK(pcnt_unit_enable(e->unidad));
    ESP_ERROR_CHECK(pcnt_unit_clear_count(e->unidad));
    ESP_ERROR_CHECK(pcnt_unit_start(e->unidad));

    // 2) LEDC: timer i, canal i, 10 bits → hasta 78 kHz; arranca a 1 kHz y desconectado
    ledc_timer_config_t tc = {
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .duty_resolution = LEDC_TIMER_10_BIT,
        .timer_num = (ledc_timer_t)i,
        .freq_hz = 1000,
        .clk_cfg = LEDC_AUTO_CLK,
    };
    ESP_ERROR_CHECK(ledc_timer_config(&tc));
    ledc_channel_config_t ch = {
        .gpio_num = PIN_STEP[i],
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .channel = (ledc_channel_t)i,
        .intr_type = LEDC_INTR_DISABLE,
        .timer_sel = (ledc_timer_t)i,
        .duty = 512,  // 50 %
        .hpoint = 0,
    };
    ESP_ERROR_CHECK(ledc_channel_config(&ch));
    hw_cortar(i);  // inmediatamente: no sale ningún pulso hasta que se pida

    // 3) El LEDC dejó el pin sólo como salida: rehabilitar la entrada para que el PCNT lo vea
    gpio_pullup_dis(PIN_STEP[i]);
    gpio_pulldown_dis(PIN_STEP[i]);
    PIN_INPUT_ENABLE(GPIO_PIN_MUX_REG[PIN_STEP[i]]);

    e->base = 0;
    e->hw_dir = +1;
    e->wp = 0;
    e->f_aplicada = 0;
  }
}

// =============================================================================
// Perfil común
// =============================================================================
static inline float aproximar(float v, float v_des, float dv) {
  if (v < v_des) return (v_des - v > dv) ? v + dv : v_des;
  return (v - v_des > dv) ? v - dv : v_des;
}

static bool se_mueve(const eje_t *e) { return e->modo != REPOSO || e->v != 0.0f; }

// Dentro del candado. En hardware corta el pin (función de ROM, corta).
static void parar_eje_sin_candado(int i, int32_t pos) {
  eje_t *e = &ej[i];
  e->modo = REPOSO;
  e->v = 0;
  e->v_obj = 0;
  e->inc = 0;
  e->paso_pendiente = false;
  e->objetivo = pos;
  if (gen == GEN_HARDWARE) hw_cortar(i);
}

static void encolar(const mot_evento_t *ev) {
  uint8_t sig = (cola_fin + 1) % TAM_COLA;
  if (sig == cola_ini) cola_ini = (cola_ini + 1) % TAM_COLA;
  cola[cola_fin] = *ev;
  cola_fin = sig;
}

static void revisar_finales(void) {
  for (int j = 0; j < N_EJES; j++) {
    bool act = fin_activo(j);
    bool subida = act && !final_previo[j];
    final_previo[j] = act;
    if (!subida) continue;
    mot_evento_t ev = {0};
    ev.final_eje = j;
    ev.t_deteccion_us = (uint32_t)esp_timer_get_time();
    ev.t_flanco_us = fin_primer_flanco_us(j);
    int32_t pos[N_EJES];
    for (int i = 0; i < N_EJES; i++) pos[i] = mot_posicion(i);
    portENTER_CRITICAL(&candado);
    for (int i = 0; i < N_EJES; i++) {
      ev.pos[i] = pos[i];
      ev.vel[i] = ej[i].v;
      if (se_mueve(&ej[i])) ev.ejes_en_movimiento |= (1 << i);
    }
    if (pol == FINAL_DETIENE_TODO) {
      for (int i = 0; i < N_EJES; i++) {
        if (se_mueve(&ej[i])) ev.ejes_detenidos |= (1 << i);
        parar_eje_sin_candado(i, pos[i]);
      }
    } else if (pol == FINAL_BLOQUEA_SU_EJE && ej[j].v * SENTIDO_FINAL[j] > 0) {
      ev.ejes_detenidos |= (1 << j);
      parar_eje_sin_candado(j, pos[j]);
      ej[j].n_bloqueos++;
    }
    encolar(&ev);
    portEXIT_CRITICAL(&candado);
  }
}

static void actualizar_eje(int i) {
  int32_t pos = mot_posicion(i);
  portENTER_CRITICAL(&candado);
  eje_t *e = &ej[i];
  float v = e->v;
  switch (e->modo) {
    case REPOSO:
      v = 0;
      break;
    case POSICION: {
      int32_t d = e->objetivo - pos;
      if (d == 0) {
        v = 0;
        e->modo = REPOSO;
        break;
      }
      float v_des = sqrtf(2.0f * e->a * fabsf((float)d));
      if (v_des > e->vmax) v_des = e->vmax;
      if (d < 0) v_des = -v_des;
      v = aproximar(v, v_des, e->a * DT);
      float v_min = (VEL_MIN < e->vmax) ? VEL_MIN : e->vmax;
      if (fabsf(v) < v_min && (v == 0 || ((v > 0) == (d > 0)))) v = (d > 0) ? v_min : -v_min;
      break;
    }
    case VELOCIDAD:
      v = aproximar(v, e->v_obj, e->a * DT);
      if (e->v_obj == 0 && v == 0) e->modo = REPOSO;
      break;
  }
  if (pol == FINAL_BLOQUEA_SU_EJE && fin_activo(i) && v * SENTIDO_FINAL[i] > 0) {
    parar_eje_sin_candado(i, pos);
    e->n_bloqueos++;
    v = 0;
  }
  float tope = mot_paso_max();
  if (v > tope) v = tope;
  if (v < -tope) v = -tope;
  e->v = v;
  if (gen == GEN_SOFTWARE) {
    if (v > 0) e->dir_pedida = +1;
    else if (v < 0) e->dir_pedida = -1;
    e->inc = (uint32_t)(fabsf(v) * (4294967296.0f / F_TICK));
  }
  portEXIT_CRITICAL(&candado);
  if (gen == GEN_HARDWARE) hw_aplicar(i, v);
}

static void callback_perfil(void *arg) {
  uint32_t t0 = (uint32_t)esp_timer_get_time();
  if (muestrear_fin) fin_muestrear();
  revisar_finales();
  for (int i = 0; i < N_EJES; i++) actualizar_eje(i);
  uint32_t dt = (uint32_t)esp_timer_get_time() - t0;
  if (dt > perfil_max) perfil_max = dt;
}

// =============================================================================
// API
// =============================================================================
void mot_iniciar(generador_t g, bool muestrear_finales) {
  gen = g;
  muestrear_fin = muestrear_finales;
  for (int i = 0; i < N_EJES; i++) {
    eje_t *e = &ej[i];
    e->modo = REPOSO;
    e->v = e->v_obj = 0;
    e->objetivo = 0;
    e->limitar = false;
    e->n_bloqueos = 0;
    e->pos = 0;
    e->acc = e->inc = 0;
    e->dir = e->dir_pedida = +1;
    e->pulso_alto = e->paso_pendiente = false;
    e->espera_dir = 0;
    e->conectado = false;
    mot_fijar_limites_art(i, VEL_TEST_DEG_S[i], ACEL_TEST_DEG_S2[i]);
    final_previo[i] = fin_activo(i);
  }
  if (gen == GEN_SOFTWARE) iniciar_software();
  else iniciar_hardware();

  esp_timer_create_args_t args = {
      .callback = callback_perfil,
      .arg = NULL,
      .dispatch_method = ESP_TIMER_TASK,
      .name = "pi7_perfil",
  };
  ESP_ERROR_CHECK(esp_timer_create(&args, &timer_perfil));
  ESP_ERROR_CHECK(esp_timer_start_periodic(timer_perfil, PERIODO_PERFIL_US));
  t_carga = esp_timer_get_time();
}

generador_t mot_generador(void) { return gen; }
const char *mot_nombre_generador(void) {
  return gen == GEN_SOFTWARE ? "SOFTWARE (ISR gptimer)" : "HARDWARE (LEDC + PCNT)";
}

float mot_paso_max(void) { return gen == GEN_SOFTWARE ? PASO_MAX_SW : (float)FREC_HW_MAX_HZ; }

static float limitar_vel(int e, float v) {
  float tope = VEL_ABS_MAX_DEG_S * pasos_grado_art(e);
  if (tope > mot_paso_max()) tope = mot_paso_max();
  if (v > tope) v = tope;
  if (v < -tope) v = -tope;
  return v;
}

void mot_fijar_vel_max(int e, float pps) { ej[e].vmax = fabsf(limitar_vel(e, pps)); }
void mot_fijar_acel(int e, float pps2) { ej[e].a = (pps2 > 1.0f) ? pps2 : 1.0f; }
float mot_vel_max(int e) { return ej[e].vmax; }
float mot_acel(int e) { return ej[e].a; }
void mot_fijar_limites_art(int e, float vel, float acel) {
  mot_fijar_vel_max(e, vel * pasos_grado_art(e));
  mot_fijar_acel(e, acel * pasos_grado_art(e));
}

void mot_mover_a(int e, int32_t p) {
  portENTER_CRITICAL(&candado);
  ej[e].objetivo = p;
  ej[e].limitar = true;
  ej[e].modo = POSICION;
  portEXIT_CRITICAL(&candado);
}

void mot_mover_rel(int e, int32_t delta) {
  int32_t pos = mot_posicion(e);
  portENTER_CRITICAL(&candado);
  int32_t base = (ej[e].modo == POSICION) ? ej[e].objetivo : pos;
  ej[e].objetivo = base + delta;
  ej[e].limitar = true;
  ej[e].modo = POSICION;
  portEXIT_CRITICAL(&candado);
}

void mot_mover_rel_grados_motor(int e, float deg) { mot_mover_rel(e, (int32_t)lroundf(deg * pasos_grado_motor(e))); }
void mot_mover_rel_grados_art(int e, float deg) { mot_mover_rel(e, (int32_t)lroundf(deg * pasos_grado_art(e))); }

void mot_jog(int e, float pps) {
  pps = limitar_vel(e, pps);
  portENTER_CRITICAL(&candado);
  ej[e].limitar = false;
  ej[e].v_obj = pps;
  ej[e].modo = VELOCIDAD;
  portEXIT_CRITICAL(&candado);
}

void mot_detener(int e) {
  portENTER_CRITICAL(&candado);
  if (ej[e].modo != REPOSO) {
    ej[e].limitar = false;
    ej[e].v_obj = 0;
    ej[e].modo = VELOCIDAD;
  }
  portEXIT_CRITICAL(&candado);
}

void mot_parar_ya(int e) {
  int32_t p = mot_posicion(e);
  portENTER_CRITICAL(&candado);
  parar_eje_sin_candado(e, p);
  portEXIT_CRITICAL(&candado);
}

void mot_parar_todo(void) {
  for (int i = 0; i < N_EJES; i++) mot_parar_ya(i);
}

bool mot_en_movimiento(int e) { return se_mueve(&ej[e]); }
bool mot_alguno_en_movimiento(void) {
  for (int i = 0; i < N_EJES; i++)
    if (se_mueve(&ej[i])) return true;
  return false;
}

int32_t mot_posicion(int e) {
  if (gen == GEN_SOFTWARE) return ej[e].pos;
  return ej[e].base + ej[e].hw_dir * hw_cuenta(e);
}

void mot_fijar_posicion(int e, int32_t p) {
  if (se_mueve(&ej[e])) return;
  if (gen == GEN_SOFTWARE) {
    portENTER_CRITICAL(&candado);
    ej[e].pos = p;
    ej[e].objetivo = p;
    portEXIT_CRITICAL(&candado);
  } else {
    int32_t c = hw_cuenta(e);
    ej[e].base = p - ej[e].hw_dir * c;
    ej[e].objetivo = p;
  }
}

float mot_velocidad(int e) { return ej[e].v; }
int32_t mot_objetivo(int e) { return ej[e].objetivo; }
float mot_grados_motor(int e) { return mot_posicion(e) / pasos_grado_motor(e); }
float mot_grados_art(int e) { return mot_posicion(e) / pasos_grado_art(e); }

void mot_fijar_politica(politica_final_t p) { pol = p; }
politica_final_t mot_politica(void) { return pol; }

bool mot_leer_evento(mot_evento_t *ev) {
  bool hay = false;
  portENTER_CRITICAL(&candado);
  if (cola_ini != cola_fin) {
    *ev = cola[cola_ini];
    cola_ini = (cola_ini + 1) % TAM_COLA;
    hay = true;
  }
  portEXIT_CRITICAL(&candado);
  return hay;
}

uint32_t mot_perfil_max_us(void) { return perfil_max; }
uint32_t mot_bloqueos(int e) { return ej[e].n_bloqueos; }
void mot_reiniciar_diagnostico(void) {
  perfil_max = 0;
  for (int i = 0; i < N_EJES; i++) ej[i].n_bloqueos = 0;
}

float mot_carga_isr(void) {
  int64_t t = esp_timer_get_time();
  float dt = (t - t_carga) * 1e-6f;
  uint32_t c = ciclos_isr;
  ciclos_isr = 0;
  t_carga = t;
  if (dt <= 0) return 0;
  return 100.0f * c / (CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ * 1e6f * dt);
}

int32_t mot_hw_cuenta(int e) { return gen == GEN_HARDWARE ? hw_cuenta(e) : 0; }
