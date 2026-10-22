# SNH: Guía de estudio para el Parcial N° 2 (Oleohidráulica, U4–U6)

Parcial: **lunes 19/10/2026** · individual · escrito · con catálogos adjuntos (casi seguro) · **sin formulario**.
Armada el 2026-10-12 a partir de `SNH_U0_dossier-parcial2_apunte.md`, los enunciados originales (Makro, 2020, TP3), el apunte de Martina y `SNH_U0_diapositivas-clave_teorica.pdf`. Las cuentas están verificadas con Python.

**Convenciones de esta guía**

- **"ver pág. N"** remite a la página N de `SNH_U0_diapositivas-clave_teorica.pdf` (la selección de 54 diapositivas). Los enunciados se citan como "Makro p. 6", "2020 p. 2", "TP3 p. 3".
- **Unidades de la cátedra**: kg/cm² ≈ bar ≈ kp/cm², fuerzas en kg (kgf), áreas en cm², caudal en l/min o cm³/s, cilindrada en cm³/rev. La equivalencia exacta es 1 kg/cm² = 0,981 bar; la cátedra las toma como iguales y esta guía también.
- ⚠️ **= verificar con la cátedra**: inferencia, criterio no confirmado o dato que no sale del material de la cátedra.
- "Dato de catálogo" = solo lo que figura en los catálogos adjuntos a los enunciados (transcriptos en el dossier §4). Todo lo demás es orden de magnitud.

## Índice

- **PARTE A — Fundamentos desde cero**
  - A1. Qué es un sistema oleohidráulico
  - A2. Las 4 relaciones de todo el parcial
  - A3. La bomba da caudal; la carga pone la presión → limitadora
  - A4. El cilindro
  - A5. Los componentes, uno por uno
  - A6. Cómo leer un esquema
  - A7. Fluido y contaminación (nivel examen)
- **PARTE B — Resolución del parcial**
  - §0. Mapa del parcial (prioridad **alta**)
  - §1. Procedimiento maestro del caso práctico (**alta**)
  - §2. Cómo leer los catálogos que adjuntan (**alta**)
  - §3. El esquema estándar, opcionales, centros de la 4/3 (**alta**)
  - §4. Limitadora: procedimiento y valor de ajuste (**alta**)
  - §5. Automatismos eléctricos (**media-alta**)
  - §6. Teoría corta: respuestas modelo (**media**)
  - §7. Parciales anteriores resueltos (**alta**)
  - §8. Variantes numéricas para practicar (**media**)
  - §9. Hoja "de memoria" (**alta**)
  - §10. Errores típicos y criterios de corrección (**alta**)
  - Anexo. Temas que nunca se tomaron (**baja**)

---

# PARTE A — FUNDAMENTOS DESDE CERO

## A1. Qué es un sistema oleohidráulico

**Intuición.** Es el mismo esquema que en neumática (generar fluido a presión → válvulas → actuador), con dos diferencias que lo cambian todo:

- el fluido es **aceite**, prácticamente incompresible;
- el aceite **no se escapa a la atmósfera**: vuelve al tanque y se reutiliza. Es un circuito **cerrado**.

En neumática el compresor llena un tanque de aire y el aire usado se tira por el escape. Acá no hay "tanque de aire comprimido" (salvo el acumulador, A5): la bomba empuja aceite **en el momento** en que se lo necesita, y ese aceite vuelve al depósito por la línea de retorno.

**Flujo de energía** (ver pág. 3):

```
 Energía      ┌───────┐  mecánica  ┌───────┐  hidráulica  ┌──────────┐  mecánica
 eléctrica ──►│ Motor │──────────► │ Bomba │────────────► │ Actuador │──────────► Trabajo
 (o química)  │  ηM   │  (eje: M,n)│  ηB   │   (p, Q)     │   ηA     │  (F, v)
              └───────┘            └───────┘              └──────────┘
```

$$\eta_{total}=\eta_M\cdot\eta_B\cdot\eta_A$$

**Flujo del aceite** (ver pág. 4 y pág. 5):

```
 TANQUE ──► filtro aspiración ──► BOMBA ──► válvulas ──► CILINDRO
   ▲                                                         │
   └────────── filtro de retorno ◄──── válvulas ◄────────────┘
```

**Por qué el aceite hay que cuidarlo.** Como vuelve y se reutiliza, todo lo que le pasa se acumula: la suciedad que agarró, el calor que juntó, el aire y el agua que le entraron. La pág. 4 lo lista: retorno, filtrado, temperatura, espumado. El aceite sucio desgasta las piezas (A7), y **la calidad del aceite define la vida útil de los equipos**. Por eso el circuito lleva tanque, filtros y a veces enfriador, que en neumática no existen o son mucho más simples.

**Diferencias con neumática** (para la pregunta teórica):

| Aspecto | Neumática | Oleohidráulica |
|---|---|---|
| Fluido | Aire, compresible | Aceite, ~incompresible (≈ 0,7 % de reducción de volumen cada 100 bar) |
| Presiones | ~6–10 bar | decenas a cientos de bar (catálogos adjuntos: 70–350 bar) |
| Fuerza | baja–media | alta (toneladas con cilindros chicos) |
| Velocidad | alta | moderada |
| Precisión / posicionado | media (el aire se comprime) | alta, movimiento uniforme |
| Fluido usado | se descarga a la atmósfera | **retorna al tanque**: requiere acondicionamiento (filtrado, temperatura, aire, agua) |
| Generación | compresor + depósito de aire | bomba que entrega caudal en el momento |
| Limpieza | limpio | fugas de aceite, suciedad; inflamable |
| Costo / mantenimiento | bajo / sencillo | alto / exigente |

**Ventajas y desventajas** (apunte SNeH):

- **Ventajas:** autolubricante; posicionamiento preciso y movimiento uniforme (incompresibilidad); mucha fuerza con equipos compactos; transmite la presión más rápido que el aire.
- **Desventajas:** suciedad y fugas; inflamable; sensible a la contaminación y a la temperatura; componentes caros; el aceite envejece; cavitación y entrada de aire.

**Cómo aparece en el parcial.** TP3 ítem 1.1 (rango de presiones), 1.2 (orden de componentes), 1.4 (el fluido se recupera: qué controlar); 2020 ítem 2 (qué forma parte del sistema).

---

## A2. Las 4 relaciones de todo el parcial

Con estas cuatro fórmulas se resuelve el 80 % de cualquier caso práctico.

### 1) Presión, fuerza y área: $p = F/A$

$$p\;[\text{kg/cm}^2]=\frac{F\;[\text{kg}]}{A\;[\text{cm}^2]}$$

Es la ventaja de trabajar en kg y cm²: el cociente da directamente kg/cm² ≈ bar.

*Ejemplo:* levantar 1000 kg con un pistón de 40 mm ($A=\pi\cdot 4^2/4=12{,}57$ cm²) requiere $p=1000/12{,}56=79{,}6$ kg/cm² (≈ 78 bar ≈ 7,8 MPa).

Para **dimensionar** se usa al revés: $A_{necesaria}=F/p_{disponible}$.

### 2) Caudal, área y velocidad: $Q = A \cdot v$

$$Q\;[\text{cm}^3/\text{s}]=A\;[\text{cm}^2]\cdot v\;[\text{cm/s}]\qquad Q\;[\text{l/min}]=\frac{Q\;[\text{cm}^3/\text{s}]\cdot 60}{1000}$$

Es continuidad pura: el pistón barre un volumen $A\cdot L$ en el tiempo $t$, y ese volumen lo tiene que poner la bomba.

*Ejemplo:* el mismo pistón de 12,56 cm² con una carrera de 50 cm en 15 s: $v=50/15=3{,}33$ cm/s → $Q=12{,}56\cdot 3{,}33=41{,}9$ cm³/s $=2{,}51$ l/min.

Atajo útil: **1 l/min = 16,67 cm³/s**.

### 3) Caudal de la bomba: $Q = V_g \cdot n \cdot \eta_v$

$$Q\;[\text{cm}^3/\text{min}]=V_g\;[\text{cm}^3/\text{rev}]\cdot n\;[\text{rpm}]\cdot\eta_v$$

- $V_g$ = **cilindrada**: el volumen que la bomba desplaza en una vuelta del eje. Es lo que se elige en el catálogo (AZPB 1,0 · 2,0 · … · 7,1 cm³/rev).
- $n$ = rpm del motor que la mueve.
- $\eta_v$ = **rendimiento volumétrico**: parte del aceite se fuga internamente de la descarga a la aspiración (holguras entre engranajes y carcasa), así que entra menos de lo teórico. En 2025 lo dieron: 0,92.

Para elegir la bomba se despeja:

$$V_{g,necesaria}=\frac{Q\;[\text{cm}^3/\text{min}]}{n\cdot\eta_v}\;\;\rightarrow\;\;\text{se toma la cilindrada de catálogo inmediatamente mayor}$$

*Ejemplo:* necesito 2,51 l/min = 2512 cm³/min con un motor de 1450 rpm: $V_g=2512/(1450\cdot 0{,}92)=1{,}88$ cm³/rev → AZPB **2,0** cm³/rev → $Q_{real}=2{,}0\cdot1450\cdot0{,}92=2668$ cm³/min = 2,67 l/min.

### 4) Potencia hidráulica: $P = p \cdot Q$

$$P\;[\text{kW}]=\frac{p\;[\text{bar}]\cdot Q\;[\text{l/min}]}{600}\qquad P_{motor}=\frac{P_{hidr}}{\eta_{total,bomba}}$$

(El 600 sale de $10^5\,\text{Pa}\cdot\frac{10^{-3}}{60}\,\text{m}^3/\text{s}=1{,}667$ W; $1/1{,}667\cdot1000=600$.)

*Ejemplo:* 130 bar y 2,67 l/min → $P=130\cdot2{,}67/600=0{,}58$ kW hidráulicos; con un rendimiento total de bomba del orden de 0,85 (⚠️ asumido; la tabla de bombas del apunte de Martina da 0,8–0,91 para engranajes) → 0,68 kW en el eje (≈ 0,92 CV).

1 CV = 0,7355 kW · 1 HP = 0,7457 kW.

**Orden de magnitud de las pérdidas** (diagrama de potencias del apunte SNeH):

| Elemento | Pérdida típica |
|---|---|
| Motor eléctrico | ≈ 5 % |
| Bomba | ≈ 10 % |
| Válvulas y tubos | ≈ 10 % |
| Cilindro | ≈ 5 % (motor hidráulico ≈ 10 %) |

En total se pierde un 25–30 %: de 200 bar a la salida de la bomba llegan ≈ 140–150 bar útiles al actuador. Por eso no conviene elegir un cilindro que trabaje "pegado" a la presión disponible.

**Cómo aparece en el parcial.** En todos los casos prácticos: 2025 ítem 1, 2020 ítem 15, TP3 ítem 6, Makro ítems 1–5.

---

## A3. La idea clave: la bomba da CAUDAL; la PRESIÓN la impone la carga

### La intuición

Una bomba de engranajes es de **desplazamiento positivo**: en cada vuelta atrapa un volumen fijo de aceite entre los dientes y la carcasa y lo empuja a la salida (ver el corte de la pág. 6, ítem 1). No "decide" la presión: **mete un volumen por vuelta, pase lo que pase**.

Analogía: es como una jeringa que alguien aprieta con un motor a velocidad constante. Si la punta está libre, el líquido sale sin esfuerzo (presión ≈ 0). Si tapás la punta con el dedo, el motor sigue empujando y la presión sube hasta que algo cede: el dedo, la jeringa o el motor.

En el circuito, el "dedo" es la **carga**. El aceite llega al cilindro, y para que el pistón se mueva la presión tiene que subir hasta $p=F/A$. Nada más: si la carga es 1000 kg sobre 12,56 cm², la presión es ≈ 80 kg/cm² aunque la bomba "aguante" 220 bar. Si no hay carga, la presión es apenas la necesaria para vencer las pérdidas de carga.

> **Frase de examen:** "La bomba de desplazamiento positivo genera caudal. La presión aparece como consecuencia de la resistencia al flujo, es decir de la carga en el actuador y de las pérdidas en válvulas y tuberías."

Es **exactamente** lo que se pregunta en 2020 ítems 1 y 9, y es el error de Martina en el TP3 ("la bomba proporciona presión").

### Qué pasa cuando el cilindro llega a tope

El pistón llega al final de la carrera y no se puede mover más. La bomba sigue girando y metiendo $V_g$ por vuelta. Ese aceite **no tiene a dónde ir** (es incompresible). La presión sube sin límite teórico hasta que:

- revienta una manguera, un sello o la carcasa de la bomba, o
- el motor eléctrico se frena (sobrecorriente) o se rompe el eje.

Por eso **la válvula limitadora de presión es obligatoria** en todo circuito con bomba de caudal fijo: es la "salida de emergencia" que, al llegar a la presión de ajuste, abre un camino de la línea de presión al tanque y deja pasar **todo** el caudal de la bomba. La pág. 37 lo dice con la frase que conviene repetir: *limita la presión de trabajo a un máximo admisible, protege contra sobrecargas y va inmediatamente detrás de la bomba*. También se la llama válvula de seguridad o de alivio (ver pág. 35 y pág. 37).

### Por qué va en derivación y no en serie

```
   CORRECTO (derivación)                      INCORRECTO (en serie)

 bomba ──►──┬──────►── al circuito          bomba ──► [limitadora] ──► circuito
            │                                          (todo el caudal la
       [limitadora]                                     atravesaría siempre)
            │
            ▼
          TANQUE
```

- **En derivación** (en paralelo, una "T" desde la línea de presión al tanque) la limitadora está **cerrada** mientras $p<p_{ajuste}$ y el aceite va al cilindro. Solo abre cuando la presión llega al ajuste.
- **En serie** el aceite tendría que **atravesarla** para llegar al cilindro. Una limitadora cerrada cortaría el circuito; abierta, mandaría todo a tanque. No funciona.

Martina lo anotó al ver los dibujos del profe: *"el regulador de presión no está en serie"* (ver los esquemas de pág. 1, 6, 25 y 33: la limitadora 4 cuelga de la línea roja y descarga a tanque).

### El valor de ajuste (criterio)

La limitadora tiene que abrir **por encima** de la presión que hace falta para mover la carga; si no, el cilindro nunca se mueve y todo el aceite se va a tanque. Y tiene que abrir **por debajo** de lo que aguanten la bomba y el resto de los componentes:

$$p_{trabajo} + \Delta p_{pérdidas} \;<\; p_{ajuste} \;\le\; p_{máx\ admisible}\ (\text{bomba, componentes, presión dada en el enunciado})$$

Lo que se observó en los parciales corregidos (detalle en §4):

- 2025: el profe escribió **"P_ureg > P_trabajo"** y llevó el ajuste a **≈ 130 kg/cm²**, la presión máxima de bomba que daba el enunciado, en lugar de 125.
- 2020: las opciones eran 95, 100 y 145 kg/cm² para un trabajo de ≈ 80 kg/cm².
- Makro: el enunciado dice "regular a un valor que el manómetro lo pueda ver / 100 bar".

⚠️ verificar con la cátedra: el criterio práctico que se desprende es **ajuste ≈ presión máxima dada en el enunciado** y, si no la dan, **trabajo + 10–25 %**. Siempre justificar el número.

### Arranque en vacío (centro tándem)

Un motor asincrónico que arranca contra carga pide una corriente de arranque alta y tarda en acelerar. Si al arrancar la bomba ya tuviera que empujar contra la limitadora, arrancaría cargado a la presión de ajuste.

**Solución:** que en reposo la direccional conecte **P con T** (centro *tándem* o de recirculación; ver pág. 31 abajo a la derecha, "Tandem: P aberto ao tanque, A e B bloqueados"). Así la bomba descarga a tanque a presión casi nula: el motor arranca **en vacío** y además no se calienta el aceite mientras el equipo está parado.

El catálogo de bomba de 2025 lo pedía explícitamente: *"se sugiere que la bomba arranque en vacío, es decir motor con corriente nominal"*. Tabla de centros en A6 y §3.

**Cómo aparece en el parcial.** 2020 ítems 1, 9, 15.3 y 15.4; 2025 ítem 2 (25 %) y nota del catálogo B; TP3 ítem 1.7; Makro ítem 6 (7.2).

---

## A4. El cilindro

### Lado pistón y lado vástago

El cilindro de doble efecto tiene dos cámaras (ver pág. 39 y pág. 43):

```
          lado PISTÓN (A1)         lado VÁSTAGO (A3 anular)
        ┌────────────────────┬──────────────────────┐
  A ──► │                    │▓│                    │ ◄── B
        │   área = A1        │▓│══════════════════════════ vástago (A2)
        │   (círculo entero) │▓│   área = A1 − A2   │
        └────────────────────┴──────────────────────┘
                          émbolo
```

- **Lado pistón** (conexión A, la cámara "de atrás"): el aceite empuja sobre el círculo entero, $A_1=\pi D^2/4$.
- **Lado vástago** (conexión B): el aceite empuja sobre la **corona** que queda alrededor del vástago, el área anular $A_3=A_1-A_2$, con $A_2=\pi d^2/4$.
- En la tabla de cilindros de la cátedra: $A_1$ = pistón, $A_2$ = vástago, $A_3$ = anular; $\varphi=A_1/A_3$ (ver §2.1).

### Por qué sale con más fuerza y más lento de lo que vuelve

Con la **misma presión** $p$ y el **mismo caudal** $Q$ de bomba:

| Movimiento | Área que trabaja | Fuerza | Velocidad |
|---|---|---|---|
| Extensión (aceite por A) | $A_1$ (grande) | $F_{ext}=p\,A_1$ → **mayor** | $v_{ext}=Q/A_1$ → **menor** |
| Retracción (aceite por B) | $A_3$ (chica) | $F_{ret}=p\,A_3$ → menor | $v_{ret}=Q/A_3$ → **mayor** (φ veces) |

*Ejemplo* (40/28, $A_1=12{,}56$, $A_3=6{,}40$, φ ≈ 1,96): con 2,67 l/min sale en 14,1 s y vuelve en 7,2 s.

**Consecuencia que casi nadie mira:** al retraer, el aceite que **sale** del lado pistón es φ veces el caudal de bomba: $Q_{retorno}=Q\cdot A_1/A_3$. Con 2,67 l/min y φ = 1,96 vuelven al tanque **5,2 l/min**. El filtro de retorno y la línea de retorno se dimensionan con ese caudal, no con el de bomba.

### Qué área trabaja según la orientación y el sentido de la carga

**Regla:** la presión se calcula con el área de la cámara que está empujando **contra** la carga.

| Situación | Área que dimensiona | Ejemplo |
|---|---|---|
| Carga que se opone a la extensión (empujar, levantar con el vástago hacia arriba) | $A_1$ | gato 2025, brazo 2020, Makro |
| Carga que se opone a la retracción (tirar) | $A_3$ | TP3: 270 kg en retracción |
| Cilindro vertical que levanta y **baja por peso propio** | Solo $A_1$. El lado vástago no hace fuerza: se conecta a tanque. Puede ser de simple efecto | 2020 ítem 15.2; Makro ("trabaja siempre vertical") |
| Esfuerzo en los dos sentidos | Verificar las dos: $p_{ext}=F_{ext}/A_1$ y $p_{ret}=F_{ret}/A_3$; manda la mayor | TP3 ítem 6 |

Error clásico (Avanzini 2020): verificar el lado vástago cuando la retracción es por peso propio. No hace falta: con retorno por gravedad nadie empuja por B.

