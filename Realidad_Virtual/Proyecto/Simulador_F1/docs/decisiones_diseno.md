# Decisiones de diseño

Qué se decidió, qué alternativas había y por qué. Sirve como base para la sección de diseño del
informe (capas de software, lógica de interacción con el usuario).

## 1. Dos capas de software, unidas por un protocolo

La consigna pide elementos de diseño en al menos dos capas: **nivel hardware de IHM** y **nivel de
lógica de interacción con el mundo**. El proyecto las separa con un límite bien definido:

| Capa | Dónde vive | Estado |
|---|---|---|
| 1. Dispositivo IHM (firmware) | ESP32 del volante | Fase 2 |
| — *Protocolo UDP* — | `docs/protocolo.md` | Definido, implementado del lado PC y probado con un volante simulado |
| 2a. Entrada/salida | `scripts/input/` (`InputManager`, `TelemetryOut`) | Hecho |
| 2b. Lógica de interacción con el mundo | `scripts/car/`, `scripts/race/`, `scripts/track/`, `scripts/ui/` | Hecho |

Ventaja principal: las dos fases se pueden desarrollar y **probar por separado**. Esta fase quedó
verificada sin que exista el volante, y en la Fase 2 el firmware se puede probar contra el juego sin
tocar el juego.

## 2. `InputManager`: una única puerta de entrada

**Decisión:** ningún script del juego consulta `Input` para manejar. Todos leen
`InputManager.steer / throttle / brake` y escuchan sus señales.

**Por qué:** el dispositivo de entrada es justamente lo que cambia en este trabajo. Si el auto
leyera teclas, agregar el volante implicaría tocar el auto. Con el `InputManager`, agregar un
dispositivo es escribir una clase nueva (`InputSource`) y registrarla.

**Cómo quedó:**

- `InputSource` (clase base): ejes crudos + botones con detección de flancos + encoder.
- Cuatro fuentes: `KeyboardSource`, `GamepadSource`, `UdpWheelSource`, `AutopilotSource`.
- El `InputManager` consulta la fuente activa **una vez por tick de física** y con prioridad antes
  que el auto (`process_physics_priority = -100`), para que todos vean el mismo dato en el mismo tick.
- El procesamiento común (zona muerta, curva, sensibilidad) está en el `InputManager` y no en cada
  fuente; el suavizado del teclado, que es propio de ese dispositivo, está en `KeyboardSource`.
- Funciona en pausa (`PROCESS_MODE_ALWAYS`) para poder despausar con cualquier dispositivo.

**Botones como eventos y como estados:** algunas acciones son de "un toque" (subir marcha, DRS,
cámara) y otras de "mantener" (ERS). La fuente informa el estado de cada botón; el `InputManager`
emite una señal en el flanco de subida (`action_pressed`, `shift_up_pressed`, ...) y además permite
consultar `is_held(accion)`.

**El volante también maneja los menús.** Con un menú en pantalla, el `InputManager` traduce las
acciones del volante a las acciones de interfaz estándar de Godot (`ui_up`, `ui_accept`, ...). Así
los menús se escriben con nodos `Control` comunes y funcionan con mouse, teclado, gamepad y volante
sin código específico.

## 3. `TelemetryOut`: la interacción es de ida y vuelta

Un sistema de realidad mixta no solo recibe del usuario: también le **devuelve** estímulos. El
autoload `TelemetryOut` es el espejo del `InputManager`: el auto publica su estado y este nodo lo
envía al dispositivo (LEDs de cambio, vibración). Se definieron eventos hápticos con intensidad y
duración para piano, pasto, choque y cambio de marcha. Mientras no hay volante, el gamepad vibra
con esos mismos eventos y `fake_wheel.py` los muestra.

Los **shift lights** se calculan con una única función (`WheelProtocol.leds_for_rpm`) que usan el
HUD, el volante simulado y, en la Fase 2, el firmware: lo que se ve en pantalla es lo que mostrará
la tira física.

