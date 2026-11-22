# Protocolo UDP volante ↔ simulador

Este documento es la especificación de la comunicación entre el **dispositivo IHM** (volante con
ESP32) y el **mundo virtual** (Godot). Es el "contrato" entre las dos capas del sistema: mientras
ambos lados lo respeten, se pueden desarrollar y probar por separado.

Implementaciones de referencia:

| Lado | Archivo |
|---|---|
| PC (Godot) | `scripts/input/wheel_protocol.gd`, `scripts/input/udp_wheel_source.gd`, `scripts/input/telemetry_out.gd` |
| Herramientas (Python) | `tools/wheel_protocol.py`, `tools/fake_wheel.py`, `tools/serial_bridge.py` |
| Volante (ESP32) | Fase 2 — pendiente |

## 1. Resumen

| | Volante → PC | PC → Volante |
|---|---|---|
| Transporte | UDP | UDP |
| Puerto de destino | **4210** (en la PC) | **4211** (en el volante) |
| Frecuencia | ~100 Hz | ~30 Hz (telemetría) + eventos |
| Mensajes | `W` | `T`, `V` |

- Los mensajes son **texto ASCII**, un mensaje por línea, terminados en `\n`.
  Se eligió texto (y no binario) para poder depurar con cualquier monitor serie o con Wireshark.
- Un datagrama UDP puede traer una o varias líneas.
- No hay conexión ni acuses de recibo: si un paquete se pierde, el siguiente (10 ms después) lo
  reemplaza. Por eso cada mensaje `W` y `T` lleva el **estado completo**.
- La PC no necesita conocer de antemano la IP del volante: responde a la **IP de origen** del
  último paquete `W` recibido. Mientras no llegue ninguno, usa la IP configurada en
  *Opciones → IP del volante* (por defecto `127.0.0.1`).

## 2. Mensaje `W` — estado del volante (volante → PC)

```
W,<steer>,<throttle>,<brake>,<buttons_bitmask>,<encoder_delta>\n
```

| Campo | Tipo | Rango | Significado |
|---|---|---|---|
| `steer` | entero | −1000 … 1000 | Dirección. Negativo = izquierda. Puede venir **sin calibrar** (el juego calibra). |
| `throttle` | entero | 0 … 1000 | Acelerador (0 = suelto). |
| `brake` | entero | 0 … 1000 | Freno (0 = suelto). |
| `buttons_bitmask` | entero | 0 … 255 | Un bit por botón; 1 = apretado (ver tabla). |
| `encoder_delta` | entero con signo | típ. −3 … 3 | Pasos del encoder **desde el paquete anterior**. Positivo = horario. |

Ejemplos:

```
W,0,0,0,0,0          volante centrado, nada apretado
W,-350,1000,0,0,0    doblando a la izquierda, acelerador a fondo
W,120,0,800,2,0      frenando y bajando una marcha (bit 1)
W,0,650,0,8,1        ERS apretado (bit 3) y un paso de encoder horario
```

### Mapa de bits de `buttons_bitmask`

| Bit | Valor | Constante | Botón | Acción en el juego |
|---|---|---|---|---|
| 0 | 1 | `BTN_SHIFT_UP` | Leva derecha | Subir marcha |
| 1 | 2 | `BTN_SHIFT_DOWN` | Leva izquierda | Bajar marcha |
| 2 | 4 | `BTN_DRS` | DRS | Abrir / cerrar alerón |
| 3 | 8 | `BTN_ERS` | ERS | Empuje extra **mientras se mantiene** |
| 4 | 16 | `BTN_PIT_LIMITER` | Limitador | Activar / desactivar limitador de boxes |
| 5 | 32 | `BTN_RESET` | Reset | Volver a pista |
| 6 | 64 | `BTN_CAMERA` | Cámara | Cámara siguiente |
| 7 | 128 | `BTN_PAUSE` | Pulsador del encoder | Pausa / menú |

- El volante envía el **estado** de cada botón (apretado / suelto). La detección de flancos
  ("recién apretado") la hace el juego (`InputSource._set_button`).
- El firmware debe hacer el **antirrebote** de microswitches y pulsadores.
- En los menús del juego: encoder = mover el foco, levas = cambiar valores, DRS = aceptar,
  Reset = volver.

