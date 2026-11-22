# Banco de pruebas del robot · Grupo 7 (PI7) · Robótica II

Proyecto **PlatformIO + ESP-IDF** con **tests parciales** para verificar cada subsistema del robot por separado (motores, encoders, finales de carrera y servo) antes de escribir el firmware final.

Es **un solo firmware**: al arrancar no enciende nada de potencia y muestra un **menú**. Se elige el test escribiendo `t01` … `t09`. Cada test inicializa **sólo lo que usa**: el del servo no toca los motores, el de los encoders no genera pasos, y así con el resto. Para cambiar de test se escribe `reset` (el ESP32 se reinicia y vuelve al menú).

> **Estado:** el código compila y la lógica de generación de pasos se verificó en simulación, pero **todavía no se probó en el robot**. Los pines salen de la hoja *Especificaciones de Hardware*.

---

## 1. Puesta en marcha (una sola vez)

1. Abrir la carpeta `PI7_banco_pruebas` en **VS Code** con PlatformIO (*PIO Home → Open Project*). Es un proyecto completo: no hace falta copiar nada a otro proyecto.
2. Si en la carpeta existe un archivo `sdkconfig.nodemcu-32s`, **borrarlo**. Se regenera desde `sdkconfig.defaults` con lo que el banco necesita: CPU a 240 MHz, tick de FreeRTOS de 1 ms y más pila para la tarea principal.
3. Compilar y cargar: **Upload** (flecha →) en la barra de PlatformIO.
4. Abrir el **Serial Monitor** (enchufe) de PlatformIO a 115200. Tiene que aparecer el banner con el chip y el menú.
5. En el banner, controlar que diga `Tick FreeRTOS : 1000 Hz`. Si dice otra cosa, no se aplicó el paso 2.

Requiere la plataforma `espressif32` con **ESP-IDF 5.x**. Al compilar aparece un aviso de *deprecated* sobre `driver/i2c.h`: es esperado.

### Cómo se usa la consola

- Se escribe el comando y se manda con **Enter**. El firmware hace eco de lo que escribís.
- `?` (o cualquier comando desconocido) muestra la ayuda del test.
- `x` + Enter: **para los tres motores de inmediato**.
- Durante una rutina larga, **cualquier tecla la aborta**.
- `reset`: vuelve al menú.
- Ejes: `1` = q1 base · `2` = t2 hombro · `3` = t3 codo (= Motor 1, 2, 3 de la hoja). Los ángulos son **articulares**, salvo los comandos que dicen "motor".

---

## 2. El robot, en lo que importa para estos tests

| Eje | Nombre | Qué mueve | Sentido **positivo** | Final de carrera |
|---|---|---|---|---|
| `1` | q1 base | Giro de la torreta | Antihorario visto desde arriba | ≈ +129° |
| `2` | t2 hombro | Ángulo del brazo desde la horizontal | Brazo hacia arriba | ≈ 118° |
| `3` | t3 codo | Ángulo **absoluto** del antebrazo | Antebrazo hacia arriba | ≈ 49° |

- **Transmisión:** NEMA 17 (Leadshine 42HS08) con driver DM556, correa GT2 20T → 90T, o sea una **reducción de 4,5** (10° articulares = 45° de motor).
- **Encoders:** un AS5600 en el eje de cada motor, detrás del multiplexor PCA9548A (canales 2, 3 y 4).
- **Servo:** el SG90 gira un medio disco bajo el vaso. Con ψ = −3° la compuerta está **cerrada** (retiene la esfera); con ψ = −30° está **abierta** (la esfera cae). Hay un tope mecánico en +3°.
- **Homing de hombro y codo juntos.** Si el codo va solo a su final con el hombro bajo, la biela del codo choca con el eje del hombro (ver T07).

### Lo que sale de la hoja de hardware y conviene saber

