# Bitácora de desarrollo — Simulador F1, Fase 1 (software)

Este documento cuenta **cómo se hizo** esta fase: en qué orden, con qué método, qué se probó, qué
problemas aparecieron y cómo se resolvieron. Está pensado para que puedas entender el proceder,
explicarlo en el informe y continuar el trabajo.

- **Fecha:** 16 de noviembre de 2026 (una sola sesión de trabajo).
- **Quién:** Claude (asistente de IA), a partir del pedido escrito en `prompt_simulador_F1_fase1.md`.
- **Resultado:** proyecto de Godot 4.7 completo y jugable, con sus herramientas, pruebas y documentación.

> **Leelo con esta salvedad:** todo lo que dice "verificado" se verificó ejecutando el juego en un
> servidor, sin pantalla ni sonido reales. Lo que **no** se pudo comprobar está listado sin vueltas
> en la sección 6. Lo primero que conviene hacer es abrirlo en tu PC y revisar esa lista.

---

## 1. Punto de partida

### Qué leí antes de empezar

| Material | Qué saqué de ahí |
|---|---|
| `prompt_simulador_F1_fase1.md` | El alcance completo: arquitectura obligatoria (`InputManager`, fuentes, `TelemetryOut`), protocolo, contenido del juego, hitos y forma de trabajar. |
| `Trabajo_integrador/Consigna/rv_meca_tp integrador.docx.pdf` | Requisitos de la cátedra: primitivas 3D (punto 8), la lógica de interacción con el usuario como elemento importante cuando se usa un motor gráfico (punto 10), al menos 2 escenarios o niveles (punto 12), elementos de diseño en 2 capas de software (punto 13), informe tipo "manual paso a paso" (punto 7), video de 5–7 minutos y repositorio. |
| Tu TP5 (`trabajo-pactico-numero-5/`) | Tu configuración: Godot 4.7, Jolt, Forward+, `d3d12` en Windows, ventana con *stretch* `canvas_items` / `expand`, `.gitignore` y `.gitattributes`. Copié esa configuración. También tu estilo: nombres en inglés con comentarios en español. |

Los informes de años anteriores (`Trabajo_integrador/Ejemplos/`) **no los leí**: solo vi que
estaban. No hicieron falta para el software, pero te van a servir de modelo para el informe.

### Dónde quedó el proyecto

