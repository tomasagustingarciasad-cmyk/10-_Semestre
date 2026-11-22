# Pendientes, limitaciones y próximos pasos

## 1. Lo que NO se pudo verificar en el desarrollo de esta fase

Esta fase se desarrolló y probó ejecutando Godot 4.7 en un servidor Linux sin placa de video ni
audio. Quedó verificado todo lo que es lógica y física (ver `BITACORA.md`), pero hay cosas que
**solo se pueden comprobar en tu PC** y conviene revisar antes que nada:

| Qué | Por qué no se verificó | Qué mirar |
|---|---|---|
| Aspecto con **Forward+** | Las capturas de revisión se hicieron con el renderer de compatibilidad por software | Que el cielo, las sombras, la niebla y la lluvia se vean bien; brillo general |
| **Sonido** del motor | No había dispositivo de audio | Que suene, que el tono siga a las RPM y que el volumen sea razonable (*Opciones → Volumen*) |
| **Sensación de manejo** con teclado | Las pruebas las hizo el piloto automático y teclas simuladas | Suavizado del teclado, agresividad de la dirección; ajustar en *Opciones* o en `car_setup_default.tres` |
| **Gamepad** real | No había uno conectado | Ejes de los gatillos y numeración de botones |
| **Rendimiento** (FPS) | Se renderizó por software | Si va lento: bajar `TREE_COUNT` y la cantidad de gotas (`RAIN_AMOUNT`), o desactivar MSAA en `project.godot` |
| **Aspecto de los 24 circuitos** | Solo se miraron capturas de Mónaco, Spa y Suzuka; el resto se verificó por números (vuelta completa, sin salidas) | Recorrer cada uno: muros que tapen la pista, tribunas o edificios mal ubicados, pianos raros |
| **Spray, asfalto mojado y cielo de lluvia** | Ídem renderer por software | Que el spray no tape demasiado ni cueste FPS (`SPRAY_AMOUNT` en `car_builder.gd`) |
| **Menú de sesión con gamepad y volante** | Se probó la lógica, no un dispositivo real | Navegar con cruceta/stick y con el volante simulado |
| **Aquaplaning "al volante"** | Lo probaron el piloto automático y una prueba automática | Si resulta muy brusco o muy suave: `AQUAPLANING_MIN_GRIP` en `tyre_compound.gd` y las velocidades de `TYRE_COMPOUNDS` |
| **Manejo con la carga aerodinámica nueva** (Fase 1c) | Lo midieron el skidpad y el piloto automático, no una persona | Si el auto resulta nervioso o "sobre rieles": `tyre_load_sensitivity`, `grip_rear` y la amortiguación en `car_setup.gd` |
| **Ayuda de dirección con teclado** (Fase 1c) | Se verificó el cálculo, no la sensación | Si queda corta o larga de giro: `STEER_ASSIST_MARGIN` en `f1_car.gd`; se apaga en *Opciones* |
| **Desgaste "al volante"** (Fase 1c) | La estrategia se verificó con una cuenta y con el piloto automático | Si se gasta muy rápido o muy lento: `RACE_TYRE_LIFE_FACTOR` en `race_session.gd` |
| Dificultad de los rivales | Solo se comparó contra el piloto automático (los rivales son entre 4 y 10 % más lentos que él en "Normal") | *Opciones → Dificultad de los rivales*; `skill` de cada rival en `level_builder.gd` y `AI_DIFFICULTY_PACE` en `settings.gd` |

## 2. Limitaciones conocidas

- **Circuitos reales aproximados.** La planta, la longitud y el sentido son reales; el ancho, el
  pit lane, las zonas de DRS, los sectores y el decorado son genéricos. Detalle en `circuitos.md` §7.
  En Suzuka el cruce del ocho es a nivel.
- **Circuitos planos.** No hay desniveles ni peraltes. El método (curva + extrusión) los admite: habría
  que dar altura a los puntos de control y ajustar el suelo.
- **Rivales simples.** No pelean la posición, no cometen errores y entre ellos no se estorban (se
  cruzan lado a lado por carriles distintos). El jugador los puede chocar pero ellos no "rebotan".
- **Piloto automático.** Sigue la línea de carrera, pero no entra a
  boxes: en modo demo, en Carrera, termina con la penalización por no parar. Si queda trabado más
  de 4 s pide el "reset" solo (pasa a veces en la largada de Mónaco).
- **Tiempos de vuelta contra la realidad.** El piloto automático queda en promedio a +7,6 % de las
  poles de 2025 en seco (22 circuitos; ver `resultados_circuitos.md`). Lo que falta es sobre todo geometría: las curvas
  lentas de la fuente son más cerradas que las reales y no se usan los pianos. Mónaco es el peor
  (+16 %) por los muros pegados y la pista angosta.
- **Carrera en Mónaco con piloto automático.** En tránsito puede necesitar uno o dos "reset".
- **Suspensión.** Es dura y sin barras ni alturas variables; el auto baja 47 mm a velocidad máxima.
- **Rivales y clima variable.** Cambian de compuesto cuando otro rinde un 4 % más; no anticipan el
  clima ni administran el desgaste.
