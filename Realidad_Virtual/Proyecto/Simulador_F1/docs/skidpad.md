# Skidpad, recta y frenada: capacidad medida del auto

Generado por `tools/godot/tests/test_skidpad.gd` (no editar a mano: se reescribe en cada corrida).
El auto del jugador sobre un plano, con neumático medio nuevo en seco, manejado por una fuente
de entrada propia registrada en el `InputManager`.

Puesta a punto medida: `downforce_coef` = 3.20 N/(m/s)², masa 800 kg, agarre 2.15 / 2.36 (delante / detrás),
rigidez de suspensión 300, freno máximo 34000 N.

## 1. Skidpad: aceleración lateral máxima

Dirección a tope y velocidad constante; media de 4 s en régimen estacionario.
"Antes" es la misma prueba con la puesta a punto de la Fase 1b (`downforce_coef` = 1,30).

| Velocidad | Antes (Fase 1b) | Ahora | Radio del círculo | Carga aerodinámica / peso |
|---|---|---|---|---|
| 54 km/h | 1.91 g | **2.09 g** | 11 m | 0.09 |
| 90 km/h | 2.10 g | **2.43 g** | 26 m | 0.25 |
| 126 km/h | 2.34 g | **2.88 g** | 43 m | 0.50 |
| 162 km/h | 2.63 g | **3.42 g** | 60 m | 0.83 |
| 198 km/h | 2.99 g | **4.00 g** | 77 m | 1.23 |
| 234 km/h | 3.40 g | **4.58 g** | 94 m | 1.72 |
| 270 km/h | 3.89 g | **5.11 g** | 112 m | 2.29 |
| 306 km/h (solo llegó a 287 km/h) | 4.00 g | **5.33 g** | 121 m | 2.95 |

## 2. Recta y frenada

| Medición | Antes (Fase 1b) | Ahora |
|---|---|---|
| 0-100 km/h | 2.31 s | 2.12 s |
| 0-200 km/h | 4.78 s | 4.50 s |
| Velocidad máxima (DRS + ERS) | 345 km/h | 345 km/h |
| Frenada 300-100 km/h: tiempo | 1.73 s | 1.35 s |
| Frenada 300-100 km/h: distancia | 89 m | 71 m |
| Frenada 300-100 km/h: media | 3.28 g | 4.19 g |
| Frenada 300-100 km/h: máxima | 4.93 g | 5.16 g |
| Hundimiento de la suspensión a velocidad máxima | 64 mm de 100 mm | 47 mm de 100 mm |

## 3. Lateral por compuesto (neumático nuevo, seco)

| Compuesto | 90 km/h | 234 km/h |
|---|---|---|
| blando | 2.50 g | 4.72 g |
| medio | 2.43 g | 4.58 g |
| duro | 2.35 g | 4.44 g |
| intermedio | 2.13 g | 4.02 g |
| lluvia | 1.89 g | 3.56 g |