## 4. Fuentes intercambiables y piloto automático

Se agregó una cuarta fuente no pedida, `AutopilotSource`, porque resolvía dos necesidades:

- **Probar sin manos.** El desarrollo de esta fase se validó ejecutando el juego sin ventana; hacía
  falta "alguien" que manejara. Como el piloto automático entra por el `InputManager`, cada prueba
  recorre la misma cadena que recorrerá el volante.
- **Modo demostración.** Sirve para filmar el volante físico reaccionando (LEDs, vibración) sin
  tener que manejar.

Usa persecución pura (apunta a un punto adelantado del eje) y un control proporcional de velocidad
contra el perfil que calcula el circuito.

## 5. Escenas generadas por código

**Decisión:** las escenas `.tscn` las escribe Godot ejecutando `tools/godot/build_scenes.gd`.

**Alternativas:** (a) armarlas a mano en el editor; (b) construir todo en `_ready()` al iniciar el
juego, sin escenas.

**Por qué (c) generarlas:**

- El desarrollo de esta fase se hizo sin acceso al editor gráfico; hacía falta un método que
  produjera escenas válidas de manera verificable. Quien escribe el archivo es el propio Godot
  (`PackedScene.pack` + `ResourceSaver.save`), así que el formato es correcto por construcción.
- Frente a (b), las escenas generadas **se pueden abrir en el editor**: se ve el circuito, el árbol
  de nodos del auto, las zonas. Eso sirve para el informe (capturas) y para seguir editando a mano.
- El proceso queda documentado y es reproducible (requisito de "manual paso a paso"): los datos de
  diseño están en un archivo, y el circuito completo se regenera con un comando.

**Costo:** hay que recordar que regenerar pisa los cambios manuales. Está avisado en el README y en
el encabezado del generador.

Las pantallas de menú y el HUD sí se arman al iniciar (`_ready`), porque son listas de controles
estándar y resulta más claro leerlas como código que como una escena con decenas de nodos.

## 6. `VehicleBody3D` con Jolt: verificación

La consigna de desarrollo pedía verificar que `VehicleBody3D` funcionara bien con Jolt y, si no,
pasar a un controlador por raycasts. **Se verificó y se mantuvo `VehicleBody3D`.** Evidencia:

- Un experimento inicial confirmó el contacto de las ruedas, el sentido de avance y el de giro.
- El piloto automático completa vueltas enteras sin salirse (`test_drive.gd`), a 336 km/h de máxima.
- A 278 km/h, sin doblar, contra el muro de la curva 1: el auto **no lo atraviesa** (`test_controls.gd`).
- Las zonas `Area3D` detectan al vehículo correctamente (checkpoints, DRS, boxes).

`VehicleBody3D` ya es, internamente, un vehículo por raycasts (cada rueda lanza un rayo); lo que
aporta Jolt es la dinámica del cuerpo rígido y las colisiones. El único problema encontrado no fue
de Jolt sino de configuración (amortiguamiento lineal por defecto; ver `modelo_motor_caja.md` §11).

Ajustes para alta velocidad: 120 ticks de física por segundo, `continuous_cd` en el auto, muros de
0,8 m de espesor.

## 7. Detección de superficie por geometría

**Decisión:** saber qué pisa cada rueda proyectando su posición sobre el eje de la pista, en lugar
de consultar con qué objeto colisiona.

**Por qué:** es determinista, no depende de detalles de las mallas de colisión y entrega de paso el
**progreso** en la vuelta, que se necesita igual para posiciones, delta y reinicios. Además es una
aplicación directa de lo visto en la materia (proyección, producto escalar).

## 8. Rivales cinemáticos

**Decisión:** los rivales no simulan física de vehículo; avanzan sobre el `Path3D` siguiendo un
perfil de velocidad calculado con la curvatura.