**Carga que "arrastra" (*overrunning*).** Cuando la carga **ayuda** al movimiento (bajar un peso), el cilindro tiende a "escaparse" más rápido de lo que la bomba lo llena. La velocidad se controla **frenando la salida** del aceite de la cámara que la carga presuriza: en una carga vertical, la línea A. Se hace con una reguladora de caudal con antirretorno que deja pasar libre hacia el cilindro y estrangula la salida (en neumática es el *meter-out*).

### Amortiguación de fin de carrera

Sin amortiguación, el émbolo llega a la tapa a toda velocidad y golpea. Con amortiguación, en los últimos milímetros un **émbolo de amortiguación** (un "buje" solidario al pistón) entra en un alojamiento de la tapa y tapa la salida principal. El aceite que queda atrapado solo puede salir por un orificio chico regulable con un tornillo (la "válvula de amortiguación"): se forma una cámara a presión que **frena** el pistón.

- Ver el corte de pág. 43 ("amortiguación ajustable de posiciones finales", "émbolo de amortiguación") y pág. 44.
- Lleva la velocidad de **1–2 m/min a 0,2–0,3 m/min** (pág. 44). Atos la recomienda por encima de **0,05 m/s** si no hay otro sistema de frenado externo (pág. 45).
- Símbolo: cilindro con un rectángulo chico en la tapa y una flecha oblicua (regulable); ver pág. 43 abajo a la derecha:

```
   ┌──┬─────────────────┐
   │▯╱│        │        │      ▯ con flecha = amortiguación regulable
   └──┴────────┼────────┘
               └────────────
```

Es la respuesta a **2020 ítem 10** ("disminuye la velocidad en el **último tramo**") y a la llegada lenta a los extremos de **Makro** (ver §3.5).

### Pandeo, primero intuitivo

El vástago es una barra larga y delgada **comprimida** cuando el cilindro empuja. Una barra esbelta comprimida no falla por aplastamiento: falla porque **se arquea de costado** de golpe al superar una carga crítica (la columna de Euler). Ya lo sabés de Elementos de Máquina: lo nuevo es cómo lo pide la cátedra.

Sube el riesgo con:

- vástago **más fino** (la rigidez va con $d^4$);
- **carrera más larga** (la carga crítica cae con el cuadrado de la longitud);
- extremos **más libres** (más longitud libre de pandeo).

Fórmula de la cátedra (pág. 40):

$$F_{adm}=\frac{K}{S}=\frac{10\cdot E\cdot J}{S\cdot S_k^2}\qquad J=0{,}0491\,d^4\ [\text{cm}^4]\qquad E=2{,}1\cdot10^6\ \text{kgf/cm}^2\qquad S=3$$

- $F$ = carga máxima de servicio [kgf]; $K$ = carga de pandeo [kgf]; $S_k$ = longitud libre de pandeo [cm]; $d$ = diámetro del **vástago** [cm]. El 10 es ≈ π².
- Casos de Euler (pág. 40):

| Caso | Fijación | $S_k$ | Comentario |
|---|---|---|---|
| 1 | un extremo libre, otro fijo | $2l$ | el peor; carga sin guiar sobre un cilindro empotrado |
| 2 (básico) | dos extremos articulados | $l$ | el más usado: cilindro con horquillas/rótulas en ambos extremos |
| 3 | articulado + fijo | $l/\sqrt2$ | carga guiada; "guiado cuidadoso de la carga, posible bloqueo" |
| 4 | dos extremos fijos | $l/2$ | "desfavorable, gran posibilidad de bloqueo" |

La cátedra: *"La verificación al pandeo debe realizarse siempre, principalmente cuando las cargas y las carreras son importantes."*

En el parcial sirve para **elegir el vástago** cuando la tabla ofrece dos (40/18 vs 40/28): la presión la define el pistón y el pandeo define el vástago. Procedimiento en §1, paso 4.

**Cómo aparece en el parcial.** 2025 ítem 1 (elegir 40/18 o 40/28), 2020 ítem 15.1 y 15.2, TP3 ítem 6A, Makro ítem 3 ("definir el área que considera").

---

## A5. Los componentes, uno por uno

Formato: **qué hace** · **símbolo** · **cómo se elige (dato de selección)** · **qué pasa si falta**. El dato de selección es lo que el profe penalizó en 2025 ("faltó explicar elementos de selección por P y Q").

### A5.1 Tanque o depósito

- **Qué hace:** almacena el aceite y lo deja "descansar" antes de volver a la bomba. En ese tiempo: decanta la suciedad, libera el aire (burbujas), separa el agua, disipa calor por las paredes y compensa fugas y la diferencia de volumen entre las cámaras del cilindro. Ver pág. 19 (construcción para liberar aire: deflector/bafle, difusor, retorno lejos de la aspiración) y pág. 48–49.
- **Partes:** tapón de llenado; drenaje en el fondo, que es inclinado; respiradero con filtro; visor/indicador de nivel y de temperatura; **placa deflectora (chicana)** entre retorno y aspiración; tapas de registro; conexiones de aspiración y retorno con el retorno **sumergido**; intercambiador si hace falta.
- **Símbolo:** rectángulo abierto arriba; en esquemas simples, una línea horizontal en la base o `└┘` en cada descarga ("descarga al depósito", pág. 50).
- **Dato de selección:** **volumen = 2 a 4 veces el caudal de la bomba por minuto** (Parker, pág. 49), más el volumen activo del sistema (cilindros); la diapositiva "Selección de componentes" habla del volumen activo + un % adicional. Parker: chicana a 2/3 del nivel; ~20 % de aire sobre el aceite.
- **Si falta o es chico:** el aceite vuelve a la bomba caliente, con aire y suciedad → espuma, cavitación, desgaste.

### A5.2 Filtros

Ver pág. 15 a 18. Todos se dibujan como un **rombo con una línea de trazos interior** (el elemento filtrante); con un antirretorno en paralelo cuando tienen bypass.

```
        ╱╲
   ────◇──────     filtro: rombo con línea de trazos
        ╲╱
```

| Filtro | Dónde va | Qué hace | Dato de selección (orden de magnitud de las diapositivas) |
|---|---|---|---|
| **Aspiración** | antes de la bomba, dentro del tanque | malla gruesa: protege la bomba de partículas grandes | 90–120 µm, 3×Q (Parker pág. 49). Si es muy fino o se tapa → **cavitación**. Algunos proveedores lo desaconsejan |
| **Presión / impulsión** | después de la bomba | protege los componentes sensibles (válvulas, proporcionales) | 3–5 µm, 3×Q (Parker); cuerpo robusto y caro (tiene que aguantar la presión del sistema); con bypass e indicador de ensuciamiento. Si es por una proporcional, va justo antes de ella |
| **Retorno** | en la línea al tanque | retiene lo que generó el desgaste antes de que llegue al tanque | 15–25 µm, 3×Q, con bypass (Parker). Baja presión → barato; es el más común |
| **Respiradero** | tapa del tanque | filtra el aire que entra cuando baja el nivel; con sílica gel, frena la humedad (cambia de color) | 2×Q (Parker) |
| **Fuera de línea (riñón)** | circuito aparte: bomba auxiliar + filtro (+ enfriador) | mantiene limpieza y temperatura sin parar la máquina | caudal propio |
| **Magnético** | en tapones o en el tanque | retiene partículas ferrosas | — |

- **Datos de selección de cualquier filtro: presión, caudal y micronaje.** Es una frase del profe (apunte SNeH): *"Se seleccionan los filtros en base a la presión, el caudal y el micronaje."*
- El micronaje lo define el **componente más sensible** (tabla de pág. 13): bombas de engranajes, cilindros, direccionales, de seguridad y estranguladoras → **20 µm**; bombas de pistones y paletas, válvulas de presión, proporcionales → **10 µm**; servoválvulas y servocilindros → **5 µm**.
- **Si falta:** desgaste por abrasión y erosión (A7), fugas, pérdida de rendimiento, trabado de correderas.

### A5.3 Bomba

- **Qué hace:** convierte la energía mecánica del eje en **caudal** (A3). Siempre va con el motor; el conjunto se dibuja así (ver pág. 1 y pág. 6):

```
     ▲                 círculo con triángulo lleno apuntando hacia afuera = bomba
   ( ▲ )══[ M ]        de caudal fijo, un sentido de flujo. "══" = eje/acople.
     │                 Con una flecha oblicua cruzando el círculo = cilindrada variable.
   aspira
```

- **Tipos** (ver pág. 20–22 y la tabla del apunte de Martina):

| Tipo | Presión nominal (orden) | Cilindrada | Rasgos |
|---|---|---|---|
| Engranajes externos | 63–210 bar | 1,2–250 cm³ | **compacta, barata**, robusta, ruidosa; caudal fijo. La de todos los catálogos de parcial (AZPB, AZPF) |
| Engranajes internos | 160–250 bar | 4–250 cm³ | muy silenciosa, barata |
| Paletas | 100–160 bar | 5–160 cm³ | fija o variable; vida útil muy alta |
| Pistones axiales (placa o eje inclinado) | 160–250 bar | 25–800 cm³ | **caudal variable** cambiando el ángulo; puede ser bomba o motor; transmisiones hidrostáticas; cara |
| Pistones radiales | 160–320 bar | 5–160 cm³ | altas presiones, caudal variable; cara |
| Tornillo | ≤ 180 bar | — | 3000–5000 rpm, caudal continuo, bajo ruido (pág. 20) |

(Rangos del apunte de Martina, fuente no identificada: orden de magnitud. Nota: ese apunte dice "ruido alto" en paletas; otras fuentes dicen bajo ruido.)

- **Dato de selección:** **caudal** (→ cilindrada con las rpm y $\eta_v$) y **presión** (la de trabajo tiene que ser ≤ la presión continua de catálogo, p. ej. AZPB p1 = 220 bar). Además: rpm dentro de mín./máx. del catálogo, sentido de giro, eje y brida compatibles con el motor.
- **Si falta… es el generador.** Si está mal elegida: corta de caudal → el cilindro no llega al tiempo; sobrada → hay que estrangular y el excedente se va por la limitadora como calor.

### A5.4 Válvula antirretorno (retención, *check*)

- **Qué hace:** deja pasar en un sentido y bloquea el otro (pág. 38). Detrás de la bomba (pág. 6, ítem 3) evita que el aceite vuelva hacia la bomba cuando para y que una carga empuje la bomba al revés.
- **Símbolo:** una bola apoyada en un asiento en "V":

```
   ──○◁──   o con resorte:  ──/\/\○◁──      pasa de izquierda a derecha;
                                             bloquea de derecha a izquierda
```

  Ver pág. 38 (sin precarga, con resorte, **pilotada**).
- **Pilotada:** bloquea como una normal, pero una señal de presión por una línea de pilotaje la **abre** y deja pasar en sentido inverso. Sirve para **retener una carga vertical sin fugas** y soltarla solo cuando se manda bajar (§3.3).
- **Dato de selección:** caudal y presión (y presión de apertura del resorte).
- **Si falta:** la carga puede hacer girar la bomba al revés al detenerse; con el motor parado la línea se descarga.

### A5.5 Válvula limitadora de presión (de seguridad, de alivio)

- **Qué hace:** ver A3. Un cono o bola apretado contra su asiento por un resorte; el resorte se pretensa con un tornillo. Cuando $p\cdot A_{asiento}$ supera la fuerza del resorte, el cono se levanta y el aceite pasa de P a T. Cortes: pág. 33 (DBDH, asiento cónico 25–400 bar, o bola hasta 630 bar), pág. 35 y pág. 37.
- **Símbolo** (ver pág. 35 y 37): un cuadrado con una flecha que pasa de la entrada a la salida a tanque, normalmente **cerrada** (flecha desplazada). De un lado, el resorte con flecha oblicua (regulable); del otro, la línea de pilotaje de trazos que toma la presión de entrada:

```
          P
          │
     ┌ ─ ─┤          ┌ ─ ─ ┐  línea de pilotaje (trazos): lee la presión de P
     ┊  ┌─┴──┐       
     └ ►│ ↓  │/\/\/↗   resorte regulable
        └─┬──┘
          │
         └┴┘  T (tanque)
```

  En la versión **pilotada** (precomandada) la de trazos va a una válvula piloto chica; la del esquema básico de Makro p. 6 y de 2020 ítem 13 se dibuja con pilotaje.
- **Dato de selección:** **rango de presión** que incluya el valor de ajuste y **caudal ≥ caudal máximo de la bomba**, porque en el peor caso pasa todo el caudal por ella.
- **Si falta:** sobrepresión al llegar a tope → rotura (A3).
- Ajuste: §4.

### A5.6 Manómetro

- **Qué hace:** muestra la presión. Con glicerina para amortiguar las pulsaciones de la bomba; se conecta a un punto de medición (minimess / Stauff Test 20, pág. 32).
- **Símbolo:** círculo con una aguja oblicua `(↗)`.
- **Dato de selección:** **escala** mayor que la presión de ajuste (que "el manómetro lo pueda ver", Makro). ⚠️ práctica habitual: fondo de escala ≈ 1,5–2 × la presión que se va a leer.
- **No regula nada** (2020 ítem 3: regula la limitadora y visualiza el manómetro).

### A5.7 Presostato

- **Qué hace:** convierte presión en **señal eléctrica**: un contacto que conmuta cuando la presión cruza un valor ajustado (con algo de histéresis). Sirve para automatismos: "cuando la presión llega a X, hacer Y" o "cuando cae por debajo de X…".
- **Símbolo:** un rectángulo con la conexión de presión y un contacto eléctrico (pág. 48 ítem 15; Martina lo dibujó así en su esquema del TP3, agregado en rojo por el profe).
- **Dato de selección:** **rango de ajuste** que contenga el punto de conmutación, **presión máxima** ≥ presión del sistema, tipo de contacto (NA/NC) y tensión.
- **Dónde se pone** (lo que le marcaron a Ribeiro): en la línea donde la presión **cambia** con el evento que se quiere detectar (§5.2).

### A5.8 Válvula direccional (distribuidora)

- **Qué hace:** decide **a qué conexión del cilindro va el aceite** y cuál vuelve a tanque → define el **sentido** del movimiento o la parada. Por dentro es una **corredera** (*spool*): un eje con resaltos que se desliza dentro de un cuerpo y tapa o destapa los conductos (ver el corte de pág. 31 y la 4WE 6 de pág. 25).
- **Designación vías/posiciones** (pág. 26 y 28): "4/3" = **4 vías** (conexiones: P, T, A, B) / **3 posiciones** (3 cuadrados).
- **Letras** (pág. 28): **P (1)** presión; **T, R (3)** tanque/retorno; **A, B (2, 4)** trabajo; **X, Y** pilotaje; **L** drenaje.
- **Cómo se lee el símbolo:** cada cuadrado es una posición; adentro, las flechas son los caminos abiertos y las "T" (⊥) los bloqueos. Las conexiones se dibujan sobre la posición de reposo. Para ver qué pasa al accionar un lado, se "corre" mentalmente la válvula: el cuadrado del lado accionado pasa a ocupar el lugar del de reposo.

```
        A   B                       a: P→A, B→T  (flechas paralelas)
   ┌────┬────┬────┐                 0: centro (según el tipo, ver A6)
 y1│ ↑↓ │ ⊥⊥ │ ╳  │y2               b: P→B, A→T  (flechas cruzadas)
 ╱ │ a  │ 0  │ b  │ ╲  + resortes a ambos lados: centrada por resortes
   └────┴────┴────┘
        P   T
```

- **Accionamientos** (pág. 27 y 29): **manual** (mando muscular, pulsador, **palanca**, pedal); **mecánico** (palpador, resorte, rodillo, rodillo escamoteable); **eléctrico** (**solenoide/electroimán**: simple 1b, doble 2b, proporcional); **hidráulico o neumático** (pilotaje directo, diferencial); **combinado** (solenoide + piloto hidráulico = electrohidráulico, para válvulas grandes). Diferencia con neumática: **en hidráulica el accionamiento se dibuja a la derecha** (pág. 27). En la práctica los esquemas de la cátedra lo ponen de los dos lados para las 4/3.
- **Posición normal:** con retorno por muelle, es la casilla dibujada junto al muelle; en las 4/3 centradas por resortes, la del medio.
- **Dato de selección:** **caudal máximo** (el de bomba, o el de retorno si es mayor) y **presión máxima** → tamaño nominal (NG). Ejemplo de las diapositivas: 4WE 6 (NG6) admite 350 bar y 60 (AC) / 80 (DC) l/min; 4WE 10 (NG10), 315 bar y 120 l/min. Más: tipo de centro, accionamiento, tensión de bobina, montaje sobre placa ISO 4401 (NG6 = CETOP 03).
- **Si falta:** no hay manera de invertir el movimiento ni de detenerlo.

### A5.9 Reguladora de caudal (estranguladora)

- **Qué hace:** regula la **velocidad** del cilindro poniendo una restricción al paso del aceite (pág. 24, 35, 36).
- **Física:** en un orificio, $Q\propto A_{orificio}\sqrt{\Delta p}$. Si se achica el orificio, pasa menos caudal para el mismo Δp. Pero en un circuito con bomba fija el caudal "sobrante" tiene que ir a algún lado: **sube la presión antes de la reguladora hasta que abre la limitadora**, y el excedente vuelve a tanque por la limitadora, **convertido en calor** (desventaja que conviene comentar en el examen).
- **Tipos** (pág. 36–37):

| Tipo | Símbolo | Comportamiento |
|---|---|---|
| Fija (diafragma/orificio) | `─)(─` dos arcos enfrentados | sección constante; Δp = p_e1 − p_e2 |
| Variable (estrangulador ajustable) | `─)(─` con flecha oblicua | regulable a mano; **el caudal depende de la carga** (si cambia Δp, cambia Q) |
| Compensada por presión | igual con una flecha vertical adicional | una balanza interna mantiene **Δp constante** en el orificio → Q constante **aunque cambie la carga** (ver el corte 2FRM de pág. 34) |
| Con antirretorno (unidireccional) | estrangulador + antirretorno en paralelo, encuadrados | regula en un sentido, libre en el otro (pág. 37) |
| Bidireccional | sin antirretorno | regula en los dos sentidos |

- **Dato de selección:** **caudal** (rango de regulación que incluya el caudal deseado) y **presión** máxima.
- Aplicaciones (pág. 35): reducir velocidad, accionamientos retardados, temporizaciones, impulsos.
- **Así se regula el tiempo de un actuador** (TP3 1.6): con la reguladora de caudal (y, en el diseño, eligiendo la cilindrada de bomba).

### A5.10 Cilindro

Ver A4. **Dato de selección:** fuerza y presión → **diámetro de pistón**; pandeo y fuerza de retracción → **vástago**; **carrera** (≤ carrera máxima de catálogo, p. ej. CD70 Ø32 → 800 mm); amortiguación; fijación (define el caso de Euler); sellos según velocidad y temperatura (pág. 46). Símbolos en pág. 41.

### A5.11 Tuberías

- **Qué hacen:** unen los componentes. Rígidas de acero (con racores de anillo cortante, niples para soldar) o flexibles (mangueras).
- **Símbolos** (pág. 50): línea llena = alimentación y retorno; trazos = pilotaje/gobierno; trazos finos = drenaje o escape; arco = flexible; punto = unión; cruce sin punto = no conectadas; trazo y punto = varios elementos en un bloque.
- **Por qué importa el diámetro:** la pérdida de carga crece con la velocidad. La de fricción depende de **longitud, sección, rugosidad, cantidad de accesorios, velocidad/caudal y viscosidad** (pág. 51):

$$h_f=\lambda\,\frac{L}{D}\,\frac{v^2}{2g}$$

- **Dato de selección:** **velocidad recomendada** (pág. 52) → diámetro interior; **presión nominal (PN) ≥ presión del sistema**.