Pediste guardar todo en `Realidad_Virtual\Proyecto`. El proyecto de Godot quedó en
`Proyecto\Simulador_F1\` (y no directamente en `Proyecto\`) para que después puedan convivir al lado
el firmware y el informe, por ejemplo `Proyecto\Firmware_ESP32\` y `Proyecto\Informe\`.

### Entorno de trabajo

Trabajé en un servidor Linux, no en tu computadora. Bajé **Godot 4.7-stable** (el mismo que usás) y
lo ejecuté de dos maneras:

- **Sin ventana (`--headless`)** para generar escenas y correr pruebas. Con `--fixed-fps 60` la
  simulación avanza a paso fijo y a toda velocidad: una vuelta de un minuto se calcula en ~2 segundos.
- **Con una pantalla virtual** (Xvfb + renderizado por software) para sacar capturas y revisar que
  el circuito, el auto, el HUD y los menús se vieran razonables. Ese entorno solo soporta el
  renderer de **compatibilidad**, no Forward+.

Al terminar copié los archivos a tu carpeta (el historial de git va aparte: ver sección 7).

---

## 2. Método de trabajo

Tres decisiones de método marcaron todo lo demás:

1. **Experimentar antes de diseñar.** Lo que no sabía con certeza lo medí con un script de 30 líneas
   antes de escribir código que dependiera de eso (sección 3).
2. **Escenas generadas por código.** No tenía el editor gráfico, así que las escenas `.tscn` las
   escribe Godot ejecutando `tools/godot/build_scenes.gd`. El formato es válido por construcción y
   el proceso queda documentado. Las escenas son normales: las podés abrir y editar.
3. **Un piloto automático como herramienta de prueba.** Para saber si el auto "se maneja" sin poder
   manejarlo, escribí una fuente de entrada más (`AutopilotSource`) que conduce por el mismo
   `InputManager` que usará el volante. Cada prueba recorre la cadena real completa.

Sobre los hitos: el pedido listaba 8 hitos a verificar uno por uno. Los respeté como orden de
construcción y de prueba, pero escribí el código de varios hitos de corrido antes de la primera
ejecución (los modelos de motor, DRS, ERS y neumáticos son parte del auto y no tenía sentido probar
el auto sin ellos). Quedaron tres *commits* de git que agrupan los hitos; no hay uno por hito.

---

## 3. Experimentos previos

| Pregunta | Cómo la respondí | Resultado | Consecuencia |
|---|---|---|---|
| ¿`VehicleBody3D` funciona con Jolt? ¿Hacia dónde avanza y hacia dónde gira? | Un auto mínimo sobre un plano, aplicando `engine_force` y `steering` | Funciona. `engine_force` positiva empuja hacia **+Z**; `steering` positivo gira a la **izquierda** | Modelé el auto mirando a −Z (convención de Godot) y aplico ambas con signo cambiado. Me quedé con `VehicleBody3D`. |
| En `CSGPolygon3D` modo PATH, ¿qué lado es +X de la sección? | Extruí un rectángulo de x = 0 a 5 y tiré dos rayos | +X es la **derecha** del sentido de avance. La colisión se genera bien | Pude escribir las secciones (pianos, muros) sabiendo qué lado es cuál. |
| ¿Puedo ver lo que dibujo? | Captura de un cubo con Xvfb + OpenGL por software | Sí, con el renderer de compatibilidad | Usé capturas para revisar el aspecto. |
| ¿Cómo queda el trazado? | Volqué la curva a JSON y la grafiqué coloreada por radio de curvatura | 2951 m; chicana de 23–25 m de radio, horquilla de ~25 m | Confirmé que había recta larga, chicana y horquilla antes de construir nada encima. |

---

## 4. Desarrollo por hitos

### Hito 1 — Proyecto base, `InputManager` y auto manejable

**Qué hice**

- `project.godot` con tu configuración más: 120 ticks de física, 4 autoloads, nombres de capas de colisión.
- Capa de entrada: `InputSource` (base), `KeyboardSource` (con suavizado), `GamepadSource`,
  `UdpWheelSource`, `AutopilotSource`, y el autoload `InputManager`.
- `WheelProtocol` (constantes del protocolo) y el autoload `TelemetryOut`.
- El auto: `CarSetup` (recurso con todos los parámetros), `Drivetrain`, `F1Systems`, `F1Car`,
  sonido por síntesis, cámaras, y el modelo de primitivas (`car_builder.gd`).

**Cómo lo probé:** `tools/godot/tests/test_drive.gd` — circuito + auto + piloto automático.

**Problema 1 — los scripts de prueba no compilaban.** Un script lanzado con `--script` se compila
*antes* de que existan los autoloads; como mi prueba nombraba el tipo `F1Car`, arrastraba la
compilación de `f1_car.gd`, que usa `InputManager`, y fallaba. *Solución:* en los scripts de prueba
no uso tipos del juego (variables sin tipo, y los nodos se cargan recién al iniciar). Está
comentado en cada prueba.

**Problema 2 — el auto no pasaba de 250 km/h.** La primera vuelta salió (63,9 s, sin despistes) pero
la velocidad máxima era muy baja. Medí la aceleración en la recta: 2,3 m/s² cuando las cuentas
daban 8. Fui descartando causas imprimiendo valores cada medio segundo: acelerador a fondo, fuerza
de tracción correcta, ruedas sin patinar, sin freno. Comparé dos marchas y vi que la fuerza que
"faltaba" crecía con la velocidad: ~4300 N a 59 m/s y ~5000 N a 65 m/s. Eso es `0,1 × masa ×
velocidad`: el **amortiguamiento lineal por defecto** de Godot (0,1 s⁻¹), que a esas velocidades
frena más que toda la aerodinámica. *Solución:* `linear_damp_mode = REPLACE` con `linear_damp = 0`
en el auto. Resultado: 336 km/h con DRS y vueltas de 58,7 s.

**Problema 3 — el DRS no abría.** El piloto automático "apretaba" el botón pero no pasaba nada: el
`InputManager` descarta los botones de juego mientras hay un menú, y la bandera `GameState.in_menu`
arranca en `true`. En el juego real la sesión la pone en `false`; mi prueba no lo hacía. Era un
error de la prueba, pero confirmó que ese filtro funciona.

### Hito 2 — Circuito y cronometraje

**Qué hice**

- `track_layout.gd`: 36 puntos de control y medidas. `build_curve()` los convierte en una `Curve3D`
  suave (tangentes tipo Catmull-Rom, manijas de 1/3 de la distancia al vecino).
- `track_builder.gd`: asfalto, líneas, pit lane, pianos y muros por extrusión (`CSGPolygon3D`),
  zonas `Area3D`, decorado con primitivas.
- `track.gd`: progreso, superficie bajo un punto, transformaciones, curvatura, perfil de velocidad.
- `lap_timer.gd`: checkpoints en orden, 3 sectores, mejor vuelta, delta, validez.

**Decisiones**

- **Pianos solo en las curvas**, detectadas por curvatura (radio < 130 m): 7 tramos, cada uno con su
  sub-curva. Pianos en toda la vuelta habría sido más simple pero poco creíble.
- **Muros sobre curvas paralelas** al eje. No podían compartir la curva del asfalto porque frente a
  boxes el muro interior tiene que alejarse para dejar lugar al pit lane.
- **Superficie por geometría**, no por colisión (ver `docs/decisiones_diseno.md` §7).
- **Cronometraje con precisión menor al tick:** corrijo el instante de cruce con `d / v`.

**Problema 4 — los árboles no aparecían.** En la primera captura no había ninguno. El archivo de la
escena tenía los `MultiMesh` con 220 instancias pero **sin las posiciones**: sin placa de video,
Godot no conserva ese buffer y no lo guarda. *Solución:* la escena guarda la lista de posiciones,
giros y escalas en un nodo (`tree_scatter.gd`, script `@tool`) que arma los `MultiMesh` al iniciar.

**Verificación:** capturas del circuito desde arriba, de la chicana, la horquilla, boxes y la
largada. En `test_levels.gd` la suma de los tres sectores coincide con el tiempo de vuelta
(18,966 + 17,802 + 22,051 = 58,819 ≈ 58,820 s).

### Hitos 3 y 4 — Motor/caja, HUD y mecánicas F1

El modelo ya estaba escrito desde el hito 1; acá lo verifiqué y armé el HUD.

- **Motor y caja:** en 1ª a fondo el limitador clava el auto en 95 km/h, que es exactamente la
  velocidad calculada para 12000 rpm en esa marcha. La caja automática sube y baja sola. Una rebaja
  que pasaría de vueltas al motor es rechazada.
- **DRS:** abre solo dentro de la zona, se cierra al frenar; además mueve el flap del alerón.
- **ERS:** se gasta manteniendo el botón y se recarga frenando.
- **Neumáticos:** ajusté el desgaste con las pruebas. Primero daba 17 % por vuelta; subí la vida útil
  hasta ~12 %. Con lluvia se disparaba al 30 % por el patinamiento, así que bajé el peso de ese
  término (quedó ~12 % también en mojado).
- **Limitador:** se estabiliza en 79,8 km/h con el acelerador a fondo.

**Problema 5 — el HUD salía amontonado en una esquina.** En la primera captura del juego, el
tablero central y los mensajes aparecían arriba y abajo a la izquierda. Había usado
`set_anchors_preset()`, que cambia los anclajes pero recalcula los márgenes para que el control *no
se mueva*. *Solución:* `set_anchors_and_offsets_preset()` más direcciones de crecimiento, en una
función `_anchor()`. La segunda captura salió bien.

**Ajustes visuales después de mirar las capturas:** la cámara onboard quedaba tapada por el halo
(lo subí y afiné, y bajé la cámara); la T-cam mostraba la toma de aire en primer plano (la adelanté);
la luz trasera flotaba detrás del auto (le agregué la estructura que la sostiene).

### Hito 5 — Nivel 1: Clasificación con fantasma

`ghost_lap.gd` graba la vuelta (60 muestras por segundo) y una tabla distancia→tiempo;
`qualifying_session.gd` guarda el récord en `user://` y lo reproduce.

