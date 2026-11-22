// =============================================================================
// pi7_motores.h — Movimiento de los tres DM556, con dos generadores de pasos
// -----------------------------------------------------------------------------
// Qué hace : rampas trapezoidales (perfil a 1 kHz en un esp_timer), modos
//            posición / velocidad / parada, vigilancia de finales con política
//            de seguridad y cola de eventos. Los pulsos los genera:
//   GEN_SOFTWARE  ISR de gptimer a 40 kHz con acumulador de fase (núcleo 1).
//                 Posición exacta, cualquier perfil, cuesta CPU.
//   GEN_HARDWARE  LEDC genera el tren (50 %, 10 bits) y el PCNT cuenta los
//                 pulsos leyendo el MISMO pin. Al llegar al pulso N, una
//                 interrupción del PCNT desconecta el LEDC del pin: corte exacto
//                 sin CPU por paso. Tramo máximo con corte exacto: PASOS_HW_MAX_TRAMO.
// Las dos variantes tienen la misma API: todos los tests corren con cualquiera.
// Convención: + de la coordenada = + de pasos. DIR_INVERTIDA corrige cableado.
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
// =============================================================================
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "pi7_config.h"

typedef enum {
  FINAL_IGNORAR = 0,         // sólo se informa
  FINAL_BLOQUEA_SU_EJE = 1,  // su eje no avanza hacia el final; alejarse sí
  FINAL_DETIENE_TODO = 2,    // cualquier final detiene los tres (diagnóstico de cableado)
} politica_final_t;

typedef struct {
  uint8_t final_eje;           // qué final se activó (0..2)
  uint8_t ejes_en_movimiento;  // máscara de bits
  uint8_t ejes_detenidos;      // máscara de bits
  int32_t pos[N_EJES];         // [upasos] al detectar
  float vel[N_EJES];           // [upasos/s] al detectar
  uint32_t t_deteccion_us;
  uint32_t t_flanco_us;        // primer flanco crudo
} mot_evento_t;

void mot_iniciar(generador_t gen, bool muestrear_finales);
generador_t mot_generador(void);
const char *mot_nombre_generador(void);

void mot_fijar_vel_max(int e, float pps);
void mot_fijar_acel(int e, float pps2);
float mot_vel_max(int e);
float mot_acel(int e);
void mot_fijar_limites_art(int e, float vel_deg_s, float acel_deg_s2);
float mot_paso_max(void);                  // [upasos/s] del generador activo

void mot_mover_a(int e, int32_t posicion);
void mot_mover_rel(int e, int32_t delta);
void mot_mover_rel_grados_motor(int e, float deg);
void mot_mover_rel_grados_art(int e, float deg);
void mot_jog(int e, float pps);            // velocidad con rampa; signo = sentido
void mot_detener(int e);                   // con rampa
void mot_parar_ya(int e);                  // inmediata
void mot_parar_todo(void);

bool mot_en_movimiento(int e);
bool mot_alguno_en_movimiento(void);
int32_t mot_posicion(int e);               // [upasos]
void mot_fijar_posicion(int e, int32_t p); // sólo detenido
float mot_velocidad(int e);                // [upasos/s]
int32_t mot_objetivo(int e);
float mot_grados_motor(int e);
float mot_grados_art(int e);

void mot_fijar_politica(politica_final_t p);
politica_final_t mot_politica(void);
bool mot_leer_evento(mot_evento_t *ev);

uint32_t mot_perfil_max_us(void);
uint32_t mot_bloqueos(int e);
void mot_reiniciar_diagnostico(void);
float mot_carga_isr(void);                 // [%] de un núcleo usada por la ISR software desde la última consulta
int32_t mot_hw_cuenta(int e);              // pulsos contados por el PCNT en el tramo actual (hardware)
