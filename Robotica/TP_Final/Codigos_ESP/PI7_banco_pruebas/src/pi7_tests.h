// =============================================================================
// pi7_tests.h — Entradas de cada test y ayudas compartidas por los tests
// Cada test inicializa SÓLO lo que necesita y no vuelve: se sale con 'reset'.
// Autor: Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include "pi7_config.h"

void t01_ejecutar(generador_t g);  // diagnóstico (no mueve nada)
void t02_ejecutar(generador_t g);  // finales de carrera (no mueve nada)
void t03_ejecutar(generador_t g);  // servo
void t04_ejecutar(generador_t g);  // encoders (no mueve nada)
void t05_ejecutar(generador_t g);  // motores en lazo abierto
void t06_ejecutar(generador_t g);  // motor contra encoder
void t07_ejecutar(generador_t g);  // motor contra final + homing
void t08_ejecutar(generador_t g);  // integración / quemado
void t09_ejecutar(generador_t g);  // generador por hardware (LEDC + PCNT)

// Ayudas (pi7_ayudas.c)
bool ay_esperar_quieto(uint32_t timeout_ms);   // false si se abortó o venció; para todo en ese caso
void ay_vaciar_eventos(void);
void ay_informar_eventos(void);                // imprime eventos de finales pendientes
bool ay_comando_comun(int n, char *tok[]);     // 'x', 'reset', 'carga': true si lo atendió
void ay_listo(const char *test);               // imprime "#LISTO tNN"
