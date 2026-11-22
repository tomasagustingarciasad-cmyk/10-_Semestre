# Clima, compuestos de neumáticos y aquaplaning

Agregado en la **Fase 1b**. Código: `scripts/track/weather.gd`, `scripts/car/tyre_compound.gd`,
`scripts/car/f1_car.gd` (`_update_surfaces`) y `scripts/track/track.gd` (`build_speed_profile`).
Los valores de cada compuesto están en `assets/tyres/<id>.tres` (los escribe
`tools/godot/car_builder.gd`, tabla `TYRE_COMPOUNDS`).

## 1. Clima y agua en pista

El clima se elige en el menú antes de cada sesión, en **cualquiera de los dos niveles**. Los dos
niveles tienen el mismo nodo `Clima` (`weather.gd`), que al iniciar configura cielo, niebla, sol y
partículas de lluvia. De él salen dos números:

| Variable | Rango | Qué es |
|---|---|---|
| `rain_intensity` | 0 … 1 | Cuánto llueve (maneja lo visual: cielo, niebla, gotas). |
| `water_level` | 0 … 1 | **Agua en pista**. Es lo único que mira la física. |

| Clima | Lluvia | Agua en pista |
|---|---|---|
| Seco | 0 | 0 |
| Lluvia | 1 | 0,70 (`rain_water_level`) |
| Variable | cambia de 0 a 1 (o de 1 a 0, al azar) entre el 25 % y el 50 % de la duración estimada de la sesión | sigue a la lluvia con retardo: tarda 45 s en mojarse del todo y 150 s en secarse |

El agua no es uniforme: `Weather.get_water_at(punto)` la modula con ruido (charcos), entre el 60 %
y el 100 % del nivel general. Por eso cada rueda puede pisar una cantidad de agua distinta.

Cuando el agua cambia más de 0,05 la sesión actualiza todo lo que depende de ella
(`SessionBase._refresh_conditions`): aspecto del asfalto (más oscuro y brillante), perfil de
velocidad del piloto automático y de los rivales, y la decisión de los rivales de cambiar neumáticos.

## 2. Compuestos

| Compuesto | Letra / color | Agarre en seco | Agarre en mojado | Desgaste en seco | Desgaste en mojado | Aquaplaning: inicio | Aquaplaning: total |
|---|---|---|---|---|---|---|---|
| Blando | B / rojo | 1,03 | 0,55 | ×2,0 | ×1 | 150 km/h | 220 km/h |
| Medio | M / amarillo | 1,00 | 0,55 | ×1 | ×1 | 150 km/h | 220 km/h |
| Duro | D / blanco | 0,97 | 0,55 | ×0,55 | ×1 | 150 km/h | 220 km/h |
| Intermedio | I / verde | 0,88 | 0,80 | ×2,5 | ×1 | 230 km/h | 290 km/h |
| Lluvia extrema | L / azul | 0,78 | 0,86 | ×4 | ×1 | 280 km/h | 340 km/h |

El **medio** es el "slick" de referencia del pedido (1,00 / 0,55); blando y duro son el extra de
estrategia: más agarre y más desgaste, o al revés (§9).

El agarre del compuesto se interpola según el agua. Se considera "mojado del todo" a partir de un
agua de 0,5 (`WET_REFERENCE_WATER`):

```
mojado      = clamp(agua / 0,5 ; 0 ; 1)
compuesto   = lerp(agarre_seco, agarre_mojado, mojado)
desgaste    = lerp(desgaste_seco, desgaste_mojado, mojado)     (multiplica el desgaste normal)
```

Se elige en el menú (neumático de salida) y se cambia en la **parada en boxes**: mientras dura el
servicio (3,2 s) las levas o el botón DRS (teclas E / Q / F) pasan de un compuesto a otro; el HUD
muestra el elegido. Los rivales salen con el mejor compuesto para el agua del momento
(`TyreCompound.best_for`) y, si el clima cambia y otro compuesto rinde al menos un 4 % más, entran
a boxes a cambiarlo.

## 3. Aquaplaning

A alta velocidad sobre agua, la rueda "flota" y pierde agarre. Se calcula **por rueda**
(`TyreCompound.get_aquaplaning_factor`):

```
banda        = 1 − 0,25 · desgaste                    (el neumático gastado aquaplanea antes)
v_inicio     = inicio_del_compuesto · banda
v_total      = total_del_compuesto  · banda
pérdida      = agua_bajo_la_rueda · (1 − 0,3)
aquaplaning  = 1 − pérdida · smoothstep(v_inicio, v_total, velocidad)
```