**Verificación:** el nivel corrió de punta a punta en la primera ejecución: dos vueltas válidas, el
archivo del fantasma se creó (~100 kB) y el delta apareció en la segunda vuelta. Como el piloto
automático repite casi la misma vuelta, el fantasma quedaba superpuesto con el auto y no se
distinguía en la captura; lo confirmé por dos caminos: imprimiendo su estado (visible, 2,8 m
adelante del auto) y renderizándolo aparte al lado de un rival (se ve translúcido celeste).

### Hito 6 — Nivel 2: Carrera con IA, lluvia y boxes

`ai_car.gd` (rivales), `race_session.gd` (semáforo, posiciones, parada obligatoria, penalizaciones,
resultados), `weather.gd` (lluvia) y las reglas de boxes en `session_base.gd`.

**Problema 6 — el piloto automático chocaba a los rivales.** En la primera carrera hizo vueltas de
81, 73 y 69 s con despistes. Dos causas: no esquivaba a nadie, y los rivales que iban a boxes
frenaban sobre la línea de carrera. *Soluciones:* (a) los rivales que van a boxes ahora se abren
hacia el lado del pit lane y frenan recién dentro del carril de entrada; (b) le di al piloto
automático una lógica mínima de tránsito (cambia de carril o levanta). Después: tres vueltas válidas
de 67,5 / 65,7 / 65,6 s bajo la lluvia, pasando a los cuatro rivales.

**Problema 7 — no parar en boxes convenía.** La parada cuesta ~22 s y la penalización por no parar
era de 20 s. La subí a **30 s**.

**Problema 8 — tiempos absurdos en la tabla.** Al cortar una carrera recién largada, los rivales
aparecían con "8:50", "10:27"... La estimación para quien no llegó dividía por una velocidad media
todavía casi nula. *Solución:* durante los primeros 20 s se usa una velocidad media fija.

**Ajuste de dificultad:** con el agarre inicial de los rivales el piloto automático les sacaba ~5 s
por vuelta. Lo subí (`AI_PROFILE_GRIP` de 1,5 a 1,6). En la prueba final el piloto automático, sin
parar y con +30 s, terminó **segundo a 1,1 s** del ganador: una carrera pareja. Es el número a tocar
si te resulta fácil o difícil.

**Reglas de boxes (`test_pits.gd`):** exceso de velocidad → +5 s; detenerse en el box → auto
frenado, 2,6 s, neumáticos nuevos y parada contada; limitador → 79,8 km/h y sin sanción.

### Hito 7 — Menús, calibración, UDP y herramientas Python