- **Aquaplaning.** Es una caída de agarre por rueda; no modela la dirección "liviana" ni el
  drenaje de la pista. Los charcos son ruido fijo, iguales en todas las sesiones.
- **Carga de circuitos.** La malla CSG se calcula al cargar (0,5–0,9 s medido sin ventana). Si en una
  PC lenta se notara, se puede hornear a `ArrayMesh` + colisión en `track_builder.gd`.
- **Mejores tiempos sin nombre.** La tabla guarda los 5 mejores por circuito y clima, con
  compuesto y fecha.
- **Daños.** Los choques solo generan vibración y pérdida de tiempo.
- **Largada.** No se detecta la largada en falso: el auto está frenado hasta que se apaga el semáforo.
- **Tiempos de los rivales que no llegaron.** Si el jugador gana, el tiempo final de los rivales
  que seguían en pista se **estima** con su velocidad media.
- **DRS con lluvia.** En la F1 real se deshabilita en mojado; acá se dejó habilitado para que la
  mecánica se pueda usar en los dos niveles.
- **Un fantasma por circuito y clima** (el récord). El clima "variable" tiene el suyo.
- **Opciones dentro del nivel.** Las opciones se cambian desde el menú principal, no desde la pausa.
- **`unique_id` de los nodos.** Cada vez que se regeneran las escenas, Godot asigna identificadores
  nuevos a los nodos. No afecta al juego, pero `git diff` muestra muchas líneas cambiadas.

## 3. Ideas de mejora (opcionales)

- Que el piloto automático entre a boxes y elija compuesto.
- Línea de carrera que use los pianos y frene "en apoyo" (hoy deja 1,8 m al borde).
- Niveles de dificultad en el menú de opciones.
- Datos reales por circuito en `circuits.json`: zonas de DRS, sectores, lado y largo de boxes
  (el recurso ya tiene los campos `drs_zones`, `sector_ends`, `pit_side`).
- Safety car / bandera amarilla cuando un rival queda parado.
- Charcos visibles y línea seca que se forma con el paso de los autos.
- Banderas (amarilla al reiniciar un auto, azul al ser alcanzado).
- Repetición de la carrera usando el mismo sistema de grabación del fantasma.
- Elevación del circuito.
- Activar la interpolación de física (`physics/common/physics_interpolation`) si en monitores de
  más de 120 Hz se nota algún tirón (habría que llamar a `reset_physics_interpolation()` al
  reubicar el auto).

## 4. Fase 2 — firmware del ESP32 y volante

El lado PC ya está listo y probado con `tools/fake_wheel.py`. Orden sugerido:

1. **Esqueleto de comunicación (sin sensores).** Un sketch que se conecte al WiFi y envíe
   `W,0,0,0,0,0` a 100 Hz a la IP de la PC, puerto 4210. Verificar en el juego (*Opciones → Volante
   UDP*) que diga "Conectado". Es el equivalente en hardware de `fake_wheel.py --auto`.
2. **Recepción de telemetría.** Escuchar el puerto 4211, interpretar `T,...` y mostrar `rpm_pct`
   por el monitor serie. Después, la **tira WS2812** con la regla de `docs/protocolo.md` §3
   (comparar contra los shift lights del HUD: deben coincidir).
3. **Dirección con el AS5600** (I²C). Enviar el ángulo escalado a −1000…1000 y usar la pantalla de
   **calibración** del juego. Cuidar que el valor no "dé la vuelta" dentro del recorrido.
4. **Botones y levas** con antirrebote → `buttons_bitmask`. Probar cada bit con la tabla del protocolo.
5. **Encoder rotativo** → `encoder_delta` (acumular entre envíos).
6. **Motor de vibración** con PWM y un transistor → eventos `V,...`.
7. **Pedales** (opcionales): potenciómetro en el acelerador (ADC) y celda de carga + HX711 en el freno.
8. **Alternativa por cable:** las mismas líneas por `Serial` a 115200 y `tools/serial_bridge.py`.
9. **Robustez:** apagar LEDs y motor si no llega telemetría en 500 ms; reconexión WiFi; decidir cómo
   conoce el ESP32 la IP de la PC (fija, o *broadcast*).
10. **Mecánica:** diseño e impresión 3D del volante, montaje del imán del AS5600 en el eje, tope
    mecánico y retorno al centro (resorte o elástico).

Para el informe y el video conviene registrar desde el principio: esquema de conexiones, fotos del
armado, y capturas del juego con el HUD mostrando "Volante UDP: Conectado".

## 5. Pendientes del trabajo integrador (fuera del código)

Según la consigna de la cátedra:

- Informe técnico tipo "manual paso a paso" (hardware y software), con esquemas de partes,
  interconexiones y capas de software. Los documentos de `docs/` y `BITACORA.md` son materia prima.
- Video de 5 a 7 minutos mostrando hardware, software y partes críticas del código.
- Repositorio con todo (código, informe, imágenes, videos) y envío del enlace a la cátedra.
- Citar las fuentes y aclarar el uso de asistencia por IA en el desarrollo.
