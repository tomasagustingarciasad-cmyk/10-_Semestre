# Cómo se arma el circuito: curvas, superficies y transformaciones

Notas para el informe sobre la construcción del **Autódromo Los Aromos** (circuito original del
proyecto) y su relación con contenidos de la materia: **curvas y superficies en el espacio** y
**transformaciones geométricas**.

Código: `scripts/track/track_layout.gd` (datos), `tools/godot/track_builder.gd` (generación de la
escena), `scripts/track/track.gd` (consultas en tiempo de juego). Escena resultante:
`scenes/track/circuito.tscn`.

## 1. Idea general

```
puntos de control (x, z)  ──►  curva suave (Curve3D en un Path3D)  ──►  superficies por extrusión (CSGPolygon3D)
        datos                         eje de la pista                    asfalto, pianos, líneas, muros
```

Todo el circuito sale de **36 puntos** escritos a mano en `TrackLayout.MAIN_POINTS` y de un puñado
de medidas (ancho, distancia a los muros...). Cambiando un punto y regenerando, se mueven solos el
asfalto, los pianos, los muros, los checkpoints, los carteles y el perfil de velocidad de la IA.

| Dato | Valor |
|---|---|
| Longitud | 2951 m |
| Ancho del asfalto | 13 m (`HALF_WIDTH` = 6,5 m) |
| Sentido | Horario (visto desde arriba) |
| Sectores | S1: 0–987 m · S2: 987–1945 m · S3: 1945–2951 m |
| Vuelta de referencia | ~58,7 s (piloto automático, seco) |

Sistema de coordenadas: plano **XZ**, con Y hacia arriba (el circuito es plano). La recta principal
va hacia +X; con ese sentido de marcha la derecha del auto apunta a +Z, que es el interior del
circuito (donde está el pit lane).

## 2. La curva: de puntos sueltos a una curva suave

Un `Path3D` contiene una `Curve3D`: una sucesión de tramos de **Bézier cúbica**. Cada punto de la
curva tiene una posición `P` y dos "manijas" (vectores `in` y `out`) que definen la tangente. Entre
dos puntos consecutivos `P₀` y `P₁` el tramo es:

```
B(t) = (1−t)³·P₀ + 3(1−t)²t·(P₀ + out₀) + 3(1−t)t²·(P₁ + in₁) + t³·P₁ ,     t ∈ [0, 1]
```

Para no tener que dibujar las manijas a mano, `TrackLayout.build_curve()` las calcula:

- **Dirección:** la de la cuerda que une al punto anterior con el siguiente,
  `T = normalizar(P_siguiente − P_anterior)`. Es la regla de las splines de **Catmull-Rom**: la
  tangente en cada punto es paralela al segmento entre sus vecinos. Como la manija de entrada y la
  de salida comparten dirección, la curva tiene tangente continua (no hay quiebres).
- **Longitud:** un tercio de la distancia al vecino de ese lado (`out = T·|P_sig − P|/3`,
  `in = −T·|P − P_ant|/3`). Con puntos separados de manera despareja (rectas de 250 m, curvas con
  puntos cada 25 m) esto evita rulos y sobrepasos.
- **Cierre:** el primer punto se repite al final, con las mismas manijas, así el lazo cierra suave.

Consecuencias prácticas del método:

- Tres puntos alineados dan una **recta exacta** (las manijas quedan sobre la recta).
- Una curva de radio casi constante se logra poniendo puntos sobre una circunferencia (la
  horquilla usa 5 puntos sobre un círculo de radio 30 m).

### Parametrización por longitud de arco

El parámetro `t` de Bézier no avanza a velocidad constante. Godot "hornea" la curva
(`bake_interval` = 1 m): la muestrea en puntos equiespaciados y permite consultar la posición a una
**distancia** `s` del inicio con `curve.sample_baked(s)`. En el proyecto esa distancia se llama
*offset* y es la coordenada natural de todo: la línea de llegada es `s = 0`, el sector 1 termina en
`s = 987 m`, un rival está "en `s = 1520`", etc. La operación inversa,
`curve.get_closest_offset(punto)`, da el **progreso** de un auto en la vuelta.

### Sistema de referencia móvil

En cada punto del eje se define una terna ortonormal (`Track.get_transform_at`):

```
adelante  f = normalizar(C(s + 1) − C(s − 1))      tangente por diferencia central
arriba    u = (0, 1, 0)                            el circuito es plano
derecha   d = f × u                                producto vectorial
```