| Línea | Velocidad recomendada |
|---|---|
| Succión | 0,5–0,8 m/s (con acceso: hasta 1,5) |
| Retorno | 2–4 m/s |
| Presión hasta 100 bar | 2–4 m/s |
| Presión hasta 315 bar | 3–12 m/s |

(Rexroth, aceite 22–68 cSt a 30–60 °C.) La succión va **lenta** para no bajar la presión a la entrada de la bomba: la AZPB admite 0,7–3 bar **absolutos** en la aspiración; por debajo hay cavitación.

### A5.12 Acumulador

- **Qué hace:** almacena aceite a presión comprimiendo un gas (nitrógeno) separado por una vejiga, una membrana o un pistón (pág. 53–54). Sirve para estabilizar la presión, amortiguar pulsaciones, dar caudal de punta o de emergencia.
- **Símbolo:** óvalo vertical con una línea horizontal interior (separador gas/aceite); ver pág. 54 arriba.
- **Estados** (pág. 53): $p_0,V_0$ precarga de N₂ (vacío de aceite) → $p_1,V_1$ presión mínima de trabajo → $p_2,V_2$ máxima. El aceite útil es $\Delta V=V_1-V_2$.
- **Seguridad** (pág. 54): bloque con llave de corte, descarga a tanque, limitadora y manómetro. Precarga solo con **nitrógeno**.
- **Nunca apareció en un parcial.** Resumen en el anexo.

---

## A6. Cómo leer un esquema hidráulico

### A6.1 Recorrido del esquema básico de Makro p. 6

Elementos, de abajo hacia arriba:

- motor eléctrico M + bomba de caudal fijo, que aspira del tanque;
- antirretorno con resorte;
- nudo de la línea de presión: de ahí sale la **limitadora pilotada** a tanque (en derivación), con **manómetro**, y la línea a P de la direccional;
- direccional **4/3 por solenoides y1/y2, centrada por resortes**;
- A → lado pistón del cilindro de doble efecto; B → lado vástago;
- T de la direccional → **filtro de retorno** → tanque.

```
          ┌───────────────────────────┬────────────────┐
          │      lado pistón (A1)     │▓ lado vástago  │══════ vástago
          └──┬────────────────────────┴─────────────┬──┘
             │ conexión A                           │ conexión B
             └──────────────┐          ┌────────────┘
                          A │          │ B
                      ┌─────┴──┬───────┴┬────────┐
               y1 /\/ │   a    │   0    │   b    │ /\/ y2   (centrada por resortes)
                      └─────┬──┴───────┬┴────────┘
                          P │          │ T
       manómetro (↗)────────┤          │
                            │          ◇  filtro de retorno
         ┌──────────────────┤          │
         │                  ○  antirretorno con resorte
    [limitadora]            │          │
     (pilotada)          ( ▲ )══[M]    │   bomba + motor
         │                  │          │
    ═════╧══════════════════╧══════════╧═════  TANQUE
```

**Posición 0 (centro, ningún solenoide energizado).** Depende del centro elegido (las 5 opciones de Makro p. 6, tabla de A6.2). Con **centro tándem/recirculación** (opción 5): **P→T** directo, el aceite de la bomba vuelve a tanque por el filtro de retorno a casi 0 bar (bomba en vacío, el manómetro marca ≈ 0); **A y B bloqueadas**: el cilindro queda **detenido y retenido** donde estaba (salvo fugas internas de la corredera).

**Posición a (y1 energizado): extender.** La casilla "a" (flechas paralelas) toma el lugar del centro:

- P→A: bomba → antirretorno → P → A → **lado pistón**. El pistón avanza; la presión sube a $F/A_1$ + pérdidas (el manómetro lo muestra).
- B→T: el aceite del **lado vástago** sale por B → T → filtro de retorno → tanque.
- Si el cilindro llega a tope, la presión sube hasta el ajuste y la limitadora descarga **todo** el caudal a tanque (A3).

**Posición b (y2 energizado): retraer.** La casilla "b" (flechas cruzadas) toma el lugar del centro:

- P→B: bomba → **lado vástago**: el pistón retrocede (más rápido, A4).
- A→T: el aceite del **lado pistón** vuelve a tanque. Ojo: son φ veces el caudal de bomba (A4).

### A6.2 Los centros de la 4/3: qué pasa con la bomba y con la carga

Cortes en pág. 31; símbolos con solenoides en pág. 30; las 5 variantes de Makro p. 6.

| Centro | Conexiones en reposo | La **bomba** en reposo | La **carga** en reposo | Cuándo usarlo |
|---|---|---|---|---|
| **Tándem / recirculación en posición central** (Makro opción 5; pág. 31 "tandem") | **P→T**; A y B bloqueadas | descarga a tanque a ~0 bar → **arranque en vacío**, poco calor | **retenida** (con fugas de la corredera) | el caso típico de parcial: gato, elevador, prensa con una bomba fija. **Recomendado por defecto** |
| **Cerrado** (Makro opción 4; pág. 31 "todas bloqueadas") | P, T, A, B bloqueadas | contra la limitadora: **todo el caudal a p_ajuste** → calor, motor cargado, no arranca en vacío | retenida | con acumulador o bomba variable; con varios actuadores en paralelo desde una bomba |
| **Abierto / recirculación con central flotante** (Makro opción 1; pág. 31 "centro aberto") | P, T, A, B todas unidas | en vacío | **libre (flotante)**: una carga vertical **baja sola** | cuando el actuador debe quedar libre (motor hidráulico que gira por inercia, posicionado a mano). **No** para cargas verticales |
| **Flotante estrangulada** (Makro opción 2) | como la anterior, con estrangulamiento en el centro | en vacío | libre, pero frenada | transición suave ⚠️ interpretación del símbolo; verificar con la hoja |
| **Interconectada** (Makro opción 3) | ⚠️ según el símbolo: P unida a A y B (T bloqueado). La lectura alternativa es A y B unidas entre sí | — | — | ⚠️ verificar el símbolo con la cátedra antes de usarlo |
| **P bloqueado, A y B a tanque** (pág. 31 abajo derecha) | P bloqueada; A→T, B→T | contra la limitadora | libre | descomprimir las cámaras; pilotar un antirretorno pilotado |

> **Frase de examen:** "Adopto una 4/3 de centro tándem (P→T, A y B bloqueadas): en reposo la bomba recircula a tanque sin presión, con lo que el motor arranca en vacío y no se calienta el aceite, y el cilindro queda bloqueado reteniendo la carga."

**Cómo aparece en el parcial.** Makro ítem 4 (elegir de las 5 opciones "según operación y seguridad"); 2020 ítem 13 y TP3 ítem 3 (listar los componentes del circuito básico, que tiene centro tándem y accionamiento manual por palanca); 2025 ítem 3 (Ribeiro: "P y T unidos en el centro").

---

## A7. Fluido y contaminación (nivel examen)

**Funciones del aceite** (pág. 7 y apuntes):

1. **Transmitir energía/potencia**: es la función principal; posible porque es casi incompresible.
2. **Lubricar** las piezas en movimiento.
3. **Refrigerar**: lleva el calor al tanque.
4. **Sellar**: con la viscosidad adecuada llena las holguras.
5. Proteger contra la corrosión.
6. Amortiguar vibraciones.

→ 2020 ítem 5: la correcta es **(3) lubricar, refrigerar y transmitir potencia**. "Filtrar" y "contener impurezas" **no** son funciones del aceite: las impurezas son el problema.

**Viscosidad.** Resistencia del fluido a fluir. Baja con la temperatura (ver la gráfica ISO VG de pág. 8):

- demasiado **fría** → muy viscosa → cuesta aspirar (cavitación) y hay muchas pérdidas;
- demasiado **caliente** → muy fluida → no sella ni lubrica y suben las fugas internas.

Hay una zona ideal de trabajo. Clasificación **ISO VG** (la viscosidad en cSt a 40 °C: VG 32, 46, 68…) y DIN 51524. **Índice de viscosidad (IV)**: cuanto mayor, menos varía la viscosidad con la temperatura (líneas más planas en pág. 8). Otras propiedades: punto de inflamación, punto de anilina (ataque a sellos y mangueras), demulsibilidad (separar el agua), antiespumante, antioxidante. Tipos: casi siempre **aceite mineral con aditivos**; sintéticos para casos especiales; poco usados: agua, aceite soluble, aceite vegetal. Régimen de lubricación: total, parcial o límite. Flujo: laminar con Re < 2000, transición 2000–4000, turbulento > 4000.

**Contaminación: tipos** (pág. 10):

- **Sólida**: escoria, óxido, fibras, metal, pintura.
- **Gaseosa**: burbujas de aire.
- **Líquida**: agua (condensación, intercambiador roto) u otro aceite.

**Orígenes** (pág. 9): limpieza en el montaje, tanque no hermético, filtro de aire, **aceite nuevo** (viene sucio: se filtra al llenar), desgaste de componentes, tuberías y mangueras, sellos, reparaciones.

**Desgaste** (pág. 11–12):

- **Abrasión**: partículas atrapadas entre dos superficies en movimiento → cambian las tolerancias, aumentan las fugas, cae la eficiencia y las partículas generan más partículas. En cilindros: fugas, desgaste de sellos y guías, pérdida de velocidad y de capacidad de retención.
- **Erosión**: partículas arrastradas a alta velocidad que golpean cantos y bordes (correderas, dientes de engranaje).

**Por qué la contaminación se realimenta** (pág. 14): la fuga por una holgura radial crece con **el cubo** de la holgura ($q\propto r^3$) y es inversamente proporcional a la viscosidad. Más desgaste → más holgura → más fuga → la bomba trabaja más → sube la temperatura → baja la viscosidad → más fuga.

**Medición:** contadores de partículas → código **ISO 4406** de 3 números (partículas > 4, > 6 y > 14 µm por ml), p. ej. 18/15/12 (pág. 13).

**Aire en el aceite:** tanque con deflector y difusor, retorno sumergido y lejos de la aspiración, aditivos antiespumantes (pág. 19). Con burbujas aparece el **efecto Diesel**: la burbuja se comprime, se calienta y quema el sello.

**Cómo aparece en el parcial.** Solo en preguntas teóricas: 2020 ítems 2, 4, 5 y 8; TP3 1.3, 1.4, 1.5 y 2. Respuestas modelo en §6.


---

# PARTE B — RESOLUCIÓN DEL PARCIAL

## §0. Mapa del parcial

### Qué tomaron y con qué peso

| Parcial | Ítem | Peso | Qué piden |
|---|---|---|---|
| **2025 Gato para fosa** (el más reciente, con corrección) | 1 | 30 % | cilindro + bomba con hojas adjuntas, pérdidas $\sum kQ^2$, $\eta_v$ = 0,92 |
| | 2 | 25 % | protección contra sobrecarga: **qué elemento, valor de ajuste y procedimiento** "según catálogo" (DBD) |
| | 3 | 25 % | componentes entre bomba y cilindro: **esquema + función + selección por P y Q** |
| | 4 | 20 % | automatismo eléctrico: parar al 80 %, retener, **retornar solo al retirar la carga** (presostato) |
| **Makro / autoelevadores** (en grupo de 2) | 1–5 | 60 % | definir carga, presión, cilindro, bomba, esquema con 4/3 a elegir entre 5, **llegada lenta a los extremos**, resumen de datos |
| | 6 | 25 % | lista de elementos con función + **valor de ajuste de la limitadora** |
| | 7 | 15 % | **diámetro de tuberías** por velocidad recomendada |
| **2020** | 1–13 | 40 % | opción múltiple / ampliar: teoría corta |
| | 14 | 20 % | qué se selecciona primero (→ el cilindro) |
| | 15 | 40 % | cilindro (150 kg/cm²) + bomba AZPF (retorno por peso propio) + protección + valor de ajuste |
| **TP3 2025** (práctica, no parcial) | 1–5 | — | teoría, tratamiento del aceite, circuito básico con dato de selección, sellos, armar esquema |
| | 6 | — | cilindro CD70 a 70 kg/cm² (fuerza en los dos sentidos), bomba AZPB, verificación del caudal, elementos de regulación, **circuito eléctrico de parada a mitad de carrera** |

### Qué se repite (y por eso va primero en esta guía)

| Tema | 2025 | Makro | 2020 | TP3 | Dónde está |
|---|:-:|:-:|:-:|:-:|---|
| Cilindro de la tabla por $F/p$ | ✔ | ✔ | ✔ | ✔ | §1 pasos 1–4, §2.1–2.2 |
| Bomba: cilindrada → código de catálogo | ✔ | ✔ | ✔ | ✔ | §1 pasos 5–7, §2.3–2.4 |
| Limitadora: elemento y **valor de ajuste** | ✔ | ✔ | ✔ | ✔ | A3, §4 |
| Componentes intermedios con función y dato de selección | ✔ | ✔ | ✔ (13) | ✔ | A5, §3 |
| Llegada lenta / amortiguación | — | ✔ | ✔ (10) | ✔ (4, rojo del profe) | A4, §3.5 |
| Automatismo eléctrico | ✔ | — | — | ✔ | §5 |
| Teoría corta | — | — | ✔ | ✔ | §6 |
| Tuberías | — | ✔ | — | — | §1 paso 12, §2.5 |
| Pérdidas de carga con $k$ | ✔ | — | — | — | §1 paso 8 |

> **Los 5 criterios que más puntos costaron** (detalle en §10)
> 1. **Cada componente: nombre + función + con qué P y Q se selecciona** (2025 ítem 3: 15/25 por omitirlo).
> 2. **Ajuste de la limitadora por encima del trabajo, ≈ presión máxima dada**, y justificado (2025 ítem 2: 13/25 por poner 125 en lugar de 130).
> 3. **El presostato con ubicación y valor justificados** (2025 ítem 4: "¿cuál es el valor de ajuste del presostato?").
> 4. **El diseño arranca por el cilindro**, no por la bomba (2020 ítem 14).
> 5. **La bomba da caudal, no presión** (2020 ítems 1 y 9; error de Martina).

---

## §1. Procedimiento maestro del caso práctico

Orden de la cátedra (diapositiva "Selección de componentes", Anzola, en el apunte de Martina p. 11):

1. fluido;
2. presión de trabajo;
3. **cilindro** (con presión y fuerza → diámetro; con velocidad → caudal);
4. **bomba** y motor;
5. tanque;
6. filtros;
7. direccionales;
8. válvulas de control;
9. tuberías.

Los pasos de abajo siguen ese orden. Cada uno trae la **frase lista para escribir**.

### Paso 0 — Tabla de datos y supuestos

Antes de calcular, escribí una tabla con: $F$ (y en qué sentido actúa), $p$ disponible, carrera $L$, tiempo $t$ o velocidad $v$, rpm (o tensión y frecuencia del motor), $\eta_v$, coeficientes $k$, orientación del cilindro, cómo retorna (bomba o peso propio).

Si falta un dato, **adoptalo y decilo**:

> "Adopto … porque …"

Es lo que se evalúa en Makro ("definir la carga máxima por ciclo", "adoptar la presión").

### Paso 1 — Carga y área que trabaja (ver A4)

- ¿La carga se opone a la extensión? → $A_1$.
- ¿A la retracción? → $A_3$.
- ¿Retorna por peso propio? → solo $A_1$.
- Si hay fuerza en los dos sentidos, se verifican las dos.

> "La carga actúa verticalmente hacia abajo y se eleva extendiendo el vástago, por lo que la presión se determina con el área del lado pistón $A_1$. La retracción se produce por peso propio, por lo que el lado vástago no requiere verificación de fuerza."

### Paso 2 — Presión → área → pistón de tabla

$$A_{1,nec}=\frac{F}{p_{disp}}\qquad D_{mín}=\sqrt{\frac{4A_{1,nec}}{\pi}}$$

Se toma de la tabla el **pistón inmediatamente mayor** y se recalcula la presión real:

$$p_{trabajo}=\frac{F}{A_{1,tabla}}\;<\;p_{disp}\ ✓$$

> "Con $F$ = 1500 kg y $p$ = 130 kg/cm²: $A_{nec}=11{,}54$ cm² ($D\ge38{,}3$ mm). Se selecciona de la tabla adjunta el pistón Ø40 ($A_1=12{,}56$ cm²), inmediato superior. La presión de trabajo resulta $p=1500/12{,}56=119{,}4$ kg/cm² < 130 ✓."

Dos alertas:

- Si la presión real queda **muy pegada** a la disponible (p. ej. 124 de 150, o 99,5 de 100), comentá el margen: hay que sumar pérdidas y fricción del cilindro ⚠️, y la limitadora tiene que quedar por encima. Si no hay margen, subí un diámetro (§8, variante 3).
- Si la tabla da fuerzas a 160 bar, **no** se compara contra $F_1$ directamente: ver §2.1.

### Paso 3 — Si hay fuerza en retracción: verificar el lado vástago

$$p_{ret}=\frac{F_{ret}}{A_3}\;<\;p_{disp}$$

Con dos vástagos posibles, el más grueso tiene menos $A_3$ → más presión de retracción. Comparar con lo que exige el paso 4.

### Paso 4 — Pandeo → elegir el vástago

1. Elegí el **caso de Euler** según cómo está montado y si la carga está guiada (tabla de A4, pág. 40). Decilo explícitamente.
2. Longitud $l$: ⚠️ simplificación usada en esta guía: $l$ ≈ carrera (el tramo de vástago fuera del cilindro). La longitud libre real (desde la fijación hasta la carga, con el cilindro extendido) es mayor y hace el caso más crítico; verificar con la cátedra qué longitud toma.
3. $S_k$ según el caso; $J=0{,}0491\,d^4$ con $d$ en cm.
4. $F_{adm}=\dfrac{10\cdot2{,}1\cdot10^6\cdot J}{3\cdot S_k^2}\ \ge F$.

> "Verificación al pandeo (Euler, S = 3). El gato trabaja vertical con el extremo superior libre (caso 1, $S_k=2l$). Con $l$ ≈ 50 cm: vástago Ø18 → $J$ = 0,515 cm⁴ → $F_{adm}$ = 361 kgf < 1500 ✗; vástago Ø28 → $J$ = 3,018 cm⁴ → $F_{adm}$ = 2113 kgf > 1500 ✓. Se adopta el cilindro **40/28**."

Si ningún vástago de ese pistón alcanza, se sube el pistón o se cambia la fijación/guiado (otro caso de Euler) y se dice.

### Paso 5 — Velocidad/tiempo → caudal

$$v=\frac{L}{t}\qquad Q=A_1\cdot v\ [\text{cm}^3/\text{s}]\qquad Q\,[\text{l/min}]=Q\,[\text{cm}^3/\text{s}]\cdot0{,}06$$

- **Atajo de la tabla de cilindros:** la columna $q_{V1}$ es el caudal a 0,1 m/s → $Q=q_{V1}\cdot v/(0{,}1\ \text{m/s})$. Para 40 a 3,33 cm/s: $7{,}5\cdot0{,}333=2{,}5$ l/min ✓ (sirve para chequear).
- Si el tiempo es **máximo** ("en un tiempo máximo de 60 s"), cualquier bomba que lo haga **más rápido** cumple (TP3; el error de Juano fue cambiar el dato).

### Paso 6 — Cilindrada, rpm, $\eta_v$ → bomba de catálogo

**Las rpm.** Si el enunciado las da, se usan esas. Si solo da "3×380 V, 50 Hz", **adoptá y decilo** (⚠️ verificar con la cátedra):

| Polos | Sincrónica a 50 Hz | Real típica (con resbalamiento) |
|---|---|---|
| 2 | 3000 rpm | ≈ 2850–2950 rpm |
| 4 | 1500 rpm | ≈ 1420–1480 rpm |
| 6 | 1000 rpm | ≈ 940–970 rpm |