- Sin agua el factor es 1 (no hay aquaplaning).
- Por debajo de `v_inicio` es 1; por encima de `v_total` vale `1 − 0,7·agua` (con agua 1 queda
  el 30 % del agarre: `AQUAPLANING_MIN_GRIP`).
- `smoothstep` da una transición suave (pendiente cero en los extremos), sin escalones.

Ejemplo con slick y agua 0,70 (lluvia): a 150 km/h → 1,00; a 185 km/h → 0,755; a 220 km/h o más → 0,51.

## 4. Fórmula completa del agarre de cada rueda

```
agarre = base × carga × superficie × desgaste × compuesto(agua) × aquaplaning(velocidad, agua, desgaste)
```

| Factor | De dónde sale | Valores |
|---|---|---|
| base | `CarSetup.grip_front` / `grip_rear` | 2,15 adelante, 2,36 atrás |
| carga | `CarSetup.get_load_factor` (Fase 1c) | sensibilidad a la carga: 1,00 parado → 0,77 a 250 km/h |
| superficie | lo que pisa esa rueda (`Track.get_surface_at`) | asfalto 1,00 · piano y pasto, los valores de `CarSetup` |
| desgaste | `F1Systems.Tyres.get_grip_factor` | 1,00 nuevo → 0,925 en el acantilado → 0,70 gastado (§9) |
| compuesto(agua) | tabla de la sección 2 | p. ej. slick: 1,00 seco → 0,55 mojado |
| aquaplaning | sección 3 | 1,00 … 0,30 |

Tabla de ejemplo (rueda nueva sobre asfalto; producto compuesto × aquaplaning):

| Situación | Medio | Intermedio | Lluvia extrema |
|---|---|---|---|
| Seco, cualquier velocidad | **1,00** | 0,88 | 0,78 |
| Lluvia (agua 0,70), 120 km/h | 0,55 | 0,80 | **0,86** |
| Lluvia (agua 0,70), 200 km/h | 0,33 | 0,80 | **0,86** |
| Lluvia (agua 0,70), 260 km/h | 0,28 | 0,60 | **0,86** |
| Lluvia (agua 0,70), 320 km/h | 0,28 | 0,41 | 0,55 |
| Pista húmeda (agua 0,25), 200 km/h | 0,67 | **0,84** | 0,82 |

Se ve la lógica de la elección: en seco gana el slick; con poca agua, el intermedio; con lluvia, el
de lluvia extrema, y a más de 280 km/h ni ese se salva.

## 5. Avisos al piloto

- **HUD:** aparece el texto `AQUAPLANING` mientras el menor factor de las cuatro ruedas está por
  debajo de 0,88. Arriba a la derecha se ve el compuesto montado (letra y color), su desgaste y el
  agua en pista.
- **Vibración:** al empezar el aquaplaning, y cada 0,4 s mientras dura, se envía un evento
  `V,<intensidad>,120` (intensidad base 170, escalada con la pérdida de agarre).
- **Telemetría:** el bit 7 de `flags_bitmask` (`FLAG_AQUAPLANING`, valor 128). Es nuevo y
  compatible hacia atrás: ver `docs/protocolo.md`.

## 6. Rivales y piloto automático

El perfil de velocidad (`Track.build_speed_profile`) recibe la puesta a punto del auto, el agarre
del compuesto y los datos de aquaplaning (`TyreCompound.get_profile_aquaplaning`): en cada punto,
la velocidad de paso por curva se calcula con el agarre ya reducido por el aquaplaning a esa
velocidad (se resuelve por bisección).
Resultado: con slicks bajo la lluvia los rivales y el piloto automático frenan mucho antes y doblan
más despacio; con el neumático correcto casi no pierden.

## 7. Spray

Cada auto (jugador y rivales) tiene un nodo `Spray` (`scripts/car/spray.gd`): partículas que
levantan una nube de agua detrás, proporcional a la velocidad y al agua en pista. No afecta la
física; reduce la visibilidad al seguir de cerca a otro auto.

## 8. Aquaplaning y carga aerodinámica (Fase 1c)

Con la carga aerodinámica nueva (3,2 en vez de 1,30) el auto dobla y frena mucho más fuerte, pero el
aquaplaning **no cambió**: es un factor sobre el coeficiente de agarre, independiente de la carga.
Sigue teniendo sentido, y se nota más: con slicks bajo la lluvia a 220 km/h el auto pasa de poder
doblar a ~4,4 g a ~1,2 g (0,55 × 0,51 del agarre), justo donde más carga hay. Con lluvia extrema a
esa velocidad conserva el 86 %. Las velocidades de inicio y de aquaplaning total de cada compuesto
se dejaron como estaban.