Con esa terna cualquier punto cercano a la pista se expresa como "a `s` metros de la largada y a
`ℓ` metros a la derecha del eje": `P = C(s) + ℓ·d`. Así se ubican los cajones de la grilla, los
carteles, los rivales (cada uno en su carril) y el auto al reiniciar.

En Godot esa terna más el origen es un `Transform3D`: `Basis(d, u, −f)` y origen `P` (el eje −Z de
un nodo es su "adelante"). Es una **transformación rígida** (rotación + traslación) que lleva las
coordenadas locales del objeto a coordenadas del mundo.

## 3. Las superficies: extrusión a lo largo de la curva

Una **superficie de barrido** se genera trasladando una curva plana (la *sección transversal*) a lo
largo de otra curva (la *directriz*), manteniéndola perpendicular a la tangente:

```
S(s, w) = C(s) + x(w)·d(s) + y(w)·u(s)
```

donde `(x(w), y(w))` recorre el polígono de la sección. Eso es exactamente lo que hace
`CSGPolygon3D` en modo **PATH** con rotación **PATH_FOLLOW**: toma un polígono 2D y lo "arrastra"
por el `Path3D`, colocando una copia cada `path_interval` metros (3 m acá) y uniendo copias
consecutivas con caras.

En la sección, X positivo es la **derecha** del sentido de marcha (se verificó con un rayo de
prueba) e Y es la altura.

| Elemento | Sección (x, y) en metros | Colisión |
|---|---|---|
| Asfalto | rectángulo de x = −6,5 a 6,5; cara superior en y = 0,03 | sí |
| Líneas de borde | franja de 0,25 m junto a cada borde, 1,5 cm sobre el asfalto | no |
| Pianos | **cuña** de 1,3 m: 3,5 cm junto al asfalto, 7 cm en el borde exterior | sí |
| Muros | rectángulo de 0,8 × 1,1 m | sí |
| Pit lane | rectángulo de 9 m, 1 cm más bajo que la pista | sí |

Con `use_collision` activado, Godot genera además la malla de colisión de cada extrusión, de modo
que lo que se ve es lo que se toca.

**Pianos solo en las curvas.** El generador recorre el eje midiendo la curvatura; donde el radio es
menor que 130 m marca un tramo, lo extiende 14 m antes y después, y une los tramos cercanos.
Resultan 7 tramos. Para cada uno crea una **sub-curva** (un `Path3D` con los puntos de ese tramo) y
extruye dos cuñas, una a cada lado. Los colores rojo/blanco salen de una textura de 2 píxeles
repetida a lo largo de la curva (`path_continuous_u`).

**Muros: curvas paralelas (offset).** El muro no puede usar la misma directriz que el asfalto
porque frente a boxes tiene que alejarse para dejar lugar al pit lane. Se construye una **curva
paralela**: se muestrea el eje cada 6 m y cada punto se desplaza sobre la normal,

```
M(s) = C(s) + δ(s)·d(s)
```

con `δ = −17 m` para el muro exterior y `δ(s)` variable para el interior: 14,5 m en general y 42 m
frente a boxes, con una transición suave (`smoothstep`) de 45 m. Con esos puntos se arma otra
`Curve3D` y se extruye un rectángulo. (Una curva paralela solo es válida mientras `|δ|` sea menor
que el radio de curvatura del lado interno; el radio mínimo del circuito es 22,8 m.)

## 4. Curvatura y perfil de velocidad

La curvatura `κ = 1/R` se estima con el círculo que pasa por tres puntos del eje separados 5 m
(curvatura de Menger):

```
κ = 2·(a × b) / (|a|·|b|·|c|)        a = P₁−P₀,  b = P₂−P₁,  c = P₂−P₀   (en el plano XZ)
```

El signo del producto cruzado indica el sentido: positivo = curva a la derecha.

| Curva | Distancia [m] | Sentido | Radio mínimo [m] |
|---|---|---|---|
| 1 | 530–600 | derecha | 84 |
| 2 (chicana) | 790 | izquierda | 25 |
| 3 (chicana) | 840 | derecha | 23 |
| 4 | 1060 | derecha | 102 |
| 5 (horquilla) | 1780–1830 | derecha | 24 |
| 6 | 1990 | izquierda | 43 |
| 7–8 (enlazadas) | 2170–2300 | izquierda | 85 |
| 9 | 2500–2560 | derecha | 43 |
| 10 | 2620 | derecha | 34 |

Con la curvatura se calcula la **velocidad máxima de paso** en cada punto. La fuerza centrípeta
necesaria debe ser menor que el agarre disponible, que crece con la carga aerodinámica:

