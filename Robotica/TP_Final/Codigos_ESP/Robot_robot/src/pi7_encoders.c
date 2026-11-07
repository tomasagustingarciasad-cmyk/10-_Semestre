// =============================================================================
// pi7_encoders.c — Implementación. Ver el .h.
// Registros AS5600: 0x0B STATUS (bit5 MD, bit4 ML, bit3 MH) · 0x0C/0x0D RAW ANGLE ·
//                   0x1A AGC · 0x1B/0x1C MAGNITUDE
// Autor: Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#include "pi7_encoders.h"
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "driver/i2c.h"
#include "esp_timer.h"

#define PUERTO I2C_NUM_0
#define TIMEOUT_I2C (pdMS_TO_TICKS(20) > 0 ? pdMS_TO_TICKS(20) : 1)

static const uint8_t REG_STATUS = 0x0B, REG_RAW = 0x0C, REG_AGC = 0x1A, REG_MAG = 0x1B;
static int canal_actual = -1;
static bool hay_mux = false;
static bool instalado = false;
static uint32_t frec = 400000;

static int32_t acumulado[N_EJES];
static uint16_t anterior[N_EJES];
static bool primera[N_EJES];
static uint32_t n_lect[N_EJES], n_err[N_EJES], t_ult[N_EJES], t_max[N_EJES], n_saltos[N_EJES];

static void instalar(void) {
  if (instalado) i2c_driver_delete(PUERTO);
  i2c_config_t c = {
      .mode = I2C_MODE_MASTER,
      .sda_io_num = PIN_SDA,
      .scl_io_num = PIN_SCL,
      .sda_pullup_en = GPIO_PULLUP_DISABLE,  // hay 2,2 kΩ externos
      .scl_pullup_en = GPIO_PULLUP_DISABLE,
      .master.clk_speed = frec,
  };
  i2c_param_config(PUERTO, &c);
  i2c_driver_install(PUERTO, I2C_MODE_MASTER, 0, 0, 0);
  instalado = true;
  canal_actual = -1;
}

static bool probar(uint8_t dir) {
  i2c_cmd_handle_t cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (uint8_t)(dir << 1) | I2C_MASTER_WRITE, true);
  i2c_master_stop(cmd);
  esp_err_t r = i2c_master_cmd_begin(PUERTO, cmd, TIMEOUT_I2C);
  i2c_cmd_link_delete(cmd);
  return r == ESP_OK;
}

static bool escribir_mux(uint8_t mascara) {
  return i2c_master_write_to_device(PUERTO, DIR_MUX, &mascara, 1, TIMEOUT_I2C) == ESP_OK;
}

static bool seleccionar(uint8_t canal) {
  if (canal_actual == canal) return true;
  if (!escribir_mux((uint8_t)(1u << canal))) {
    canal_actual = -1;
    return false;
  }
  canal_actual = canal;
  return true;
}

static bool leer_reg(uint8_t reg, uint8_t *buf, size_t n) {
  return i2c_master_write_read_device(PUERTO, DIR_AS5600, &reg, 1, buf, n, TIMEOUT_I2C) == ESP_OK;
}

bool enc_iniciar(uint32_t frec_hz) {
  frec = frec_hz;
  instalar();
  hay_mux = probar(DIR_MUX);
  for (int e = 0; e < N_EJES; e++) {
    acumulado[e] = 0;
    primera[e] = true;
  }
  enc_reiniciar_estadisticas();
  return hay_mux;
}

void enc_fijar_frecuencia(uint32_t frec_hz) {
  frec = frec_hz;
  instalar();
}
uint32_t enc_frecuencia(void) { return frec; }
bool enc_mux_presente(void) { return hay_mux; }

bool enc_leer_crudo(int e, uint16_t *crudo) {
  uint32_t t0 = (uint32_t)esp_timer_get_time();
  uint8_t b[2];
  bool ok = seleccionar(CANAL_MUX[e]) && leer_reg(REG_RAW, b, 2);
  uint32_t dt = (uint32_t)esp_timer_get_time() - t0;
  n_lect[e]++;
  t_ult[e] = dt;
  if (dt > t_max[e]) t_max[e] = dt;
  if (!ok) {
    n_err[e]++;
    canal_actual = -1;
    return false;
  }
  *crudo = (uint16_t)(((b[0] & 0x0F) << 8) | b[1]);
  return true;
}

