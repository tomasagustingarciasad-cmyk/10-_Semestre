[Parcial](#parcial) [Ruta](#ruta) [Fórmulas](#formulas) [Resueltos](#ej) [Tuberías](#tuberias) [Catálogos](#catalogos) [Esquema](#esquema) [Eléctrico](#electrico) [Teoría](#teoria) [Preguntas](#preguntas) [Errores](#errores)

SNeH · 5° año · Ing. Anzola

# Parcial de Oleohidráulica

Todo sale de los parciales 2020 y 2023, el TP N° 3, los apuntes de cátedra y tu propio TP corregido. Primero la ruta de cálculo (que es la mitad del puntaje), después los ejercicios resueltos, los catálogos y la teoría que preguntan. Neumática no entra.

Fuerza + presión→ CILINDRO→ velocidad→ CAUDAL→ BOMBA→ motor→ tuberías→ protección

## El parcial en un minuto

**Dos formatos que usó la cátedra:**

- **2020 / 2023:** \~14 preguntas conceptuales de marcar y ampliar (**40 %**) + un ejercicio de selección de cilindro y bomba con catálogo (**40 %**) + un ítem corto de "qué elemento usarías para proteger y a qué valor lo ajustás" (**20 %**).
- **Parcial N° 2 tipo proyecto:** dimensionar un equipo completo (**60 %**) + listar elementos del esquema y valores de ajuste (**25 %**) + seleccionar diámetros de tubería (**15 %**).

En los dos casos el núcleo es el mismo: **seleccionar cilindro, bomba y protecciones de catálogo**, dibujar el esquema y justificar cada elección.

**Regla de oro.** Nunca empieces por la bomba. Con la fuerza y una presión de trabajo se elige **primero el cilindro**; recién con el área del cilindro y la velocidad sale el caudal, y con caudal + presión sale la bomba. Esta pregunta entró literal en 2020 (ítem 14) y la respuesta correcta es **"ninguno de los listados: primero el cilindro"**.

**Lo que se repite en todos los años:**

- La bomba da **caudal**; la presión la genera la **resistencia al flujo**.
- Orden de los elementos del circuito y función de cada uno.
- Los cinco filtros: dónde va cada uno y para qué.
- Regular **velocidad** = válvula reguladora de caudal. Regular/limitar **fuerza y presión** = válvula limitadora (de alivio). **Ver** presión = manómetro.
- Selección de cilindro y bomba con tabla.
- A qué valor se ajusta la válvula de alivio.

## La ruta de cálculo

Este es el orden que pide la cátedra en los apuntes ("selección de componentes"). Si el ejercicio es largo, seguilo tal cual y vas sumando puntos aunque no llegues al final.

1. #### Fluido y presión de trabajo

   Aceite mineral, grado ISO VG según temperatura ambiente. La presión la impone el cliente o la elegís vos: los sistemas oleohidráulicos trabajan entre **70 y 350 bar** (cilindros hasta 300–350, válvulas hasta \~315).
2. #### Cilindro

   Con la fuerza máxima y la presión disponible: A = F / p. Después vas a la tabla y elegís el diámetro comercial **inmediatamente superior**.

   **Verificá los dos lados**: extensión usa el área del pistón A₁, retracción usa el área anular A₃ (que es siempre menor, así que es la condición crítica).
3. #### Velocidad y caudal

   v = carrera / tiempo y Q = A₁ · v. Ojo con las unidades: cm² × cm/s = cm³/s.
4. #### Bomba

   Vg = Q / n, con n en rev/s o rev/min según cómo tengas Q. Del catálogo elegís la cilindrada **inmediata superior** y después verificás: Q_real = Vg · n · η_v debe ser mayor que el caudal requerido.
5. #### Motor de accionamiento

   Motor asíncrono trifásico 3×380 V – 50 Hz: la velocidad sincrónica es 3000 (2 polos), 1500 (4 polos) o 1000 rpm (6 polos). **Usá la velocidad real**, no la sincrónica: ≈ 2900, 1450 o 960 rpm. Potencia: P\[kW\] = p\[bar\]·Q\[l/min\] / (600·η).
6. #### Tanque, filtros y válvulas

   Tanque: volumen activo del sistema más un porcentaje. Filtros: se eligen por **presión, caudal y micronaje**, y el grado de limpieza lo define **el componente más delicado** (la bomba, o la válvula proporcional si hay). Direccionales y de control: por **Q máximo y presión**.
7. #### Tuberías

   d = √(4Q / π·v) con la velocidad recomendada de cada línea, y después al diámetro interior comercial inmediato superior.
8. #### Pérdidas y presión de regulación

   Sumás las pérdidas de los accesorios ΔP = Σ k·Q², y entonces P_trabajo = P_cilindro + ΔP. La válvula de alivio se ajusta **por encima** de la presión de trabajo y por debajo de la máxima admisible del sistema.

## Fórmulas y conversiones

F = p · A

Fuerza del cilindro. A₁ en extensión, A₃ en retracción.

A₁ = π·D²/4

Área del pistón (lado tapa).

A₃ = π·(D²−d²)/4

Área anular (lado vástago).

φ = A₁ / A₃

Relación de áreas. La retracción es φ veces más rápida y φ veces menos fuerte.

v = carrera / t

Velocidad del vástago.

Q = A · v

Caudal necesario. cm² × cm/s = cm³/s.

Vg = Q / n

Cilindrada de la bomba, en cm³/rev.

Q_real = Vg · n · η_v

Caudal entregado. η_v ≈ 0,90–0,95.

P\[kW\] = p·Q / (600·η)

p en bar, Q en l/min. Potencia del motor.

ΔP = Σ k·Q²

Pérdida de carga de cada accesorio, k del catálogo, Q en l/min.

d = √(4Q / π·v)

Diámetro interior de la tubería.

h_f = λ·(L/D)·v²/2g

Pérdida por fricción en tubería (Darcy).

**Conversiones que vas a usar sí o sí**

- **1 bar ≈ 1,02 kg/cm²** → en el parcial tratalos como iguales, pero aclaralo.
- 1 kg ≈ 9,8 N → **1000 kg = 9,8 kN**. 10 bar = 1 MPa.
- 1 m/min = 1,667 cm/s. 1 l/min = 16,67 cm³/s.
- Re \< 2000 laminar · 2000–4000 transición · > 4000 turbulento.

## Los tres ejercicios resueltos

Son los que ya tomó. Si entendés estos tres, el ejercicio del parcial es una variante con otros números.

### A · Parcial 2020: brazo de 1000 kg

**Datos:** F = 9,8 kN ≈ 1000 kgf · carrera 500 mm · presión en bomba 150 kg/cm² · velocidad de extensión 4 m/min ≈ 6,7 cm/s · motor 3×380 Vca – 50 Hz · la retracción es por peso propio.

1. #### Cilindro

   Se usa la columna de fuerza para **160 bar** de la tabla (la más parecida a los 150 disponibles) y se verifica con presiones:

   32/14 → A₁ = 8,04 cm² A₃ = 6,50 cm² p ext = 1000/8,04 = 124 kg/cm² OK p ret = 1000/6,50 = 154 kg/cm² NO (> 150) 40/18 → A₁ = 12,56 cm² A₃ = 10,02 cm² p ext = 1000/12,56 = 79,6 kg/cm² OK p ret = 1000/10,02 = 99,8 ≈ 100 kg/cm² OK

   **Cilindro 40/18/500.** El 32/22 ni se evalúa: la fuerza en tracción es muy baja.
2. #### Caudal

   Q = v · A₁ = 6,7 cm/s × 12,56 cm² = 84,2 cm³/s = 5052 cm³/min ≈ 5,05 l/min
3. #### Bomba

   Motor de 4 polos a 50 Hz → 1500 rpm teóricos, **1450 rpm reales**.

   Vg = 5052 cm³/min ÷ 1450 rpm = 3,48 cm³/rev → del Código de tipos: tamaño nominal 004 = 4,0 cm³/vuelta Verificación: 4 × 1450 = 5800 cm³/min = 96,6 cm³/s > 84,2 cm³/s OK

   **Bomba AZPF…004** (engranajes externos, cilindrada fija).
4. #### Protección y ajuste

   Elemento: **válvula reguladora/limitadora de presión** (opción B). El presostato solo avisa o corta un circuito eléctrico, no descarga el aceite; la reguladora de caudal controla velocidad, no esfuerzo.

   Valor: la presión necesaria más exigente es la de retracción, **100 kg/cm²**. Con 95 el cilindro no llega a mover la carga, y 145 deja casi sin margen respecto de los 150 de la bomba. La respuesta "de libro" es **100 kg/cm²**; si querés jugarla fina, poné **D: \~110 kg/cm²** y justificá que la de alivio siempre se ajusta *por encima* de la presión de trabajo (ver la corrección del profe en el ejemplo C).

### B · TP N° 3 2025: 480 kg en extensión

**Datos:** 480 kg en extensión y 270 kg en retracción · p máx del sistema 70 kg/cm² · carrera 300 mm · tiempo máximo 60 s · motor 3×380/220 Vca de 1500 rpm acoplado directo · opciones de cilindro 25×16, 32×18, 40×25 · catálogo CD70/CG70.

1. #### Cilindro

   480 kg ≈ 4,71 kN y 270 kg ≈ 2,65 kN. En la fila de **70 bar**:

   | Opción | F lado pistón | ¿≥ 4,71 kN? | F lado vástago | ¿≥ 2,65 kN? |
   | --- | --- | --- | --- | --- |
   | A · 25×16 | 3,44 kN | No | 2,08 kN | No |
   | B · 32×18 | 5,63 kN | Sí | 3,84 kN | Sí |
   | C · 40×25 | 8,80 kN | Sí | 5,40 kN | Sí |

   **Se elige B (32×18)**: cumple las dos condiciones y no sobredimensiona. Comprobación por presión: 480/8,04 = 59,7 kg/cm² y 270/5,50 = 49,1 kg/cm², los dos por debajo de 70.
2. #### Caudal

   V = A₁ · carrera = 8,04 cm² × 30 cm = 241,2 cm³ Q = V/t = 241,2 / 60 s = 4,02 cm³/s = 241,2 cm³/min
3. #### Bomba — acá está la trampa

   Vg = 241,2 cm³/min ÷ 1450 rpm = 0,17 cm³/rev

   La bomba más chica del catálogo AZPB es de **1,0 cm³/rev**, o sea que **sobra caudal**: entregaría 1450 cm³/min ≈ 24 cm³/s y el cilindro haría la carrera en unos 10 s en vez de 60.

   **Respuesta correcta:** se adopta la de 1,0 cm³/rev y se **regula la velocidad con una válvula reguladora de caudal**; el caudal sobrante vuelve al tanque por la válvula de alivio. Decir "no existe bomba" o inventar una de 0,17 cm³/rev es el error típico.
4. #### Verificación del caudal (ítem C)

   Con un **caudalímetro** en la línea de presión, a la presión de trabajo. Alternativa de taller: medir el tiempo que tarda en llenar un recipiente de volumen conocido, o cronometrar la carrera del cilindro cuyo volumen ya conocés.
5. #### Otros elementos (ítem D)

   Reguladora de caudal (velocidad) · limitadora de presión apenas después de la bomba (presión y protección) · manómetro para ver y ajustar · antirretorno a la salida de la bomba · filtros de aspiración y retorno.

### C · Tu TP del gato de fosa, con las correcciones del profe

**Datos:** carga nominal 1500 kg · presión máxima en bomba 130 bar · carrera 500 mm · tiempo de subida/bajada 15 s · cilindro de doble efecto · coeficientes de pérdida: direccional 0,0206, antirretorno 0,0153, filtro 0,0111 (kg/cm² por (l/min)²) · rendimiento volumétrico 92 %.

1. #### Cilindro

   A₁ = F/p = 1500/130 = 11,54 cm² → Ø = √(4A/π) = 3,83 cm = 38,3 mm Se adopta Ø 40 / vástago 28 → A₁ = 12,56 cm² A₃ = 6,40 cm² Verificación: F = p·A₁ = 130 × 12,56 = 1632,8 kg > 1500 kg OK
2. #### Velocidad y caudal

   v = 50 cm / 15 s = 3,33 cm/s Q = A₁ · v = 12,56 × 3,33 = 41,8 cm³/s = 2509 cm³/min Presión real de trabajo del cilindro: Pc = F/A₁ = 1500/12,56 = 120 kg/cm²
3. #### Bomba y motor

   Motor 2 polos: 3000 rpm teóricos → ω_real ≈ 2940 rpm Vg = 2509 / 2940 = 0,853 cm³/rev → se adopta 1 cm³/rev Con η_v = 92 %: Vg_ef = 0,92 cm³/rev Q_real = 0,92 × 2940 = 2705 cm³/min = 45,1 cm³/s > 41,8 OK
4. #### Pérdidas de carga

   Q = 2705 cm³/min = 2,705 l/min ΔP = (0,0111 + 2×0,0153 + 0,0206) × 2,705² = 0,0623 × 7,32 ≈ 0,46 kg/cm² P_trabajo = Pc + ΔP ≈ 120 + 0,5 = 120,5 ≈ 125 kg/cm²
5. #### Presión de regulación — acá te lo corrigió

   **Lo que marcó en rojo:** P_reg > P_trabajo, y puso **P_reg ≈ 130 kg/cm²**.

   Vos habías escrito que la presión de trabajo era 125 y regulabas la válvula a 125. La de alivio nunca se ajusta *igual* a la presión de trabajo: si lo hacés, la válvula abre justo cuando el sistema está trabajando y el cilindro se queda sin fuerza. Se ajusta **por encima de la presión de trabajo y por debajo del máximo admisible** del componente más débil (acá, los 130 bar de la bomba).

   **Segunda corrección:** "todos estos elementos se seleccionan por **P_máx, P_reg y Q**". Cuando listes los elementos del esquema, al lado de cada uno poné **por qué parámetro lo seleccionaste**. No alcanza con describir la función.

## Tuberías de interconexión

Vale 15 % en el parcial tipo proyecto y es rápido si tenés el caudal.

**Velocidades recomendadas del fluido**

- Línea de **succión / aspiración**: 0,625 – 1,25 m/s
- Línea de **presión**: 2,1 – 4,75 m/s
- Línea de **retorno**: 1,5 – 3 m/s

La aspiración va lenta y con diámetro grande para no generar cavitación en la bomba.

#### Ejemplo con Q = 45 cm³/s (el gato de fosa)

A = Q / v y d = √(4A/π) Presión (v = 4 m/s = 400 cm/s): A = 45/400 = 0,113 cm² → d = 3,8 mm → tubo Ø6 × 1,0 (di = 4,0) Retorno (v = 2,5 m/s = 250 cm/s): A = 45/250 = 0,180 cm² → d = 4,8 mm → tubo Ø8 × 1,5 (di = 5,0) Succión (v = 1 m/s = 100 cm/s): A = 45/100 = 0,450 cm² → d = 7,6 mm → tubo Ø10 × 1,0 (di = 8,0)

#### Diámetros disponibles (DIN 2413)

| Ø ext (mm) | Pared s (mm) | Ø int (mm) | PN estático (bar) | P rotura (bar) | Peso (kg/m) |
| --- | --- | --- | --- | --- | --- |
| 4 | 0,50 | 3,0 | 313 | 1160 | 0,047 |
| 4 | 1,00 | 2,0 | 627 | 2700 | 0,074 |
| 5 | 1,00 | 3,0 | 501 | 2120 | 0,099 |
| 6 | 0,75 | 4,5 | 333 | 1150 | 0,103 |
| 6 | 1,00 | 4,0 | 444 | 1650 | 0,123 |
| 6 | 1,50 | 3,0 | 666 | 2550 | 0,166 |
| 8 | 1,00 | 6,0 | 333 | 1175 | 0,173 |
| 8 | 1,50 | 5,0 | 499 | 1925 | 0,240 |
| 8 | 2,00 | 4,0 | 666 | 2500 | 0,296 |
| 10 | 1,00 | 8,0 | 282 | 900 | 0,222 |
| 10 | 1,50 | 7,0 | 423 | 1450 | 0,314 |
| 10 | 2,00 | 6,0 | 564 | 2025 | 0,395 |
| 10 | 2,50 | 5,0 | 705 | 2675 | 0,462 |

Después de elegir el diámetro, verificá que la **presión nominal del tubo** supere la presión de regulación del sistema.

## Catálogos

### Cilindros — áreas y fuerzas a 160 bar

Es la tabla del parcial 2020 y del Parcial N° 2. Las dos filas de cada pistón son los dos vástagos posibles.

| Pistón Ø | Vástago Ø | φ = A₁/A₃ | A₁ pistón | A₂ vástago | A₃ anular | F₁ presión | F₃ tracción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 25 | 12 / 18 | 1,30 / 2,08 | 4,91 | 1,13 / 2,54 | 3,78 / 2,37 | 7,85 kN | 6,04 / 3,78 |
| 32 | 14 / 22 | 1,25 / 1,90 | 8,04 | 1,54 / 3,80 | 6,50 / 4,24 | 12,87 kN | 10,40 / 6,79 |
| 40 | 18 / 28 | 1,25 / 1,96 | 12,56 | 2,54 / 6,16 | 10,02 / 6,40 | 20,11 kN | 16,03 / 10,25 |
| 50 | 22 / 36 | 1,25 / 2,08 | 19,63 | 3,80 / 10,18 | 15,83 / 9,45 | 31,42 kN | 25,33 / 15,13 |
| 63 | 28 / 45 | 1,25 / 2,04 | 31,17 | 6,16 / 15,90 | 25,01 / 15,27 | 49,88 kN | 40,02 / 24,43 |
| 80 | 36 / 56 | 1,25 / 1,96 | 50,26 | 10,18 / 24,63 | 40,08 / 25,63 | 80,42 kN | 64,14 / 41,02 |
| 100 | 45 / 70 | 1,25 / 1,96 | 78,54 | 15,90 / 38,48 | 62,64 / 40,06 | 125,66 kN | 100,21 / 64,09 |
| 125 | 56 / 90 | 1,25 / 2,08 | 122,72 | 24,63 / 63,62 | 98,09 / 59,10 | 196,35 kN | 156,94 / 94,56 |
| 160 | 70 / 110 | 1,25 / 1,90 | 201,06 | 38,48 / 95,03 | 162,58 / 106,03 | 321,70 kN | 260,12 / 169,64 |
| 200 | 90 / 140 | 1,25 / 1,96 | 314,16 | 63,62 / 153,94 | 250,54 / 160,22 | 502,65 kN | 400,86 / 256,35 |

Áreas en cm². F₁ = fuerza en extensión a 160 bar. F₃ = fuerza en tracción (retracción).

### Cilindros CD70 / CG70 — fuerzas por presión de servicio

Es la del TP N° 3 (catálogo rs17016). Entrás por la presión del sistema y leés la fuerza disponible.

| Presión | Lado | 25/12 | 25/16 | 32/18 | 32/22 | 32/25 | 40/16 | 40/18 | 40/25 | 50/22 | 50/25 | 50/36 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 40 bar | pistón | 1,96 | 3,22 | 5,03 | 7,85 |  |  |  |  |  |  |  |
| 40 bar | vástago | 1,55 | 1,19 | 2,19 | 1,69 | 1,25 | 4,21 | 3,99 | 3,06 | 6,32 | 5,87 | 3,78 |
| 50 bar | pistón | 2,46 | 4,02 | 6,29 | 9,82 |  |  |  |  |  |  |  |
| 50 bar | vástago | 1,94 | 1,49 | 2,74 | 2,11 | 1,56 | 5,27 | 5,00 | 3,83 | 7,91 | 7,35 | 4,73 |
| 70 bar | pistón | 3,44 | 5,63 | 8,80 | 13,75 |  |  |  |  |  |  |  |
| 70 bar | vástago | 2,71 | 2,08 | 3,84 | 2,96 | 2,19 | 7,38 | 7,01 | 5,40 | 11,08 | 10,31 | 6,62 |
| 105 bar | pistón | 5,16 | 8,45 | 13,20 | 20,62 |  |  |  |  |  |  |  |
| 105 bar | vástago | 3,96 | 3,04 | 5,77 | 4,44 | 3,28 | 11,07 | 10,52 | 8,03 | 16,62 | 15,44 | 9,93 |
| Sup. pistón (cm²) | 4,91 | 8,04 | 12,56 | 19,63 |  |  |  |  |  |  |  |  |
| Sup. anular (cm²) | 3,78 | 2,90 | 5,50 | 4,24 | 3,13 | 10,55 | 10,02 | 7,65 | 15,83 | 14,71 | 9,46 |  |
| Carrera máx (mm) | 600 | 800 | 1000 | 1200 |  |  |  |  |  |  |  |  |

Fuerzas en kN.

### Bombas de engranajes AZPB-3x (Bosch Rexroth)

| Cilindrada (cm³/rev) | 1 | 2 | 2,5 | 3,15 | 4 | 4,5 | 5 | 6,3 | 7,1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| p continua máx (bar) | 220 | 220 | 220 | 220 | 220 | 220 | 220 | 220 | 200 |
| p intermitente (bar) | 250 | 250 | 250 | 250 | 250 | 250 | 250 | 250 | 230 |
| p pico (bar) | 270 | 270 | 270 | 270 | 270 | 270 | 270 | 270 | 250 |
| n mínima (rpm) | 750 | 750 | 750 | 750 | 750 | 750 | 750 | 750 | 750 |
| n máxima (rpm) | 6000 | 5000 | 5000 | 4000 | 4000 | 4000 | 4000 | 3500 | 3500 |

Presión de succión 0,7 a 3 bar absolutos. **Verificá siempre que la velocidad del motor caiga entre n mínima y n máxima.**

#### Cómo se lee el código de tipos

AZ P B – 3 2 – 4.0 R C P 02 M D 200xx

- **AZ** engranajes externos · **P** = bomba · **B** = serie · **3** = 3ª generación · **2** = resistente a la corrosión
- **4.0** = tamaño nominal, la cilindrada en cm³/rev (1.0 · 2.0 · 2.5 · 3.1 · 4.0 · 4.5 · 5.0 · 6.3 · 7.1)
- **R / L** = sentido de giro, horario o antihorario
- **C / H / N** eje · **P / O / M / Y** tapa delantera · **01 / 02 / 20** conexiones · **M / K / P** sellos
- **200xx** = ajuste de la válvula incorporada (PRV 200 bar)

En el parcial 2020 el código era **AZPF** y los tamaños venían como 004 = 4,0 cm³/vuelta, 005 = 5,5, 008 = 8,0, 011 = 11,0, 014 = 14,0, 016 = 16,0, 019 = 19,0, 022 = 22,5, 025 = 25,0, 028 = 28,0.

### Qué bomba elegir y por qué

| Tipo | Velocidad (rpm) | Cilindrada (cm³) | p nominal (MPa) | Rendimiento | Ruido | Precio |
| --- | --- | --- | --- | --- | --- | --- |
| Engranajes exteriores | 500–3500 | 1,2–250 | 6,3–21 | 0,80–0,91 | Alto | Barata |
| Engranajes interiores | 500–3500 | 4–250 | 16–25 | 0,80–0,91 | Muy bajo | Barata |
| Paletas | 960–3000 | 5–160 | 10–16 | 0,80–0,93 | Alto | Barata |
| Pistones axiales | 750–3000 | 25–800 | 16–25 | 0,82–0,92 | Alto | Cara |
| Pistones radiales | 960–3000 | 5–160 | 16–32 | 0,90 | Alto | Cara |

Pregunta fija: **las de engranajes son las más compactas y económicas**. Las de pistones son las de mayor presión y rendimiento, y las únicas con caudal variable preciso; las de engranajes externos son siempre de **cilindrada fija**.

## El esquema oleohidráulico

Lo piden siempre: dibujarlo, listar los elementos en orden y decir la función y el dato de selección de cada uno.

**Orden desde el tanque hasta el actuador**

Tanque → filtro de aspiración → motor + bomba → antirretorno → (filtro de presión) → válvula limitadora de presión + manómetro → válvula direccional 4/3 → válvulas reguladoras de caudal → cilindro → filtro de retorno → tanque

| # | Elemento | Función | Se selecciona por |
| --- | --- | --- | --- |
| 1 | Depósito / tanque | Almacena el aceite, deja decantar impurezas, libera el aire, reduce el espumado y disipa calor | Volumen activo del sistema + un porcentaje |
| 2 | Filtro de aspiración | Retiene partículas gruesas antes de la bomba. Malla gruesa, para no provocar cavitación | Caudal y micronaje grueso |
| 3 | Motor eléctrico + bomba | Convierte energía mecánica en hidráulica: genera el **caudal** | Caudal, presión, rpm |
| 4 | Válvula antirretorno | Impide que el aceite vuelva hacia la bomba y la dañe; mantiene la línea presurizada | Q y P |
| 5 | Válvula limitadora (de alivio) | Protege contra sobrepresiones derivando el excedente al tanque. Fija la presión máxima | P_máx, P_reg y Q |
| 6 | Manómetro | Permite **ver** la presión para ajustar la limitadora. No la regula | Rango de presión |
| 7 | Filtro de presión (si hace falta) | Protege válvulas proporcionales y componentes delicados. Caro, malla fina | P, Q y micronaje fino |
| 8 | Válvula direccional 4/3 | Dirige el aceite a un lado u otro del cilindro: extensión, retracción y parada | Q máx, P y tipo de accionamiento |
| 9 | Reguladoras de caudal | Regulan la velocidad y el tiempo del actuador en cada sentido | Q y P |
| 10 | Cilindro | Convierte la energía hidráulica en fuerza y movimiento lineal | F, p, carrera |
| 11 | Filtro de retorno | Retiene las partículas de desgaste antes de que el aceite vuelva al tanque. Barato, baja presión | Q y micronaje |
| 12 | Filtro de respiradero | Filtra el aire que entra al tanque. Lleva sílica gel para la humedad | Caudal de aire y humedad |

### Símbolos que tenés que saber dibujar

**Depósito**~~abierto a la atmósfera~~

**Filtro**~~rombo + línea de trazos~~

**Bomba fija**~~triángulo lleno = sale aceite~~

**Motor eléctrico**~~acoplado a la bomba~~

**Antirretorno**~~pasa en un solo sentido~~

**Limitadora de presión**~~flecha + resorte + pilotaje~~

**Manómetro**~~solo visualiza~~

**Presostato**~~contacto NA/NC por presión~~

**Direccional 4/3**~~4 vías, 3 posiciones~~

**Reguladora de caudal**~~estrangula = regula velocidad~~

**Cilindro doble efecto**~~dos tomas, presión en los dos lados~~

**Cilindro simple efecto**~~retorno por resorte o peso~~

**Acumulador**~~almacena energía, amortigua pulsos~~

**Intercambiador**~~enfría el aceite~~

El **rombo es siempre acondicionamiento del fluido**: con línea de trazos es filtro, con flechas hacia afuera es enfriador. El **triángulo lleno** indica líquido (en neumática va hueco).

**Detalle que marca el profe.** La válvula limitadora de presión **no va en serie** en la línea: va en **derivación**, tomada de la línea de presión y descargando al tanque. Si la dibujás en serie, perdés el punto.

## El circuito eléctrico de mando

Apareció en el TP N° 3 (ítem E) y en tu propio parcial: arrancar con un pulsador no retenido y que el cilindro pare solo en algún punto.

**Los tres bloques, siempre los mismos:**

1. **Pulsador de marcha S1** (NA, no retenido) → energiza la bobina del relé K1.
2. **Contacto de enclavamiento (sello):** un contacto NA de K1 en paralelo con S1, para que K1 siga energizado cuando soltás el pulsador.
3. **Condición de parada:** un contacto **NC** en serie con la bobina. Cuando el vástago llega a la posición, el sensor o fin de carrera S2 abre, K1 se desenergiza, el solenoide se apaga y la direccional vuelve al centro por resorte. El cilindro queda detenido.

Un contacto NA de K1 alimenta el solenoide de la válvula direccional. Para detener a mitad de carrera, el fin de carrera va montado a 150 mm en un cilindro de 300 mm de carrera, y la direccional tiene que ser de **centro cerrado** para que el vástago no siga por inercia ni baje por la carga.

**Variante con presostato** (la de tu parcial): el cilindro extiende por línea A; cuando la presión llega al valor ajustado en el presostato, su contacto cambia de estado y ese pulso dispara el relé que acciona el solenoide de retracción. Así el final del movimiento lo detecta la presión en vez de la posición.

Dos formas de detectar que llegó al final: **por posición** (fin de carrera, sensor inductivo) o **por presión** (presostato, cuando el cilindro hace tope y la presión sube).

## La teoría que preguntan

### El fluido

- **Qué se usa:** aceite mineral con aditivos (y fluidos sintéticos). Poco usados: agua, aceite soluble, vegetales.
- **Funciones (la pregunta fija):** **transmitir potencia, lubricar y refrigerar**. Además sella (por viscosidad, en las holguras), protege contra la corrosión y amortigua vibraciones. La opción "filtrar" o "contener impurezas" es falsa: eso lo hacen los filtros.
- **Viscosidad:** resistencia del fluido a circular. Varía **inversamente con la temperatura**. Mucha viscosidad → operación lenta y consumo alto; poca → fugas internas y mala lubricación. Se elige el grado **ISO VG** según la temperatura de trabajo.
- **Índice de viscosidad:** cuánto cambia la viscosidad con la temperatura. **Mayor índice = menos variación = mejor.**
- **Otros parámetros:** punto de anilina (ataca las juntas), punto de inflamación, untuosidad, demulsibilidad, antiespumantes.
- Es prácticamente **incompresible** (≈ 0,7 % cada 100 bar): de ahí la precisión y la rigidez frente a la neumática.

### Contaminación

- **Más del 75 % de las fallas** vienen de la contaminación del aceite.
- **Sólida:** óxido, partículas metálicas, fibras, pintura. Causa **abrasión** (raya superficies) y **erosión** (desgasta bordes de carretes).
- **Líquida:** agua por condensación o error en la recarga; degrada aditivos y oxida.
- **Gaseosa:** burbujas de aire → **cavitación** en la bomba, funcionamiento errático y ruidoso.
- **Medición: norma ISO 4406.** Código de tres números con la cantidad de partículas mayores a **4, 6 y 14 micras** por mililitro. Se cuenta en laboratorio con contador de partículas.
- **El grado de limpieza lo define el componente más delicado** del sistema: normalmente la bomba, o la válvula proporcional si hay.

### Los cinco filtros

| Filtro | Dónde va | Para qué |
| --- | --- | --- |
| Aspiración | En la succión, antes de la bomba, dentro del tanque | Retiene partículas gruesas. Malla gruesa: si es fina genera caída de presión y cavitación. Algunos proveedores lo desaconsejan |
| Presión | Después de la bomba, antes de las válvulas | Protege los componentes delicados. Malla fina, construcción robusta, el más caro |
| Retorno | En la línea de retorno, antes del tanque | Retiene las partículas de desgaste del sistema. Baja presión, barato, cartucho reemplazable. Es el que siempre se pone |
| Respiradero | En la tapa del tanque | Filtra el aire que entra y absorbe humedad con **sílica gel** (cambia de color cuando hay que reemplazarla) |
| Fuera de línea (riñón) | Circuito independiente con bomba propia | Filtra y acondiciona la temperatura en forma continua sin parar la máquina. Es el método más efectivo |

### Depósito

**Funciones:** almacenar y recircular el aceite, compensar fugas, **dejar decantar impurezas, reducir el espumado y liberar el aire**, disipar calor.

**Partes:** tapón de llenado y de drenaje, filtro de aire (respiradero), control de nivel y de temperatura, **placa deflectora** que separa el retorno de la aspiración, fondo inclinado con concavidad para impurezas, tapas de registro, conexiones de aspiración y retorno, intercambiador si hace falta.

**Qué se controla:** nivel y temperatura. El retorno va **sumergido y lejos de la aspiración** para no meter aire.

### Cilindros

- **Simple efecto:** la presión actúa en un solo sentido; vuelve por resorte, peso propio o carga. Un solo sello de trabajo y una sola toma.
- **Doble efecto:** presión en los dos lados, control total del movimiento. Dos sellos y dos tomas.
- **Amortiguamiento:** frena el vástago en el **último tramo de la carrera**, regulable con un tornillo. Es la respuesta a "cómo hago que la carga arribe lentamente a las posiciones extremas".
- **Pandeo:** en cilindros largos y delgados se verifica el vástago con la fórmula de **Euler**.
- Frente a los neumáticos: más precisos (fluido incompresible), fuerzas mucho mayores, movimientos más lentos, más robustos y caros, sellos más resistentes.

### Válvulas

- **Direccionales:** se nombran **vías / posiciones** (una 4/3 tiene 4 vías y 3 posiciones). Accionamiento: **eléctrico** (bobina/solenoide), **manual** (pulsador, palanca, pedal), **mecánico** (leva, rodillo, fin de carrera) y **fluídico** (pilotaje por presión de aceite o aire). Con retorno por muelle, la posición normal es la dibujada junto al resorte.
- **De presión:** limitadora o de alivio (protege del exceso, descarga al tanque), reductora, de secuencia.
- **De caudal:** estrangulan el paso y regulan la velocidad. Suelen ser unidireccionales, con un antirretorno en paralelo para que regulen en un solo sentido.
- **De bloqueo:** antirretorno, simple o pilotado.

### Acumuladores

Almacenan y liberan energía hidráulica: estabilizan la presión, amortiguan pulsaciones, cubren picos de demanda y sirven de emergencia. Tipos: **de vejiga** (el más común, respuesta rápida), **de pistón** (presiones altas, robusto), **de diafragma** (compacto, volúmenes chicos) y **de peso o resorte** (poco usados, grandes). Se controla presión y temperatura.

### Ventajas y desventajas frente a la neumática

| A favor | En contra |
| --- | --- |
| Fuerzas y presiones mucho mayores | Suciedad; el aceite es inflamable |
| Posicionamiento preciso (fluido incompresible) | Sensible a la contaminación y a la temperatura |
| Movimiento uniforme y transmisión rápida de la presión | Componentes caros y pesados |
| Autolubricante | El aceite envejece y hay que recuperarlo y acondicionarlo |
| Buen control de velocidad y fuerza | Cavitación, entrada de aire, bloqueos |

## Banco de preguntas

Son las del parcial 2020 y las conceptuales del TP N° 3. Tocá **Modo práctica** arriba para ocultarlas y destapar una por una.

## Errores que te van a costar puntos

| Error | Lo correcto |
| --- | --- |
| Empezar seleccionando la bomba | Primero el cilindro. La bomba sale después, del caudal |
| Decir que la bomba genera presión | Genera caudal; la presión la produce la resistencia al flujo |
| Verificar el cilindro solo en extensión | La retracción usa el área anular, que es menor: casi siempre es la condición crítica |
| Ajustar la válvula de alivio igual a la presión de trabajo | P_reg > P_trabajo, y por debajo de la máxima del componente más débil |
| Usar la velocidad sincrónica del motor (1500 / 3000 rpm) | Usar la real: ≈ 1450 o 2940 rpm por el resbalamiento |
| Listar elementos sin decir por qué parámetro se eligen | Cada uno con su dato de selección: P_máx, P_reg, Q, F, carrera |
| Dibujar la limitadora de presión en serie | Va en derivación, descargando al tanque |
| Decir que el manómetro regula la presión | Solo la visualiza. Regula la válvula limitadora |
| Regular la velocidad con la válvula de presión | La velocidad y el tiempo se regulan con la reguladora de caudal |
| Poner filtro de malla fina en la aspiración | Malla gruesa: una fina genera caída de presión y cavitación |
| Mezclar unidades (bar con kg/cm², mm con cm) | Pasá todo a cm, cm², kg y kg/cm² antes de empezar |
| Dejar el ejercicio sin verificar | Siempre cerrá con la verificación: F disponible > F necesaria, Q bomba > Q requerido |

## Las dos horas

- **0:00 – 0:35 · Ruta de cálculo y fórmulas.** Anotá la ruta de memoria en una hoja hasta que te salga sin mirar. Es la mitad del parcial.
- **0:35 – 1:15 · Los tres ejercicios resueltos.** Rehacé el A y el B con la calculadora tapando los resultados. El C leelo con las correcciones.
- **1:15 – 1:35 · Esquema y símbolos.** Dibujá el circuito completo de memoria y escribí al lado de cada elemento la función y el dato de selección.
- **1:35 – 1:55 · Banco de preguntas en modo práctica** + la tabla de errores.
- **1:55 – 2:00 · Repaso final:** velocidades de tubería, los cinco filtros, ISO 4406 y las conversiones.

**Llevá:** calculadora, regla, lápiz y goma (el esquema se dibuja), y las tablas de catálogo si las permite.

Fuentes: Parcial N° 02 2020 y su resolución (G. Avanzini), Parcial N° 2 tipo proyecto, TP N° 3 2025 y resoluciones de Martina y Juano, apuntes de cátedra de Hidráulica y SNeH, y tu propio TP del gato de fosa con las correcciones del Ing. Anzola. Catálogos: cilindros CD70/CG70 (rs17016), bombas Bosch Rexroth AZPB-3x y AZPF, tuberías DIN 2413.