### Sobre `encoder_delta`

Es el único campo incremental. Si se pierde un paquete se pierden esos pasos; se acepta porque el
encoder solo ajusta el reparto de frenos o mueve el foco de un menú. El firmware debe acumular los
pasos y poner el acumulador en cero al enviar.

## 3. Mensaje `T` — telemetría (PC → volante)

```
T,<rpm_pct>,<gear>,<flags_bitmask>\n
```

| Campo | Tipo | Rango | Significado |
|---|---|---|---|
| `rpm_pct` | entero | 0 … 100 | Régimen del motor como porcentaje del máximo. |
| `gear` | entero | −1 … 8 | −1 = marcha atrás, 0 = punto muerto, 1 … 8 = marchas. |
| `flags_bitmask` | entero | 0 … 255 | Un bit por estado (ver tabla). |

Ejemplo: `T,87,5,3` → 87 % de RPM, 5ª marcha, DRS disponible y abierto.

### Mapa de bits de `flags_bitmask`

| Bit | Valor | Constante | Estado | Uso sugerido en el volante |
|---|---|---|---|---|
| 0 | 1 | `FLAG_DRS_AVAILABLE` | Auto en zona de DRS | LED de DRS parpadeando |
| 1 | 2 | `FLAG_DRS_OPEN` | Alerón abierto | LED de DRS fijo |
| 2 | 4 | `FLAG_PIT_LIMITER` | Limitador activo | Tira parpadeando en amarillo |
| 3 | 8 | `FLAG_ERS_DEPLOY` | Usando batería | LED de ERS |
| 4 | 16 | `FLAG_REV_LIMIT` | Motor en el corte | — (la tira ya parpadea) |
| 5 | 32 | `FLAG_IN_PIT_LANE` | Dentro del pit lane | Aviso si el limitador está apagado |
| 6 | 64 | `FLAG_LAP_INVALID` | Vuelta invalidada | LED rojo |
| 7 | 128 | `FLAG_AQUAPLANING` | Aquaplaning (alguna rueda flotando sobre el agua) | LED de aviso / parpadeo azul |

> **Compatibilidad (Fase 1b):** el bit 7 es nuevo. El formato del mensaje no cambió: sigue siendo
> un entero decimal en el mismo campo, que ahora puede llegar a 255 en vez de 127. Un firmware
> que solo mira los bits 0–6 sigue funcionando sin cambios; conviene leer el campo como entero
> de 16 bits (o `uint8_t`, nunca `int8_t`) y enmascarar los bits que se usan.

Al salir de la pista (volver al menú) el juego envía un último `T,0,0,0` para apagar los LEDs.

### Shift lights: de `rpm_pct` a LEDs

La tira tiene **10 LEDs**. El HUD del juego y el volante usan la misma regla
(`WheelProtocol.leds_for_rpm`):

```
si rpm_pct < 62            -> 0 LEDs
si no  encendidos = piso((rpm_pct - 62) / (94 - 62) * 10) + 1      (máximo 10)
si rpm_pct >= 97           -> toda la tira parpadea en azul ("cambiá ya")
```

Colores por posición (el LED 0 es el primero en encender): LEDs 0–3 **verdes**, 4–6 **rojos**,
7–9 **azules**.

| `rpm_pct` | 60 | 62 | 70 | 78 | 86 | 94 | 97+ |
|---|---|---|---|---|---|---|---|
| LEDs encendidos | 0 | 1 | 3 | 6 | 8 | 10 | parpadeo |

## 4. Mensaje `V` — evento de vibración (PC → volante)

```
V,<intensidad>,<duracion_ms>\n
```

| Campo | Rango | Significado |
|---|---|---|
| `intensidad` | 0 … 255 | Ciclo de trabajo del PWM del motor de vibración. |
| `duracion_ms` | ≥ 0 | Cuánto dura el pulso. Un evento nuevo reemplaza al anterior. |

Eventos que genera el juego (`TelemetryOut.VIBRATION_PRESETS`); la intensidad base se escala con
la velocidad (piano, pasto) o con la violencia del golpe (choque):

