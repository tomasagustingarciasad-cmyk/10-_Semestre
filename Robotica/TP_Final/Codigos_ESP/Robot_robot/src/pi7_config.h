// =============================================================================
// pi7_config.h — Configuración única del banco de pruebas (ESP-IDF)
// -----------------------------------------------------------------------------
// Qué hace : única fuente de verdad del firmware de prueba: pines (de la hoja
//            "Especificaciones de Hardware"), parámetros de cada eje,
//            transmisión, encoders, finales de carrera y servo.
//            NINGÚN otro archivo redefine estos valores.
// Autor    : Grupo 7 (PI7) + Claude. 2026-11-06.
//
// Índice de eje en todo el firmware: 0 = q1 base · 1 = t2 hombro · 2 = t3 codo.
// En la consola los ejes se escriben 1, 2, 3 (= Motor 1, 2, 3 de la hoja).
//
// Qué se completa con los tests (ver LEEME.md):
//   FINAL_ACTIVO_ALTO ...... T02 'calibrar'
//   SERVO_US_PSI_* ......... T03 'marcar'
//   DIR_INVERTIDA .......... T05 'sentido'
//   MICROPASOS, ENC_INVERTIDO  T06 'auto'
// "⚠️ decisión pendiente" = valor supuesto que todavía hay que medir o confirmar.
// =============================================================================
#pragma once
#include <stdint.h>
#include <stdbool.h>

#define N_EJES 3
#define BAUDIOS_SERIE 115200

static const char *const NOMBRE_EJE[N_EJES] = {"q1 base", "t2 hombro", "t3 codo"};

// -----------------------------------------------------------------------------
// 1. Pines (hoja de hardware, ESP32 NodeMCU-32S)
// -----------------------------------------------------------------------------
// Supuesto: Motor 1 = base, Motor 2 = hombro, Motor 3 = codo, y lo mismo para
// encoders y finales ⚠️ decisión pendiente. T05, T06 y T07 detectan cruces.
static const int8_t PIN_STEP[N_EJES]  = {14, 17, 19};  // PUL → base del BC337 (1 kΩ)
static const int8_t PIN_DIR[N_EJES]   = {13, 16, 18};  // DIR → base del BC337 (1 kΩ)
static const int8_t PIN_FINAL[N_EJES] = {23, 25, 26};  // salida del filtro RC (10 kΩ · 1 µF)
static const int8_t PIN_SDA   = 21;                    // pull-up externo 2,2 kΩ
static const int8_t PIN_SCL   = 22;                    // pull-up externo 2,2 kΩ
static const int8_t PIN_SERVO = 4;                     // 220 Ω en serie al SG90
static const int8_t PIN_LED   = 2;                     // LED de la placa (latido); -1 si no hay ⚠️

// -----------------------------------------------------------------------------
// 2. Etapa de salida a los DM556 (BC337, ánodo común a 5 V)
// -----------------------------------------------------------------------------
// GPIO en ALTO → BC337 satura → optoacoplador del DM556 ENCENDIDO.
// ENA desconectado: los drivers están siempre habilitados (no hay forma de
// liberar los motores por software: para girarlos a mano, cortar los 24 V).
static const bool STEP_ACTIVO_ALTO = true;

// -----------------------------------------------------------------------------
// 3. Motores y transmisión (Leadshine 42HS08 + DM556, GT2 20T → 90T)
// -----------------------------------------------------------------------------
static const uint16_t PASOS_MOTOR_REV = 200;                    // [pasos/rev] 1,8°
static const uint16_t MICROPASOS[N_EJES] = {16, 16, 16};        // [-] ⚠️ decisión pendiente: DIP del DM556 (T06 lo mide)
static const float    RELACION_G[N_EJES] = {4.5f, 4.5f, 4.5f};  // [-] 90/20

// Sentido: con 'false', DIR en ALTO = sentido + de la coordenada.
// +: q1 antihorario visto desde arriba; t2 levanta el brazo; t3 levanta el antebrazo.
static const bool DIR_INVERTIDA[N_EJES] = {false, false, false};  // se ajusta con T05

// Generador de pasos
typedef enum { GEN_SOFTWARE = 0, GEN_HARDWARE = 1 } generador_t;
static const generador_t GENERADOR_POR_DEFECTO = GEN_SOFTWARE;   // 't05 hw' fuerza el otro
// Software: ISR de gptimer, acumulador de fase. Pulso = 1 tick.
static const uint32_t PERIODO_TICK_US   = 25;    // [µs] → 40 kHz; paso máx. 20 kHz
static const uint8_t  TICKS_ESPERA_DIR  = 2;     // [ticks] DIR ≥ 50 µs antes del primer paso (DM556 pide ≥ 5 µs)
// Hardware: LEDC genera, PCNT cuenta en el mismo pin y corta en el pulso N.
static const uint32_t FREC_HW_MAX_HZ    = 20000; // [Hz] la ISR de corte tiene que caer en el semiperíodo bajo
static const uint32_t FREC_HW_MIN_HZ    = 5;     // [Hz] por debajo se considera detenido
static const int32_t  PASOS_HW_MAX_TRAMO = 30000;// [upasos] corte exacto hasta este largo de movimiento (contador de 16 bits)
static const uint32_t PERIODO_PERFIL_US = 1000;  // [µs] rampas y finales a 1 kHz