$n_s=60\,f/(\text{pares de polos})$. Lo que hace que el motor gire menos que la sincrónica es el **resbalamiento** del motor asincrónico, no un "rendimiento del motor" (concepto que usó Ribeiro, sin penalización).

> "Adopto un motor trifásico de 4 polos, 1450 rpm reales (sincrónica 1500 a 50 Hz menos el resbalamiento)."

**Cilindrada:**

$$V_{g,nec}=\frac{Q\,[\text{cm}^3/\text{min}]}{n\cdot\eta_v}\;\rightarrow\;V_g\text{ de catálogo inmediato superior}\;\rightarrow\;Q_{real}=V_g\,n\,\eta_v$$

**Verificaciones contra el catálogo** (AZPB, §2.3):

- $p_{trabajo}$ (y la de ajuste) ≤ **p1 máx. continua** (220 bar; 200 bar para 7,1);
- $n$ ≥ 750 rpm (mín.) y $n$ ≤ máx. a p2 del tamaño elegido;
- tiempo real $t=A_1L/Q_{real}$ ≤ el pedido.

> "$V_g=2512/(1450\cdot0{,}92)=1{,}88$ cm³/rev → AZPB tamaño **2,0** cm³/rev. $Q_{real}=2{,}0\cdot1450\cdot0{,}92=2{,}67$ l/min → subida en 14,1 s < 15 s ✓. Presión de trabajo 120 < 220 bar (p1) ✓; 1450 rpm entre 750 y 5000 ✓."

**Rpm mayores → bomba más chica**, con el mismo caudal. Con 2900 rpm el mismo caso da AZPB 1,0 (Ribeiro). Las dos son válidas si se justifica la rpm.

### Paso 7 — Designación (ordering code)

Con el código transcripto (§2.3) se puede armar la designación **solo con las opciones que figuran**:

> "AZPB-xx-**2.0 R** C P 02 M B: tamaño 2,0 cm³/rev, giro horario, eje cónico 1:5 con brida de 2 bulones Ø32, conexiones roscadas métricas, sellos NBR, tapa trasera estándar."

El catálogo aclara que no todas las combinaciones son seleccionables por código: se confirman con las tablas de tipos estándar o con el fabricante. Si no te piden el código completo, alcanza con "AZPB tamaño 2,0, giro R". **No** inventes letras que no estén en la hoja.

### Paso 8 — Pérdidas de carga con $\Delta p=\sum k\,Q^2$

$$\Delta p\,[\text{kg/cm}^2]=\Big(\sum k_i\Big)\,Q^2\qquad Q\text{ en l/min (con el caudal real de la bomba)}$$

**Qué $k$ sumar:** los componentes que atraviesa el aceite en el camino. Ribeiro sumó filtro + 1 antirretorno + direccional y sacó el puntaje completo. Si en el esquema hay una reguladora con antirretorno o un antirretorno pilotado en el camino, agregá un antirretorno más ⚠️ criterio.

$$p_{bomba}=p_{trabajo}+\Delta p\;\le\;p_{máx}\ ✓$$

> "Con $Q$ = 2,67 l/min: $\Delta p=(0{,}0111+0{,}0153+0{,}0236)\cdot2{,}67^2=0{,}36$ kg/cm² (con dos antirretornos, 0,46). Resulta despreciable: $p_{bomba}=119{,}4+0{,}4\approx120$ kg/cm² < 130 ✓."

Ojo con el caudal: con 2,67 l/min (AZPB 2,0 a 1450 o 1,0 a 2900) da **0,356**; con 2,705 l/min (1,0 a 2940, Ribeiro) da **0,366**. Las dos redondean a 0,36. El valor 0,34 del dossier no sale con ninguno de esos caudales: pediría $Q$ ≈ 2,61 l/min.

### Paso 9 — Potencia del motor

**Con la presión de ajuste**, no con la de trabajo: en el peor caso (cilindro a tope) **todo** el caudal pasa por la limitadora a $p_{ajuste}$.

$$P_{hidr}=\frac{p_{ajuste}\,[\text{bar}]\cdot Q\,[\text{l/min}]}{600}\qquad P_{motor}=\frac{P_{hidr}}{\eta_{t}}$$

$\eta_t$ ≈ 0,85 ⚠️ asumido (la tabla de bombas da 0,8–0,91 para engranajes). Se adopta el escalón comercial superior ⚠️ (serie habitual de motores: 0,37 · 0,55 · 0,75 · 1,1 · 1,5 · 2,2 · 3 · 4 · 5,5 · 7,5 kW).

> "$P=130\cdot2{,}67/600=0{,}58$ kW; con $\eta_t$ ≈ 0,85, 0,68 kW → motor de **0,75 kW (1 CV)**, 4 polos, 3×380 V 50 Hz."

### Paso 10 — Ajuste de la limitadora → §4

> "La protección contra sobrecarga es la **válvula limitadora de presión** (de seguridad), instalada en derivación inmediatamente después de la bomba y descargando a tanque. Se ajusta a ≈ 130 kg/cm², la presión máxima de bomba del enunciado, por encima de la de trabajo (≈ 120) y por debajo de la máxima continua de la bomba (220 bar)."

### Paso 11 — Componentes intermedios → §3 (tabla con P y Q de cada uno)

### Paso 12 — Tuberías

1. Elegí la velocidad recomendada según la línea y la presión (A5.11; Makro p. 7; pág. 52).
2. $d_{int,mín}=\sqrt{\dfrac{4Q}{\pi v}}$ con $Q$ en m³/s ($Q$[l/min]/60000) → resultado en m.
3. Elegí el tubo con **$d_7$ (diámetro interior) ≥ $d_{mín}$** y **PN ≥ presión de ajuste**.
4. Recalculá la velocidad real y verificá que caiga dentro del rango.

> "Línea de presión (130 kg/cm², rango 3–12 m/s): $Q$ = 2,67 l/min = 4,45·10⁻⁵ m³/s. Con un tubo 8×2 ($d_7$ = 4 mm, PN 500): $v$ = 3,5 m/s ✓ dentro del rango, PN 500 > 130 ✓."

Para la línea de **retorno** usá el caudal que sale del lado pistón al retraer ($Q\cdot\varphi$, A4). Para la **succión**, 0,5–0,8 m/s.

### Paso 13 — Retorno: tiempo y caudal

- Doble efecto con bomba: $t_{ret}=A_3L/Q_{real}$ (más rápido que la ida); $Q_{salida\,lado\,pistón}=Q_{real}\cdot A_1/A_3$.
- Por peso propio: la bomba no interviene; la velocidad de bajada la fija la **reguladora de caudal en la línea A** (A4, carga que arrastra).
- Si te dan un tiempo de bajada y la bomba lo hace más rápido: reguladora de caudal.

### Paso 14 — Resumen de datos (formato de Makro ítem 5)

| Dato | Valor |
|---|---|
| Carga estimada | … kg (y por qué) |
| Presión adoptada para la bomba | … kg/cm² |
| Cilindro | pistón × vástago / carrera … mm (caso de Euler adoptado) |
| Velocidad / tiempo | … m/min / … s |
| Bomba / motor | AZPB …; … rpm; … kW |
| Ajuste limitadora | … kg/cm² |
| Llegada lenta a los extremos | amortiguación regulable + reguladora de caudal en … |
| Tuberías | presión …, retorno …, succión … |

---

## §2. Cómo leer los catálogos que adjuntan

### §2.1 Tabla de cilindros "Fuerza para 160 bar / Caudal para 0,1 m/s" (2025 hoja A, Makro p. 4, 2020 p. 3)

**Columnas:**

- pistón Ø (AL) y vástago Ø (MM). Hay **dos filas de vástago por pistón**: elegís pistón y vástago;
- $\varphi=A_1/A_3$;
- **$A_1$ = pistón, $A_2$ = vástago, $A_3$ = anular** (cm²);
- $F_1$ = presión (extensión, sobre $A_1$), $F_2$ = diferencial (sobre $A_2$, conexión regenerativa), $F_3$ = tracción (retracción, sobre $A_3$), **en kN y a 160 bar**;
- $q_{V1}$ = salida (lado pistón), $q_{V2}$ = diferencial, $q_{V3}$ = entrada (lado vástago), en **l/min para 0,1 m/s**.

**Los dibujos debajo de la tabla:** $F_1$ empuja hacia afuera con $A_1$ y $q_{V1}$; $F_3$ tira hacia adentro con $A_3$ y $q_{V3}$; $F_2$ es la conexión diferencial con $A_2$.

**Errores típicos:**

| Error | Cómo evitarlo |
|---|---|
| Comparar la carga con $F_1$ sin cambiar la presión | Las fuerzas son **a 160 bar**. Para otra presión: $F=F_{160}\cdot p/160$, o mejor $F=p\cdot A$ con el área de la tabla |
| Confundir $A_1$ con $A_3$ (Avanzini rotuló $A_1$ al anular) | $A_1$ = círculo entero (el número **mayor**, una sola por pistón); $A_3$ = corona (depende del vástago) |
| Mezclar kN y kg | 1 kN ≈ 102 kgf. Con la tabla: 160 bar × 12,56 cm² = 20,1 kN = 2050 kgf. Con kg/cm² ≈ bar da 2010 kg: la diferencia de 2 % es la de bar vs kg/cm², despreciable para la cátedra |
| Usar $q_V$ como caudal de diseño | Está a **0,1 m/s**; escalarlo: $Q=q_V\cdot v/0{,}1$ |
| Elegir el vástago "a ojo" | Fino (φ ≈ 1,25) → mejor retracción, peor pandeo; grueso (φ ≈ 2) → mejor pandeo, retracción más rápida y con menos fuerza (§1 paso 4) |

### §2.2 Rexroth CD70 / CG70 "Diámetro, fuerzas y superficies" (TP3 p. 3)

- Ya da las **fuerzas en kN para 40, 50, 70 y 105 bar**, lado pistón (una por pistón) y lado vástago (una por vástago).
- Leé directamente la fila de la presión del sistema y convertí kN → kgf (× 102).
- También trae la superficie de pistón, la anular, φ, las superficies de amortiguación y la **carrera máxima** (25 → 600 mm; 32 → 800; 40 → 1000; 50 → 1200).

*Ejemplo TP3* (70 bar): Ø32 lado pistón 5,63 kN = **574 kgf** ≥ 480 ✓; 32/18 lado vástago 3,84 kN = **392 kgf** ≥ 270 ✓; Ø25 lado pistón 3,44 kN = 351 kgf < 480 ✗.

Errores típicos: leer la fila de otra presión; olvidar que el lado vástago tiene un valor por vástago; no verificar la carrera máxima.

### §2.3 Bomba de engranajes Rexroth AZPB-3x (2025 hoja B, Makro p. 5, TP3 p. 4)

**Tamaños (cm³/rev):** 1,0 · 2,0 · 2,5 · 3,15 · 4,0 · 4,5 · 5,0 · 6,3 · 7,1. El código dice "3.1" para 3,15.

**Tabla AZPB-3x** (dato de catálogo):

| | 1 a 6,3 cm³/rev | 7,1 cm³/rev |
|---|---|---|
| Presión de succión (absoluta) | 0,7–3 bar abs | 0,7–3 bar abs |
| p1 máx. **continua** | **220 bar** | 200 bar |
| p2 máx. intermitente | 250 bar | 230 bar |
| p3 máx. de pico | 270 bar | 250 bar |
| n mín. | 750 rpm | 750 rpm |
| n máx. a p2 | 1,0 → 6000; 2,0–2,5 → 5000; 3,15–5,0 → 4000; 6,3 → 3500 | 3500 |

- **p1, p2, p3:** la presión de trabajo y la de ajuste de la limitadora se comparan con **p1 (continua)**. p2 y p3 son tolerancias de corta duración y de picos.
- **Presión de succión en bar absolutos:** 0,7 bar abs equivale a −0,3 bar relativos. Si la aspiración tiene más vacío que eso, hay cavitación (filtro de aspiración tapado o fino, tubo de succión chico).
- **Ordering code:** `AZ P B – x x – [tamaño] [giro R/L] [eje C/H/N] [tapa P/O/M/Y] [conexiones 01/02/20] [sellos M/K/P] [tapa trasera B/A] [válvula] [especial]`. Ejemplo del catálogo: `AZPB-xx-4.0RCP02MD200xx Sxxxx`. Opción "200 xx = PRV 200 bar": limitadora integrada en la bomba.
- Compatibilidades: eje C con tapa P; H con O; N con M o Y.

**Errores típicos:**

- Multiplicar mal unidades: $V_g$ [cm³/rev] × $n$ [rpm] = cm³/min → ÷ 1000 → l/min. **No** cm³/s.
- No aplicar $\eta_v$ cuando lo dan (Avanzini 2020).
- Elegir un tamaño **menor** que el necesario porque "está cerca".
- Olvidar verificar rpm máx./mín. y p1 (sobre todo con 7,1, que tiene p1 = 200 bar).

### §2.4 Bomba de engranajes AZPF, código de tipos (2020 p. 3)

`AZ P F – x x – [tamaño] …` con: función P = bomba; estado de serie 1 = cojinetes estándar, 2 = reforzados; versión 0 = fosfatada, 1 = fosfatada enclavijada, 2 = cromatizada enclavijada.

**Tamaño nominal (F):**

| Código | 004 | 005 | 008 | 011 | 014 | 016 | 019 | 022 | 025 | 028 |
|---|---|---|---|---|---|---|---|---|---|---|
| cm³/vuelta | 4,0 | 5,5 | 8,0 | 11,0 | 14,0 | 16,0 | 19,0 | 22,5 | 25,0 | 28,0 |

La hoja adjunta en 2020 **no** trae presiones ni rpm límite. Si en el examen tampoco las trae, decí "verificar presión máxima y rpm en la hoja de datos de la serie". **Error típico:** leer "016" como 1,6 cm³; es 16,0.

### §2.5 Tuberías, niples VOSS (Makro p. 7)

- **$d_1$** = diámetro exterior del tubo; **$d_7$ = diámetro interior** (el que importa para la velocidad); **PN** = presión nominal; "tubo 12×1,5" = exterior 12 mm, espesor 1,5 → interior 9 mm.
- Tabla completa en el dossier §4.5: interiores de 3 a 36 mm; PN 500/400/315 en los chicos y 160 en los de 22 a 42 mm.

**Errores típicos:**

- Usar $d_1$ en lugar de $d_7$.
- No verificar **PN ≥ presión de ajuste**: los tubos de 22 a 42 mm son PN 160; para 150 kg/cm² pasan, para 200 no.
- Usar el rango de velocidad equivocado: 2–4 m/s hasta 100 bar, 3–12 m/s hasta 315 bar, retorno 2–4, succión 0,5–0,8.
- Dimensionar el retorno con el caudal de bomba en vez del que sale del lado pistón.

### §2.6 Limitadora DBD de accionamiento directo (2025 hoja C)

Lo que se puede afirmar con la hoja: es una **limitadora de presión de accionamiento directo, tipo DBD (Rexroth)**, con un **cabezal de regulación** (tornillo de ajuste, contratuerca, tapa) cuyas medidas de llave están acotadas como **SW1, SW2, SW3**, y un esquema de bloque con la limitadora. Los cortes de la familia en pág. 33 (DBDH: asiento cónico 25–400 bar, o bola en la versión de 630 bar).

En la foto disponible **no se leen los valores**: ni escalones de presión ni medidas. En el examen, **leé la hoja que te den** y citá de ahí:

- el **escalón/rango de presión** que contiene tu ajuste;
- la **llave** para el tornillo y para la contratuerca;
- el **sentido de giro** para aumentar la presión.

Procedimiento en §4.

### §2.7 Direccionales (datos que muestran las diapositivas, pág. 25)

4WE 6 (NG6): 350 bar, 60 l/min (AC) / 80 l/min (DC). 4WE 10 (NG10): 315 bar, 120 l/min. Precomandadas 4WEH (NG10–32): 350 bar, 1100 l/min. Placa ISO 4401: NG6 = CETOP 03, NG10 = CETOP 05.

Con los caudales de los parciales (2–20 l/min) una NG6 sobra: "se selecciona una direccional NG6 (350 bar, 60–80 l/min), suficiente para $Q$ = … y $p$ = …". Son datos de las diapositivas de clase, no de un catálogo adjunto: si en el examen dan otra hoja, usá esa.


---

## §3. El esquema hidráulico estándar

Qué hace cada componente y cómo es su símbolo: **A5**. Cómo se recorre un esquema y qué hace cada centro: **A6**. Acá va lo que se escribe en el examen.

### §3.1 Lista ordenada con dato de selección (formato de respuesta de 2025 ítem 3 y TP3 ítem 3)

En el examen, armá esta tabla con **los números de tu caso**:

| # | Componente | Función (1 línea) | Se selecciona por |
|---|---|---|---|
| 1 | Tanque con respiradero | almacenar, decantar, disipar calor, liberar aire | volumen ≈ 2–4 × $Q_{bomba}$/min + volumen del cilindro |
| 2 | Filtro de aspiración | proteger la bomba de partículas gruesas | $Q$ (3×Q), malla gruesa 90–120 µm, baja Δp (evitar cavitación) |
| 3 | Grupo motor-bomba | generar el caudal | $Q$ y $p$ → cilindrada, rpm, potencia |
| 4 | Antirretorno | impedir el retroceso del aceite hacia la bomba | $Q$, $p$ |
| 5 | Limitadora de presión (+ manómetro) | proteger contra sobrepresión; descargar a tanque | rango de $p$ que incluya el ajuste; $Q$ ≥ $Q_{bomba}$ |
| 6 | Manómetro | visualizar la presión (ajuste, control) | escala > $p_{ajuste}$ |
| 7 | (Filtro de presión) | proteger componentes sensibles | $p$ del sistema, $Q$, micronaje según componente |
| 8 | Direccional 4/3 (centro, accionamiento) | dar el sentido de movimiento / parada | $Q$ máx., $p$ máx. → tamaño nominal; tensión de bobina |
| 9 | Reguladora(s) de caudal con antirretorno | regular la velocidad / el tiempo | rango de $Q$, $p$ |
| 10 | Cilindro con amortiguación | transformar en fuerza y carrera; frenar en los extremos | $F$, $p$, carrera, pandeo |
| 11 | Filtro de retorno (con bypass) | retener partículas del desgaste | $Q$ de retorno (con φ), baja $p$, 10–25 µm |
| 12 | Tuberías | conducir | $Q$ y velocidad → $d_7$; PN ≥ $p_{ajuste}$ |

> **Frase clave** (lo que faltó en 2025): "Todos los componentes intermedios se seleccionan para una presión máxima de … kg/cm² (ajuste de la limitadora) y un caudal de … l/min (caudal real de la bomba; en el retorno, … l/min por la relación de áreas)."

### §3.2 Esquema estándar completo (para dibujar en el examen)

```
              ┌──┬────────────────────┬──────────┬──┐
              │▯╱│    lado pistón     │▓ vástago │╲▯│══════════  cilindro DE con
              └┬─┴────────────────────┴──────────┴─┬┘            amortiguación regulable
               │ A                                 │ B
     [presostato]┤ (opcional, §5.2)                │
               │                                   │
  [antirretorno pilotado]◄ - - pilotaje desde B - -┤  (opcional: carga vertical, §3.3)
               │                                   │
  [reguladora c/ antirretorno]       [reguladora c/ antirretorno]
               │                                   │
               └─────────────┐       ┌─────────────┘
                           A │       │ B
                     ┌───────┴──┬────┴─────┬──────────┐
              y1 /\/ │    a     │ 0 tándem │    b     │ /\/ y2
                     └───────┬──┴────┬─────┴──────────┘
                           P │       │ T
                             │       │
           (opcional) filtro ◇       ◇ filtro de retorno con bypass e indicador
                  de presión │       │
       manómetro (↗)─────────┤       │
              ┌──────────────┤       │
         [limitadora]        ○ antirretorno
              │              │       │
              │           ( ▲ )══[M] │   motor-bomba
              │              │       │
              │              ◇ filtro de aspiración
        ══════╧══════════════╧═══════╧════════ TANQUE      ◇ respiradero en la tapa
```