- Menús por código con nodos `Control`: principal, opciones, calibración, pausa, resultados.
- El volante también navega los menús: el `InputManager` traduce sus botones a acciones `ui_*`.
- `tools/wheel_protocol.py`, `fake_wheel.py` y `serial_bridge.py`.

**Verificación**

- `test_controls.gd` inyecta **teclas reales** (eventos de entrada de Godot) y comprueba 22 cosas:
  suavizado del teclado, caja manual, limitador de régimen, rebaja rechazada, DRS, ERS, caja
  automática, vuelta invalidada, choque contra el muro (a 278 km/h, **sin atravesarlo**), volver a
  pista, cámara, limitador, encoder, pausa y marcha atrás. Todo OK.
- `test_udp.gd` + `fake_wheel.py --auto`, por la red local real: 870 paquetes `W` recibidos sin
  errores; dirección, acelerador y un botón llegaron al juego; el auto se movió; volvieron la
  telemetría y los eventos de vibración; y al cortar el volante el juego lo marcó "Sin señal" a los
  500 ms y soltó el acelerador. Todo OK.
- `serial_bridge.py` con un puerto serie virtual: reenvió los `W` hacia el juego, la telemetría
  hacia el "ESP32", e ignoró una línea de depuración intercalada.
- `fake_wheel.py` con ventana: prueba de humo con un controlador de video ficticio (abre, dibuja,
  cierra).

### Hito 8 — Documentación

`README.md`, `tools/README.md`, los cinco documentos de `docs/` y esta bitácora. Los escribí al
final, con los números de las pruebas ya corridas.

---

## 5. Verificación final

Para asegurarme de que el proyecto funciona "recién bajado", copié solo los archivos versionados a
una carpeta vacía (sin la caché `.godot/` y sin datos de usuario) y repetí todo desde cero:

| Prueba | Resultado |
|---|---|
| Importación limpia (`--import`) | Sin errores |
| Arranque normal (menú principal) | Sin errores |
| `test_drive.gd` | Vueltas de 59,85 y 58,68 s; máxima 336 km/h; 0,00 s fuera de pista |
| `test_levels.gd clasificacion` | Vueltas válidas de 58,820 y 58,678 s; récord guardado |
| `test_levels.gd carrera` (3 vueltas) | Vueltas válidas de 67,5 / 65,7 / 65,6 s; tabla de resultados coherente |
| `test_controls.gd` | TODO OK |
| `test_pits.gd` | TODO OK |
| `test_udp.gd` + `fake_wheel.py` | TODO OK |
| Puente serie (puerto virtual) | OK en los dos sentidos |

Las pruebas quedaron en `tools/godot/tests/` y las podés correr vos (instrucciones en `tools/README.md`).

---

## 6. Lo que NO se verificó

| Qué | Por qué | Riesgo |
|---|---|---|
| Aspecto con **Forward+** | Mis capturas son con el renderer de compatibilidad por software | Bajo: materiales y luces estándar. Puede cambiar el brillo, las sombras o la niebla. |
| **Sonido** del motor | No había audio | Medio: el código es simple, pero nadie lo escuchó. Puede sonar feo o fuerte. |
| **Cómo se siente manejar** | Manejaron el piloto automático y teclas simuladas | Medio: es lo más subjetivo. Todo es ajustable desde `car_setup_default.tres` y *Opciones*. |
| **Gamepad** físico | No había | Medio: los ejes de los gatillos y la numeración de botones dependen del control. |
| **FPS** en tu PC | Se renderizó por software | Bajo/medio: la escena es liviana, pero no lo medí. |
| El **volante** real | No existe todavía | El lado PC está probado contra el volante simulado. |
| Navegar los menús **con el volante** | Lo implementé pero no escribí una prueba | Bajo: son pocas líneas. |
| El aspecto de la ventana de `fake_wheel.py` | La abrí sin pantalla | Bajo. |

Si algo de esto falla, el detalle de qué tocar está en `docs/pendientes.md`.

---

## 7. Cosas que conviene que sepas

- **Regenerar pisa.** Si editás una escena a mano y después corrés `build_scenes.gd`, perdés el
  cambio. Elegí un camino por escena: o seguís con el generador, o seguís en el editor.
- **El fantasma del piloto automático.** Si corrés `test_levels.gd` con `clasificacion`, deja
  guardado un récord de ~58,7 s. Para empezar de cero borrá `fantasma_clasificacion.dat` (en el
  editor: *Proyecto → Abrir carpeta de datos de usuario*). El proyecto que te entrego **no** trae
  ningún récord.