- **Drivers.** Los DM556 se manejan con BC337 en ánodo común: GPIO en ALTO → optoacoplador encendido. **ENA no está conectado**, así que los motores siempre tienen par. Para girarlos a mano (T04) hay que **cortar los 24 V**.
- **Retardo de los finales.** El filtro RC de los finales (10 kΩ · 1 µF) tarda **~14 ms** en cruzar el umbral del ESP32, no 10 (es 1,39 τ). A la velocidad de homing lenta (2 °/s) eso son ~0,03°: despreciable. A 60 °/s son ~0,8°: por eso el homing hace una segunda pasada lenta.
- **Confirmación por software de los finales.** El ESP32 no tiene histéresis en las entradas: un flanco tan lento puede cruzar el umbral varias veces. El firmware igual confirma 2 ms por software (no cuesta nada), y T02 mide si el RC alcanza solo.
- **Pull-up interno de los finales apagado.** Con los 10 kΩ en serie formaría un divisor.
- **GPIO14** (PUL del motor 1) puede dar pulsos durante el arranque del ESP32: el motor 1 puede dar un paso suelto al resetear. Sin correa no importa; con correa, tenerlo en cuenta.
- **Supuesto ⚠️:** Motor 1 = base, 2 = hombro, 3 = codo, y lo mismo para encoders y finales. T05, T06 y T07 detectan si algo está cruzado.

---

## 3. Qué hay en la carpeta

```
PI7_banco_pruebas/
├── LEEME.md                    este archivo
├── platformio.ini              placa nodemcu-32s, ESP-IDF, monitor a 115200
├── sdkconfig.defaults          240 MHz, tick 1 ms, pila de 8 kB
├── CMakeLists.txt
├── src/
│   ├── pi7_config.h            ← EL ÚNICO ARCHIVO QUE SE EDITA
│   ├── main.c                  menú de tests
│   ├── pi7_comun.*             consola, banner, validación de pines, esperas
│   ├── pi7_motores.*           movimiento con rampas y DOS generadores de pasos
│   ├── pi7_encoders.*          AS5600 vía PCA9548A
│   ├── pi7_finales.*           finales de carrera
│   ├── pi7_servo.*             SG90
│   ├── pi7_ayudas.c, pi7_tests.h   ayudas compartidas por los tests
│   └── t01_ … t09_*.c          un archivo por test
└── herramientas/
    └── PI7_ele_captura_serie_script.m   captura los datos de los tests a CSV desde MATLAB
```

### 3.1 Módulos

| Archivo | Qué hace |
|---|---|
| `pi7_config.h` | Pines, micropasos, reducción, sentidos de motores y encoders, polaridad de los finales, velocidades de prueba, homing y calibración del servo. Los tests imprimen la línea exacta para pegar acá cuando algo no coincide. |
| `pi7_comun` | Consola por UART con eco. Banner con chip, versión de ESP-IDF y **motivo del último reinicio** (detecta *brownout*). Validación de pines, esperas que se pueden abortar, bloques CSV. |
| `pi7_motores` | Rampas trapezoidales calculadas a 1 kHz, modos posición / velocidad / parada y vigilancia de finales con política de seguridad. Tiene **dos generadores de pasos con la misma interfaz** (sección 3.3). |
| `pi7_encoders` | Selecciona el canal del multiplexor y lee el ángulo. Acumula vueltas (encoder incremental). Diagnóstico del imán, errores y tiempos. |
| `pi7_finales` | Confirmación de 2 ms y conteo de flancos crudos por interrupción: dice si el RC deja una sola transición por apretada. |
| `pi7_servo` | Pulso de 500 a 2500 µs a 50 Hz con rampa. "Soltar" corta los pulsos y deja el servo sin par. Conversión ψ ↔ µs. |

### 3.2 Tests