**Reglas de dibujo que corrige el profe:**

- la limitadora **en derivación**, inmediatamente después de la bomba y antes de la direccional (A3);
- el manómetro en la línea de presión, junto a la limitadora, para poder ajustarla;
- **amortiguación** dibujada en el cilindro (el profe la agregó en rojo al esquema de Martina);
- **presostato** si hay automatismo por presión (también agregado en rojo).

### §3.3 Opcionales: cuándo agregar cada uno

| Opcional | Agregalo cuando… | Por qué |
|---|---|---|
| **Presostato** | el automatismo depende de la presión (retorno al retirar la carga, aviso de sobrecarga, secuencia por presión) | da la señal eléctrica (§5.2) |
| **Antirretorno pilotado** en la línea A | hay que **retener una carga vertical** por tiempo prolongado (gato, elevador) | la corredera de la direccional tiene fugas internas: la carga bajaría lentamente. El antirretorno de asiento cierra sin fugas y se abre solo cuando hay presión de pilotaje (al mandar bajar). ⚠️ No figura en los enunciados; va por completitud y seguridad |
| **Reguladora de caudal con antirretorno** (unidireccional) | hay que regular la velocidad **en un sentido** | en la línea A, con el antirretorno pasando libre hacia el cilindro: regula la **bajada** de una carga vertical (frena la salida) |
| **Reguladora bidireccional** | la misma restricción sirve en los dos sentidos | más simple; regula ida y vuelta |
| Reguladora **compensada por presión** | la velocidad tiene que ser constante aunque varíe la carga | mantiene Δp constante en el orificio (pág. 36) |
| **Filtro de presión** | hay componentes sensibles (proporcionales, servos) | antes de esos componentes; en el circuito básico no suele hacer falta |
| **Amortiguación** de fin de carrera | velocidad > 0,05 m/s (Atos, pág. 45), masas grandes o pedido de "llegada lenta" | frena en el último tramo (A4) |
| Filtro fuera de línea / enfriador | equipos grandes o servicio continuo | limpieza y temperatura sin parar |
| Acumulador | demanda de caudal de punta, emergencia, mantener presión | ver anexo |

### §3.4 Qué centro de 4/3 elegir (tabla completa en A6.2)

| Necesidad | Centro |
|---|---|
| Arranque en vacío + retener la carga (caso típico) | **Tándem / recirculación en posición central** (Makro opción 5) |
| Carga vertical: retener sin que baje | Tándem; para retención sin fugas, **+ antirretorno pilotado** en A (y entonces mejor centro con A y B a tanque ⚠️, §3.6) |
| Cilindro libre en reposo (que se pueda mover a mano, motor que gira por inercia) | abierto / flotante (opción 1) |
| Bomba variable o acumulador, varios actuadores | cerrado (opción 4) |

En Makro hay que **justificar la elección "según operación y seguridad"**:

> "Elijo la opción 5 (recirculación en la posición central = tándem): en reposo P→T, la bomba descarga sin presión (arranque en vacío del motor, sin calentamiento del aceite) y A y B quedan bloqueadas, de modo que la carga elevada no desciende. Descarto el centro flotante (1, 2) porque dejaría bajar la carga por su peso, y el cerrado (4) porque la bomba quedaría descargando por la limitadora a plena presión."

### §3.5 Cómo hacer que la carga "arribe lentamente" a los extremos

Es la consigna de Makro y el ítem 10 de 2020. Hay dos recursos, que se combinan:

1. **Amortiguación de fin de carrera regulable**, en el cilindro (A4, pág. 43–45). Actúa **solo en el último tramo** de la carrera: lleva de 1–2 m/min a 0,2–0,3 m/min.
   - **Cómo se ajusta:** con el tornillo de la válvula de amortiguación de cada tapa. Cerrándolo se achica el paso del aceite atrapado y se frena más. ⚠️ Procedimiento habitual: empezar con la amortiguación abierta, hacer carreras de prueba con la carga de trabajo e ir cerrando hasta que el pistón llegue sin golpe y sin quedarse corto ni tardar demasiado; después fijar.
2. **Reguladoras de caudal** (A5.9): fijan la velocidad de **toda** la carrera. En una carga vertical, la de la línea A con antirretorno regula la bajada.
   - **Cómo se ajusta:** girando el estrangulador mientras se mide el tiempo de carrera, hasta el tiempo deseado; en las de llave (2FRM, pág. 34), se fija con la llave.
   - Desventaja: el caudal excedente pasa por la limitadora → calor.

> **Frase de examen:** "Para que la carga arribe lentamente a las posiciones extremas se prevé un cilindro con **amortiguación de fin de carrera regulable** en ambas tapas, que reduce la velocidad en el último tramo (de 1–2 m/min a 0,2–0,3 m/min), y **reguladoras de caudal con antirretorno** en las líneas A y B para fijar la velocidad de subida y de bajada. Las amortiguaciones se ajustan con su tornillo de regulación en carreras de prueba con carga, y las reguladoras midiendo el tiempo de carrera."

Opción más avanzada ⚠️ (fuera del material de la cátedra): **válvulas proporcionales** con rampas de aceleración y frenado.

### §3.6 Retener una carga vertical (gato 2025, autoelevadores)

- El **centro tándem** bloquea A y B, pero la corredera no es estanca (holgura radial, A7): la carga baja de a poco.
- Para retención prolongada o por seguridad: **antirretorno pilotado** en la línea A, entre la direccional y el cilindro. Bloquea sin fugas y se abre solo al haber presión en B (orden de bajar).
- Con antirretorno pilotado, el centro ideal es el que **descarga A y B a tanque**: el abierto (opción 1 de Makro, que además arranca en vacío) o el de "P bloqueado, A y B al tanque" (pág. 31).
  - El antirretorno es el que retiene la carga, y la línea de pilotaje queda sin presión, así que cierra bien.
  - Con tándem puro puede quedar presión atrapada en B que lo entreabra.
  - ⚠️ práctica industrial; en el examen, si no ponés antirretorno pilotado, el centro es **tándem**.

---

## §4. Limitadora de presión: procedimiento y valor de ajuste

Física y ubicación: **A3**. Símbolo y selección: **A5.5**.

### §4.1 Qué elemento

> "Para evitar sobrecargas se utiliza una **válvula limitadora de presión (de seguridad o de alivio)**, en este caso de accionamiento directo tipo DBD según la hoja adjunta. Se instala **en derivación inmediatamente después de la bomba**, descargando a tanque: mientras la presión es menor que la de ajuste permanece cerrada y, al alcanzarla, abre y deriva el caudal de la bomba al tanque, limitando la presión máxima del sistema y por lo tanto la fuerza máxima del cilindro."

Un **presostato** no protege: solo da una señal eléctrica. Una **reguladora de caudal** cambia la velocidad, no limita la presión. Es la discusión de 2020 ítem 15.3.

### §4.2 El valor de ajuste

**Lo observado:**

| Caso | Trabajo | Presión dada | Ajuste | Fuente |
|---|---|---|---|---|
| 2025 gato | 119,4 kg/cm² | 130 (máx. bomba) | **≈ 130** | corrección en rojo del profe ("P_ureg > P_trabajo", "P_ureg ≈ 130"). Ribeiro puso 125 → 13/25 |
| 2020 brazo, Ø40 | 79,6 kg/cm² | 150 (en bomba) | opciones 95 / 100 / 145 | Avanzini eligió 100 (sin corrección visible) |
| Makro equipo B | 50–80 kg/cm² según cilindro | 10 MPa ≈ 102 kg/cm² | "regular a un valor que el manómetro lo pueda ver / **100 bar**" | nota impresa en el enunciado |
| TP3 | 59,7 kg/cm² | 70 (máx. sistema) | — (no se pide) | |

**Criterio** ⚠️ verificar con la cátedra:

$$p_{trabajo}+\Delta p\;<\;p_{ajuste}\;\le\;p_{máx}\ (\text{la del enunciado, la continua de la bomba, PN de componentes})$$

1. Si el enunciado da una **presión máxima** (de bomba o de sistema) → **ajustá ≈ esa presión**, como en 2025.
2. Si no la da → **trabajo + 10–25 %**.
3. Siempre **verificá** que sea menor que la continua de la bomba (220 bar AZPB) y que la PN de los tubos.

**Por qué "limita la sobrecarga" (la justificación que suma):** la fuerza máxima que puede hacer el cilindro es $F_{máx}=p_{ajuste}\cdot A_1$.

- 2025: $130\cdot12{,}56=1633$ kg = **1,09 ×** la carga nominal.
- 2020 con Ø40: con 95 → 1193 kg (1,19×); con 100 → 1256 kg (1,26×); con **145 → 1821 kg (1,82×)**. Con 145 solo se protege la bomba: el mecanismo podría recibir casi el doble de la fuerza de diseño.

> **Frase de examen:** "Ajusto la limitadora a **130 kg/cm²**, la presión máxima de bomba indicada: queda por encima de la de trabajo (119,4 + 0,4 de pérdidas ≈ 120 kg/cm²), de modo que el cilindro puede levantar la carga nominal, y por debajo de la máxima continua de la bomba (220 bar). Así la fuerza máxima queda limitada a $130\cdot12{,}56\approx1630$ kg (≈ 1,1 veces la nominal) y se protege el equipo ante una sobrecarga o al llegar a fin de carrera."

### §4.3 Procedimiento de ajuste (sin inventar datos de la DBD)

> 1. **Antes de arrancar**: aflojar la contratuerca del cabezal de regulación (con la llave que indica la hoja, medida SW…) y **descomprimir** el resorte girando el tornillo de regulación hacia el lado de menor presión, para que al arrancar la presión no supere el valor buscado.
> 2. Verificar que haya un **manómetro** en la línea de presión, entre bomba y limitadora (punto de medición, pág. 32), con escala mayor que el valor a ajustar.
> 3. Arrancar la bomba **en vacío** (direccional en el centro tándem).
> 4. Llevar el sistema a la condición en que **todo el caudal debe pasar por la limitadora**: accionar la direccional y llevar el cilindro **a fin de carrera** (a tope), o bloquear la salida de la bomba.
> 5. Con el cilindro a tope, **girar el tornillo de regulación** en el sentido que comprime el resorte (⚠️ normalmente horario; verificar en la hoja) mientras se lee el manómetro, hasta llegar a **130 kg/cm²**.
> 6. **Fijar la contratuerca** sin mover el tornillo; colocar la tapa o precinto si la tiene.
> 7. **Verificar**: volver la direccional al centro (la presión cae a ≈ 0) y repetir la maniobra hasta tope; el manómetro tiene que volver a marcar 130. Para **bajar** el valor se afloja el tornillo (resorte menos comprimido) y se repite desde el punto 4.

Lo que le marcaron a Ribeiro (13/25): 125 en lugar de 130, y la frase del procedimiento. El texto exacto de la corrección no se ve, pero su procedimiento **no llevaba el cilindro a tope** (sin eso la limitadora no abre y no se puede leer el ajuste), **no arrancaba con el resorte aflojado** y llamaba "reguladora de presión" a la limitadora ⚠️ (la cátedra usa los dos nombres; preferí "limitadora de presión / válvula de seguridad").

---

## §5. Automatismos eléctricos típicos

**Notación** (escalera, entre L1 y N):

- `─┤ ├─` contacto **NA** (normal abierto);
- `─┤/├─` contacto **NC** (normal cerrado);
- `─( K1 )─` bobina de relé;
- `─( Y1 )─` solenoide de la direccional (Y1 = extender, posición a; Y2 = retraer, posición b);
- S = pulsadores; B = sensores / finales de carrera.

La lógica es la de Automatismos; lo específico de hidráulica es **qué solenoide mueve qué** y **qué hace la válvula en reposo**: con centro tándem centrada por resortes, al desenergizar el solenoide **el cilindro se detiene y retiene la carga**.

### §5.1 Parada automática a una posición intermedia (TP3 6E: mitad de carrera; 2025: 80 %)

**Señales:** S0 parada (pulsador NC), S1 marcha (pulsador NA, **no retenido** → hace falta autorretención), B50 final de carrera o sensor a mitad de carrera (contacto NC que abre al ser accionado).

```
 L1                                                              N
  │   S0       S1            B50                                 │
  ├──┤/├──┬───┤ ├────┬──────┤/├──────────────────( K1 )──────────┤
  │       │   K1     │                                           │
  │       └───┤ ├────┘                                           │
  │                                                              │
  │   K1                                                         │
  ├──┤ ├─────────────────────────────────────────( Y1 )──────────┤
```

**Lógica:**

- S1 energiza K1, que se **autorretiene** con su contacto en paralelo (porque S1 vuelve al soltarlo).
- K1 energiza Y1 → la direccional pasa a "a" → el cilindro extiende.
- Al llegar a la mitad, B50 abre → cae K1 → cae Y1 → los resortes centran la válvula (tándem) → el cilindro **se detiene y queda retenido**; la bomba recircula a tanque.
- Si se vuelve a pulsar S1 con el cilindro parado sobre B50, no arranca (B50 abierto) → no se pasa de la posición.
- ⚠️ La leva o el sensor tiene que seguir accionado con el cilindro detenido: frena unos milímetros después de la señal.
- S0 corta todo (parada).

**Para volver:** agregar una segunda línea como la de §5.3 (S2 → K2 → Y2, con un final de carrera B0 de posición inicial).

### §5.2 Retención y retorno automático al retirar la carga (2025 ítem 4)

**Lo que se pide:** subir con la carga, **detenerse al 80 %** y mantenerla; cuando la carga se retira con otro medio (grúa), **retornar solo**. Dato: el cilindro sin carga genera una contrapresión de 3 a 5 kg/cm².

**Dónde va el presostato y por qué** (⚠️ inferencia sobre la corrección; el profe solo preguntó "¿cuál es el valor de ajuste del presostato P?"):

- Con el cilindro detenido (centro tándem, A y B bloqueadas), la carga presuriza el aceite atrapado en el **lado pistón (línea A)**: $p_A=1500/12{,}56\approx$ **119 kg/cm²**.
- Al retirar la carga, esa presión cae a la contrapresión del cilindro solo: **3–5 kg/cm²**.
- El evento "se retiró la carga" es una **caída de presión en la línea A**. El presostato va **en la línea A, entre la direccional (o el antirretorno pilotado) y el cilindro**, del lado donde queda atrapada la presión.
- **No** en la línea B (lado vástago): ahí no hay presión que cambie con la carga; Ribeiro lo puso ahí, ajustado a 128.
- **No** en P: con centro tándem, P está a ≈ 0 bar en reposo.

**Valor de ajuste** (⚠️ criterio propio, a justificar):

- Tiene que conmutar **por caída** de presión.
- El punto de conmutación tiene que quedar **por encima de 5 kg/cm²** con margen para la tolerancia y la histéresis del presostato, y **muy por debajo de 119**.
- Propuesta: **≈ 10 kg/cm²**. Con 10 kg/cm² el sistema considera "sin carga" cualquier carga residual menor que $(10-5)\cdot12{,}56\approx63$ kg (a $(10-3)\cdot12{,}56\approx88$ kg), y con cualquier pieza mayor que eso sigue reteniendo. Rango razonable: 8–15 kg/cm².

**Señales:** S0 parada (NC), S1 marcha (NA), B80 sensor al 80 % (contacto NA y NC), B0 sensor de posición inicial (contacto NC que abre con el cilindro abajo), PS presostato en A, contacto que **cierra cuando p < 10 kg/cm²**.

```
 L1                                                                     N
  │ 1) SUBIR                                                            │
  │   S0       S1           B80        K2                               │
  ├──┤/├──┬───┤ ├────┬─────┤/├───────┤/├──────────────────( K1 )────────┤
  │       │   K1     │                                                  │
  │       └───┤ ├────┘                                                  │
  │   K1                                                                │
  ├──┤ ├──────────────────────────────────────────────────( Y1 )────────┤
  │                                                                     │
  │ 2) MEMORIA "CARGA ELEVADA"                                          │
  │       B80              B0                                           │
  ├──┬───┤ ├────┬─────────┤/├─────────────────────────────( K3 )────────┤
  │  │   K3     │                                                       │
  │  └───┤ ├────┘                                                       │
  │                                                                     │
  │ 3) BAJAR (automático)                                               │
  │   S0       K3      PS(p<10)           B0         K1                 │
  ├──┤/├──┬───┤ ├─────┤ ├──────┬─────────┤/├────────┤/├───( K2 )────────┤
  │       │   K2               │                                        │
  │       └───┤ ├──────────────┘                                        │
  │   K2                                                                │
  ├──┤ ├──────────────────────────────────────────────────( Y2 )────────┤
```

**Lógica, paso a paso:**

1. Cilindro abajo: B0 accionado (su NC abierto) → K2 y K3 no pueden energizarse.
2. S1 → K1 (autorretenido) → Y1 → sube. Sale de B0 (B0 vuelve a cerrar).
3. Al 80 %, B80 acciona: su NC corta K1 → Y1 cae → la válvula se centra (tándem) → **se detiene y retiene**; su NA setea la memoria **K3** (autorretenida a través de B0).
4. Con la carga encima, $p_A$ ≈ 119 > 10 → PS abierto → no pasa nada: **retiene**.
5. Se retira la carga con la grúa → $p_A$ cae a 3–5 < 10 → PS cierra → con K3 cerrado se energiza **K2** (autorretenido) → Y2 → **retrae**.
6. Al llegar abajo, B0 abre → caen K2 y K3 → la válvula se centra. Ciclo terminado.

Enclavamientos: K2 NC en la línea de K1 y K1 NC en la de K2 (nunca los dos solenoides a la vez). Si se sube sin carga, al llegar al 80 % la presión ya es < 10 y vuelve enseguida: es coherente, porque no hay nada que retener.

Hidráulicamente conviene un **antirretorno pilotado** en A para que la carga no baje por fugas mientras espera (§3.6). El presostato queda **entre ese antirretorno y el cilindro**.

### §5.3 Ciclo ida/vuelta con dos pulsadores y enclavamientos

**Señales:** S0 parada (NC), S1 "avanzar" (NA), S2 "retroceder" (NA), B1 final de carrera extendido (NC), B0 final de carrera retraído (NC).

```
 L1                                                              N
  │   S0       S1           B1         K2                        │
  ├──┤/├──┬───┤ ├────┬─────┤/├───────┤/├──────────( K1 )─────────┤
  │       │   K1     │                                           │
  │       └───┤ ├────┘                                           │
  │   K1                                                         │
  ├──┤ ├─────────────────────────────────────────( Y1 )──────────┤
  │                                                              │
  │   S0       S2           B0         K1                        │
  ├──┤/├──┬───┤ ├────┬─────┤/├───────┤/├──────────( K2 )─────────┤
  │       │   K2     │                                           │
  │       └───┤ ├────┘                                           │
  │   K2                                                         │
  ├──┤ ├─────────────────────────────────────────( Y2 )──────────┤
```

**Lógica:**