- **Git: el historial viene aparte.** Trabajé con git desde el inicio (4 commits, con autor
  "Claude"), pero la herramienta con la que copié los archivos a tu PC no permite escribir dentro
  de una carpeta `.git`. Por eso `Simulador_F1\` llegó **sin** repositorio y el historial quedó en
  el archivo `Proyecto\simulador_f1_historial.bundle`. Tenés dos caminos:

  ```bat
  :: A) Recuperar mi historial dentro de la carpeta que ya tenés
  cd Proyecto\Simulador_F1
  git init -b main
  git fetch ..\simulador_f1_historial.bundle main
  git reset FETCH_HEAD
  git status          &:: debe decir que no hay nada para confirmar

  :: B) Empezar un historial propio desde cero
  cd Proyecto\Simulador_F1
  git init -b main
  git add -A
  git commit -m "Fase 1: simulador"
  ```

  El repositorio que entregues a la cátedra tiene que reflejar tu trabajo; cualquiera de los dos
  caminos sirve. El `.gitignore` ya excluye `.godot/`.
- **El ícono pesa más de lo esperado.** `icon.svg` es un dibujo de 20 líneas, pero al exportarlo
  desde mi entorno se le agregó automáticamente un bloque `<metadata>` con credenciales de
  contenido (C2PA) que lo identifican como generado con IA. Godot lo importa igual.
- **Aclará el uso de IA.** La consigna pide dejar claras las fuentes (observación 2). Lo dejé
  asentado en el README; corresponde que también figure en el informe.
- **Para defenderlo vas a tener que entenderlo.** Hay partes que conviene leer con calma porque son
  las más "preguntables": `input_manager.gd`, `f1_car.gd` (el tick paso a paso), `drivetrain.gd`,
  `lap_timer.gd` y `track_layout.gd` + `track_builder.gd`. Los documentos de `docs/` explican el
  porqué de cada una.

---

## 8. Números del proyecto

| | |
|---|---|
| Scripts del juego (GDScript) | 38 |
| Scripts de herramientas y pruebas (GDScript) | 10 |
| Herramientas en Python | 3 |
| Escenas | 15 |
| Líneas de código (aprox.) | 6000 de GDScript del juego · 2000 de generadores y pruebas · 700 de Python |
| Circuito | 2951 m, 36 puntos de control, 7 tramos de piano, 220 árboles |
| Vuelta de referencia (piloto automático) | 58,7 s en seco · 65,6 s con lluvia |
| Velocidad máxima | 336 km/h (8ª, con DRS y ERS) |

---

## 9. Por dónde seguir

1. Abrí el proyecto en Godot 4.7, apretá F5 y recorré la lista de la sección 6.
2. Ajustá a tu gusto el manejo y la dificultad.
3. Probá la cadena UDP con `tools/fake_wheel.py` para familiarizarte con el protocolo.
4. Fase 2: el orden sugerido para el firmware está en `docs/pendientes.md` §4.

---

# Fase 1b — circuitos reales, clima elegible, neumáticos y aquaplaning

- **Fecha:** 16 de noviembre de 2026 (segunda sesión de trabajo).
- **Pedido:** `prompt_simulador_F1_fase1b.md`.
- **Resultado:** 25 circuitos, clima elegible en los dos niveles, 5 compuestos, aquaplaning,
  menú de sesión, spray, mejores tiempos; 7 pruebas automáticas con veredicto, todas en `TODO OK`.

> Vale la misma salvedad que en la Fase 1: todo se verificó sin pantalla ni sonido reales. Lo que
> falta mirar en tu PC está en `docs/pendientes.md` §1.

## 10. Antes de tocar nada: tus cambios a mano

Comparé tu carpeta con el historial (`simulador_f1_historial.bundle`). Diferencias encontradas:

| Archivo | Cambio tuyo | Qué hice |
|---|---|---|
| `scripts/car/engine_sound.gd` | Motor más grave (`PULSES_PER_REVOLUTION` 1.0, mezcla de armónicos) | Lo tomé tal cual y **no lo modifiqué** en toda la fase |
| `project.godot` | Reordenado por el editor al abrirlo | Lo tomé tal cual |
| `.godot/`, `tools/__pycache__/` | Carpetas generadas | Ignoradas |

Quedaron registrados en un commit aparte ("Cambios manuales de Tomás") para que el historial
distinga lo tuyo de lo mío.

## 11. Decisiones principales

1. **Un recurso por circuito** (`CircuitData`) y **un generador genérico**. `track_builder.gd` se
   reescribió para no saber nada de un circuito en particular: todo sale del eje y de unas pocas
   medidas. Los Aromos pasó a ser un recurso más y sirve de control: tiene que dar lo mismo que antes.
2. **Trazados reales desde GeoJSON** (bacinger/f1-circuits, MIT), con un conversor en Python
   reproducible. Se escala cada trazado a la **longitud oficial**.
3. **El circuito no vive en la escena del nivel.** La sesión carga solo el elegido. Los dos niveles
   quedaron iguales salvo los rivales, y los dos tienen el nodo `Clima`.
4. **El agua en pista (0..1) es la única variable del clima que mira la física.** Lluvia, cielo y
   niebla son visuales. Eso permitió el clima Variable casi gratis.
5. **Compuestos como recursos** (`TyreCompound`), con la fórmula de aquaplaning adentro, para que
   el auto, los rivales y el piloto automático usen exactamente la misma cuenta.
6. **CSG sin hornear:** medí la carga (0,5–0,9 s por circuito) y no justificaba perder la edición en
   el editor. Queda anotado cómo hacerlo si hiciera falta.
7. **Protocolo UDP intacto:** solo se agregó el bit 7 de `flags` y un evento de vibración más,
   con el mismo formato de mensajes.

## 12. Hitos y problemas encontrados

### Hito 1b-1 — Circuitos

- Verifiqué el calendario 2026 y las longitudes oficiales por búsqueda web, y que el repositorio
  tuviera los 24 trazados (incluido Madrid).
- **Problema: progreso en pistas que se cruzan.** "El punto más cercano del eje" salta de tramo en
  Suzuka y en horquillas cerradas. → `Track.get_offset_near()`: búsqueda local alrededor del
  progreso anterior. Lo usan cronómetro, sesión, piloto automático y rivales.
- **Problema: muros y controles que invaden el tramo vecino.** → medición de separación entre
  tramos ("clearance") que acerca o interrumpe muros, angosta los controles de paso y decide si
  entran tribuna y edificio de boxes.
- **Problema: Mónaco sin zona de DRS** (no tiene rectas largas). → criterio que se relaja en etapas.
- **Problema: Singapur al revés** en la fuente. → el conversor compara el sentido con el del
  catálogo y lo invierte.
- Control: Los Aromos da la misma vuelta que en la Fase 1 (58,6–58,8 s).

### Hito 1b-2 — Clima, compuestos y aquaplaning

- `weather.gd` reescrito (seco / lluvia / variable, agua con charcos por ruido).
- `tyre_compound.gd` + 5 recursos; `f1_car.gd` aplica la fórmula por rueda.
- El perfil de velocidad (`build_speed_profile`) incorpora el aquaplaning: rivales y piloto
  automático frenan antes con el neumático equivocado.
- Rivales: salen con el mejor compuesto para el agua y lo cambian si otro rinde 4 % más.
  **Problema:** con clima variable se quedaban con el compuesto decidido a mitad del cambio
  (intermedios en pista seca). → la parada prevista monta siempre el mejor compuesto del momento.

### Hito 1b-3 — Menú, HUD y extras

- `session_setup.gd`: selectores navegables con las acciones `ui_*` (teclado, gamepad y volante),
  dibujo del trazado, mejores tiempos y sugerencia de neumático.
- HUD: compuesto (letra y color), desgaste, circuito, clima, agua y aviso `AQUAPLANING`.
- Extras hechos: **spray**, **slicks blando/medio/duro**, **tabla de mejores tiempos**, clima
  **Variable**.

### Hito 1b-4 — Pruebas en todos los circuitos

- `test_circuit.gd` + `run_circuits.py`: 25 circuitos × 2 climas = 50 vueltas del piloto automático.
- **Problema: vuelta inválida en Mónaco** ("exceso de velocidad en boxes" pasando por la recta).
  La zona con límite del pit lane pisaba la pista: el pit lane todavía no se había separado y las
  cajas de la zona eran largas para una recta curva. → la zona empieza donde el pit lane ya está
  separado, y se arma con cajas de 8 m.
- **Problema: el limitador "fallaba" en Mónaco.** Era la prueba: con un pit lane de 172 m el auto
  salía de la zona antes de medir. → se mide la velocidad máxima dentro de la zona.
- **Problema: el piloto automático se trababa en la carrera de Mónaco** al querer pasar por afuera
  en una pista de 9 m. → el margen lateral depende del ancho de la pista; si no hay lugar, sigue al
  de adelante; y si queda trabado 4 s, pide el reset como haría un piloto.
- `test_pits.gd` se corrió en los 25 circuitos (pit lane automático): todos OK.

## 13. Verificación final de la Fase 1b

| Prueba | Resultado |
|---|---|
| `test_controls.gd` | TODO OK |
| `test_pits.gd` (en los 25 circuitos) | TODO OK |
| `test_weather.gd` | TODO OK |
| `test_tyres.gd` | TODO OK |
| `run_circuits.py` (50 combinaciones) | TODO OK — tabla en `docs/resultados_circuitos.md` |
| `test_udp.gd` + `fake_wheel.py --auto` | TODO OK |
| Carreras completas (`test_levels.gd`) | Los Aromos con lluvia, Mónaco en seco, Suzuka con clima variable: terminan y dan resultados |

**No verificado** (detalle en `docs/pendientes.md` §1): aspecto con Forward+, sonido, manejo real
con teclado/gamepad, el menú nuevo con un dispositivo real, y el aspecto de cada uno de los 24
circuitos (solo miré capturas de Mónaco y Spa; el resto se validó por números).

## 14. Cosas que conviene que sepas (Fase 1b)

- **`scenes/track/circuito.tscn` ya no se usa.** Fue reemplazado por
  `scenes/track/circuitos/los_aromos.tscn`. No puedo borrar archivos en tu PC: borralo a mano
  (y su `.import`/`.uid` si los hubiera). No rompe nada si queda.
- **Récord viejo:** `user://fantasma_clasificacion.dat` se migra solo a
  `user://fantasmas/los_aromos_seco.dat` la primera vez que corras Clasificación en Los Aromos.