| Test | ¿Mueve? | Qué verifica | Comandos |
|---|---|---|---|
| **t01** diagnóstico | No | Pines, parámetros, bus I2C canal por canal, imanes, finales. `sonda`: qué GPIO cambia al apretar cada final | `todo` `param` `i2c` `enc` `finales` `sonda` |
| **t02** finales | No | Apretadas y soltadas con sus flancos crudos, polaridad real, pines flotantes, cables cruzados | `calibrar` `estado` `plot` `cero` |
| **t03** servo | Servo | Recorrido, rampa, calibración cerrado/abierto, ciclos y brownout | `us` `+`/`-` `soltar` `rampa` `barrido` `marcar cerrado` `marcar abierto` `psi` `abrir` `cerrar` `ciclos` |
| **t04** encoders | No | Imán, ruido en reposo, tiempo de lectura (frecuencia máx. del lazo), vuelta a mano, frecuencia del I2C | `estado` `diag` `monitor` `vuelta` `ruido` `tiempo` `frec` `cero` |
| **t05** motores | Motores | Sentido de giro guiado, micropasos a ojo, rampas, cambios de sentido, carga de CPU | `eje` `m` `mm` `p` `vuelta` `ida` `jog` `s` `v` `a` `sentido` `todos` `politica` `carga` |
| **t06** motor + encoder | Motores | Canal cruzado, signo del encoder, **micropasos reales del DM556**, pasos perdidos, excentricidad del imán, seguimiento, velocidad máx. | `auto` `rel` `lineal` `seguir` `velmax` `estado` `cero` |
| **t07** motor + final | Motores | Cada final frena a su motor (con la latencia), bloqueo, homing, homing conjunto hombro + codo, disparos falsos | `parada` `bloqueo` `homing` `homing23` `ruido` |
| **t08** integración | Todo | Quemado con todo moviéndose a la vez: errores I2C, disparos falsos, pasos perdidos, reinicios | `correr` `estado` |
| **t09** generador HW | Motores | Generador por hardware: frecuencia real, **N pulsos exactos**, repetibilidad, rampa y la demo del `main.c` de referencia | `frec` `pulsos` `repetir` `rampa` `demo` |

Cada verificación termina en **PASA / NO PASA**.

### 3.3 Los dos generadores de pasos

| | **Software** (por defecto) | **Hardware** (`hw`) |
|---|---|---|
| Cómo | Interrupción de un timer a 40 kHz (núcleo 1) con acumulador de fase | **LEDC** genera el tren de pulsos; el **PCNT** los cuenta leyendo el mismo pin y corta el tren en el pulso N exacto |
| CPU por paso | Sí (`carga` en T05 lo mide) | No |
| Frecuencia máx. | 20 kHz | 20 kHz (configurable) |
| Posición exacta | Siempre | Hasta 30 000 pasos por movimiento (contador de 16 bits); más que el recorrido de cualquier eje |

**Por qué el PCNT.** El `main.c` de referencia con LEDC genera una frecuencia, pero no sabe cuántos pasos dio: sirve para girar, no para posicionar. Sumándole el PCNT queda un generador por hardware que **sí** posiciona.

Los dos tienen la misma interfaz: cualquier test de motores se corre con uno u otro agregando `sw` o `hw` (ej.: `t06 hw`). T09 usa siempre el de hardware.

---

## 4. Antes de energizar

- [ ] **Correas afuera** en los tres ejes. Todos los tests están pensados así.
- [ ] Corriente de los DM556 al mínimo en los DIP (sin carga no hace falta más).
- [ ] Anotar los micropasos del DIP de cada DM556 (T06 los mide igual).
- [ ] Revisar contra la hoja de hardware que AS5600, PCA9548A y módulos de finales estén a **3,3 V**.
- [ ] Revisar que el SG90 esté en el 5 V de la ATX y que todas las masas lleguen al nodo central.
- [ ] La primera vez con el servo, **medio disco desmontado**: el primer pulso es un salto.

---

## 5. Secuencia de prueba

Hacerla **en orden**: cada paso usa lo que dejó configurado el anterior. Cada vez que se cambia `pi7_config.h` hay que **volver a compilar y cargar**.