- S1 → K1 autorretenido → Y1 → avanza hasta B1, que corta.
- S2 → K2 → Y2 → retrocede hasta B0.
- El **enclavamiento cruzado** (K2 NC en la línea de K1 y viceversa) impide energizar los dos solenoides a la vez.
- Con ninguno energizado, la válvula vuelve al centro (tándem) y el cilindro se detiene donde esté: pulsando S0 se para en cualquier punto.
- **Variante con retorno automático:** poner un contacto **NA de B1 en paralelo con S2**. Al llegar al final de la extensión, el cilindro vuelve solo.


---

## §6. Teoría corta: respuestas modelo

Escritas como para el examen: 2–4 líneas. La explicación de fondo está en la Parte A.

### §6.1 Parcial 2020, ítems 1–13 (opción múltiple / ampliar, 40 %)

**1. La presión en un sistema oleohidráulico:** marcar **(1) y (3)**.
> La presión se genera como consecuencia del esfuerzo en el actuador y de la resistencia al flujo (válvulas, tuberías). La bomba no "origina" presión: entrega caudal, y la presión sube hasta el valor necesario para vencer la carga, con el límite de la válvula limitadora. (A3)

**2. Qué forma parte del sistema y qué no:**
> **Sí:** enfriador o intercambiador de calor, depósito, filtro y aceite. **No:** aire y agua. Son contaminantes (gaseoso y líquido) que hay que eliminar: el aire produce espuma, cavitación y efecto Diesel; el agua produce corrosión y degrada el aceite. (A7)

**3. "Regula la presión del sistema permitiendo su visualización":**
> Ningún elemento hace las dos cosas. La **válvula de alivio (limitadora)** regula, es decir limita, la presión máxima; el **manómetro** permite visualizarla. Se usan juntos: el manómetro se coloca junto a la limitadora para poder ajustarla. El filtro no tiene relación. ⚠️ Si hay que marcar uno solo, explicar como arriba.

**4. "Puede estar en la aspiración, en línea de presión, en retorno o como sistema externo":** **(2) filtro**.
> Es necesario porque el aceite recircula y acumula contaminación sólida (desgaste, montaje, aceite nuevo, ingreso por sellos y respiradero), que provoca abrasión y erosión de bombas, válvulas y cilindros. Aspiración protege la bomba; presión, los componentes sensibles; retorno retiene lo generado por desgaste; el externo (fuera de línea) filtra y enfría sin parar la máquina. (A5.2)

**5. Funciones del fluido:** **(3) lubricar, refrigerar y transmitir potencia**.
> Las otras opciones mencionan "filtrar" y "contener impurezas", que no son funciones del aceite. Además sella holguras y protege contra la corrosión. (A7)

**6. Para visualizar la presión: (1) manómetro.** Los demás:
> **Presostato:** convierte la presión en una señal eléctrica (contacto que conmuta a un valor ajustado), para automatismos o alarmas. **Válvula limitadora:** limita la presión máxima y protege el sistema contra sobrecargas descargando a tanque. **Válvula direccional:** dirige el caudal hacia una u otra cámara del actuador y define el sentido de movimiento o la parada.

**7. Compactas y de menor costo:** **(1) bombas de engranajes**.
> Son de construcción simple, robustas y baratas, de caudal fijo; contra ellas, más ruido y menor presión que las de pistones. (A5.3)

**8. Disipa temperatura, libera el aire y decanta contaminantes:** **(1) depósito**.
> El volumen de reserva (2–4 veces el caudal de la bomba) y la placa deflectora entre retorno y aspiración le dan tiempo al aceite para liberar el aire, decantar partículas y agua y enfriarse a través de las paredes. (A5.1)

**9. La bomba produce:** **(1) caudal**.
> La bomba de desplazamiento positivo entrega un volumen por vuelta; la presión depende de la carga (ver ítem 1).

**10. Disminuye la velocidad del cilindro en el último tramo:** **(4) amortiguamiento**.
> La amortiguación de fin de carrera atrapa el aceite en la tapa y lo hace salir por un orificio regulable, reduciendo la velocidad solo en el final (de 1–2 a 0,2–0,3 m/min). La reguladora de flujo, en cambio, regula la velocidad de **toda** la carrera. (A4)

**11. Accionamiento eléctrico:** **(3) bobina / solenoide**.

**12. Otros accionamientos de direccionales (3):**
> **Manual** (palanca, pulsador, pedal); **mecánico** (rodillo, palpador, leva, resorte); **hidráulico o neumático** (pilotaje). También el electrohidráulico: solenoide que comanda una válvula piloto. (pág. 27, 29)

**13. Listado correcto de la figura:** **(3)**.
> Tanque, grupo motor-bomba, válvula antirretorno, válvula reguladora (limitadora) de presión, válvula direccional, válvula reguladora de caudal y cilindro. La (4) tiene los mismos elementos **en otro orden** (direccional después del cilindro), que no es el orden del flujo; la (1) y la (2) omiten elementos o agregan un filtro que no está. (ver pág. 6, numeración 1–7)

**14. Con Fuerza y Velocidad como datos, qué se selecciona primero:** **(D) ninguno → el cilindro.**
> Con la fuerza y la presión de trabajo se dimensiona el **cilindro** (área → diámetro). Con su área y la velocidad se obtiene el **caudal**, y recién con presión y caudal se elige la bomba, después el motor, filtros, válvulas y tuberías. Es el orden de la diapositiva "Selección de componentes". La bomba, las tuberías y el filtro dependen del caudal y de la presión, que salen del cilindro.

### §6.2 TP3 2025, ítem 1 (teoría)

**1.1 Rango de presiones.**
> ⚠️ La cátedra no da un número único. Orden de magnitud: decenas a cientos de bar. Los catálogos de clase llegan a 70 bar (CD70), 160 bar (CDT3), 220–250 bar (bomba AZPB), 250–350 bar (CDH1/CDH3, direccionales 4WE 6) y hasta 630 bar en válvulas especiales. Una respuesta razonable: "en la industria, típicamente entre 70 y 350 bar". La tabla de bombas da 63 a 320 bar nominales según el tipo.

**1.2 Orden de componentes de bomba a actuador.**
> Tanque → filtro de aspiración → bomba (con motor) → antirretorno → limitadora de presión en derivación, con manómetro → (filtro de presión) → válvula direccional → reguladora(s) de caudal → cilindro; retorno: direccional → filtro de retorno → tanque. (§3.2)

**1.3 Fluido y condiciones.**
> Aceite mineral con aditivos (antidesgaste, antioxidante, antiespumante). Viscosidad adecuada al rango de temperatura de trabajo (clase ISO VG, alto índice de viscosidad), buena demulsibilidad (separa el agua), punto de inflamación alto, compatibilidad con sellos (punto de anilina) y **limpieza** según el componente más sensible (código ISO 4406). (A7)

**1.4 Parámetros a controlar para mantener el fluido.**
> Nivel, **temperatura** (y por lo tanto viscosidad), **contaminación sólida** (grado de limpieza ISO 4406, saturación de filtros), **agua** (máximo del orden de 0,04 %), **aire** (espuma), y envejecimiento del aceite (oxidación). Se controlan con visor de nivel y temperatura, indicadores de filtros, respiradero con sílica gel, análisis de aceite. (pág. 48–49)

**1.5 Elementos de almacenamiento y qué controlan.**
> El **depósito** (tanque), con indicador de nivel, termómetro o detector de temperatura, respiradero con filtro, placa deflectora, drenaje e intercambiador si hace falta. Controla nivel, temperatura, liberación de aire y decantación de impurezas. El **acumulador** almacena aceite a presión (energía). (A5.1, A5.12)

**1.6 Cómo se regula el tiempo de un actuador.**
> Regulando el **caudal** que entra o sale del actuador: $t=A\,L/Q$. En el diseño se elige la cilindrada de la bomba; en operación, con una **válvula reguladora de caudal** (preferentemente compensada por presión y con antirretorno, para regular un solo sentido). (A5.9)

**1.7 Qué previene esfuerzos elevados, dónde va y cómo se ajusta.**
> La **válvula limitadora de presión (de seguridad)**: va inmediatamente después de la bomba, en derivación hacia el tanque. Se ajusta con el cilindro a fin de carrera, girando su tornillo de regulación mientras se lee el manómetro, hasta un valor algo mayor que la presión de trabajo y menor que la máxima admisible; luego se fija con la contratuerca. (§4)

### §6.3 TP3 2025, ítems 2 a 5

**2. Tratamiento y acondicionamiento del aceite** (figura de pág. 18):
> **Respiradero:** filtra el aire que entra al tanque y retiene humedad (sílica gel). **Filtro de presión:** después de la bomba, protege válvulas y actuadores sensibles. **Filtro de retorno:** retiene las partículas generadas por el desgaste antes de que el aceite vuelva al tanque. **Filtración fuera de línea:** bomba auxiliar y filtro (y enfriador) independientes que filtran y acondicionan la temperatura de forma continua. (Si aparece, **filtro de aspiración**: protege la bomba de partículas gruesas.) Objetivo general: mantener el grado de limpieza del componente más sensible, controlar la temperatura y eliminar aire y agua.

**3. Elementos básicos con nombre, función y dato de selección** (figura numerada 1–7): usá la tabla de §3.1 con estos 7 elementos.
1. Bomba (Q, p).
2. Tanque (volumen 2–4 × Q).
3. Antirretorno (Q, p).
4. Limitadora (rango de p, Q ≥ Q_bomba).
5. Cilindro DE (F, p, carrera).
6. Direccional 4/3 con mando manual por palanca, centrada por resortes, centro tándem (Q, p, tamaño nominal).
7. Reguladora de caudal (rango de Q, p).

**4. Pistones y sellos:**
> **Izquierda:** pistón con un único sello de labio (en U) que sella en un solo sentido → **cilindro de simple efecto**, retorno por resorte o por peso propio. **Derecha:** cilindro de **doble efecto** con juntas del émbolo en los dos sentidos, casquillo guía, empaquetadura y retén rascador del vástago y **amortiguación ajustable en ambas posiciones finales**, para trabajo con esfuerzo en los dos sentidos y llegada suave a los extremos. (pág. 43)

**5. Armar el esquema de la figura pictórica** (tanque, bomba, *bypass valve 3000 psi*, direccional, cilindro, filtro de retorno):

```
                 ┌─────────┐
                 │cilindro │  (vertical, doble efecto)
                 └─┬─────┬─┘
                   A     B
                ┌──┴──┬──┴──┬─────┐
          /\/ ──│  a  │  0  │  b  │── /\/   direccional 4/3
                └──┬──┴──┬──┴─────┘
                   P     T
        ┌──────────┤     │
   [limitadora]    │     ◇ filtro de retorno (con indicador)
   3000 psi ≈      │     │
   207 bar         ( ▲ )══[M]
        │          │     │
   ═════╧══════════╧═════╧════ TANQUE
```

> La "bypass valve 3000 psi" es la **válvula limitadora (de alivio)**, ajustada a ≈ 207 bar (≈ 211 kg/cm²), en derivación de la línea de presión al tanque.

### §6.4 Otros temas que podrían aparecer en el mismo estilo

**Funciones del aceite; viscosidad / ISO VG / IV** → A7.
> "La viscosidad es la resistencia del fluido a circular; disminuye con la temperatura. Se elige la clase ISO VG para que en el rango de temperatura de trabajo quede en la zona ideal. Un índice de viscosidad alto indica poca variación con la temperatura."

**Tipos y orígenes de contaminación; abrasión y erosión** → A7.
> Sólida, gaseosa, líquida. Abrasión: partículas entre superficies en movimiento. Erosión: partículas a alta velocidad contra cantos.

**Filtros: ubicación y micronaje** → A5.2.
> "El grado de filtración lo define el componente más sensible del sistema: 20 µm para bombas de engranajes, cilindros y direccionales; 10 µm para bombas de pistones o paletas y válvulas proporcionales; 5 µm para servoválvulas."

**Depósito** → A5.1.
> Funciones: almacenar, decantar, disipar calor, liberar aire, compensar fugas. Volumen 2–4 × Q de bomba por minuto.

**Tipos de bomba** → tabla A5.3.
> "La bomba de engranajes es la más económica y compacta; las de pistones axiales permiten caudal variable y mayores presiones, a mayor costo."

**Designación vías/posiciones y letras** → A5.8.
> "Una 4/3 tiene 4 vías (P, T, A, B) y 3 posiciones. P: presión; T: tanque; A y B: trabajo; X, Y: pilotaje; L: drenaje. La posición de reposo es la dibujada junto al resorte."

**Tipos de válvulas:**
> **Distribuidoras/direccionales** (dirigen el aceite; también pilotan otras válvulas); **reguladoras de presión** (limitadora, reductora); **reguladoras de caudal**; **de bloqueo** (antirretorno, simple o pilotado). (pág. 23–24)

**Reguladora de presión vs limitadora** (pág. 35 y pág. 23):
> La **limitadora** fija un **máximo** y descarga el exceso a tanque. La **reductora** mantiene **constante** una presión menor aguas abajo (ejemplo de pág. 23: entra a 120 bar, sale a 90). ⚠️ La cátedra a veces llama "reguladora de presión" a la limitadora (2020 ítem 13, figura de Martina).

**Reguladoras de caudal: fija, variable, compensada, con antirretorno** → tabla A5.9.

**Antirretorno, manómetro, presostato** → A5.4, A5.6, A5.7.

**Cilindros:**
> **Partes:** camisa, émbolo con juntas y banda guía, vástago, culatas anterior y posterior, casquillo guía, empaquetadura y rascador, émbolo y válvula de amortiguación (pág. 43). **Tipos:** simple efecto (retorno por resorte o por peso), doble efecto, doble vástago, telescópico (pág. 41).

**Amortiguación** → A4.
> De 1–2 m/min a 0,2–0,3 m/min; recomendada por encima de 0,05 m/s.

**Sellos** → anexo.

**Tuberías: de qué depende la pérdida de carga** → A5.11.
> Longitud, sección, rugosidad, cantidad de accesorios, velocidad/caudal y viscosidad.

**Diferencias con neumática** → tabla A1.


---

## §7. Parciales anteriores resueltos (modelo)

Todas las cuentas están verificadas con Python. Donde hay un supuesto, se dice cuál.

### §7.1 Parcial 2, 2025: Gato hidráulico para fosa

**Datos:** carga 1,5 t; presión máxima en la bomba 130 bar; carrera 500 mm; subida/bajada 15 s; cilindro de doble efecto; $\eta_v$ = 0,92; $k$ direccional 0,0236, antirretorno 0,0153, filtro 0,0111 (kg/cm²)/(l/min)²; motor 3×380 V 50 Hz (rpm no dadas); se sugiere arranque en vacío.

**Lo que hizo Ribeiro y su nota** (≈ 75): ítem 1 30/30, ítem 2 13/25, ítem 3 15/25, ítem 4 17/20. Detalle en el dossier §2.1.

#### Ítem 1 (30 %): cilindro y bomba

**Cilindro.**

- $A_{nec}=1500/130=11{,}54$ cm² → $D\ge38{,}3$ mm → **pistón Ø40** ($A_1=12{,}56$ cm²).
- $p_{trabajo}=1500/12{,}56=$ **119,4 kg/cm²** < 130 ✓.
- Vertical, la carga se opone a la extensión → trabaja $A_1$. En la bajada, la carga empuja: carga que arrastra (A4).

**Vástago por pandeo** (Euler, S = 3). El gato está fijado abajo y la carga apoya arriba sin guía → **caso 1** ($S_k=2l$) ⚠️. Con $l$ ≈ carrera = 50 cm, $S_k$ = 100 cm:

| Vástago | $J$ (cm⁴) | $F_{adm}$ caso 1 | Verifica |
|---|---|---|---|
| Ø18 | 0,515 | 361 kgf | ✗ (< 1500) |
| Ø28 | 3,018 | 2113 kgf | ✓ |

→ **Cilindro 40/28/500.** Ribeiro eligió 40/28 sin verificar pandeo: la verificación lo justifica.

⚠️ Si la cátedra toma la longitud libre real (≈ cilindro extendido, $l$ ≈ 100 cm → $S_k$ = 200 cm), el 40/28 da 528 kgf y no verificaría en caso 1 (haría falta un vástago ≥ 36 mm, o guiar la carga: caso 2 con $l$ = 100 → 2113 ✓). Mencionalo en una línea si te sobra tiempo.

**Caudal.** $v=50/15=3{,}33$ cm/s (2 m/min) → $Q=12{,}56\cdot3{,}33=41{,}9$ cm³/s = **2,51 l/min** (chequeo con la tabla: $q_{V1}$ = 7,5 l/min a 0,1 m/s → 7,5·0,333 = 2,5 ✓).

**Bomba** (rpm adoptadas, ⚠️ decirlo):

| Motor adoptado | $V_{g,nec}$ con $\eta_v$ | AZPB | $Q_{real}$ | Subida |
|---|---|---|---|---|
| 4 polos, 1450 rpm | 1,88 cm³/rev | **2,0** | 2,67 l/min | 14,1 s ✓ |
| 2 polos, 2900 rpm | 0,94 cm³/rev | **1,0** | 2,67 l/min | 14,1 s ✓ |
| (Ribeiro) 2940 rpm | 0,93 cm³/rev | 1,0 | 2,705 l/min | 13,9 s ✓ |

- Verificación de catálogo: 130 bar < p1 = 220 bar ✓; 1450 rpm entre 750 y 5000 (tamaño 2,0) ✓; 2900 rpm < 6000 (tamaño 1,0) ✓.
- Designación de ejemplo: AZPB-xx-**2.0R**CP02MB (§1 paso 7).

**Pérdidas.** Con $Q$ = 2,67: $\Delta p=(0{,}0111+0{,}0153+0{,}0236)\cdot2{,}67^2=$ **0,36 kg/cm²** (0,46 con dos antirretornos) → $p_{bomba}$ ≈ 119,8 kg/cm² < 130 ✓. Con 2,705 l/min da 0,37. Ribeiro escribió 0,48: no coincide con su propio caudal (con 2,705 da 0,37; 0,48 sería con dos antirretornos).

**Potencia.** $130\cdot2{,}67/600=0{,}58$ kW → / 0,85 ⚠️ = 0,68 kW → **motor 0,75 kW (≈ 1 CV)**, 3×380 V 50 Hz.

**Bajada** (doble efecto con bomba por B): $t=6{,}40\cdot50/44{,}5=$ **7,2 s** < 15 s, y además la carga empuja (arrastra). Para cumplir 15 s y que no se "escape": **reguladora de caudal con antirretorno en la línea A** que limite la salida del lado pistón a ≈ 2,5 l/min. El excedente de bomba sale por la limitadora.

#### Ítem 2 (25 %): protección contra sobrecarga

- **Elemento:** válvula **limitadora de presión de accionamiento directo tipo DBD** (hoja C), en derivación inmediatamente después de la bomba, a tanque (§4.1).
- **Valor:** **130 kg/cm²** (= presión máxima de bomba del enunciado; > 119,8 de trabajo + pérdidas; < 220 continua de bomba). Limita la fuerza a ≈ 1630 kg (1,09 × la nominal) (§4.2).
- **Procedimiento:** §4.3 completo, citando de la hoja C la llave del cabezal (SW…) y el sentido de giro.

**Dónde se pierden puntos:** ajustar a "trabajo + pérdidas" (125); no llevar el cilindro a tope para ajustar; no mencionar el manómetro; no fijar la contratuerca; no verificar.

#### Ítem 3 (25 %): componentes intermedios, esquema, función y selección

Esquema: el de §3.2 con centro tándem (arranque en vacío, retiene la carga), reguladora con antirretorno en A, presostato en A (para el ítem 4) y antirretorno pilotado opcional.

