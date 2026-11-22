// =============================================================================
// pi7_encoders.h — AS5600 detrás de un PCA9548A, usados como incrementales
// -----------------------------------------------------------------------------
// Qué hace : selecciona el canal del multiplexor, lee RAW ANGLE (12 bits),
//            desenvuelve la vuelta y acumula cuentas con signo. Lee el estado
//            del imán (MD/ML/MH, AGC, MAGNITUDE), cuenta errores y tiempos.
// Nota     : para no perder vueltas hay que leer cada encoder antes de que su
//            motor gire media vuelta: llamar enc_actualizar_todos() seguido.
// Depende  : driver I2C "legacy" de ESP-IDF (driver/i2c.h, 4.4–5.x). En IDF ≥ 5.2
//            compila con un aviso de "deprecated": es esperado.
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "pi7_config.h"

typedef struct {
  bool md, ml, mh;     // imán detectado / débil / fuerte
  uint8_t agc;         // a 3,3 V rango 0–128; ideal en el medio
  uint16_t magnitud;
} enc_diag_t;

bool enc_iniciar(uint32_t frec_hz);     // true si responde el multiplexor
void enc_fijar_frecuencia(uint32_t frec_hz);
uint32_t enc_frecuencia(void);
bool enc_mux_presente(void);
bool enc_presente(int e);
bool enc_leer_crudo(int e, uint16_t *crudo);
bool enc_leer_diag(int e, enc_diag_t *d);
bool enc_actualizar(int e);
bool enc_actualizar_todos(void);
int32_t enc_cuentas(int e);             // acumuladas, con ENC_INVERTIDO aplicado
uint16_t enc_ultimo_crudo(int e);
void enc_cero(int e);
void enc_cero_todos(void);
float enc_grados_motor(int e);
float enc_grados_art(int e);
uint32_t enc_lecturas(int e);
uint32_t enc_errores(int e);
uint32_t enc_tiempo_ultima_us(int e);
uint32_t enc_tiempo_max_us(int e);
uint32_t enc_saltos(int e);             // |Δ| > 1/4 de vuelta entre lecturas
void enc_reiniciar_estadisticas(void);
void enc_escanear_bus(void);