**Por qué:** la consigna de desarrollo pedía "IA simple". Cuatro `VehicleBody3D` más, manejados por
controladores, hubieran sido más costosos y mucho menos predecibles (un rival que hace un trompo
arruina la carrera). Con el perfil de velocidad los rivales frenan antes de las curvas, aceleran en
las rectas, respetan la lluvia y tienen ritmos distintos (habilidad + variación lenta en el tiempo).

**Limitaciones aceptadas:** no se defienden ni atacan; esquivan al jugador cambiando de carril o
levantando; un choque contra ellos es como chocar un objeto móvil muy pesado.

## 9. Cronometraje

- **Checkpoints en orden** (llegada → S1 → S2 → llegada): impide completar una vuelta en sentido
  contrario o cortando camino.
- **Reloj de simulación:** el tiempo es la suma de los pasos de física, no el reloj del sistema. Se
  detiene solo en pausa y es reproducible.
- **Precisión por debajo del tick:** el instante de cruce se interpola con la distancia a la línea
  y la velocidad (sin esto la resolución sería de 8,3 ms).
- **Delta por distancia:** cada vuelta guarda cuánto tiempo llevaba cada 10 m; el delta es la
  diferencia contra la vuelta de referencia *en el mismo punto de la pista*.

## 10. Fantasma

Se graba posición + rotación (cuaternión) 60 veces por segundo y se interpola al reproducir
(`lerp` de posición, `slerp` de rotación). Una vuelta de un minuto ocupa ~100 kB. Se guarda en
`user://fantasma_clasificacion.dat` con `FileAccess.store_var`. Solo se guarda una vuelta **válida**
y más rápida que el récord anterior.

## 11. Dos niveles = dos escenarios de interacción

La consigna pide al menos dos escenarios de interacción diferentes. Comparten circuito y auto, pero
cambian las **reglas de interacción**:

| | Clasificación | Carrera |
|---|---|---|
| Contra quién | Contra uno mismo (fantasma) | Contra 4 rivales |
| Entorno | Seco, buena visibilidad | Lluvia: −20 % de agarre, niebla, partículas |
| Inicio | Vuelta lanzada | Semáforo, grilla |
| Regla clave | Validez de la vuelta | Parada obligatoria, penalizaciones en tiempo |
| Uso de boxes | Opcional | Estratégico |
| Final | Cuando el jugador decide | Bandera a cuadros |

La lógica común está en `SessionBase` y cada nivel hereda y agrega lo propio.

## 12. Sin recursos externos

No hay modelos, texturas ni sonidos importados: el auto y el decorado son primitivas, las texturas
(asfalto, pasto, pianos) se generan por código y el motor suena por síntesis. Responde al requisito
de "manejar primitivas 3D", evita problemas de licencias y hace que el repositorio sea liviano.

## 13. Nombres y comentarios

Identificadores en inglés para la interfaz que venía especificada (`InputManager`, `steer`,
`throttle`, `shift_up`...) y para mantener coherencia con la API de Godot; **comentarios y textos
en español**. Los nodos de las escenas tienen nombres en español (`Circuito`, `Auto`, `Trazado`,
`Asfalto`, `Pianos`, `Muros`...) porque son lo que se ve en el editor y en las capturas del informe.
Los valores numéricos están en constantes con nombre o en el recurso `CarSetup`.

## 14. Fase 1c: medir antes de ajustar (skidpad)

El problema era "hay que ir muy lento en las curvas". En vez de tocar números a ojo, lo primero fue
una prueba automática que **mide** la capacidad del auto (`test_skidpad.gd`): aceleración lateral a
velocidad constante, aceleración, velocidad máxima, frenada y hundimiento de la suspensión. La
prueba maneja el auto con una fuente de entrada propia registrada en el `InputManager`
(`InputManager.register_source`), es decir, por el mismo camino que una persona.

Con la medición quedó claro que el agarre mecánico estaba bien y faltaba carga aerodinámica. La
misma prueba verifica después los objetivos y deja la tabla "antes / ahora" en `docs/skidpad.md`.