- **Git:** igual que antes, no pude escribir `.git` en tu PC. El bundle
  `Proyecto\simulador_f1_historial.bundle` está **actualizado** con los commits de esta fase. Si
  ya restauraste el historial (opción A de §7): `git pull ..\simulador_f1_historial.bundle main`.
  Si no, seguí la opción A tal cual.
- **Después de copiar los archivos, abrí el proyecto en el editor una vez** (o corré
  `godot --headless --import`) para que Godot registre las clases nuevas (`CircuitData`,
  `TyreCompound`, `BestTimes`).
- **Lo más "preguntable" de esta fase:** la fórmula de agarre (`docs/neumaticos_y_aquaplaning.md`),
  la conversión de coordenadas geográficas a metros y el suavizado (`docs/circuitos.md` §3) y la
  búsqueda local de progreso (`Track.get_offset_near`).

## 15. Qué propondría después

- Cargar por circuito los **datos reales** que hoy son automáticos (DRS, sectores, lado de boxes):
  el recurso ya tiene los campos.
- **Línea de carrera** para rivales y piloto automático: es lo que más acercaría los tiempos a los reales
  (hoy el piloto automático va por el centro y es ~40 % más lento que un F1).
- **Elevación** en dos o tres circuitos emblemáticos (Spa, Austin).