// Límites por defecto de los tests (articulares). Sin correa no hay carga.
static const float VEL_TEST_DEG_S[N_EJES]   = {30.0f, 30.0f, 30.0f};    // [°/s]
static const float ACEL_TEST_DEG_S2[N_EJES] = {120.0f, 120.0f, 120.0f}; // [°/s²]
static const float VEL_ABS_MAX_DEG_S = 400.0f;                          // [°/s] tope duro de cualquier comando

// -----------------------------------------------------------------------------
// 4. Encoders AS5600 detrás del PCA9548A
// -----------------------------------------------------------------------------
static const uint32_t I2C_FREC_HZ  = 400000;          // [Hz] bajar a 100000 si T04 muestra errores
static const uint8_t  DIR_MUX      = 0x70;            // A0..A2 a GND
static const uint8_t  DIR_AS5600   = 0x36;            // fija
static const uint8_t  CANAL_MUX[N_EJES] = {2, 3, 4};  // hoja: encoder 1 → canal 2, 2 → 3, 3 → 4
static const uint16_t CUENTAS_ENC_REV = 4096;         // [cuentas/rev] 12 bits
static const bool ENC_INVERTIDO[N_EJES] = {false, false, false};  // se ajusta con T06

// -----------------------------------------------------------------------------
// 5. Finales de carrera (filtro RC por hardware: 10 kΩ serie + 1 µF a GND)
// -----------------------------------------------------------------------------
static const bool FINAL_ACTIVO_ALTO[N_EJES] = {true, true, true};  // ⚠️ decisión pendiente: T02 'calibrar'
// Pull-up interno APAGADO: con los 10 kΩ en serie formaría un divisor.
static const bool FINAL_PULLUP_INTERNO = false;
// Confirmación por software: N muestras seguidas a 1 kHz. El RC ya filtra; esto
// cubre los cruces múltiples de un flanco lento (el ESP32 no tiene histéresis).
static const uint8_t FINAL_FILTRO_MUESTRAS = 2;
// Los tres finales están del lado + de su coordenada.
static const int8_t SENTIDO_FINAL[N_EJES] = {+1, +1, +1};

// Homing (velocidades articulares)
static const float HOMING_VEL_RAPIDA_DEG_S = 10.0f;  // [°/s] ⚠️ decisión pendiente
static const float HOMING_VEL_LENTA_DEG_S  = 2.0f;   // [°/s] el retardo del RC (~14 ms) da ~0,03° de error a esta velocidad
static const float HOMING_RETROCESO_DEG    = 4.0f;   // [°]
static const float HOMING_RECORRIDO_MAX_DEG[N_EJES] = {270.0f, 120.0f, 130.0f}; // [°] guarda
static const float HOME_ACT_DEG[N_EJES] = {129.0f, 118.0f, 49.0f};             // [°] disparo de cada final, del CAD ⚠️ decisión pendiente

// -----------------------------------------------------------------------------
// 6. Servo SG90 de la compuerta del vaso
// -----------------------------------------------------------------------------
static const uint16_t SERVO_US_MIN = 500;        // [µs]
static const uint16_t SERVO_US_MAX = 2500;       // [µs]
static const uint16_t SERVO_US_INICIO = 1500;    // [µs] primer pulso sugerido
static const float    SERVO_RAMPA_US_S = 2000.0f;// [µs/s]
static const uint16_t SERVO_US_PSI_CERRADO = 0;  // [µs] pulso con ψ = −3°  (0 = sin calibrar; T03)
static const uint16_t SERVO_US_PSI_ABIERTO = 0;  // [µs] pulso con ψ = −30° (0 = sin calibrar; T03)
static const float PSI_CERRADO_DEG = -3.0f;      // [°] compuerta cerrada: retiene la esfera
static const float PSI_ABIERTO_DEG = -30.0f;     // [°] compuerta abierta: la esfera cae
static const float PSI_MAX_DEG = 2.0f;           // [°] retiene hasta +2°; tope mecánico en +3°
static const float PSI_MIN_DEG = -90.0f;         // [°] libre de choques hasta −90°

// -----------------------------------------------------------------------------
// 7. Conversiones derivadas (no editar)
// -----------------------------------------------------------------------------
static inline float pasos_rev_motor(int e) { return (float)PASOS_MOTOR_REV * MICROPASOS[e]; }
static inline float pasos_grado_motor(int e) { return pasos_rev_motor(e) / 360.0f; }
static inline float pasos_grado_art(int e) { return pasos_grado_motor(e) * RELACION_G[e]; }
static inline float cuentas_grado_motor(void) { return CUENTAS_ENC_REV / 360.0f; }
static inline float cuentas_por_paso(int e) { return CUENTAS_ENC_REV / pasos_rev_motor(e); }