## 15. Carga aerodinámica realista + sensibilidad a la carga

`downforce_coef` pasó de 1,30 a **3,2** (`½·ρ·C_L·A` con `C_L·A ≈ 5,2 m²`). Dos consecuencias que
obligaron a decidir:

- **El agarre no puede crecer en proporción a la carga.** Con un coeficiente constante, 3,2 da más
  de 6 g a 250 km/h. Se agregó la sensibilidad a la carga (`tyre_load_sensitivity`), que es física
  real de un neumático y deja el objetivo pedido: ~2,1 g en lento y ~4,8 g a 250 km/h. La
  alternativa era bajar la carga a ~2,5, fuera del rango realista.
- **La suspensión tiene que soportar 4,75 veces el peso.** Se endureció (rigidez 300) hasta que la
  prueba midió menos del 60 % del recorrido usado a velocidad máxima.

La potencia y la resistencia no se tocaron: la velocidad máxima ya estaba en el objetivo.

## 16. La IA usa la puesta a punto del auto, no números propios

Antes el piloto automático y los rivales tenían coeficientes escritos a mano (`PROFILE_GRIP = 1,55`,
`AI_PROFILE_GRIP = 1,6`, `aero_per_mass = 0,0016`) que no seguían al auto. Ahora
`Track.build_speed_profile` recibe el `CarSetup` y de ahí salen la lateral disponible, la carga
aerodinámica, la sensibilidad a la carga, los frenos, la tracción, la potencia y la resistencia
(`CarSetup.get_lateral_capacity`, `get_brake_capacity`, `get_traction_capacity`, `get_peak_power`).
El perfil usa el **90 %** de la capacidad (`PROFILE_USAGE`), respeta el círculo de fricción y deja
un margen extra en las curvas muy cerradas. `test_skidpad.gd` verifica que el perfil nunca suponga
más del 95 % de lo medido: si alguien cambia la puesta a punto y la IA queda "soñando", la prueba falla.

## 17. Línea de carrera calculada al generar el circuito

Ir por el centro de la pista costaba mucho tiempo, sobre todo porque los trazados de la fuente
tienen las curvas lentas dibujadas muy cerradas (radios de 10 a 20 m sobre el eje). Se calcula una
línea de carrera con el algoritmo K1999 (`scripts/track/racing_line.gd`): cada punto se mueve a lo
ancho hasta que su curvatura es el promedio de la de sus vecinos, de grueso a fino. En una curva
típica el radio pasa de ~15 m (eje) a ~40 m (línea).

- Se calcula **al generar la escena** (`track_builder.gd`) y se guarda en el circuito
  (`Track.line_lateral`): tarda ~0,5 s por circuito y así el juego no lo paga al cargar. Si un
  circuito no la trae, `Track` la calcula la primera vez que hace falta.
- La usan el piloto automático (persecución de la línea + anticipación de la curvatura + corrección
  por error lateral) y los rivales (línea + su carril preferido).
- Margen al borde: 1,8 m del eje del auto; 0,8 m más si el muro está pegado (callejeros). En
  horquillas más cerradas que el ancho de la pista la línea no se mete del todo hacia adentro.

## 18. Ayuda de dirección: una propiedad de la fuente de entrada

La ayuda que limita el giro al agarre disponible es necesaria con teclas y molesta con un volante.
En vez de preguntar "¿es el teclado?" dentro del auto, cada fuente declara si la quiere
(`InputSource.wants_steer_assist`) y el `InputManager` decide según la opción del usuario
(automática / siempre / nunca). El volante de la Fase 2 no la usa por defecto.

## 19. Neumáticos: estrategia aunque la carrera sea corta

Ver `neumaticos_y_aquaplaning.md` §9. La decisión de fondo fue **atar el desgaste a la distancia de
la carrera**: es menos "físico" que una vida fija en kilómetros, pero es lo que hace que elegir
compuesto importe en una carrera de 3 vueltas (que es lo que se va a mostrar en la demo).