Datos de selección: **p = 130 kg/cm², Q = 2,67 l/min** (retorno al bajar: hasta 2,67·12,56/6,40 = **5,2 l/min**).

| Componente | Función | Selección con los datos del caso |
|---|---|---|
| Tanque + respiradero (sílica gel) | almacenar, decantar, disipar, liberar aire | 2–4 × 2,67 ≈ **5,3–10,7 l** + 0,63 l del cilindro |
| Filtro de aspiración | proteger la bomba | Q ≥ 2,67 l/min (Parker 3×Q ≈ 8 l/min), 90–120 µm, baja Δp |
| Motor-bomba AZPB 2,0 | generar caudal | 2,67 l/min, 130 kg/cm²; 0,75 kW |
| Antirretorno | evitar retroceso a la bomba | 2,67 l/min, 130 kg/cm² |
| Limitadora DBD + manómetro | proteger (ajuste 130) / visualizar | rango que incluya 130; Q ≥ 2,67; manómetro con escala > 130 (p. ej. 0–160 ⚠️) |
| Direccional 4/3 centro tándem, solenoides, centrada por resortes | sentido de movimiento, parada, arranque en vacío | 130 kg/cm², 5,2 l/min → NG6 sobra (350 bar, 60–80 l/min, pág. 25) |
| Reguladora de caudal con antirretorno en A | regular la bajada a 15 s (carga que arrastra) | ≈ 2,5 l/min regulados, 130 kg/cm² |
| (Antirretorno pilotado en A) | retener la carga sin fugas | 130 kg/cm², 2,67 l/min |
| Presostato en A | señal de "carga retirada" | rango que incluya ≈ 10 kg/cm²; p máx ≥ 130 |
| Cilindro 40/28/500 con amortiguación | fuerza y carrera | (ítem 1) |
| Filtro de retorno con bypass | retener partículas de desgaste | **5,2 l/min** (retorno amplificado), baja p, 20 µm (bomba de engranajes, pág. 13) |
| Tuberías | conducir | presión: 8×2 ($d_7$ = 4, PN 500, 3,5 m/s); retorno: 10×2 ($d_7$ = 6, PN 400, 3,1 m/s) |

**Dónde se pierden puntos:** esto es exactamente lo que le faltó a Ribeiro ("faltó explicar elementos de selección por P y Q"). Además, su justificación del centro ("para que se mantenga el fluido en movimiento") es pobre: el argumento es **arranque en vacío + sin calentamiento + retención**.

#### Ítem 4 (20 %): automatismo

Esquema eléctrico, presostato y valor: **§5.2**.

- Presostato **en la línea A** (entre la válvula y el cilindro), conmutando **por caída** a **≈ 10 kg/cm²**: por encima de la contrapresión de 3–5 y muy por debajo de los 119 con carga ⚠️ criterio.
- Sensor al 80 % de la carrera = 400 mm.

**Dónde se pierden puntos:** presostato en B (Ribeiro), valor sin justificar (128), no usar el dato de contrapresión de 3–5 kg/cm² (que está **para eso**).

---

### §7.2 Parcial N° 02, 2020

Ítems 1–14: respuestas en **§6.1**.

#### Ítem 15 (40 %): brazo, $F$ = 1000 kg, carrera 500 mm, 150 kg/cm² en bomba, extensión 4 m/min, retracción por peso propio

**15.1 Cilindro.**

- $A_{nec}=1000/150=6{,}67$ cm² → por presión alcanzaría Ø32 ($A_1$ = 8,04 → 124,4 kg/cm²). Margen de solo el 17 % sobre 150 para pérdidas, fricción y ajuste de la limitadora.
- Hay **dos lecturas razonables**:

| Lectura | Cilindro | p trabajo | Ajuste coherente | Fuerza máx. con el ajuste | A favor |
|---|---|---|---|---|---|
| **Recomendada** | **40/18** | 79,6 | 95–100 | 1193–1256 kg (1,2–1,26×) | las opciones de ajuste del ítem 15.4 (95 y 100) solo tienen sentido con ≈ 80 de trabajo; la AZPF más chica (004) da casi exactamente 4 m/min con Ø40 |
| Alternativa | 32/22 | 124,4 | 145 | 1166 kg (1,17×) | es el mínimo por presión (criterio de 2025); también limita la fuerza |

- ⚠️ inferencia: el diseño del enunciado apunta a Ø40.
- **Vástago** (articulado en los dos extremos, **caso 2**, $l$ ≈ 50 cm ⚠️): Ø14 → 528 kgf ✗; **Ø18 → 1443 kgf ✓**; Ø22 → 3221 ✓. El 32/14 queda descartado por pandeo (no por el área anular, como argumentó Avanzini).
- El lado vástago **no se verifica por fuerza**: la retracción es por peso propio y B va a tanque.

> "Selecciono 40/18/500: $p=1000/12{,}56=79{,}6$ kg/cm² < 150 ✓, con margen para pérdidas y para ajustar la limitadora por encima del trabajo. Pandeo caso 2: $F_{adm}$ = 1443 kgf > 1000 ✓."

**15.2 Bomba.**

- $Q=12{,}56\cdot6{,}7=84{,}2$ cm³/s = 5,05 l/min.
- Motor adoptado 4 polos 1450 rpm ⚠️ → $V_g=5050/(1450\cdot0{,}92)=3{,}79$ cm³/rev → **AZPF tamaño 004 (4,0 cm³/vuelta)**.
- $Q_{real}=4{,}0\cdot1450\cdot0{,}92=5{,}34$ l/min → $v$ = 7,1 cm/s (4,25 m/min) ✓, extensión en 7,1 s.
- Con 2900 rpm la 004 daría el doble (8,5 m/min): habría que estrangular → peor elección.
- ⚠️ En 2020 no dieron $\eta_v$; aplicar 0,92 es conservador y no cambia la selección. Avanzini no lo aplicó (96,6 cm³/s).
- La hoja AZPF no trae presión máx. ni rpm: "verificar en la hoja de datos de la serie que 150 kg/cm² y 1450 rpm estén dentro de los límites".
- Retracción por peso propio: en la bajada la línea A va a tanque a través de una **reguladora de caudal con antirretorno** que frena la salida.

**15.3 Protección: (B) válvula reguladora (limitadora) de presión.**

> "La reguladora de caudal modifica la velocidad, no la presión; el presostato solo da una señal eléctrica; la limitadora, en derivación después de la bomba, descarga a tanque al alcanzar el ajuste y limita la presión y por lo tanto la fuerza máxima."

**15.4 Valor: (B) 100 kg/cm²** (con 40/18).

> "La presión de trabajo es 79,6 kg/cm² más pérdidas; ajusto a 100 kg/cm², ≈ 25 % por encima, lo que limita la fuerza máxima a $100\cdot12{,}56=1256$ kg (1,26 × la nominal) y protege el brazo contra sobrecargas. 95 deja poco margen sobre trabajo + pérdidas. 145 solo protegería la bomba: permitiría 1821 kg (1,8 × la nominal) sobre el mecanismo."

⚠️ Si se eligió 32/22, el valor coherente es **145**: con 95 o 100 el cilindro no levantaría la carga.

**Potencia:** $100\cdot5{,}34/600/0{,}85\approx1{,}05$ kW → motor ≈ 1,1 kW ⚠️.

**Dónde se pierden puntos:**

- invertir $A_1$/$A_3$ (Avanzini);
- verificar el lado vástago con retorno por peso propio;
- no aplicar $\eta_v$;
- no justificar el valor de ajuste (es la mitad del ítem);
- contestar "la bomba" en el ítem 14.

---

### §7.3 TP3 2025, ítem 6

**Datos:** 480 kg en extensión, 270 kg en retracción; presión máxima del sistema 70 kg/cm²; catálogo CD70; motor 3×380/220 V, **1500 rpm**, IP54, acople directo; carrera 300 mm; tiempo **máximo** 60 s.

**A. Cilindro** (las dos direcciones cargan → verificar $A_1$ y $A_3$):

| Opción | $A_1$ | $p_{ext}=480/A_1$ | $A_3$ | $p_{ret}=270/A_3$ | ¿< 70? |
|---|---|---|---|---|---|
| 25×16 | 4,91 | **97,8** | 2,90 | 93,1 | ✗ |
| **32×18** | 8,04 | **59,7** | 5,50 | **49,1** | ✓ |
| 40×25 | 12,56 | 38,2 | 7,65 | 35,3 | ✓ (sobredimensionado) |

- Con la tabla a 70 bar: 32 lado pistón 5,63 kN = 574 kgf ≥ 480 ✓; 32/18 lado vástago 3,84 kN = 392 kgf ≥ 270 ✓.
- Carrera máx. Ø32 = 800 ≥ 300 ✓.

> "Selecciono **32×18** (B): cumple en los dos sentidos con margen (60 y 49 kg/cm² < 70). El 40×25 también cumple pero está sobredimensionado: más caudal, bomba y costo."

**B. Bomba.**

- $V=8{,}04\cdot30=241$ cm³ → $Q=241/60=4{,}02$ cm³/s = 0,24 l/min.
- $V_g$ = 0,16 cm³/rev (a 1500 rpm), 0,18 con $\eta_v$ y 1450 rpm.
- La más chica del catálogo es **AZPB 1,0 cm³/rev**: $Q_{real}$ = 1,0·1450·0,92 = 1,33 l/min = 22,2 cm³/s → extensión **10,9 s** y retracción **7,4 s**, ambas **< 60 s ✓** (máximo).
- Con 1500 rpm sin $\eta_v$: 9,6 s.
- Usar las 1500 rpm del enunciado o aclarar el resbalamiento (≈ 1450–1480 reales) ⚠️.

> "Como el requisito es un tiempo **máximo**, la bomba de menor cilindrada disponible lo cumple holgadamente. **No** se modifica el dato del enunciado (error de una resolución que supuso 6 s)."

**C. Verificación del caudal.**

> "La bomba entrega ≈ 22 cm³/s, 5,5 veces el mínimo de 4,0 cm³/s ✓. Para comprobarlo en el equipo: **caudalímetro** en la línea de presión, o **cronometrar la carrera** y calcular $Q=A_1\,L/t$ (se esperan ≈ 11 s de extensión). ⚠️ Otra opción práctica: medir el volumen descargado en un recipiente graduado en un tiempo dado."

**D. Otros elementos.**

> Limitadora de presión después de la bomba (ajuste ≈ 70 kg/cm², la máxima del sistema; > 59,7 de trabajo) con manómetro; **reguladoras de caudal con antirretorno** para ajustar la velocidad (si se quisiera llevar la carrera a 60 s, con la desventaja de que el excedente vuelve por la limitadora como calor: ≈ 0,13 kW); antirretorno a la salida de la bomba; presostato si hace falta una señal; filtro de retorno.

**E. Circuito eléctrico:** **§5.1** (parada a mitad de carrera, 150 mm, con autorretención por pulsador no retenido).

**Dónde se pierden puntos:** verificar un solo sentido; cambiar el dato de 60 s; decir que la bomba "da presión" (ítem 3 de Martina).

---

### §7.4 Parcial Makro / autoelevadores (equipos A y B)

#### Antes de calcular: las ambigüedades y cómo justificarlas

**Carga máxima por ciclo:**

| Lectura | A | B | Argumento |
|---|---|---|---|
| **Capacidad de levante (adoptada)** | **3000 kg** | **990 kg** | es lo que el equipo debe poder levantar; cubre el caso del pallet con margen |
| Carga dinámica máx. del pallet | 1500 kg | (990) | el pallet limita lo que se mueve **por ciclo** |
| "Peso operativo" con la anotación del profe **[Máxima carga]** | 4300 kg | 990 kg | el profe anotó "[Máxima carga]" al lado de "Peso operativo" **en las dos tablas**. En B coincide con la capacidad; en A es el peso de la máquina (Lonking: 4300 kg operativo, 3000 kg de capacidad) ⚠️ |

Con tiro directo y 150 kg/cm², A da Ø40 (1500 kg, 119,4), **Ø63 (3000 kg, 96,2)** o Ø63 (4300 kg, 138,0).

> "Adopto como carga máxima por ciclo la capacidad de levante del equipo, 3000 kg, que es la condición más exigente compatible con el uso (el pallet admite 1500 kg dinámicos, de modo que el equipo queda cubierto aunque levante un pallet al límite). El peso de horquillas y carro no se conoce y se desprecia ⚠️. Si se tomara la anotación '[Máxima carga] 4300 kg', con el mismo Ø63 la presión subiría a 138 kg/cm², todavía < 150."

**Otras definiciones** (todas ⚠️):

- **Carrera** = 1600 − 120 = **1480 mm**. El profe corrigió A a 1600 mm de altura máxima y 120 mm de despeje, los mismos valores que la elevación 0,12–1,6 m de B: se interpreta que el recorrido útil es 1,48 m. Si se toma 1600 mm, los resultados casi no cambian.
- **Velocidad:** "5 / 6 m/min (carga / descarga)". En las fichas de autoelevadores es elevación **con carga / sin carga**. Se diseña con **5 m/min con carga**; los 6 m/min se usan como velocidad máxima de bajada.
- **Mástil:** en los autoelevadores reales el mástil suele ser 2:1 con cadenas: el cilindro recorre la mitad con el doble de fuerza (práctica industrial, no está en el material de la cátedra). Se resuelve en **tiro directo** (lectura del enunciado: "el cilindro trabaja vertical") y se muestra el 2:1 en una tabla.
- **Área** (ítem 3): vertical, la carga siempre hacia abajo → **lado pistón $A_1$** para subir; la bajada por peso propio, regulada con reguladora de caudal en A. El lado vástago no carga.
- **Presiones:** A: 14,71 MPa = **150 kg/cm²**; B: 10 MPa = **102 kg/cm²** (≈ 100 bar, el valor de la nota del ítem 7.2).
- **$\eta_v$** = 0,92 (el valor dado en 2025) ⚠️.

#### Equipo A: autoelevador de descarga de camiones (motor a gas)

**Cilindro.**

- $A_{nec}=3000/150=20{,}0$ cm². Ø50 tiene 19,63 cm² (no alcanza: daría 152,8 > 150) → **Ø63** ($A_1$ = 31,17) → $p$ = **96,2 kg/cm²**.
- **Pandeo:** carrera larga (148 cm). Carga guiada por el mástil y cilindro articulado en los extremos → **caso 2** ⚠️, $S_k$ = $l$ ≈ 148 cm. 63/28 → 964 kgf ✗; **63/45 → 6434 kgf ✓** (caso 3: 63/28 da 1929 ✗ igual).
- → **63/45/1480**.

**Caudal.** $Q=31{,}17\cdot500=15\,585$ cm³/min = **15,6 l/min**.

**rpm** (⚠️ adoptado):

- La bomba la mueve el **motor de combustión** (Nissan K21, 50 HP), no un motor de 50 Hz.
- Un motor de autoelevador trabaja aproximadamente entre ralentí (~800 rpm) y ~2500–2700 rpm ⚠️ (orden de magnitud, no es dato del enunciado). Para levantar, el operador acelera.
- Adopto **2500 rpm**.

**Bomba.**

- $V_g=15\,585/(2500\cdot0{,}92)=6{,}78$ → **AZPB 7,1 cm³/rev**.
- $Q_{real}$ = 16,3 l/min → **5,24 m/min** ✓; subida de 1,48 m en ≈ 17 s.
- Catálogo: 150 kg/cm² < p1 = **200 bar** (el 7,1 tiene p1 menor) ✓; 2500 < 3500 rpm ✓.
- A 1500 rpm haría falta 11,3 cm³/rev (no hay en el catálogo): por eso hay que justificar la rpm. En ralentí (800 rpm) la misma bomba daría 1,7 m/min.

**Potencia:** $150\cdot16{,}3/600=4{,}1$ kW → / 0,85 ⚠️ ≈ **4,8 kW (≈ 6,5 CV)**, muy por debajo de los 50 HP del motor ✓ (que además mueve la tracción).

**Variante 2:1:**

| Dato | Tiro directo | Mástil 2:1 ⚠️ |
|---|---|---|
| Fuerza en el cilindro | 3000 kg | 6000 kg |
| Carrera | 1480 mm | 740 mm |
| Velocidad del cilindro | 5 m/min | 2,5 m/min |
| Pistón (p) | Ø63 (96,2) | Ø80 (119,4) |
| Vástago por pandeo (caso 2) | 45 (6434 kgf) | 36 (10 542 kgf) |
| Caudal | 15,6 l/min | 12,6 l/min |
| Bomba a 2500 rpm | AZPB 7,1 → 16,3 l/min | AZPB 6,3 → 14,5 l/min (carga a 5,8 m/min) |

**Limitadora** (dos valores defendibles; elegí uno y justificalo):

- **≈ 120 kg/cm²** ⚠️ recomendado: trabajo 96 + 25 %. Limita la fuerza a $120\cdot31{,}17\approx3740$ kg = 1,25 × la capacidad. En un autoelevador impide levantar sobrecargas que comprometan la estabilidad (vuelco), y queda < 150 ✓.
- **150 kg/cm²**: la presión del equipo dada en el enunciado (criterio de 2025). Protege bomba y componentes, pero deja levantar hasta 4675 kg (1,56×).

**Esquema** (ítem 4):

- base de Makro p. 6 con **4/3 opción 5 (recirculación en la posición central = tándem)**, justificada como en §3.4;
- **reguladora de caudal con antirretorno en A** para la bajada (≤ 6 m/min);
- **cilindro con amortiguación regulable**;
- opcional: antirretorno pilotado en A (§3.6).

**Llegada lenta** (5.5): §3.5.

**Tuberías** (ítem 7):

- **Presión** (150 kg/cm² → 3–12 m/s): $Q$ = 16,3 l/min → **12×1,5** ($d_7$ = 9 mm, PN 315): $v$ = 4,3 m/s ✓.
- **Retorno** (bajada a 6 m/min: $Q=31{,}17\cdot600=18{,}7$ l/min, 2–4 m/s) → **15×2** ($d_7$ = 11, PN 315): 3,3 m/s ✓.
- **Succión** (0,5–0,8 m/s) → **28×2,5** ($d_7$ = 23): 0,66 m/s ✓.

**Resumen (ítem 5):**

| Dato | Equipo A |
|---|---|
| Carga estimada | 3000 kg (capacidad; pallet ≤ 1500) |
| Presión adoptada bomba | 150 kg/cm² (14,71 MPa) |
| Cilindro | 63 × 45 / 1480 mm, tiro directo, con amortiguación |
| Velocidad / tiempo | 5,24 m/min / ≈ 17 s de subida |
| Bomba | AZPB 7,1 cm³/rev a 2500 rpm ⚠️ (motor a gas) |
| Limitadora | 120 kg/cm² (máx. 150) |
| Extremos | amortiguación regulable + reguladora de caudal con antirretorno en A |

#### Equipo B: autoelevador en góndolas (motor eléctrico a baterías)

**Cilindro.**

- $A_{nec}=990/102=9{,}71$ cm² → **Ø40** ($A_1$ = 12,56) → $p$ = **78,8 kg/cm²**.
- **Pandeo** ($l$ ≈ 148 cm):
  - 40/18: 165 kgf (caso 2) ✗.
  - 40/28: 964 kgf en caso 2 (✗, justo por debajo de 990) y **1929 kgf en caso 3** ✓.
  - Con el carro guiado por el mástil se adopta **caso 3** ⚠️ → **40/28/1480**.
  - Si la cátedra toma caso 2: **50/36** (2636 kgf ✓, 50,4 kg/cm²), con más caudal (19,6 l/min).

**rpm** (⚠️ adoptado): motor de corriente continua alimentado por baterías, del orden de 2500–3000 rpm ⚠️. Adopto **2800 rpm**.