```
m·v²·κ ≤ μ·(m·g + k_c·v²)      ⟹      v² = μ·g / (κ − μ·k_c/m)
```

Después se hacen dos pasadas sobre la vuelta: **hacia atrás**, para que la velocidad baje a tiempo
antes de cada curva (`v_i ≤ √(v_{i+1}² + 2·a_freno·Δs)`), y **hacia adelante**, para no acelerar
más de lo posible. El resultado (`Track.build_speed_profile`) es el "perfil de velocidad por tramo"
que siguen los rivales y el piloto automático.

## 5. Superficie bajo las ruedas (geometría en vez de colisiones)

Para saber si una rueda pisa asfalto, piano o pasto no se usan materiales de colisión: se resuelve
con la misma geometría (`Track.classify_point`):

1. `s = get_closest_offset(P)`: proyección del punto sobre el eje.
2. `ℓ = (P − C(s))·d(s)`: distancia lateral con signo (producto escalar con la derecha).
3. `|ℓ| ≤ 6,5` → asfalto; `|ℓ| ≤ 7,8` y hay piano en ese `s` → piano; si no, se prueba contra el
   eje del pit lane; si tampoco → **pasto**.

Con las cuatro ruedas en el pasto la vuelta se invalida.

## 6. Zonas con lógica: `Area3D`

| Zona | Forma | Uso |
|---|---|---|
| Línea de llegada, fin de S1, fin de S2 | caja fina transversal (3 m de espesor) | Cronometraje: deben cruzarse en orden |
| 2 zonas de DRS | caja sobre cada recta larga | Habilitan el DRS |
| Pit lane | caja sobre el tramo recto de boxes | Límite de 80 km/h |
| Box del jugador | caja de 10 × 4,2 m | Detenerse adentro = cambio de neumáticos |

Cada caja se ubica con el `Transform3D` de la sección 2. La línea de llegada es más ancha hacia la
derecha para abarcar el pit lane (quien pasa por boxes también completa la vuelta). Las zonas solo
detectan la capa de colisión del auto del jugador.

Como el aviso de ingreso a un `Area3D` llega en un tick de física (cada 8,3 ms), el instante real de
cruce se corrige con la distancia al plano de la línea y la velocidad: `t = t_tick − d / v`
(`LapTimer._crossing_time`).

## 7. Decorado con primitivas y transformaciones

- **Pórtico y semáforo:** cajas (columnas, viga, panel) y 5 esferas que cambian de material.
- **Tribuna:** 5 cajas escalonadas (cada una más alta y más atrás), asientos y techo.
- **Edificio de boxes:** cajas; los portones son cajas oscuras apenas salidas de la fachada.
- **Carteles de frenado (150/100/50):** poste + placa + texto, colocados con `get_transform_at`
  a esas distancias antes de cada frenada fuerte y girados hacia los autos que llegan.
- **Árboles:** 220 copias de dos primitivas (cilindro = tronco, cono = copa) dibujadas con
  `MultiMesh`; cada copia tiene su propia transformación (traslación + rotación en Y + escala
  uniforme) generada con una semilla fija.

El auto usa las mismas ideas (ver `tools/godot/car_builder.gd`): por ejemplo, las ruedas son
cilindros que nacen con el eje en Y y se rotan 90° en Z; la trompa es un cono rotado −90° en X; el
halo es un toro; el flap del DRS cuelga de un nodo "bisagra" ubicado en su borde delantero para que
rote alrededor de ese borde y no de su centro (composición de transformaciones).

## 8. Cómo modificar el circuito

1. Editar `MAIN_POINTS` (o las medidas) en `scripts/track/track_layout.gd`.
2. Regenerar: `godot --headless --script res://tools/godot/build_scenes.gd -- circuito niveles`.
3. Probar: `godot --headless --fixed-fps 60 --script res://tools/godot/tests/test_drive.gd -- 130`
   (informa longitud, tiempos de vuelta y salidas de pista del piloto automático).

Si se cambia la zona de la recta principal hay que revisar también `PIT_POINTS`, `DRS_ZONES` y
`SECTOR_*`, que están en coordenadas absolutas.

También se puede abrir `scenes/track/circuito.tscn` en el editor y mover los puntos del nodo
`Trazado` a mano: el asfalto y las líneas se actualizan en vivo. Pero los pianos, muros y zonas
(que derivan del trazado) solo se recalculan al regenerar, y regenerar pisa los cambios manuales.
