# Herramientas (`tools/`)

## 1. Herramientas en Python

Sirven para probar la comunicación UDP sin tener el volante, y para usar el volante por cable.

### Instalación

Requiere **Python 3.10 o superior**.

```bash
cd tools
python -m venv .venv                 # opcional, recomendado
.venv\Scripts\activate               # Windows   (en Linux/macOS: source .venv/bin/activate)
pip install -r requirements.txt
```

`fake_wheel.py --auto` no necesita ninguna librería (solo la biblioteca estándar).

### `fake_wheel.py` — volante simulado

Hace lo mismo que hará el ESP32: envía el mensaje `W` 100 veces por segundo y muestra la telemetría
(`T`) y la vibración (`V`) que recibe.

```bash
python fake_wheel.py                  # ventana: se maneja con el TECLADO (ventana del volante en foco)
python fake_wheel.py --gamepad        # ventana: se maneja con un GAMEPAD
python fake_wheel.py --auto           # sin ventana: mueve la dirección sola e imprime lo recibido
python fake_wheel.py --host 192.168.1.50      # si el juego corre en otra PC
python fake_wheel.py --center 120 --range 800 # simula un sensor descentrado (para probar la calibración)
python fake_wheel.py --help
```

Pasos para probar:

1. Abrir el juego → *Opciones* → *Fuente de entrada* → **Volante UDP**.
2. Ejecutar `python fake_wheel.py`.
3. Entrar a un nivel. La ventana del volante simulado debe quedar **en foco** para leer el teclado
   (conviene poner el juego y esa ventana lado a lado).

En la ventana se ven los 10 **shift lights**, la marcha, los estados (DRS, limitador...), la
dirección, los pedales y los botones. El fondo se pone rojo durante cada evento de vibración.

Teclas: A/D o flechas (dirección), W/S o ↑/↓ (pedales), E/Q (marchas), F (DRS), Espacio (ERS),
L (limitador), R (reset), C (cámara), P (pausa), Re Pág/Av Pág (encoder), Esc (salir).

### `serial_bridge.py` — puente USB serie ↔ UDP

Para cuando el ESP32 esté conectado por cable. Reenvía las líneas `W,...` del puerto serie al juego
por UDP, y la telemetría del juego al puerto serie.

```bash
python serial_bridge.py --list                    # ver los puertos disponibles
python serial_bridge.py --port COM5               # Windows
python serial_bridge.py --port /dev/ttyUSB0       # Linux
python serial_bridge.py --port COM5 --verbose     # muestra además los mensajes de depuración del ESP32
```

El juego se configura igual: *Fuente de entrada* → **Volante UDP**. Si el ESP32 se desconecta, el
puente reintenta abrir el puerto cada segundo.

### `wheel_protocol.py`

Constantes y funciones del protocolo compartidas por las dos herramientas. Es el equivalente en
Python de `scripts/input/wheel_protocol.gd`: si se cambia el protocolo, hay que cambiar **los dos**
(y `docs/protocolo.md`).

### Si no conecta

- **Firewall de Windows:** permitir a Godot y a Python en redes privadas.
- **Puertos ocupados:** solo un programa puede escuchar el 4210 (el juego) y uno el 4211 (el
  volante simulado **o** el puente serie, no los dos a la vez).
- **Otra PC:** en `fake_wheel.py` usar `--host <IP de la PC del juego>`. El juego responde solo a la
  IP desde la que recibe paquetes.
- En el juego, *Opciones → Log de telemetría* imprime en la consola de Godot lo que se envía.

## 2. Conversor de circuitos (`tools/circuits/`)

```bash
python tools/circuits/convert_circuits.py              # los 25
python tools/circuits/convert_circuits.py monaco spa   # solo algunos
```

Lee `circuits.json` y `geojson/*.geojson` y escribe `assets/circuits/<id>.tres`. Solo usa la
biblioteca estándar de Python. Qué hace cada paso: `docs/circuitos.md` §3. Cómo agregar un
circuito: `README.md` §8.