bool enc_leer_diag(int e, enc_diag_t *d) {
  uint8_t st, agc, mag[2];
  if (!seleccionar(CANAL_MUX[e]) || !leer_reg(REG_STATUS, &st, 1) || !leer_reg(REG_AGC, &agc, 1) ||
      !leer_reg(REG_MAG, mag, 2))
    return false;
  d->md = st & 0x20;
  d->ml = st & 0x10;
  d->mh = st & 0x08;
  d->agc = agc;
  d->magnitud = (uint16_t)(((mag[0] & 0x0F) << 8) | mag[1]);
  return true;
}

bool enc_presente(int e) { return seleccionar(CANAL_MUX[e]) && probar(DIR_AS5600); }

bool enc_actualizar(int e) {
  uint16_t c;
  if (!enc_leer_crudo(e, &c)) return false;
  if (primera[e]) {
    anterior[e] = c;
    primera[e] = false;
    return true;
  }
  int32_t d = (int32_t)c - (int32_t)anterior[e];
  if (d > 2048) d -= 4096;
  if (d < -2048) d += 4096;
  if (d > 1024 || d < -1024) n_saltos[e]++;
  anterior[e] = c;
  acumulado[e] += ENC_INVERTIDO[e] ? -d : d;
  return true;
}

bool enc_actualizar_todos(void) {
  bool ok = true;
  for (int e = 0; e < N_EJES; e++) ok &= enc_actualizar(e);
  return ok;
}

int32_t enc_cuentas(int e) { return acumulado[e]; }
uint16_t enc_ultimo_crudo(int e) { return anterior[e]; }
void enc_cero(int e) { acumulado[e] = 0; }
void enc_cero_todos(void) {
  for (int e = 0; e < N_EJES; e++) acumulado[e] = 0;
}
float enc_grados_motor(int e) { return acumulado[e] / cuentas_grado_motor(); }
float enc_grados_art(int e) { return enc_grados_motor(e) / RELACION_G[e]; }
uint32_t enc_lecturas(int e) { return n_lect[e]; }
uint32_t enc_errores(int e) { return n_err[e]; }
uint32_t enc_tiempo_ultima_us(int e) { return t_ult[e]; }
uint32_t enc_tiempo_max_us(int e) { return t_max[e]; }
uint32_t enc_saltos(int e) { return n_saltos[e]; }
void enc_reiniciar_estadisticas(void) {
  for (int e = 0; e < N_EJES; e++) n_lect[e] = n_err[e] = t_ult[e] = t_max[e] = n_saltos[e] = 0;
}

static int escanear(const char *donde) {
  int n = 0;
  for (uint8_t a = 1; a < 127; a++) {
    if (a == DIR_MUX) continue;
    if (probar(a)) {
      printf("    %s: dispositivo en 0x%02X%s\n", donde, a, a == DIR_AS5600 ? "  (AS5600)" : "");
      n++;
    }
  }
  return n;
}

void enc_escanear_bus(void) {
  printf("Escaneo I2C (SDA = GPIO%d, SCL = GPIO%d, %lu Hz)\n", PIN_SDA, PIN_SCL, (unsigned long)frec);
  hay_mux = probar(DIR_MUX);
  if (!hay_mux) {
    printf("  !! El PCA9548A no responde en 0x%02X. Revisar 3,3 V, SDA/SCL invertidos, A0–A2, RESET en alto.\n",
           DIR_MUX);
    printf("  Bus sin multiplexor:\n");
    if (escanear("bus") == 0) printf("    (nada responde: el bus está muerto)\n");
    return;
  }
  printf("  PCA9548A presente en 0x%02X\n", DIR_MUX);
  escribir_mux(0);
  canal_actual = -1;
  printf("  Bus principal (canales cerrados):\n");
  if (escanear("bus") == 0) printf("    (vacío, correcto)\n");
  for (uint8_t c = 0; c < 8; c++) {
    escribir_mux((uint8_t)(1u << c));
    char donde[12];
    snprintf(donde, sizeof(donde), "canal %u", c);
    int esperado = -1;
    for (int e = 0; e < N_EJES; e++)
      if (CANAL_MUX[e] == c) esperado = e;
    int n = escanear(donde);
    if (esperado >= 0 && n == 0)
      printf("    canal %u: VACÍO, pero el config espera el encoder del eje %d (%s)\n", c, esperado + 1,
             NOMBRE_EJE[esperado]);
    else if (esperado >= 0)
      printf("    canal %u ↔ eje %d (%s) según el config\n", c, esperado + 1, NOMBRE_EJE[esperado]);
  }
  escribir_mux(0);
  canal_actual = -1;
}