**Bomba.**

- $Q=12{,}56\cdot1000=12\,560$ cm³/min = **12,6 l/min**.
- $V_g=12\,560/(2800\cdot0{,}92)=4{,}88$ → **AZPB 5,0**.
- $Q_{real}$ = 12,9 l/min → **10,25 m/min** ✓ (subida en ≈ 8,7 s).
- 78,8 < 220 ✓; 2800 < 4000 ✓.

**Potencia:** $100\cdot12{,}9/600=2{,}15$ kW → / 0,85 ≈ **2,5 kW** ⚠️.

**Limitadora:** **100 bar** (nota del enunciado; ≈ 10 MPa de trabajo del equipo):

- > 78,8 de trabajo ✓; < 220 ✓;
- limita la fuerza a $100\cdot12{,}56=1256$ kg (1,27 ×) ✓: cumple **los dos criterios**;
- manómetro con escala que permita ver 100 (p. ej. 0–160 ⚠️).

**Variante 2:1** ⚠️: 1980 kg, 740 mm. Ø50 daría 100,9 kg/cm²: **no** sirve con la limitadora a 100 → Ø63 (63,5 kg/cm²; 63/28 caso 2 a 74 cm: 3858 kgf ✓) → 15,6 l/min → AZPB 6,3 a 2800 rpm → carga a 10,4 m/min.

**Tuberías** (100 bar → 2–4 m/s):

- **Presión:** 12,9 l/min → **12×1,5** ($d_7$ = 9, PN 315): 3,4 m/s ✓.
- **Retorno** (bajada a 12 m/min: 15,1 l/min) → **15×2,5** ($d_7$ = 10): 3,2 m/s ✓.
- **Succión:** **28×2,5**: 0,52 m/s ✓.

**Resumen:**

| Dato | Equipo B |
|---|---|
| Carga estimada | 990 kg |
| Presión adoptada bomba | ≈ 100 kg/cm² (10 MPa) |
| Cilindro | 40 × 28 / 1480 mm (caso 3) |
| Velocidad / tiempo | 10,25 m/min / ≈ 8,7 s |
| Bomba | AZPB 5,0 cm³/rev a 2800 rpm ⚠️ (motor CC) |
| Limitadora | 100 bar |
| Extremos | amortiguación regulable + reguladora de caudal con antirretorno en A |

**Ítem 6 (7.1): lista de elementos y función.** La tabla de §3.1 completada con los números de A o B.

**Dónde se pierden puntos en Makro:**

- no **definir y justificar la carga** (es lo primero que pide);
- no justificar las rpm (para A es imposible con 1500 rpm);
- elegir el centro sin argumento de operación y seguridad;
- olvidar la llegada lenta (vale en el 5.5 y en el esquema);
- dejar el ajuste sin número;
- elegir tubos por diámetro exterior o sin verificar PN.


---

## §8. Variantes numéricas para practicar el procedimiento

Tapá la solución, resolvé con §1 y compará. Catálogos: tabla de cilindros de §2.1 (dossier §4.1) y AZPB. $\eta_v$ = 0,92 en todas.

### Variante 1: doble efecto, motor de 4 polos

**Datos:** $F$ = 2500 kg empujando, $p$ = 160 kg/cm², carrera 400 mm, extensión en ≤ 8 s, retracción con bomba, cilindro articulado en los dos extremos, motor 1450 rpm.

<details><summary>Solución</summary>

1. $A_{nec}$ = 2500/160 = 15,63 cm² → **Ø50** ($A_1$ = 19,63) → $p$ = **127,4 kg/cm²** < 160 ✓.
2. Pandeo, caso 2, $l$ ≈ 40 cm: vástago 22 → 5032 kgf ✓ → **50/22/400** (el vástago fino da más área anular y fuerza de retracción).
3. $v$ = 40/8 = 5 cm/s → $Q$ = 19,63·5 = 98,2 cm³/s = **5,89 l/min**.
4. $V_g$ = 5890/(1450·0,92) = 4,41 → **AZPB 4,5** → $Q_{real}$ = 6,00 l/min → extensión en **7,85 s** ✓.
5. Retracción: $A_3$ = 15,83 → 6,3 s; caudal de retorno del lado pistón $6{,}0\cdot19{,}63/15{,}83=$ **7,4 l/min**.
6. Ajuste de limitadora: **160 kg/cm²** (la dada) > 127,4 ✓ < 220 ✓; $F_{máx}$ = 3141 kg (1,26×).
7. Potencia: 160·6,0/600/0,85 = 1,9 kW → **2,2 kW** ⚠️.
8. Línea de presión (3–12 m/s): **10×2** ($d_7$ = 6, PN 400) → 3,5 m/s ✓.

</details>

### Variante 2: la misma con motor de 2 polos (2900 rpm)

<details><summary>Solución</summary>

- $V_g$ = 5890/(2900·0,92) = 2,21 → **AZPB 2,5** → $Q_{real}$ = 6,67 l/min → extensión en **7,06 s** ✓; 2900 < 5000 rpm (máx. del 2,5) ✓.
- Potencia 160·6,67/600/0,85 = 2,1 kW → **2,2 kW**: el mismo motor.
- **Conclusión:** a más rpm, bomba más chica para el mismo caudal; la potencia depende de $p\cdot Q$, no de la cilindrada.

</details>

### Variante 3: simple efecto vertical, retorno por peso propio

**Datos:** $F$ = 800 kg vertical, $p$ = 100 kg/cm², carrera 300 mm, subida a 3 m/min, bajada por peso propio, motor 1450 rpm.

<details><summary>Solución</summary>

1. $A_{nec}$ = 8,0 → Ø32 ($A_1$ = 8,04) → $p$ = **99,5 kg/cm²**: **sin margen** (no quedaría lugar para pérdidas ni para ajustar la limitadora por encima del trabajo y por debajo de 100) → **Ø40** ($A_1$ = 12,56) → $p$ = **63,7 kg/cm²** ✓.
2. Pandeo caso 2, $l$ ≈ 30: vástago 18 → 4009 kgf ✓ → **40/18/300**. Lado vástago a tanque (respiradero): no se verifica por fuerza.
3. $Q$ = 12,56·300 = 3768 cm³/min = **3,77 l/min**.
4. $V_g$ = 3768/(1450·0,92) = 2,82 → **AZPB 3,15** → 4,20 l/min → **3,35 m/min**, subida en 5,4 s.
5. Bajada: la bomba no interviene; **reguladora de caudal con antirretorno en A** fija la velocidad de descenso; amortiguación abajo.
6. Ajuste ≈ **80 kg/cm²** (63,7 + 25 %) ⚠️: limita la fuerza a 1005 kg (1,26×) y queda < 100.
7. Potencia 80·4,2/600/0,85 = 0,66 kW → **0,75 kW**.
8. Esquema: puede bastar una **3/2** o una 4/3 con B tapado o a tanque; centro tándem para retener.

</details>

---

## §9. Hoja "de memoria" (no hay formulario)

### Fórmulas

| Qué | Fórmula | Unidades de cátedra |
|---|---|---|
| Presión | $p=F/A$ | kg/cm² = kg / cm² |
| Áreas | $A_1=\pi D^2/4$, $A_2=\pi d^2/4$, $A_3=A_1-A_2$, $\varphi=A_1/A_3$ | cm² con D en cm |
| Caudal del cilindro | $Q=A\,v$ | cm³/s = cm²·cm/s; ×0,06 → l/min |
| Tiempo | $t=A\,L/Q$ | s |
| Caudal de bomba | $Q=V_g\,n\,\eta_v$ | cm³/min = cm³/rev · rpm; ÷1000 → l/min |
| Cilindrada | $V_g=Q/(n\,\eta_v)$ → catálogo inmediato superior | cm³/rev |
| Retorno amplificado | $Q_{ret}=Q\,A_1/A_3$ | l/min |
| Pérdidas con $k$ | $\Delta p=\sum k\,Q^2$ | kg/cm², Q en l/min |
| Potencia | $P=p\,Q/600$; $P_{motor}=P/\eta_t$ | kW = bar · l/min / 600 |
| Fuerza máx. con el ajuste | $F_{máx}=p_{ajuste}\,A_1$ | kg |
| Velocidad en tubo | $v=4Q/(\pi d^2)$; $d=\sqrt{4Q/(\pi v)}$ | m/s, m, m³/s |
| Pandeo (Euler, cátedra) | $F_{adm}=\dfrac{10\,E\,J}{S\,S_k^2}$, $J=0{,}0491\,d^4$ | kgf, cm⁴, cm; $E=2{,}1\cdot10^6$ kgf/cm², $S=3$ |
| Pérdida en tubo | $h_f=\lambda\,\dfrac{L}{D}\,\dfrac{v^2}{2g}$ | m |
| rpm sincrónica | $n_s=60f/\text{pares de polos}$ | rpm |

### Casos de Euler

| Caso | Fijación | $S_k$ |
|---|---|---|
| 1 | libre + fijo | $2l$ |
| 2 (básico) | articulado + articulado | $l$ |
| 3 | articulado + fijo | $l/\sqrt2\approx0{,}71\,l$ |
| 4 | fijo + fijo | $l/2$ |

### Conversiones

| | Equivalencia |
|---|---|
| Presión | 1 kg/cm² ≈ 1 kp/cm² ≈ **1 bar** (exacto: 0,981 bar = 98,1 kPa); 1 bar = 10⁵ Pa = 0,1 MPa = 14,5 psi; **1 MPa = 10 bar ≈ 10,2 kg/cm²**; 1 psi = 0,069 bar; 3000 psi ≈ 207 bar |
| Caudal | **1 l/min = 16,67 cm³/s**; 1 cm³/s = 0,06 l/min; 1 m³/s = 60 000 l/min |
| Fuerza | 1 kgf = 9,81 N; **1 kN ≈ 102 kgf**; 1 t = 1000 kgf |
| Potencia | 1 CV = 0,7355 kW; 1 HP = 0,7457 kW; 1 kW ≈ 1,36 CV |
| Velocidad | 1 m/min = 1,667 cm/s; 1 cm/s = 0,6 m/min |
| Ejemplos de cátedra | 14,71 MPa = 150 kg/cm²; 10 MPa ≈ 102 kg/cm² ≈ 100 bar; 4 m/min ≈ 6,7 cm/s |

### Motores de 50 Hz

| Polos | Sincrónica | Real |
|---|---|---|
| 2 | 3000 | ≈ 2850–2950 |
| 4 | 1500 | ≈ 1420–1480 |
| 6 | 1000 | ≈ 940–970 |

⚠️ Si no las dan, adoptar 1450 (o 2900) y decirlo. El motor gira por debajo de la sincrónica por **resbalamiento**.

### Valores de las diapositivas (orden de magnitud)

**Velocidades en tuberías** (Rexroth, pág. 52):

| Línea | Velocidad |
|---|---|
| Succión | 0,5–0,8 m/s |
| Retorno | 2–4 m/s |
| Presión ≤ 100 bar | 2–4 m/s |
| Presión ≤ 315 bar | 3–12 m/s |

**Micronaje por componente** (pág. 13):

| Componente | Micronaje |
|---|---|
| Engranajes, cilindros, direccionales, válvulas de seguridad y estranguladoras | 20 µm (NAS 10, ISO 19/16) |
| Bombas de pistones o paletas, válvulas de presión, proporcionales | 10 µm (NAS 9) |
| Servoválvulas y servocilindros | 5 µm (NAS 7) |

**Parker** (pág. 49):

| Elemento | Valor |
|---|---|
| Tanque | **2–4 × Q** de bomba (por minuto) |
| Filtro de succión | 90–120 µ, 3×Q |
| Filtro de presión | 3–5 µ, 3×Q |
| Filtro de retorno con bypass | 15–25 µ, 3×Q |
| Respiro | 2×Q |
| Chicana | 2/3 del nivel |
| Aire sobre el aceite | 20 % |

**Cilindros y amortiguación:**

- amortiguación: de **1–2 m/min a 0,2–0,3 m/min**; recomendada > **0,05 m/s** (pág. 44–45);
- sellos: NBR+PU 0,5 m/s; PTFE hasta 4 m/s (pág. 46);
- AZPB: p1 220 bar (7,1 → 200); n mín. 750; succión 0,7–3 bar **abs**.

### Orden de diseño (diapositiva de Anzola)

fluido → presión → **cilindro** → caudal → **bomba** → motor → tanque → filtros → direccionales → válvulas de control → tuberías.

### Criterio de ajuste de la limitadora

$p_{trabajo}+\Delta p<p_{ajuste}\le p_{máx}$; ≈ presión máxima dada; si no la dan, trabajo +10–25 % ⚠️.

---

## §10. Errores típicos y criterios de corrección observados

1. **"La bomba genera presión."** No: genera **caudal**; la presión la impone la carga (A3). 2020 ítems 1 y 9; Martina, TP3.
2. **Empezar por la bomba.** Se empieza por el **cilindro** (2020 ítem 14; diapositiva de Anzola).
3. **Componentes sin dato de selección.** Cada uno con **función + P + Q** (y micronaje en filtros). 2025 ítem 3: 15/25.
4. **Ajuste de la limitadora por debajo de la presión máxima dada sin justificar.** El profe: "P_ureg > P_trabajo", "≈ 130". 2025 ítem 2: 13/25. Siempre dar el **número** y el **porqué** (incluida la fuerza máxima resultante).
5. **Limitadora dibujada en serie.** Va **en derivación**, inmediatamente después de la bomba, a tanque.
6. **Procedimiento de ajuste incompleto.** Manómetro, resorte aflojado al arrancar, **cilindro a tope**, girar leyendo, contratuerca, verificar (§4.3).
7. **Presostato mal ubicado o sin valor.** En la línea donde **cambia** la presión del evento (línea A con la carga retenida) y con valor justificado con los datos (contrapresión 3–5 → ajuste ≈ 10) (§5.2). 2025 ítem 4: 17/20.
8. **Confundir $A_1$ (pistón) con $A_3$ (anular)** (Avanzini). $A_1$ es la mayor y no depende del vástago.
9. **Verificar el lado vástago cuando el retorno es por peso propio.** No hace falta.
10. **Comparar con la fuerza de la tabla sin escalar la presión** (la tabla está a 160 bar).
11. **No aplicar $\eta_v$** cuando lo dan (o no decir que no lo aplicás).
12. **No justificar las rpm** o usar un "rendimiento del motor" para bajarlas: es el resbalamiento.
13. **Cambiar un dato del enunciado** porque el resultado "da raro" (Juano, TP3: 60 s → 6 s). Un tiempo **máximo** se cumple con cualquier bomba más rápida.
14. **Elegir el centro de la 4/3 sin argumento.** Tándem: arranque en vacío + sin calentamiento + retiene.
15. **Olvidar la amortiguación** en el cilindro (el profe la agregó en rojo) y la **llegada lenta** cuando la piden.
16. **Tubos por diámetro exterior o sin verificar PN.**
17. **Retorno dimensionado con el caudal de bomba** en vez de $Q\,A_1/A_3$.
18. **Pandeo sin declarar caso ni longitud.** Decí qué caso de Euler y qué $l$ adoptás.
19. **Cifras de catálogo inventadas.** Si un dato no está en la hoja (DBD, AZPF), decí "se lee en la hoja de datos".

---

## Anexo. Temas que nunca aparecieron en un parcial (resumen)

**Contaminación, ISO 4406** (pág. 13):

- tres números: partículas > 4 / > 6 / > 14 µm por ml, en escala de clases;
- equivalencias NAS 1638 → ISO 4406: 7 = 18/16/13; 8 = 19/17/14; 9 = 20/18/15; 10 = 21/19/16; 11 = 22/20/17;
- el apunte de Martina trae otra tabla de niveles recomendados por componente: proporcionales 17/15/12; bombas de paletas y pistones 18/16/13; engranajes 19/17/14; cilindros y fluido nuevo 20/18/15.
- Agua: máximo del orden de 0,04 %.
- Ejemplo de las diapositivas: una distribuidora pasó de 8 a 45 l/min de fuga por aceite en mal estado.

**Sellos** (Atos, pág. 46). Se eligen por velocidad, temperatura y tipo:

| Sistema | Material | Característica | v máx. | Temp. |
|---|---|---|---|---|
| 1 | NBR + poliuretano | alto sellado estático y dinámico | 0,5 m/s | −20 a 85 °C |
| 2 | FKM + PTFE | muy baja fricción, altas temperaturas | 4 m/s | −20 a 120 °C |
| 4 | NBR + PTFE | muy baja fricción, alta velocidad | 4 m/s | −20 a 85 °C |
| 6 a 8 | NBR + PTFE | simple efecto, muy baja fricción | 1 m/s | −20 a 85 °C |
| 8 | PTFE + NBR + poliuretano | baja fricción | 0,5 m/s | −20 a 85 °C |

- NBR = Buna-N/Perbunan; FKM = Viton; PTFE = teflón.
- Daños: desgaste, extrusión, efecto Diesel.
- Tipos: retenes con alma de acero, Polypak, chevrones.

**Acumuladores** (pág. 53–54):

- Tipos: **vejiga** (el más común, respuesta rápida), **pistón** (altas presiones, robusto), **membrana** (compacto, volúmenes chicos), de peso o resorte (raros, grandes).
- Precarga $p_0$ con **nitrógeno** (equipo de carga desde botella con reductor).
- Volumen útil $\Delta V=V_1-V_2$ entre la presión mínima y la máxima.
- Bloque de seguridad con llave de corte, descarga a tanque, limitadora y manómetro.
- Usos: estabilizar presión, amortiguar pulsaciones, caudal de punta o de emergencia.

**Depósito en detalle** (pág. 48): unidad numerada 1–15:

1. nivel;
2. respiradero con filtro;
3. detector de nivel (boya);
4. detector de temperatura;
5. motor trifásico;
6. bomba;
7. manómetro;
8. distribuidor;
9. válvula de seguridad;
10. salida a la instalación;
11. retorno;
12. refrigerador;
13. agua fría con distribuidor;
14. detector de temperatura para el distribuidor;
15. filtro.

Tanque de compensación en cilindros grandes (Yacyretá, IMPSA): absorbe la diferencia de volumen entre las cámaras.

**Bombas en detalle** (pág. 20–22):

- **Tornillo:** 3000–5000 rpm, ≤ 180 bar, caudal continuo y bajo ruido.
- **Pistones axiales de placa inclinada:** el ángulo de la placa define la carrera; reversible; transmisiones hidrostáticas; bomba o motor.
- **Eje inclinado:** variable modificando el ángulo del eje.
- **Radiales:** altas presiones (hasta ≈ 630 bar en algunos tipos), caudal variable.
- Acople bomba-motor por **linterna** y acoplamiento elástico.

**Tuberías, montaje:**

- tubos de acero (inoxidable 304L en obras);
- racores de anillo cortante DIN 3861 / ISO 8434-1 (VOSS), niples para soldar con O-ring, bridas SAE;
- prueba de presión;
- distancia máxima entre fijaciones (Rexroth): Ø 8–20 mm → 1000 mm; Ø 20–48,3 → 1500 mm; > 48,3 → 3000 mm;
- mangueras: respetar el radio mínimo de curvatura;
- ábaco de longitudes equivalentes de accesorios (pág. 51).

**Válvulas en detalle:**

- montaje sobre placa base ISO 4401 (CETOP), en bloque (manifold), en línea o cartucho;
- puntos de medición Stauff Test 20, M16 (pág. 32);
- limitadoras pilotadas para caudales grandes;
- direccionales precomandadas (4WEH) y proporcionales (4WRKE, con realimentación de posición) para tamaños grandes.