## 9. Desgaste y estrategia (Fase 1c)

### El problema

En la Fase 1b todos los compuestos perdían agarre en forma lineal hasta el 28 % y el medio duraba
unos 30 km. El blando dejaba de superar al duro en 1 o 2 vueltas: en una carrera corta nunca
convenía y no había estrategia posible.

### Tres decisiones

**1. Pérdida de agarre con meseta y acantilado** (`F1Systems.Tyres.get_loss_share`). El neumático
casi no pierde hasta el 60 % de desgaste y después cae rápido:

```
si desgaste ≤ 0,6:   parte = 0,25 · desgaste / 0,6                              (meseta)
si no:               parte = 0,25 + 0,75 · ((desgaste − 0,6) / 0,4)²            (acantilado)
agarre = 1 − 0,30 · parte
```

| Desgaste | 0 % | 30 % | 60 % | 80 % | 100 % |
|---|---|---|---|---|---|
| Agarre | 1,000 | 0,963 | 0,925 | 0,869 | 0,700 |

**2. Desgaste proporcional a la carrera** (`RaceSession._get_tyre_life`). En Carrera, la "vida" del
neumático medio (rodando derecho) es **1,5 veces la distancia total de la carrera**, con tope en la
vida real (120 km). Así una carrera de 3 vueltas gasta los neumáticos igual que una de 20, que es
lo que hacen los juegos de carreras con el "desgaste acelerado". En Clasificación rige la vida real.

El desgaste real es mayor que el de rodar derecho: la exigencia lateral lo multiplica por ~1,45 en
una vuelta rápida (medido). Con eso, en una carrera sin parar:

| Compuesto | Desgaste ×  | Llega al acantilado (60 %) al... | Llega al 100 % al... |
|---|---|---|---|
| Blando | 2,0 | 31 % de la carrera | 52 % |
| Medio | 1,0 | 62 % | recién al final (97 %) |
| Duro | 0,55 | no llega (termina en 53 %) | — |

**3. Blando más frágil y duro más durable:** el blando pasó de ×1,6 a ×2,0 y el duro de ×0,65 a ×0,55.

### Resultado: agarre medio de una tanda

Carrera de 20 vueltas (`test_tyres.gd` lo calcula y lo verifica; con otras cantidades de vueltas las
proporciones son las mismas):

| Tanda | Blando | Medio | Duro | Conviene |
|---|---|---|---|---|
| 1 vuelta | **1,024** | 0,997 | 0,968 | blando |
| 5 vueltas (25 %) | **0,999** | 0,985 | 0,962 | blando |
| 8 vueltas (40 %) | **0,980** | 0,976 | 0,957 | blando, por poco |
| 10 vueltas (50 %) | 0,953 | **0,970** | 0,954 | medio |
| 15 vueltas (75 %) | 0,875 | **0,955** | 0,946 | medio |
| 17 vueltas (85 %) | 0,857 | **0,946** | 0,943 | medio, por poco |
| 20 vueltas (100 %) | 0,837 | 0,924 | **0,938** | duro |

- **Blando:** clasificación y tandas de hasta el 40 % de la carrera.
- **Medio:** tandas de media carrera (la estrategia "normal" con la parada obligatoria).
- **Duro:** tandas largas, de más del 85–90 % (parar muy temprano o muy tarde).

La velocidad de paso por curva va con la raíz del agarre: 5 % menos de agarre es ~2,5 % menos de
velocidad en curva.

### Rivales

Los rivales ahora también se gastan, con un modelo simplificado (`AiCar.wear`): la misma curva de
agarre, con el desgaste creciendo con la distancia × 1,45 × el factor del compuesto, y vuelve a
cero en la parada. Antes no se gastaban y el jugador corría con desventaja al final de cada tanda.

## 10. Pruebas

`tools/godot/tests/test_tyres.gd` verifica la estrategia (§9), la tabla, la fórmula (incluido el punto medio de la
banda), el aquaplaning en pista con slick y sin él con lluvia extrema, la bandera, la vibración y el
aviso del HUD. `test_weather.gd` verifica el clima en los dos niveles y el modo Variable.
`test_pits.gd` verifica el cambio de compuesto en la parada.
