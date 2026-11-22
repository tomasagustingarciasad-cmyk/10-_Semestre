# Modelo físico del auto: motor, caja, frenos, aerodinámica y agarre

Notas para el informe sobre **cómo se calcula el movimiento del auto**. El criterio general fue
*arcade-sim*: que las magnitudes tengan sentido físico (unidades SI, fórmulas reconocibles) pero
priorizando que el auto sea manejable y divertido con un volante casero o un teclado.

Código: `scripts/car/f1_car.gd` (orquesta), `scripts/car/drivetrain.gd` (motor y caja),
`scripts/car/f1_systems.gd` (DRS, ERS, neumáticos). Todos los parámetros están en el recurso
`assets/setups/car_setup_default.tres` (clase `CarSetup`), editable desde el Inspector.

## 1. Qué hace Godot y qué hace el proyecto

`VehicleBody3D` (un `RigidBody3D`) con 4 `VehicleWheel3D` resuelve, usando el motor Jolt para el
cuerpo rígido:

- la **suspensión** de cada rueda (un rayo hacia abajo + resorte-amortiguador);
- la **fricción** de cada rueda: lateral (evita que el auto deslice de costado) y longitudinal
  (tracción y freno), limitada por `agarre × fuerza de la suspensión`.

El proyecto calcula y le entrega en cada tick de física (120 Hz):

| Magnitud | Dónde se aplica |
|---|---|
| Ángulo de dirección | `VehicleBody3D.steering` |
| Fuerza de tracción por rueda trasera | `VehicleWheel3D.engine_force` |
| Impulso de freno por rueda | `VehicleWheel3D.brake` |
| Coeficiente de agarre por rueda | `VehicleWheel3D.wheel_friction_slip` |
| Resistencia y carga aerodinámica | `apply_central_force()` |

Convención de ejes: el auto mira hacia **−Z** (el "adelante" de Godot). En `VehicleBody3D` una
`engine_force` positiva empuja hacia +Z y un `steering` positivo gira a la izquierda, así que ambas
se aplican con el signo cambiado (está comentado en el código).

## 2. Motor: las RPM salen de las ruedas

Las RPM **no son un estado independiente**. Con una marcha engranada, motor y ruedas están unidos
por la transmisión, así que:

```
ω_rueda  = v / r                               v: velocidad de las ruedas motrices [m/s], r = 0,34 m
rpm      = ω_rueda · i_total · 60 / (2π)       i_total = relación de la marcha × relación final
```

La velocidad de rueda se obtiene de `VehicleWheel3D.get_rpm()` (promedio de las dos traseras).

**Embrague simplificado:** en la arrancada las RPM calculadas serían casi cero. Se toma
`rpm = máx(rpm_acopladas, rpm_embrague)`, con `rpm_embrague` entre el ralentí (4000) y 8000 rpm
según el acelerador. Evita que el motor "se cale" y hace que el sonido suba al acelerar en parado.

**Curva de par** (`CarSetup.torque_curve`, un recurso `Curve` editable): X = rpm / rpm_máx,
Y = fracción del par máximo (520 N·m).

| rpm / rpm_máx | 0,00 | 0,33 | 0,60 | 0,80 | 0,92 | 1,00 |
|---|---|---|---|---|---|---|
| Par / par_máx | 0,50 | 0,70 | 0,92 | 1,00 | 0,97 | 0,88 |

**Fuerza en las ruedas:**

```
par    = par_máx · curva(rpm / rpm_máx) · acelerador
F_trac = par · i_total · η / r                 η = 0,92 (rendimiento de la transmisión)
```

**Limitador de régimen:** si las RPM acopladas llegan a 12000, el par se anula hasta que bajen.
En 1ª a fondo el auto se queda "clavado" en ~95 km/h hasta que se sube de marcha (verificado en
`test_controls.gd`).

**Freno motor:** con el acelerador suelto se agrega una retención
`F = par_retención · (rpm / rpm_máx) · i_total / r` sobre las ruedas traseras.

## 3. Caja de 8 marchas

