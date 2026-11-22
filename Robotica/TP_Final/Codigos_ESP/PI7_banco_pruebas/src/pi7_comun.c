// =============================================================================
// pi7_comun.c — Implementación. Ver el .h.
// Autor: Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include "pi7_comun.h"
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/uart.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "esp_system.h"
#include "esp_chip_info.h"
#include "esp_flash.h"
#include "esp_idf_version.h"
#include "sdkconfig.h"

#if ESP_IDF_VERSION < ESP_IDF_VERSION_VAL(5, 0, 0)
#error "El banco necesita ESP-IDF 5.x (actualizar la plataforma espressif32 de PlatformIO)."
#endif

static void (*servicio_fn)(void) = NULL;
static bool alarma = false;
static char buf_linea[128];
static int idx_linea = 0;

// -----------------------------------------------------------------------------
void com_iniciar_consola(void) {
  setvbuf(stdout, NULL, _IONBF, 0);
  uart_driver_install(UART_NUM_0, 512, 0, 0, NULL, 0);
  if (PIN_LED >= 0) {
    gpio_reset_pin(PIN_LED);
    gpio_set_direction(PIN_LED, GPIO_MODE_OUTPUT);
  }
}

uint32_t com_ms(void) { return (uint32_t)(esp_timer_get_time() / 1000); }
uint32_t com_us(void) { return (uint32_t)esp_timer_get_time(); }
float com_s(void) { return esp_timer_get_time() * 1e-6f; }

const char *com_motivo_reset(void) {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON:   return "encendido";
    case ESP_RST_EXT:       return "pin EN externo";
    case ESP_RST_SW:        return "software (comando reset)";
    case ESP_RST_PANIC:     return "PANIC (excepción del programa)";
    case ESP_RST_INT_WDT:   return "watchdog de interrupción";
    case ESP_RST_TASK_WDT:  return "watchdog de tarea";
    case ESP_RST_WDT:       return "otro watchdog";
    case ESP_RST_DEEPSLEEP: return "salida de deep sleep";
    case ESP_RST_BROWNOUT:  return "BROWNOUT (caída de tensión)";
    case ESP_RST_SDIO:      return "SDIO";
    default:                return "desconocido";
  }
}

bool com_banner(void) {
  esp_chip_info_t chip;
  esp_chip_info(&chip);
  uint32_t flash = 0;
  esp_flash_get_size(NULL, &flash);
  printf("\n");
  com_linea('=', 72);
  printf("PI7 · banco de pruebas del robot · ESP-IDF %s\n", esp_get_idf_version());
  com_linea('=', 72);
  printf("Compilado      : %s %s\n", __DATE__, __TIME__);
  printf("Chip           : ESP32 rev %d · %d núcleos · %d MHz · flash %lu kB\n", chip.revision, chip.cores,
         CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ, (unsigned long)(flash / 1024));
  printf("Tick FreeRTOS  : %d Hz%s\n", CONFIG_FREERTOS_HZ,
         CONFIG_FREERTOS_HZ == 1000 ? "" : "  !! se esperaba 1000: borrar sdkconfig.nodemcu-32s y recompilar");
  printf("Motivo de reset: %s\n", com_motivo_reset());
  bool brownout = (esp_reset_reason() == ESP_RST_BROWNOUT);
  if (brownout) {
    printf("!!! BROWNOUT: se cayó la alimentación del ESP32. Sospechosos: servo o motores tirando el 5 V\n");
    printf("!!! de la ATX, VIN flojo, GND sin llegar al nodo central.\n");
  }
  esp_reset_reason_t r = esp_reset_reason();
  if (r == ESP_RST_PANIC || r == ESP_RST_INT_WDT || r == ESP_RST_TASK_WDT)
    printf("!!! El último reset fue por una falla del programa. Anotá qué se estaba haciendo.\n");
  com_linea('-', 72);
  return brownout;
}

// -----------------------------------------------------------------------------
// Validación de pines
// -----------------------------------------------------------------------------
typedef struct {
  int8_t pin;
  char nombre[16];
  bool salida;
} pin_usado_t;

static bool es_flash(int p) { return p >= 6 && p <= 11; }
static bool es_uart0(int p) { return p == 1 || p == 3; }
static bool es_solo_entrada(int p) { return p >= 34 && p <= 39; }
static bool es_arranque(int p) { return p == 0 || p == 2 || p == 5 || p == 12 || p == 15; }
static bool existe(int p) { return p >= 0 && p <= 39 && !(p == 20 || p == 24 || (p >= 28 && p <= 31)); }

static int agregar(pin_usado_t *l, int n, int8_t pin, const char *base, int eje, bool salida) {
  if (pin < 0 || n >= 20) return n;
  l[n].pin = pin;
  l[n].salida = salida;
  if (eje >= 0) snprintf(l[n].nombre, sizeof(l[n].nombre), "%s eje %d", base, eje + 1);
  else snprintf(l[n].nombre, sizeof(l[n].nombre), "%s", base);
  return n + 1;
}