### Paso 0 · Diagnóstico (`t01`)

1. `t01`. Revisar que la tabla de pines no tenga ERROR.
2. Revisar el escaneo I2C: tiene que aparecer el PCA9548A y un AS5600 en los canales 2, 3 y 4.
3. Si hace falta, `sonda` y apretar los finales de a uno: muestra qué GPIO cambia (tienen que ser 23, 25 y 26).

**Pasa si:** no hay errores de pines, el multiplexor responde y aparecen los tres encoders con el imán OK.

### Paso 1 · Finales de carrera (`t02`)

1. Sin tocar nada, ninguno tiene que figurar APRETADO.
2. `calibrar`: 3 s sin tocar nada, y después apretar y mantener cada final cuando lo pide. Si dice NO COINCIDE o cables cruzados, pegar la línea que imprime.
3. Apretar y soltar cada final varias veces mirando los **flancos crudos**. Si en general da 1, el filtro RC funciona como dice la hoja; si da más, la confirmación de 2 ms del firmware lo está cubriendo.
4. Desconectar un módulo y ver qué estado muestra. Si se ve "suelto", un cable cortado no frenaría el homing: sólo lo frena la guarda de recorrido.

**Pasa si:** la polaridad coincide, no hay flancos sin tocar nada y cada apretada da una sola activación.

### Paso 2 · Servo (`t03`)

1. **Disco desmontado.** `us 1500`, después `+ 20` / `- 20` hasta entender para qué lado gira.
2. Montar el disco y llevarlo a la posición **cerrada** (tapa la mitad del agujero): `marcar cerrado`.
3. Llevarlo a la **abierta** (unos 27° más allá; la esfera tiene que caer): `marcar abierto`.
4. Pegar en el config las dos líneas que imprime. Probar `abrir`, `cerrar` y `ciclos 20`.

**Pasa si:** abre y cierra sin tocar el tope y sin reinicios (si se reinicia, el banner dice BROWNOUT).

### Paso 3 · Encoders (`t04`) — con los 24 V CORTADOS

1. `diag`: los tres con el imán OK.
2. `tiempo`: sin errores. Si hay errores, `frec 100000` y repetir.
3. `ruido 1`, `ruido 2`, `ruido 3`: desvío ≤ 1 cuenta.
4. `vuelta 1`, `vuelta 2`, `vuelta 3`: marcar un diente de la polea, girar una vuelta a mano y volver a la marca.

**Pasa si:** se cumplen los cuatro puntos y `estado` muestra 0 saltos.

### Paso 4 · Motores (`t05`) — 24 V conectados

1. `eje 1`, después `sentido`: el motor gira +30° articulares y pregunta si fue en el sentido positivo de la tabla de la sección 2. Si la respuesta es no, pegar la línea `DIR_INVERTIDA`. Si se movió **otro** motor, los cables STEP/DIR están cruzados entre drivers. Repetir con 2 y 3.
2. `vuelta 1` en cada eje: la marca de la polea tiene que volver exacta. Media vuelta o dos vueltas = el DIP de micropasos no coincide con `MICROPASOS`.
3. `ida 30 5`, `jog 20` y después `s`, y `todos 20`. `carga`: anotar el % de CPU del generador por software.

**Pasa si:** los tres ejes giran en el sentido correcto y la vuelta cierra en la marca.

### Paso 5 · Motor contra encoder (`t06`)

1. `auto 1`, `auto 2`, `auto 3`. Si informa signo invertido, micropasos distintos o encoder de otro eje, corregir el config y repetir hasta PASA.
2. `lineal 1` (2, 3): error del encoder en una vuelta. Si el armónico 1 es grande, el imán está descentrado.
3. Opcionales: `seguir 1 90` y `velmax 1`.

**Pasa si:** `auto` da PASA en los tres ejes.

### Paso 6 · Generador por hardware (`t09`)