Relación final 4,0. Las relaciones se eligieron para que la velocidad a 12000 rpm suba ~35 km/h
por marcha:

| Marcha | Relación | Relación total | Velocidad a 12000 rpm |
|---|---|---|---|
| 1ª | 4,05 | 16,20 | 95 km/h |
| 2ª | 2,96 | 11,84 | 130 km/h |
| 3ª | 2,33 | 9,32 | 165 km/h |
| 4ª | 1,92 | 7,68 | 200 km/h |
| 5ª | 1,64 | 6,56 | 235 km/h |
| 6ª | 1,42 | 5,68 | 271 km/h |
| 7ª | 1,26 | 5,04 | 305 km/h |
| 8ª | 1,115 | 4,46 | 345 km/h |

- **Manual:** levas. Cada cambio corta el par 60 ms. Una rebaja se **rechaza** si dejaría al motor
  por encima de 12000 × 1,02 rpm (protección contra pasarse de vueltas).
- **Automática:** sube al pasar 11600 rpm; baja cuando en la marcha inferior el motor quedaría por
  debajo de 9400 rpm. La diferencia entre ambos umbrales (histéresis) evita que la caja oscile.
- **Marcha atrás y punto muerto:** R ← N ← 1ª con el auto detenido. En automático, mantener el
  freno 0,45 s en parado engrana la marcha atrás y los pedales se invierten.

## 4. Velocidad máxima: equilibrio entre tracción y resistencia

```
F_resistencia = k_d · v² + F_rodadura          k_d = 0,78 N/(m/s)²,  F_rodadura = 150 N
```

En 8ª cerca del régimen máximo la tracción disponible es ≈ 6100 N, que iguala a la resistencia
alrededor de **88 m/s ≈ 317 km/h**. Con **DRS** la resistencia se multiplica por 0,74 y el auto
llega al corte de 8ª (~340 km/h). En las pruebas automáticas el piloto automático alcanzó 336 km/h
con DRS y ERS en la recta principal.

Con el ERS: `F_extra = mín(P_ers / v, 3200 N)` con `P_ers = 160 kW`.

## 5. Agarre y carga aerodinámica

Godot limita la fuerza que puede transmitir cada rueda a `μ × N`, donde `N` es la fuerza de la
suspensión de esa rueda y `μ` es `wheel_friction_slip`. El proyecto fija `μ` en cada tick:

```
μ_rueda = μ_base · f_carga · f_superficie · f_desgaste · f_compuesto(agua) · f_aquaplaning
```

| Factor | Valores |
|---|---|
| `μ_base` | 2,15 adelante, 2,36 atrás (un poco más atrás = auto estable, tiende a subvirar) |
| `f_carga` | sensibilidad a la carga: `1 − 0,115 × (carga aerodinámica / peso)`, con piso en 0,55 |
| `f_superficie` | asfalto y pit lane 1,0 · piano 0,92 · pasto 0,45 |
| `f_desgaste`, `f_compuesto`, `f_aquaplaning` | ver `neumaticos_y_aquaplaning.md` |

### Carga aerodinámica (Fase 1c)

```
F_carga = k_c · v²            k_c = 3,2 N/(m/s)²   (×0,88 con el DRS abierto)
```

`k_c = ½ · ρ · (C_L·A)` con ρ = 1,225 kg/m³ y `C_L·A ≈ 5,2 m²`, un valor típico de un F1 con carga
media. Con 800 kg:

| Velocidad | Carga | Carga / peso |
|---|---|---|
| 100 km/h | 2,5 kN | 0,31 |
| 200 km/h | 9,9 kN | 1,26 |
| 250 km/h | 15,4 kN | 1,97 |
| 300 km/h | 22,2 kN | 2,83 |
| 345 km/h | 29,4 kN | 3,74 |

(En la Fase 1 era 1,30: a 250 km/h la carga era 0,8 veces el peso y el auto doblaba como un GT.)

### Sensibilidad a la carga