## 3. Herramientas de Godot (`tools/godot/`)

Se ejecutan con el ejecutable de Godot 4.7 desde la carpeta del proyecto. En Windows reemplazar
`godot` por la ruta al `.exe` (por ejemplo `"C:\...\Godot_v4.7-stable_win64_console.exe"`), y
agregar `--path .` si no se está parado en la carpeta del proyecto.

### Generador de escenas

```bash
godot --headless --import                                    # una vez, si el proyecto nunca se abrió
godot --headless --script res://tools/godot/build_scenes.gd  # regenera todas las escenas
godot --headless --script res://tools/godot/build_scenes.gd -- autos
godot --headless --script res://tools/godot/build_scenes.gd -- circuito monaco spa
godot --headless --script res://tools/godot/build_scenes.gd -- niveles
```

Pasos disponibles: `autos`, `neumaticos`, `circuitos`, `interfaz`, `niveles`. Con `circuito <id> ...`
se generan solo esos circuitos. **Regenerar pisa los cambios hechos a
mano** en esas escenas.

| Archivo | Genera |
|---|---|
| `car_builder.gd` | `assets/setups/car_setup_default.tres`, `assets/tyres/*.tres` y las escenas de `scenes/car/` |
| `track_builder.gd` | `scenes/track/circuitos/<id>.tscn`, una por cada recurso de `assets/circuits/` |
| `level_builder.gd` | Menús (incluido `session_setup.tscn`), HUD y los dos niveles |
| `builder_utils.gd` | Funciones comunes (crear primitivas, guardar escenas) |

### Pruebas automáticas (`tools/godot/tests/`)

Corren el juego real sin ventana. `--fixed-fps 60` hace que la simulación avance a paso fijo y lo
más rápido posible (una vuelta de un minuto se simula en un par de segundos).

```bash
godot --headless --fixed-fps 120 --script res://tools/godot/tests/test_skidpad.gd           # ≈5 min; escribe docs/skidpad.md
godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_controls.gd
godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_pits.gd -- monaco      # circuito opcional
godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_weather.gd
godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_tyres.gd
godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_circuit.gd -- spa lluvia
python tools/godot/tests/run_circuits.py --godot RUTA_A_GODOT       # los 25 circuitos, seco y lluvia (≈6 min)
godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_drive.gd -- monaco 130
godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_levels.gd -- nivel=carrera circuito=spa clima=lluvia neumatico=lluvia vueltas=3 segundos=600
```

`test_skidpad.gd` mide la capacidad del auto sobre un plano (sin circuito) con una fuente de entrada
propia (`skidpad_source.gd`, registrada con `InputManager.register_source`). Con `-- medir` solo
mide (no verifica objetivos ni reescribe el documento) y con `-- medir traza` imprime además la
velocidad y la altura del auto en la recta. Conviene correrla cada vez que se toca `car_setup.gd`.

`run_circuits.py` lanza una instancia de Godot por combinación (en paralelo, `--jobs N`), y con la
corrida completa reescribe `docs/resultados_circuitos.md`. Acepta ids para probar solo algunos.

La prueba de red necesita tiempo real (sin `--fixed-fps`) y el volante simulado corriendo a la vez:

```bash
# Terminal 1
cd tools && python fake_wheel.py --auto --duration 9 --auto-throttle 0.6 --auto-buttons
# Terminal 2 (enseguida)
godot --headless --script res://tools/godot/tests/test_udp.gd
```

Todas menos `test_drive.gd` y `test_levels.gd` terminan con `RESULTADO: TODO OK` o con la
cantidad de fallas. Las que dan vueltas en Clasificación (`test_levels.gd`, `test_circuit.gd`)
**guardan récords** del piloto automático en `user://fantasmas/` y `user://tiempos.cfg`: si querés
empezar de cero, borrá esos archivos (*Proyecto → Abrir carpeta de datos de usuario* en el editor).

Las pruebas cambian opciones solo en memoria: no modifican `user://opciones.cfg`.