---

# Fase 1c — carga aerodinámica, IA y neumáticos

- **Fecha:** 16 de noviembre de 2026 (tercera sesión de trabajo).
- **Pedido:** `prompt_simulador_F1_fase1c.md` (había que ir demasiado lento en las curvas).
- **Resultado:** el auto dobla y frena como un F1 (5 g a 270 km/h), el piloto automático quedó en
  promedio a un dígito de las poles reales de 2025 (antes +43 %) y hay estrategia de neumáticos.

> Misma salvedad de siempre: todo está medido, nada está "sentido". La sensación de manejo la
> tenés que probar vos; qué mirar está en `docs/pendientes.md` §1.

## 16. Antes de tocar nada

Comparé tu carpeta con el historial. Único cambio tuyo desde la Fase 1b:
`assets/setups/car_setup_default.tres`, que el editor volvió a guardar agregándole identificadores
(`uid`). Lo tomé tal cual, en un commit aparte. `PIT_SERVICE_TIME` seguía en 3,2 s y
`engine_sound.gd` no cambió (ni lo toqué). `scenes/track/circuito.tscn` sigue en tu carpeta: es de
la Fase 1 y ya no se usa.

## 17. Hito 1c-1 — Medir: `test_skidpad.gd`

Antes de cambiar la física armé la prueba: el auto sobre un plano, manejado por una fuente de
entrada propia registrada en el `InputManager` (agregué `InputManager.register_source`).

- **Problema: el auto se caía del mundo.** El plano "infinito" de Jolt mide 2 km de lado; a
  300 km/h se llega al borde en segundos. → piso hecho con una caja de 60 km.
- **Problema: el desgaste contaminaba la medición.** Midiendo las velocidades una atrás de otra,
  las últimas se hacían con neumáticos gastados. → neumáticos nuevos antes de cada medición.

La medición inicial dio prácticamente tu tabla en lento (1,91 g a 54 km/h contra tu 1,88) y más
que la tuya en rápido (3,89 g a 270 km/h contra 3,17) justamente por el desgaste. La conclusión
era la misma: faltaba carga aerodinámica.

## 18. Hito 1c-2 — Carga aerodinámica y puesta a punto

| Parámetro (`car_setup.gd`) | Antes | Ahora | Por qué |
|---|---|---|---|
| `downforce_coef` | 1,30 | **3,2** | `½·ρ·C_L·A` con `C_L·A ≈ 5,2 m²` |
| `tyre_load_sensitivity` | — | **0,115** | Nuevo: el coeficiente de agarre baja con la carga (si no, más de 6 g) |
| `grip_front` / `grip_rear` | 2,05 / 2,25 | **2,15 / 2,36** | Para llegar a ~2,1 g en lento |
| `suspension_stiffness` | 90 | **300** | Con la carga nueva hacía tope |
| `damping_compression` / `relaxation` | 5,5 / 9 | **10 / 16** | Acompaña a la rigidez (va con su raíz) |
| `suspension_max_force` | 30 kN | **45 kN** | Margen para la frenada |
| `max_brake_force` | 36 kN | **34 kN** | Con más agarre, el tope de fuerza deja ~5 g de pico |
| Potencia, resistencia, DRS, `roll_influence` | | sin cambios | La velocidad máxima ya estaba en 345 km/h y el auto resultó estable |

- **Sorpresa con la suspensión.** Mi cuenta decía que con rigidez 220 alcanzaba; la prueba midió
  que el auto bajaba un 50 % más de lo calculado (64 mm), igual que antes del cambio. La dejé en
  300 y ahora la prueba verifica el hundimiento (47 mm de 100).
