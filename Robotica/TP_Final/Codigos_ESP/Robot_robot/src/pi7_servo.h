// =============================================================================
// pi7_servo.h — SG90 de la compuerta del vaso (LEDC a 50 Hz, timer 3 / canal 3)
// -----------------------------------------------------------------------------
// Qué hace : pulso de 500–2500 µs con rampa, "soltar" (sin pulsos = sin par) y
//            conversión ψ ↔ µs con la calibración de dos puntos del config.
// Uso      : srv_iniciar() NO emite pulsos. srv_actualizar() en el servicio de
//            fondo para que avance la rampa.
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "pi7_config.h"

void srv_iniciar(void);
void srv_ir_us(uint16_t us, bool con_rampa);
void srv_soltar(void);
void srv_actualizar(void);
void srv_fijar_rampa(float us_por_s);
bool srv_activo(void);
bool srv_en_movimiento(void);
uint16_t srv_us_actual(void);
uint16_t srv_us_objetivo(void);
bool srv_calibrado(void);
uint16_t srv_us_desde_psi(float psi_deg);
