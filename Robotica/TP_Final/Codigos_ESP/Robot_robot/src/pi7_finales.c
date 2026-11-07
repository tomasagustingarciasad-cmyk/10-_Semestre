// =============================================================================
// pi7_finales.c — Implementación. Ver el .h.
// Autor: Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include "pi7_finales.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "esp_attr.h"

static volatile uint32_t flancos[N_EJES];
static volatile uint32_t t_primer[N_EJES];
static volatile bool armado[N_EJES];
static volatile uint32_t n_activaciones[N_EJES];
static volatile uint8_t integrador[N_EJES];
static volatile bool estado[N_EJES];

static void IRAM_ATTR isr_flanco(void *arg) {
  int e = (int)(intptr_t)arg;
  flancos[e]++;
  if (armado[e]) {
    t_primer[e] = (uint32_t)esp_timer_get_time();
    armado[e] = false;
  }
}

static bool leer_activo(int e) { return (gpio_get_level(PIN_FINAL[e]) != 0) == FINAL_ACTIVO_ALTO[e]; }

void fin_iniciar(void) {
  esp_err_t r = gpio_install_isr_service(0);
  (void)r;  // ESP_ERR_INVALID_STATE si ya estaba instalado: no es error
  for (int e = 0; e < N_EJES; e++) {
    flancos[e] = 0;
    n_activaciones[e] = 0;
    armado[e] = true;
    if (PIN_FINAL[e] < 0) continue;
    gpio_config_t c = {
        .pin_bit_mask = 1ULL << PIN_FINAL[e],
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = FINAL_PULLUP_INTERNO ? GPIO_PULLUP_ENABLE : GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_ANYEDGE,
    };
    gpio_config(&c);
    gpio_isr_handler_add(PIN_FINAL[e], isr_flanco, (void *)(intptr_t)e);
    bool a = leer_activo(e);
    estado[e] = a;
    integrador[e] = a ? FINAL_FILTRO_MUESTRAS : 0;
  }
}

void fin_muestrear(void) {
  for (int e = 0; e < N_EJES; e++) {
    if (PIN_FINAL[e] < 0) continue;
    bool a = leer_activo(e);
    uint8_t c = integrador[e];
    if (a && c < FINAL_FILTRO_MUESTRAS) c++;
    if (!a && c > 0) c--;
    integrador[e] = c;
    if (!estado[e] && c >= FINAL_FILTRO_MUESTRAS) {
      estado[e] = true;
      n_activaciones[e]++;
      armado[e] = true;
    } else if (estado[e] && c == 0) {
      estado[e] = false;
      armado[e] = true;
    }
  }
}

bool fin_activo(int e) { return e >= 0 && e < N_EJES && PIN_FINAL[e] >= 0 && estado[e]; }
bool fin_nivel_crudo(int e) { return PIN_FINAL[e] >= 0 && gpio_get_level(PIN_FINAL[e]) != 0; }
uint32_t fin_flancos_crudos(int e) { return flancos[e]; }
uint32_t fin_activaciones(int e) { return n_activaciones[e]; }
uint32_t fin_primer_flanco_us(int e) { return t_primer[e]; }
void fin_reiniciar_contadores(void) {
  for (int e = 0; e < N_EJES; e++) flancos[e] = n_activaciones[e] = 0;
}