1. `pulsos 1 3200`: tiene que decir **EXACTO**, y el encoder tiene que marcar una vuelta de motor (±4 cuentas).
2. `repetir 1 3200 20 4000`: 20 idas y vueltas a 4 kHz. El encoder tiene que volver al inicio.
3. `frec 1 8000 3`: la frecuencia medida tiene que coincidir con la pedida.
4. Repetir en los ejes 2 y 3. Opcional: `demo` (la secuencia del `main.c` de referencia con los pines correctos).
5. Opcional: correr `t06 hw` → `auto 1`, para ver que el resto de los tests anda igual con este generador.

**Pasa si:** EXACTO en todos y el encoder vuelve al inicio. Si falla acá pero `t06` (software) pasa, el problema está en el generador por hardware: seguir con el de software.

### Paso 7 · Motor contra final (`t07`)

1. `parada 1` (2, 3): el motor gira hacia su final; apretalo con el dedo. Tiene que parar enseguida y decir PASA. Si dispara el final de otro eje, el test lo informa como cables cruzados.
2. `bloqueo 1` (2, 3): con el final apretado no avanza hacia él, pero sí se aleja.
3. `homing 1` (2, 3): seguir las indicaciones (apretar, soltar, apretar de nuevo).
4. `homing23`: apretar el final de uno de los dos ejes; el otro motor tiene que **seguir girando** hasta que se apriete el suyo.
5. `ruido 30`: los tres motores girando sin tocar nada.

**Pasa si:** todo da PASA y `ruido` da 0 disparos falsos.

### Paso 8 · Integración (`t08`)

1. `correr 300`: 5 minutos con todo moviéndose a la vez.
2. Opcional: `t08 hw` → `correr 300`, para comparar los dos generadores.

**Pasa si:** retorno ≤ 4 cuentas en los tres ejes, sin errores I2C, sin disparos falsos y sin reinicios.

Con los 9 pasos aprobados, `pi7_config.h` queda con los valores reales del robot. Es la base del firmware final, y el siguiente paso es repetir el homing **con correas** y la corriente baja.

---

## 6. Capturar datos con MATLAB

Los comandos `lineal` y `seguir` de T06 emiten los datos entre las marcas `#CSV_INI` y `#CSV_FIN`.

1. **Cerrar el monitor serie de PlatformIO**: no pueden usar el puerto los dos a la vez.
2. En `herramientas/PI7_ele_captura_serie_script.m`, poner el puerto (`COM5` o el que corresponda) y los comandos, por ejemplo `["t06", "lineal 1"]`.
3. Correrlo: reinicia el ESP32, entra al test, manda el comando, guarda el CSV en `herramientas/datos_banco/` y grafica cada columna.

---

## 7. Si algo falla

| Síntoma | Primer sospechoso |
|---|---|
| El banner dice BROWNOUT | El servo o los motores bajan el 5 V de la ATX. Revisar el VIN del ESP32 y el nodo de masa |
| `Tick FreeRTOS` distinto de 1000 | No se borró `sdkconfig.nodemcu-32s` antes de compilar |
| El motor vibra pero no gira | Bobinas cruzadas entre fases (A+/A− con B+/B−) |
| Pierde pasos rápido pero lento anda | Corriente del DM556 muy baja para esa velocidad, o el BC337 no satura (revisar la R de base de 1 kΩ) |
| `vuelta 1` da media vuelta o dos | El DIP de micropasos ≠ `MICROPASOS` |
| El encoder salta con el imán OK | Cables I2C largos o junto a los de motor: bajar a 100 kHz |
| Un final dispara solo con los motores girando | Acople de los cables de motor. Ver `ruido` de T07 |
| T09 no da EXACTO y T06 sí pasa | Problema del generador por hardware: seguir con el de software y reportarlo |
| `x` no responde | Cortar los 24 V. Los motores no tienen ENA: no hay otra forma de liberarlos |
