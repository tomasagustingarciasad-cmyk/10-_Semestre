#include <stdio.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <driver/gpio.h>
#include <driver/ledc.h>

// ==========================================
// DEFINICIÓN DE PINES (Esquema seguro)
// ==========================================
// Motor 1
#define DIR_PIN_1 GPIO_NUM_18
#define PUL_PIN_1 GPIO_NUM_19

// Motor 2
#define DIR_PIN_2 GPIO_NUM_16
#define PUL_PIN_2 GPIO_NUM_17

// Motor 3
#define DIR_PIN_3 GPIO_NUM_14
#define PUL_PIN_3 GPIO_NUM_13

// ==========================================
// CONFIGURACIÓN DE HARDWARE LEDC
// ==========================================
void iniciar_hardware_motores() {
    // 1. Configurar los pines de Dirección (DIR) como salidas estándar
    gpio_set_direction(DIR_PIN_1, GPIO_MODE_OUTPUT);
    gpio_set_direction(DIR_PIN_2, GPIO_MODE_OUTPUT);
    gpio_set_direction(DIR_PIN_3, GPIO_MODE_OUTPUT);

    // 2. Configurar los Temporizadores (Los "relojes" independientes)
    // Temporizador 0 para Motor 1
    ledc_timer_config_t timer0_conf = {
        .speed_mode       = LEDC_LOW_SPEED_MODE,
        .timer_num        = LEDC_TIMER_0,
        .duty_resolution  = LEDC_TIMER_13_BIT,
        .freq_hz          = 1000, 
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ledc_timer_config(&timer0_conf);

    // Temporizador 1 para Motor 2
    ledc_timer_config_t timer1_conf = {
        .speed_mode       = LEDC_LOW_SPEED_MODE,
        .timer_num        = LEDC_TIMER_1,
        .duty_resolution  = LEDC_TIMER_13_BIT,
        .freq_hz          = 1000, 
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ledc_timer_config(&timer1_conf);

    // Temporizador 2 para Motor 3
    ledc_timer_config_t timer2_conf = {
        .speed_mode       = LEDC_LOW_SPEED_MODE,
        .timer_num        = LEDC_TIMER_2,
        .duty_resolution  = LEDC_TIMER_13_BIT,
        .freq_hz          = 1000, 
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ledc_timer_config(&timer2_conf);

    // 3. Configurar los Canales (Vinculan el Temporizador con el Pin físico PUL)
    // Canal 0 -> Timer 0 -> Pin Motor 1
    ledc_channel_config_t ch0_conf = {
        .gpio_num       = PUL_PIN_1,
        .speed_mode     = LEDC_LOW_SPEED_MODE,
        .channel        = LEDC_CHANNEL_0,
        .intr_type      = LEDC_INTR_DISABLE,
        .timer_sel      = LEDC_TIMER_0,
        .duty           = 0, // Inician apagados (0%)
        .hpoint         = 0
    };
    ledc_channel_config(&ch0_conf);

    // Canal 1 -> Timer 1 -> Pin Motor 2
    ledc_channel_config_t ch1_conf = {
        .gpio_num       = PUL_PIN_2,
        .speed_mode     = LEDC_LOW_SPEED_MODE,
        .channel        = LEDC_CHANNEL_1,
        .intr_type      = LEDC_INTR_DISABLE,
        .timer_sel      = LEDC_TIMER_1,
        .duty           = 0, // Inician apagados (0%)
        .hpoint         = 0
    };
    ledc_channel_config(&ch1_conf);

    // Canal 2 -> Timer 2 -> Pin Motor 3
    ledc_channel_config_t ch2_conf = {
        .gpio_num       = PUL_PIN_3,
        .speed_mode     = LEDC_LOW_SPEED_MODE,
        .channel        = LEDC_CHANNEL_2,
        .intr_type      = LEDC_INTR_DISABLE,
        .timer_sel      = LEDC_TIMER_2,
        .duty           = 0, // Inician apagados (0%)
        .hpoint         = 0
    };
    ledc_channel_config(&ch2_conf);
}

// ==========================================
// FUNCIONES DE CONTROL MODULAR
// ==========================================

// Función para mover un motor a una frecuencia y dirección específicas
void mover_motor(int motor, int velocidad_hz, int direccion) {
    // 4096 representa un duty cycle del 50% para una resolución de 13 bits (8192 total)
    // Esto asegura una onda cuadrada simétrica perfecta para el driver DM556
    int duty_cycle = 4096; 

    if (motor == 1) {
        gpio_set_level(DIR_PIN_1, direccion);
        ledc_set_freq(LEDC_LOW_SPEED_MODE, LEDC_TIMER_0, velocidad_hz);
        ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, duty_cycle);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0);
    } 
    else if (motor == 2) {
        gpio_set_level(DIR_PIN_2, direccion);
        ledc_set_freq(LEDC_LOW_SPEED_MODE, LEDC_TIMER_1, velocidad_hz);
        ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1, duty_cycle);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1);
    } 
    else if (motor == 3) {
        gpio_set_level(DIR_PIN_3, direccion);
        ledc_set_freq(LEDC_LOW_SPEED_MODE, LEDC_TIMER_2, velocidad_hz);
        ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_2, duty_cycle);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_2);
    }
}

// Función para detener un motor manteniendo el torque de retención
void detener_motor(int motor) {
    if (motor == 1) {
        ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, 0);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0);
    } 
    else if (motor == 2) {
        ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1, 0);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1);
    } 
    else if (motor == 3) {
        ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_2, 0);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_2);
    }
}

// ==========================================
// PROGRAMA PRINCIPAL
// ==========================================
void app_main() {
    printf("Iniciando sistema multieje independiente por hardware...\n");
    iniciar_hardware_motores();

    while(true) {
        // --- SECUENCIA DE PRUEBA CINETICA ---

        printf("Estado 1: Motor 1 y 3 rápido hacia adelante, Motor 2 quieto\n");
        mover_motor(1, 1500, 1); // Eje 1 a 1500 Hz, dirección 1
        detener_motor(2);        // Eje 2 clavado
        mover_motor(3, 1500, 1); // Eje 3 a 1500 Hz, dirección 1
        vTaskDelay(3000 / portTICK_PERIOD_MS); // Espera de 3 segundos (El procesador duerme libre)

        printf("Estado 2: Motor 2 moviéndose lento, Motor 1 y 3 detenidos\n");
        detener_motor(1);
        mover_motor(2, 400, 0);  // Eje 2 a 400 Hz, dirección inversa 0
        detener_motor(3);
        vTaskDelay(2000 / portTICK_PERIOD_MS); // Espera de 2 segundos

        printf("Estado 3: Todos los motores moviéndose a distintas velocidades\n");
        mover_motor(1, 2000, 0); // Eje 1 muy rápido inverso
        mover_motor(2, 800, 1);  // Eje 2 velocidad media
        mover_motor(3, 100, 1);  // Eje 3 muy lento
        vTaskDelay(4000 / portTICK_PERIOD_MS); // Espera de 4 segundos

        printf("Estado 4: Todos los motores detenidos\n");
        detener_motor(1);
        detener_motor(2);
        detener_motor(3);
        vTaskDelay(2000 / portTICK_PERIOD_MS); // Espera de 2 segundos antes de repetir el bucle
    }
}