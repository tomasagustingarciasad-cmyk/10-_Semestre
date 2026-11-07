// =============================================================================
// pi7_comun.h — Utilidades comunes: consola, banner, validación de pines, esperas
// Autor: Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include "pi7_config.h"

typedef struct {
  bool motores;
  bool finales;
  bool i2c;
  bool servo;
} com_uso_t;

void com_iniciar_consola(void);
bool com_banner(void);                       // true si el último reset fue por brownout
const char *com_motivo_reset(void);
bool com_validar_pines(com_uso_t uso);       // false si hay errores graves

// Consola. Lee lo que haya sin bloquear; cuando completa una línea la parte en
// tokens (en minúscula) y devuelve la cantidad. 0 = todavía no hay línea.
int com_leer_comando(char *tok[], int max_tok);
bool com_hay_tecla(void);                    // cualquier carácter recibido (y lo descarta)
void com_vaciar_entrada(void);
char com_preguntar(const char *pregunta, uint32_t timeout_ms);

// Servicio de fondo: se llama en cada espera (leer encoders, rampa del servo...)
void com_fijar_servicio(void (*fn)(void));
void com_servicio(void);
bool com_esperar(uint32_t ms, bool abortable);  // false si el usuario abortó

uint32_t com_ms(void);
uint32_t com_us(void);
float com_s(void);

void com_csv_inicio(const char *nombre, const char *encabezado);
void com_csv_fin(void);
void com_linea(char c, int n);
int com_eje_desde_texto(const char *t);       // "1".."3" → 0..2; -1 inválido
void com_latido(void);
void com_alarma(bool on);
void com_reiniciar(void);                     // esp_restart con aviso
void com_bloquear_por_error(void);            // queda latiendo rápido hasta 'reset'
