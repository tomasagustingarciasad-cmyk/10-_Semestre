#include<stdio.h>
#include<freertos/FreeRTOS.h>
#include<freertos/task.h>
#include<driver/gpio.h>
#include<rom/ets_sys.h>

//Definicion de pines del motor 1
#define DIR_PIN_1 GPIO_NUM_13
#define PUL_PIN_1 GPIO_NUM_14

//Definicion de pines del motor 2
#define DIR_PIN_2 GPIO_NUM_16
#define PUL_PIN_2 GPIO_NUM_17

//Definicion de pines del motor 3
#define DIR_PIN_3 GPIO_NUM_18
#define PUL_PIN_3 GPIO_NUM_19

void app_main() {

//config gpio
gpio_set_direction(DIR_PIN_1, GPIO_MODE_OUTPUT);
gpio_set_direction(PUL_PIN_1, GPIO_MODE_OUTPUT);
gpio_set_direction(DIR_PIN_2, GPIO_MODE_OUTPUT);
gpio_set_direction(PUL_PIN_2, GPIO_MODE_OUTPUT);
gpio_set_direction(DIR_PIN_3, GPIO_MODE_OUTPUT);
gpio_set_direction(PUL_PIN_3, GPIO_MODE_OUTPUT);

printf("Probando motor\n");


while (true) {
        // 1. Establecer dirección de avance para los 3 ejes
        gpio_set_level(DIR_PIN_1, 1);
        gpio_set_level(DIR_PIN_2, 1);
        gpio_set_level(DIR_PIN_3, 1);

        // Generar 1600 pulsos (1 revolución completa con microstepping de 1/8)
        for(int i = 0; i < 1600; i++) {
            // Estado ALTO simultáneo
            gpio_set_level(PUL_PIN_1, 1);
            gpio_set_level(PUL_PIN_2, 1);
            gpio_set_level(PUL_PIN_3, 1);
            ets_delay_us(500); // 500 microsegundos de retención

            // Estado BAJO simultáneo
            gpio_set_level(PUL_PIN_1, 0);
            gpio_set_level(PUL_PIN_2, 0);
            gpio_set_level(PUL_PIN_3, 0);
            ets_delay_us(500);
        }

        // Pausa temporal y alimentación del Watchdog de FreeRTOS para evitar reinicios
        vTaskDelay(500 / portTICK_PERIOD_MS);

        // 2. Establecer dirección de retroceso para los 3 ejes
        gpio_set_level(DIR_PIN_1, 0);
        gpio_set_level(DIR_PIN_2, 0);
        gpio_set_level(DIR_PIN_3, 0);

        for(int j = 0; j < 1600; j++) {
            gpio_set_level(PUL_PIN_1, 1);
            gpio_set_level(PUL_PIN_2, 1);
            gpio_set_level(PUL_PIN_3, 1);
            ets_delay_us(500);

            gpio_set_level(PUL_PIN_1, 0);
            gpio_set_level(PUL_PIN_2, 0);
            gpio_set_level(PUL_PIN_3, 0);
            ets_delay_us(500);
        }

         vTaskDelay(500 / portTICK_PERIOD_MS);
    }
}