Un neumático real no rinde en proporción a la carga: cuanto más cargado, menor es su coeficiente de
agarre. Sin modelarlo, con la carga de un F1 el auto doblaría a más de 6 g. Se usa una caída lineal
del coeficiente con la carga aerodinámica (`CarSetup.get_load_factor`): a 250 km/h queda el 77 %.
La aceleración lateral máxima aproximada es

```
a_lat ≈ μ · f_carga(v) · (g + k_c · v² / m)
```

Medido en el skidpad (`docs/skidpad.md`): **2,1 g a 54 km/h, 4,6 g a 234 km/h, 5,1 g a 270 km/h**.

### Suspensión y frenos para esa carga

- A 345 km/h las ruedas soportan 4,75 veces el peso del auto. Con la rigidez anterior (90) la
  suspensión hacía tope; se subió a **300** (amortiguación 10 / 16, fuerza máxima 45 kN). El auto
  baja 47 mm entre parado y velocidad máxima, sobre 100 mm de recorrido.
- Frenos: `max_brake_force` = 34 kN (4,3 g) y un "ABS" que nunca pide más que el 95 % del agarre
  disponible. A alta velocidad manda el tope de fuerza (más la resistencia del aire: ~5,2 g de
  pico a 300 km/h); a baja velocidad manda el agarre (~2 g). De 300 a 100 km/h: 1,35 s y 71 m.
- La potencia no se tocó: la velocidad máxima sigue en 345 km/h con DRS y ERS, porque la
  resistencia (`drag_coef`) es la misma.

**Superficie bajo cada rueda:** se determina geométricamente (`Track.classify_point`): se proyecta
la posición de la rueda sobre el eje de la pista y se compara la distancia lateral con el ancho del
asfalto y del piano. En el pasto además se suma una resistencia proporcional a la velocidad.

## 6. Dirección

```
ángulo_máx(v) = 24° / (1 + (v / 30 m/s)²)
```

A baja velocidad las ruedas giran hasta 24°; a 108 km/h, 12°; a 300 km/h, menos de 3°. Así el mismo
recorrido de volante sirve para la horquilla y para la recta sin que el auto sea nervioso. Las
ruedas además giran a velocidad limitada (110°/s) para filtrar entradas bruscas.

Las fuentes analógicas (volante, gamepad) pasan por zona muerta, curva (exponente) y sensibilidad
en el `InputManager`, y usan esa curva tal cual: el piloto dosifica el giro con la mano.

### Ayuda de dirección para el teclado (Fase 1c)

Una tecla es todo o nada. Con la curva de arriba, a 200 km/h la dirección a fondo pide un giro que
equivaldría a ~9 g: el tren delantero satura enseguida y el auto se va de trompa. Con la ayuda, el
tope de giro es además **el ángulo que el agarre puede aprovechar en ese momento**
(`F1Car.get_grip_steer_angle`, modelo de bicicleta):

```
a_disponible = μ_delantero_actual · (g + k_c · v² / m)         (μ actual: compuesto, desgaste, agua, carga)
ángulo_agarre = atan(batalla · a_disponible / v²)               batalla = 3,4 m
ángulo_máx    = mínimo(curva de arriba, ángulo_agarre)
```

| Velocidad | Sin ayuda (analógico) | Con ayuda (teclado) |
|---|---|---|
| 60 km/h | 18,3° | 15,8° |
| 120 km/h | 10,7° | 5,1° |
| 200 km/h | 5,4° | 2,6° |
| 300 km/h | 2,8° | 1,5° |

Apretar la tecla a fondo pasa a significar "doblá todo lo que el auto puede". La opción está en
*Opciones → Ayuda de dirección*: **Automática** (solo teclado, por defecto), **Siempre** (también
gamepad y volante) o **Nunca**. Cada fuente declara si la quiere (`InputSource.wants_steer_assist`).

## 7. Ayudas a la conducción

Son la parte "arcade" del modelo y se pueden ajustar o desactivar desde el `CarSetup`:

