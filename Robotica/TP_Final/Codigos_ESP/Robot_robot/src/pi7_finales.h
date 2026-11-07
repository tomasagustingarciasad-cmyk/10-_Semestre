// =============================================================================
// pi7_finales.h — Finales de carrera (con filtro RC por hardware)
// -----------------------------------------------------------------------------
// Qué hace : confirmación corta por software (FINAL_FILTRO_MUESTRAS a 1 kHz),
//            conteo de flancos crudos por interrupción (mide si el RC realmente
//            deja una sola transición por apretada) y hora del primer flanco
//            (mide la latencia de parada).
// Uso      : fin_iniciar() en el arranque del test; fin_muestrear() a 1 kHz
//            (lo llama el perfil de motores o, si no hay motores, el test).
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "pi7_config.h"

void fin_iniciar(void);
void fin_muestrear(void);
bool fin_activo(int e);                 // confirmado, con la polaridad del config
bool fin_nivel_crudo(int e);            // nivel eléctrico (true = ALTO)
uint32_t fin_flancos_crudos(int e);     // flancos que vio la interrupción
uint32_t fin_activaciones(int e);       // transiciones confirmadas a "activo"
uint32_t fin_primer_flanco_us(int e);   // primer flanco desde el último cambio confirmado
void fin_reiniciar_contadores(void);