bool com_validar_pines(com_uso_t uso) {
  pin_usado_t l[20];
  int n = 0;
  for (int e = 0; e < N_EJES; e++) {
    if (uso.motores) {
      n = agregar(l, n, PIN_STEP[e], "STEP", e, true);
      n = agregar(l, n, PIN_DIR[e], "DIR", e, true);
    }
    if (uso.finales) n = agregar(l, n, PIN_FINAL[e], "FINAL", e, false);
  }
  if (uso.i2c) {
    n = agregar(l, n, PIN_SDA, "SDA", -1, false);
    n = agregar(l, n, PIN_SCL, "SCL", -1, false);
  }
  if (uso.servo) n = agregar(l, n, PIN_SERVO, "SERVO", -1, true);

  bool ok = true;
  printf("Pines usados por este test:\n");
  for (int i = 0; i < n; i++) {
    int p = l[i].pin;
    printf("  GPIO%-3d %-14s %s", p, l[i].nombre, l[i].salida ? "salida " : "entrada");
    if (!existe(p)) { printf("  ERROR: no existe en el ESP32"); ok = false; }
    else if (es_flash(p)) { printf("  ERROR: pin de la flash interna"); ok = false; }
    else if (es_uart0(p)) { printf("  ERROR: UART0 (USB-serie)"); ok = false; }
    else if (l[i].salida && es_solo_entrada(p)) { printf("  ERROR: 34-39 son sólo entrada"); ok = false; }
    else if (p == 12) printf("  OJO: GPIO12 en alto al arrancar pone la flash a 1,8 V");
    else if (es_arranque(p)) printf("  OJO: pin de arranque");
    else if (p == 14 && l[i].salida) printf("  OJO: GPIO14 puede dar pulsos durante el arranque (posible paso suelto al resetear)");
    for (int j = 0; j < i; j++)
      if (l[j].pin == p) { printf("  ERROR: repetido con %s", l[j].nombre); ok = false; }
    printf("\n");
  }
  if (!ok) {
    printf("!!! Errores de pinout: corregí pi7_config.h. Test detenido ('reset' para volver al menú).\n");
    com_alarma(true);
  }
  com_linea('-', 72);
  return ok;
}

// -----------------------------------------------------------------------------
// Consola
// -----------------------------------------------------------------------------
static int leer_byte(uint8_t *c) { return uart_read_bytes(UART_NUM_0, c, 1, 0); }

static int partir(char *s, char *tok[], int max_tok) {
  int n = 0;
  char *p = s;
  while (*p && n < max_tok) {
    while (*p == ' ' || *p == '\t' || *p == ',') p++;
    if (!*p) break;
    tok[n++] = p;
    while (*p && *p != ' ' && *p != '\t' && *p != ',') { *p = (char)tolower((unsigned char)*p); p++; }
    if (*p) *p++ = 0;
  }
  return n;
}

int com_leer_comando(char *tok[], int max_tok) {
  uint8_t c;
  while (leer_byte(&c) == 1) {
    if (c == '\r' || c == '\n') {
      if (idx_linea == 0) continue;
      printf("\n");
      buf_linea[idx_linea] = 0;
      idx_linea = 0;
      return partir(buf_linea, tok, max_tok);
    }
    if (c == 8 || c == 127) {  // backspace
      if (idx_linea > 0) { idx_linea--; printf("\b \b"); }
      continue;
    }
    if (idx_linea < (int)sizeof(buf_linea) - 1 && c >= 32) {
      buf_linea[idx_linea++] = (char)c;
      printf("%c", c);  // eco
    }
  }
  return 0;
}

void com_vaciar_entrada(void) {
  vTaskDelay(pdMS_TO_TICKS(5) + 1);
  uart_flush_input(UART_NUM_0);
  idx_linea = 0;
}

bool com_hay_tecla(void) {
  size_t n = 0;
  uart_get_buffered_data_len(UART_NUM_0, &n);
  if (n == 0) return false;
  com_vaciar_entrada();
  return true;
}

char com_preguntar(const char *pregunta, uint32_t timeout_ms) {
  com_vaciar_entrada();
  printf("%s ", pregunta);
  uint32_t t0 = com_ms();
  char *tok[2];
  while (com_ms() - t0 < timeout_ms) {
    com_servicio();
    if (com_leer_comando(tok, 2) > 0) return tok[0][0];
    vTaskDelay(1);
  }
  printf("(sin respuesta)\n");
  return 0;
}

// -----------------------------------------------------------------------------
void com_fijar_servicio(void (*fn)(void)) { servicio_fn = fn; }

void com_servicio(void) {
  if (servicio_fn) servicio_fn();
  com_latido();
}

bool com_esperar(uint32_t ms, bool abortable) {
  uint32_t t0 = com_ms();
  while (com_ms() - t0 < ms) {
    com_servicio();
    if (abortable && com_hay_tecla()) {
      printf("** abortado por el usuario **\n");
      return false;
    }
    vTaskDelay(1);  // cede la CPU: el watchdog de la tarea idle tiene que correr
  }
  return true;
}

// -----------------------------------------------------------------------------
void com_csv_inicio(const char *nombre, const char *encabezado) { printf("#CSV_INI %s\n%s\n", nombre, encabezado); }
void com_csv_fin(void) { printf("#CSV_FIN\n"); }

void com_linea(char c, int n) {
  for (int i = 0; i < n; i++) putchar(c);
  putchar('\n');
}

int com_eje_desde_texto(const char *t) {
  if (!t) { printf("Falta el eje (1, 2 o 3).\n"); return -1; }
  int e = atoi(t) - 1;
  if (e < 0 || e >= N_EJES) {
    printf("Eje inválido '%s'. 1 = q1 base, 2 = t2 hombro, 3 = t3 codo.\n", t);
    return -1;
  }
  return e;
}

void com_alarma(bool on) { alarma = on; }

void com_latido(void) {
  if (PIN_LED < 0) return;
  uint32_t periodo = alarma ? 150 : 1000;
  gpio_set_level(PIN_LED, (com_ms() % periodo) < periodo / 2);
}

void com_reiniciar(void) {
  printf("Reiniciando...\n");
  vTaskDelay(pdMS_TO_TICKS(50) + 1);
  esp_restart();
}

void com_bloquear_por_error(void) {
  char *tok[2];
  com_alarma(true);
  while (true) {
    com_latido();
    if (com_leer_comando(tok, 2) > 0 && !strcmp(tok[0], "reset")) com_reiniciar();
    vTaskDelay(10);
  }
}