- **Control de tracción:** la fuerza de tracción por rueda se limita a
  `1,15 · μ_trasero · N_trasera_estimada`. Sin esto, 1ª a fondo haría patinar las ruedas y el auto
  perdería agarre lateral al acelerar en curva.
- **Freno tipo ABS:** la fuerza total de frenado se limita a `0,95 · μ_promedio · (peso + carga)`,
  con un tope de 36 kN. Se reparte adelante/atrás según el **reparto de frenos** (58 % adelante por
  defecto, ajustable con el encoder del volante).
- `VehicleWheel3D.brake` es un **impulso por tick**, no una fuerza; por eso el código multiplica la
  fuerza deseada por `delta`.

## 8. Limitador de boxes

Con el limitador activo, el acelerador se reduce linealmente en los últimos 2 m/s antes de los
80 km/h, de modo que el auto se estabiliza justo debajo del límite (79,8 km/h en `test_pits.gd`).
Si se lo activa yendo más rápido, además aplica hasta un 30 % de freno.

## 9. ERS

| Parámetro | Valor |
|---|---|
| Capacidad de la batería | 4 MJ |
| Carga inicial | 60 % |
| Potencia de despliegue | 160 kW (se vacía en 25 s de uso continuo) |
| Recarga frenando a fondo | 260 kW |
| Recarga al levantar el acelerador | 40 kW |

Se despliega manteniendo el botón con el acelerador por encima del 30 %. No funciona con el
limitador de boxes activo.

## 10. Neumáticos

Cada rueda acumula desgaste (0 = nuevo, 1 = gastado):

```
desgaste += distancia / vida · compuesto · (1 + carga_lateral_g · 0,35)     (rodadura, más en la rueda exterior)
          + deslizamiento · 0,005 · Δt                                      (patinar gasta)
```

La pérdida de agarre no es lineal (meseta y acantilado) y la vida se ajusta a la distancia de la
carrera. Todo el detalle, con la tabla de estrategia, está en `neumaticos_y_aquaplaning.md` §2 y §9.

## 11. Un detalle que costó encontrar: el amortiguamiento por defecto

Godot aplica a todo `RigidBody3D` un amortiguamiento lineal global de 0,1 s⁻¹ (ajuste de proyecto
`physics/3d/default_linear_damp`). Equivale a una fuerza `F = 0,1 · m · v`: a 65 m/s son 5200 N,
más que toda la resistencia aerodinámica. En la primera prueba el auto no pasaba de 250 km/h y la
aceleración medida era la mitad de la calculada. Se resolvió poniendo en el auto
`linear_damp_mode = REPLACE` y `linear_damp = 0` (ver `F1Car._apply_setup`). El detalle de cómo se
detectó está en `BITACORA.md`.

## 12. Cómo ajustar el comportamiento

Abrir `assets/setups/car_setup_default.tres` en el Inspector. Algunos efectos típicos:

| Si querés... | Tocá... |
|---|---|
| Más velocidad final | bajar `drag_coef` o subir `peak_torque` |
| Más agarre en curvas rápidas | subir `downforce_coef` |
| Auto más "de cola" (sobrevirador) | bajar `grip_rear` respecto de `grip_front` |
| Dirección más directa a alta velocidad | subir `steer_speed_ref` |
| Que los neumáticos duren más | subir `tyre_life_distance` (y `RACE_TYRE_LIFE_FACTOR` en `race_session.gd` para las carreras) |
| Menos agarre a muy alta velocidad | subir `tyre_load_sensitivity` |
| Que no haga tope la suspensión | subir `suspension_stiffness` (y la amortiguación en proporción a su raíz) |
| Sacar el control de tracción | subir mucho `traction_control_factor` |

Después de cambiar algo conviene correr `tools/godot/tests/test_drive.gd` para ver el efecto en el
tiempo de vuelta del piloto automático (referencia actual en Los Aromos: ~45,5 s en seco) y
`tools/godot/tests/test_skidpad.gd`, que mide lateral, frenada, velocidad máxima y suspensión y
avisa si algo quedó fuera de los objetivos.