| Evento | Intensidad base | Duración | Cuándo |
|---|---|---|---|
| Piano | 130 | 70 ms | Alguna rueda sobre un piano |
| Pasto | 90 | 110 ms | Alguna rueda fuera de la pista |
| Choque | 255 | 350 ms | Cambio brusco de velocidad (> 2,5 m/s en un tick) |
| Cambio | 60 | 30 ms | Cambio de marcha manual |
| Aquaplaning | 170 | 120 ms | Al empezar el aquaplaning y cada 0,4 s mientras dura (escalada con la pérdida de agarre) |

El evento de aquaplaning (Fase 1b) usa el mismo mensaje `V`: para el volante es un pulso más.

El juego no envía dos eventos del mismo tipo con menos de 90 ms de separación.

## 5. Tiempos y desconexión

- **Timeout:** si la PC no recibe ningún `W` válido durante **500 ms**, `UdpWheelSource` se declara
  desconectado: pone dirección, acelerador y freno en cero, suelta los botones, y el HUD muestra
  el aviso **VOLANTE UDP DESCONECTADO**. Al volver a llegar paquetes se reconecta solo.
- Conviene que el volante aplique la misma regla: si no llega ningún `T` en 500 ms, apagar la tira
  y el motor de vibración.
- El juego consulta la red una vez por tick de física (120 Hz), así que el retardo que agrega es
  menor a 8,4 ms. Si llegan varios `W` en un mismo tick se usa el más nuevo para los ejes y se
  procesan todos para los botones y el encoder.

## 6. Calibración de la dirección

El AS5600 mide un ángulo absoluto; el cero y los topes dependen del montaje. Para no tener que
reprogramar el ESP32, **la calibración vive en el juego** (*Menú principal → Calibrar volante*):

1. Se registran tres valores crudos de `steer`: tope izquierdo (`L`), tope derecho (`R`) y centro (`C`).
2. Se guardan en `user://opciones.cfg`.
3. Cada lectura `x` se convierte con dos tramos lineales (por si el centro no está en el medio):

```
si x >= C:   steer = (x - C) / (R - C)      limitado a [0, 1]
si x <  C:   steer = (x - C) / (C - L)      limitado a [-1, 0]
```

Después el `InputManager` aplica zona muerta, curva y sensibilidad (configurables en Opciones).

El firmware solo tiene que entregar un valor **proporcional al ángulo** dentro de −1000 … 1000 que
no "dé la vuelta" (pase de 1000 a −1000) dentro del recorrido útil del volante.

Para probarlo sin hardware: `python tools/fake_wheel.py --center 120 --range 800` simula un sensor
descentrado y con menos recorrido.

## 7. Alternativa por cable: USB serie

Si el WiFi no está disponible, el ESP32 puede escribir **las mismas líneas** por el puerto serie
(115200 baudios) y `tools/serial_bridge.py` las reenvía por UDP en ambos sentidos. Para el juego no
hay diferencia. Cualquier línea que no tenga el formato `W,...` (por ejemplo mensajes de
depuración del firmware) se ignora, así que se puede dejar `Serial.println("debug...")` sin romper nada.

## 8. Guía para el firmware (Fase 2)

Esqueleto del bucle principal, en pseudocódigo:

```
cada 10 ms:
    steer    = map(leer_AS5600(), ángulo_mín, ángulo_máx, -1000, 1000)
    throttle = map(leer_ADC(pedal_acelerador), 0, 4095, 0, 1000)
    brake    = map(leer_HX711(celda_freno), 0, fuerza_máx, 0, 1000)
    buttons  = bits de las levas y los botones (con antirrebote)
    delta    = pasos_encoder_acumulados;  pasos_encoder_acumulados = 0
    enviar_udp(ip_pc, 4210, "W,%d,%d,%d,%d,%d\n")

al recibir por UDP (puerto 4211):
    "T,rpm,gear,flags"  -> actualizar tira WS2812 con la regla de la sección 3
    "V,intensidad,ms"   -> PWM del motor = intensidad durante ms

si pasan 500 ms sin "T": apagar LEDs y motor
```

Puntos a resolver en la Fase 2: descubrimiento de la IP de la PC (IP fija configurada, o enviar
los `W` por *broadcast* a `255.255.255.255:4210`), credenciales WiFi, y elección entre WiFi y
serie con una llave o por compilación.