- **Dirección con teclado.** Nueva ayuda que limita el giro al ángulo que el agarre puede usar
  (`F1Car.get_grip_steer_angle`); opción *Automática / Siempre / Nunca* en Opciones. A 240 km/h el
  tope pasa de 4,0° a 2,1° (lo verifica `test_controls.gd`).

## 19. Hito 1c-3 — IA y piloto automático

1. **El perfil de velocidad sale del `CarSetup`**, no de números propios (decisión 16 de
   `docs/decisiones_diseno.md`): usa el 90 % de la capacidad lateral, con círculo de fricción.
2. **Línea de carrera.** Con el perfil nuevo y yendo por el centro, la estimación daba ~+19 % contra
   las poles. Mirando Melbourne curva por curva encontré la causa: en los trazados de la fuente las
   curvas lentas tienen 10–20 m de radio sobre el eje.
   - Primer intento (suavizado de mínima curvatura "casero"): la línea casi no ganaba radio.
   - Segundo intento, **algoritmo K1999**: el radio de la curva 1 de Melbourne pasó de 14 m a 44 m.
     Se calcula al generar cada circuito y se guarda en la escena.
3. **El piloto automático no seguía la línea** a esos ritmos (se salía en horquillas y chocaba en
   Mónaco y Shanghái). Lo que hizo falta, en orden:
   - anticipación de la curvatura de la línea en la dirección y del frenado según el perfil;
   - margen extra del perfil en curvas muy cerradas (un auto real tarda en rotar);
   - no meter la línea del todo hacia adentro en horquillas más cerradas que el ancho de la pista
     (ahí la coordenada "lateral" se degenera): era el problema de la horquilla de Sakhir;
   - corrección por error lateral y un poco más de margen al borde (1,8 m; 2,6 m con muros pegados).
4. **Rivales:** siguen la línea, usan las mismas cuentas del auto para acelerar y frenar, se gastan,
   y su ritmo base bajó (habilidad 0,96 a 0,90) porque el perfil ahora es mucho más rápido. Opción
   *Dificultad de los rivales* (Fácil / Normal / Difícil) en Opciones.

## 20. Hito 1c-4 — Neumáticos

Meseta y acantilado, desgaste proporcional a la carrera, blando ×2,0 y duro ×0,55, desgaste en los
rivales. Decisión y tabla en `docs/neumaticos_y_aquaplaning.md` §9. `test_tyres.gd` verifica que el
blando gane en 1 vuelta, el duro en la carrera entera y que los cruces caigan donde corresponde.

## 21. Verificación final de la Fase 1c

| Prueba | Resultado |
|---|---|
| `test_skidpad.gd` | TODO OK — `docs/skidpad.md` |
| `test_controls.gd` (con la ayuda de dirección) | TODO OK |
| `test_pits.gd` (en los 25 circuitos) | TODO OK |
| `test_weather.gd`, `test_tyres.gd` (con estrategia) | TODO OK |
| `run_circuits.py` (25 circuitos × seco y lluvia) | TODO OK — `docs/resultados_circuitos.md` |
| `test_udp.gd` + `fake_wheel.py --auto` | TODO OK |
| Carreras completas | Los Aromos (seco, 5 vueltas, con medios y con blandos), Mónaco (seco), Spa (lluvia), Suzuka (variable): terminan y dan resultados |

Skidpad, antes y después (neumático medio nuevo, seco):

| Velocidad | 54 | 90 | 126 | 162 | 198 | 234 | 270 km/h |
|---|---|---|---|---|---|---|---|
| Antes | 1,91 | 2,10 | 2,34 | 2,63 | 2,99 | 3,40 | 3,89 g |
| Ahora | 2,09 | 2,43 | 2,88 | 3,42 | 4,00 | 4,58 | 5,11 g |

Tiempos contra las poles de 2025: ver el resumen al pie de `docs/resultados_circuitos.md`.

- **Las Vegas da más rápido que la pole real** (−13 %): la clasificación de 2025 se corrió con
  lluvia, así que esa pole no es una referencia en seco. La dejé en la tabla, marcada, y fuera del
  promedio.
- **Mónaco es el más lejano** (+16 %): pista de 9 m con muros pegados, donde la línea deja más
  margen, y curvas muy cerradas en la fuente.

## 22. Cosas que conviene que sepas (Fase 1c)

- **Los récords viejos quedaron fáciles o imposibles.** El auto es mucho más rápido: los fantasmas
  y la tabla de tiempos anteriores (`user://fantasmas/`, `user://tiempos.cfg`) ya no son
  comparables. Conviene borrarlos.
- **El piloto automático es una referencia dura.** Va al 90 % de la capacidad medida del auto por
  la línea de carrera; los rivales en "Normal" son entre 4 y 10 % más lentos que él.
- **Si tocás `car_setup.gd`, corré `test_skidpad.gd`.** Te dice si algo se fue de los objetivos y
  si la IA quedó suponiendo más agarre del que hay.
- **Si cambiás un circuito**, regenerá su escena: la línea de carrera se guarda adentro.
- **Git:** el bundle `Proyecto\simulador_f1_historial.bundle` está actualizado con los commits de
  esta fase (ver §14 para aplicarlo).
