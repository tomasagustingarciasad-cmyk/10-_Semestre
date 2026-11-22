"""
TP9 Robótica II (FI-UNCuyo) - Biodigestor automatizado para el Centro Verde de Guaymallén
Simulación didáctica del sistema térmico, biológico y de control (lógica que correría en el ESP32).

Escenarios (60 días de invierno, junio-julio en Mendoza):
  A) Tanque sin aislación y sin control (alimentación fija)
  B) Tanque aislado, sin calefacción ni control
  C) Tanque aislado + colector solar + resistencia de respaldo + control ESP32
     (temperatura, alimentación según pH, válvula de gas, riego con biol)

Modelo biológico simplificado de dos etapas:
  X: sólidos volátiles degradables (kg)   -> hidrólisis/acidogénesis -> A: ácidos grasos volátiles (kg)
  A -> metanogénesis (Monod, muy sensible a la temperatura e inhibida por pH bajo) -> biogás
  pH estimado empíricamente a partir de la concentración de AGV.
  La inhibición por pH usa la forma del modelo ADM1 (IWA): I = exp(-3·((pH-pH_UL)/(pH_UL-pH_LL))^2)
  para pH < pH_UL, con pH_UL = 7,0 y pH_LL = 6,0 (valores por defecto para metanogénicas acetoclásticas).
  Esto reproduce el "agriado": más ácidos -> menos metanogénesis -> todavía más ácidos.
Los parámetros son de orden de magnitud bibliográfico: el modelo sirve para comparar escenarios,
no para predecir valores exactos.
"""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import json, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "figuras")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

# ---------------- Parámetros de diseño ----------------
DT_MIN = 5                       # paso de simulación [min]
DIAS = 60
N = DIAS * 24 * 60 // DT_MIN
dt_d = DT_MIN / 1440.0           # paso en días
dt_s = DT_MIN * 60.0             # paso en segundos

V_LIQ = 0.80                     # m3 de mezcla en un tanque de 1000 L
M_LIQ = V_LIQ * 1000             # kg
CP = 4186.0                      # J/kgK
C_TERM = M_LIQ * CP              # J/K

RESIDUO_KG_D = 6.0               # kg/d de residuos (huerta + comedor del personal)
ST, SV = 0.18, 0.82              # fracción sólidos totales / volátiles
SV_IN = RESIDUO_KG_D * ST * SV   # kg SV/d (~0.89)
AGUA_L_D = 6.0                   # dilución 1:1
Q_IN = (RESIDUO_KG_D + AGUA_L_D) / 1000.0   # m3/d de carga (~12 L/d)
TRH = V_LIQ / Q_IN               # tiempo de retención hidráulico [d]

Y_BIOGAS = 0.55                  # m3 biogás / kg AGV (expresado como SV) convertido
KH35, TH_H = 0.25, 0.06          # hidrólisis 1/d a 35 °C y sensibilidad térmica
VM35, TH_M = 2.0, 0.08           # capacidad metanogénica kg/d a 35 °C y sensibilidad
KS = 0.5                         # kg
PH_UL, PH_LL = 7.0, 6.0          # límites de inhibición por pH (ADM1, acetoclásticas)

# Térmico
UA_SIN = 25.0                    # W/K tanque plástico expuesto
UA_AISL = 2.5                    # W/K con 100 mm de aislación + cubierta
A_COL, ETA_COL = 1.5, 0.45       # colector solar m2 / rendimiento medio
P_RES = 500.0                    # W resistencia de respaldo
T_SET = 33.0                     # °C consigna (mesofílico)
HIST = 1.0                       # °C histéresis de la resistencia (ON < 32 °C, OFF > 33 °C)
T_SOL_MAX = T_SET + 2            # °C la bomba solar sigue hasta 35 °C para acumular calor gratis

# Gas y riego
GASOM = 0.60                     # m3 bolsa gasómetro
QUEMADOR = 0.35                  # m3/h consumo anafe
BIOL_TANQUE = 200.0              # L
BOMBA_RIEGO = 10.0               # L/min

def ambiente(t_d):
    """Temperatura ambiente invernal de Mendoza (media ~8 °C, amplitud diaria ~7 °C) + frentes fríos."""
    h = (t_d % 1) * 24
    base = 8.0 + 7.0 * np.sin(2 * np.pi * (h - 9) / 24)
    frente = -5.0 if (18 <= t_d < 22) or (41 <= t_d < 44) else 0.0
    return base + frente

# índice de claridad diario del cielo (1 = despejado, valores bajos = nublado)
claridad = np.clip(rng.normal(0.85, 0.15, DIAS + 1), 0.25, 1.0)
claridad[18:22] = 0.3; claridad[41:44] = 0.35

def irradiancia(t_d):
    """W/m2 sobre el colector inclinado (invierno, pico ~650 W/m2)."""
    h = (t_d % 1) * 24
    if 8.5 <= h <= 18.0:
        return 650 * np.sin(np.pi * (h - 8.5) / 9.5) * claridad[int(t_d)]
    return 0.0

def carga_factor(dia):
    """Días 30-34: jornada de visitas con muchos residuos (x2.5)."""
    return 2.5 if 30 <= dia < 35 else 1.0

def ph_de(A):
    a = A / V_LIQ
    return 7.4 - 2.0 * a / (a + 4.0)

def inhib_ph(pH):
    """Factor de inhibición de la metanogénesis por pH (1 = sin inhibición), forma ADM1."""
    if pH >= PH_UL:
        return 1.0
    return float(np.exp(-3.0 * ((pH - PH_UL) / (PH_UL - PH_LL)) ** 2))

def simular(esc):
    ua = UA_SIN if esc == "A" else UA_AISL
    controlado = esc == "C"
    T = 30.0
    # estado inicial: régimen a 30 °C
    kh = KH35 * np.exp(TH_H * (T - 35)); X = SV_IN / (1 / TRH + kh)
    A = 0.4
    gas = 0.3; biol = 80.0
    res_on = bomba_sol = False
    alimentacion_frac = 1.0
    log = {k: [] for k in ["t", "T", "Ta", "pH", "gas_rate", "gas_store", "res", "sol", "biol", "riego", "feed", "cook"]}
    diario = {k: np.zeros(DIAS) for k in ["biogas", "e_res_kwh", "e_sol_kwh", "cocina_min", "venteo", "feed_kg", "riego_L"]}
    regando = False
    for i in range(N):
        t = i * dt_d; dia = int(t); h = (t % 1) * 24
        Ta = ambiente(t)
        pH = ph_de(A)
        # ---------- lógica del controlador ESP32 ----------
        if controlado:
            # temperatura: solar primero (diferencial), resistencia de respaldo
            G = irradiancia(t)
            t_col = Ta + G * 0.06            # estimación temp. colector
            bomba_sol = (T < T_SOL_MAX) and (t_col > T + 5)
            if T < T_SET - HIST and not bomba_sol: res_on = True
            if T > T_SET or bomba_sol: res_on = False
            # alimentación según pH (el operario recibe la indicación en pantalla)
            if pH < 6.5: alimentacion_frac = 0.0
            elif pH < 6.8: alimentacion_frac = 0.5
            else: alimentacion_frac = 1.0
        else:
            bomba_sol = res_on = False; G = irradiancia(t)
        # ---------- alimentación: una carga diaria a las 9:00 ----------
        feed_sv = 0.0; feed_m3 = 0.0
        if abs(h - 9.0) < DT_MIN / 120:
            f = carga_factor(dia) * alimentacion_frac
            feed_sv = SV_IN * f; feed_m3 = Q_IN * f
            diario["feed_kg"][dia] += RESIDUO_KG_D * f
        # ---------- balance térmico ----------
        q_sol = A_COL * ETA_COL * G if bomba_sol else 0.0
        q_res = P_RES if res_on else 0.0
        q_perd = ua * (T - Ta)
        T += (q_sol + q_res - q_perd) * dt_s / C_TERM
        if feed_m3 > 0:   # mezcla con carga a temperatura ambiente
            m = feed_m3 * 1000; T = (T * M_LIQ + Ta * m) / (M_LIQ + m)
        # ---------- biología ----------
        kh = KH35 * np.exp(TH_H * min(T - 35, 3))
        vm = VM35 * np.exp(TH_M * min(T - 35, 3))
        r_h = kh * X
        r_m = vm * A / (KS + A) * inhib_ph(pH)
        D = Q_IN * (carga_factor(dia) * (alimentacion_frac if controlado else 1)) / V_LIQ
        X += feed_sv + (-r_h - D * X) * dt_d
        A += (r_h - r_m - D * A) * dt_d
        A = max(A, 0)
        g = Y_BIOGAS * r_m * dt_d                 # m3 en el paso
        diario["biogas"][dia] += g
        gas += g
        if gas > GASOM:
            diario["venteo"][dia] += gas - GASOM; gas = GASOM   # sello hidráulico / alivio
        # ---------- cocina: 11:30-13:30 si hay gas (válvula habilitada por ESP32) ----------
        cook = False
        if 11.5 <= h < 13.5 and gas > 0.03:
            uso = QUEMADOR * DT_MIN / 60
            if gas - uso > 0.02:
                gas -= uso; cook = True; diario["cocina_min"][dia] += DT_MIN
        # ---------- biol y riego ----------
        if feed_m3 > 0:
            biol = min(BIOL_TANQUE, biol + feed_m3 * 1000)
        riego = False
        if controlado:
            if (abs(h - 8.0) < DT_MIN / 120 and biol > 0.5 * BIOL_TANQUE) or biol > 0.9 * BIOL_TANQUE:
                regando = True
            if biol <= 0.2 * BIOL_TANQUE: regando = False
            if regando:
                v = BOMBA_RIEGO * DT_MIN; biol -= v; riego = True; diario["riego_L"][dia] += v
        diario["e_res_kwh"][dia] += q_res * dt_s / 3.6e6
        diario["e_sol_kwh"][dia] += q_sol * dt_s / 3.6e6
        if i % 6 == 0:
            for k, v in zip(log.keys(), [t, T, Ta, pH, Y_BIOGAS * r_m, gas, res_on, bomba_sol, biol, riego, feed_sv, cook]):
                log[k].append(v)
    return {k: np.array(v) for k, v in log.items()}, diario

res = {e: simular(e) for e in "ABC"}
nombres = {"A": "A: sin aislación ni control", "B": "B: aislado, sin control", "C": "C: aislado + control ESP32"}
col = {"A": "#c0392b", "B": "#e67e22", "C": "#1e8449"}
plt.rcParams.update({"font.size": 10, "axes.grid": True, "grid.alpha": 0.3})

# Fig 1: temperatura
fig, ax = plt.subplots(figsize=(9, 4))
ax.plot(res["A"][0]["t"], res["A"][0]["Ta"], color="#95a5a6", lw=0.5, label="Ambiente")
for e in "ABC":
    ax.plot(res[e][0]["t"], res[e][0]["T"], color=col[e], lw=1.6, label=nombres[e])
ax.axhline(T_SET, ls="--", color="k", lw=0.8); ax.text(0.5, T_SET + 2.6, "Consigna 33 °C", fontsize=8)
ax.axvspan(18, 22, color="#3498db", alpha=0.08); ax.axvspan(41, 44, color="#3498db", alpha=0.08)
ax.set_xlabel("Día"); ax.set_ylabel("Temperatura [°C]"); ax.set_title("Temperatura del digestor en invierno")
ax.legend(loc="lower left", fontsize=8, ncol=2); fig.tight_layout(); fig.savefig(f"{OUT}/fig1_temperatura.png", dpi=160)

# Fig 2: biogás diario
fig, ax = plt.subplots(figsize=(9, 4))
d = np.arange(DIAS)
for e in "ABC":
    ax.plot(d, res[e][1]["biogas"] * 1000, color=col[e], lw=1.8, marker="o", ms=2.5, label=nombres[e])
ax.axvspan(30, 35, color="#8e44ad", alpha=0.08); ax.text(23.5, 0.60, "Jornada de visitas\n(carga x2,5)", fontsize=8, transform=ax.get_xaxis_transform())
ax.set_xlabel("Día"); ax.set_ylabel("Biogás [L/día]"); ax.set_title("Producción diaria de biogás")
ax.legend(fontsize=8); fig.tight_layout(); fig.savefig(f"{OUT}/fig2_biogas.png", dpi=160)

# Fig 3: pH
fig, ax = plt.subplots(figsize=(9, 4))
for e in "ABC":
    ax.plot(res[e][0]["t"], res[e][0]["pH"], color=col[e], lw=1.6, label=nombres[e])
ax.axhline(6.8, ls="--", color="#e67e22", lw=0.8); ax.axhline(6.5, ls="--", color="#c0392b", lw=0.8)
ax.text(0.5, 6.82, "Alerta: reducir carga 50 %", fontsize=8); ax.text(0.5, 6.42, "Alarma: no alimentar", fontsize=8)
ax.set_ylim(5.5, 7.6); ax.set_xlabel("Día"); ax.set_ylabel("pH"); ax.set_title("pH estimado del digestor")
ax.legend(fontsize=8, loc="lower left"); fig.tight_layout(); fig.savefig(f"{OUT}/fig3_ph.png", dpi=160)

# Fig 4: actuadores escenario C (zoom días 15-25)
lg = res["C"][0]; m = (lg["t"] >= 15) & (lg["t"] < 25)
fig, axs = plt.subplots(3, 1, figsize=(9, 6), sharex=True)
axs[0].plot(lg["t"][m], lg["T"][m], color=col["C"]); axs[0].axhline(T_SET, ls="--", color="k", lw=0.8)
axs[0].set_ylabel("T [°C]"); axs[0].set_title("Escenario C: acción del controlador (días 15 a 25, incluye frente frío)")
axs[1].fill_between(lg["t"][m], 0, lg["sol"][m] * 1.0, step="post", color="#f1c40f", label="Bomba solar")
axs[1].fill_between(lg["t"][m], 0, lg["res"][m] * 0.6, step="post", color="#c0392b", alpha=0.8, label="Resistencia")
axs[1].set_yticks([]); axs[1].legend(fontsize=8, loc="upper right"); axs[1].set_ylabel("Actuadores")
axs[2].plot(lg["t"][m], lg["gas_store"][m] * 1000, color="#2c3e50"); axs[2].set_ylabel("Gasómetro [L]")
axs[2].set_xlabel("Día"); fig.tight_layout(); fig.savefig(f"{OUT}/fig4_control.png", dpi=160)

# Fig 5: biol y riego
fig, ax = plt.subplots(figsize=(9, 3.4))
ax.plot(lg["t"], lg["biol"], color="#8e5a2b", lw=1.2, label="Nivel tanque de biol")
ax.axhline(0.9 * BIOL_TANQUE, ls="--", color="#c0392b", lw=0.8); ax.axhline(0.2 * BIOL_TANQUE, ls="--", color="#2980b9", lw=0.8)
ax.set_xlabel("Día"); ax.set_ylabel("Litros"); ax.set_title("Escenario C: control de nivel de biol y riego de la huerta")
ax.legend(fontsize=8); fig.tight_layout(); fig.savefig(f"{OUT}/fig5_biol.png", dpi=160)

# KPIs
kpi = {}
for e in "ABC":
    lg, di = res[e]
    m10 = lg["t"] >= 10      # indicadores medios y mínimos: desde el día 10 (sin el transitorio inicial)
    kpi[e] = {
        "T_media": round(float(lg["T"][m10].mean()), 1),
        "T_min": round(float(lg["T"][m10].min()), 1),
        "T_max": round(float(lg["T"][m10].max()), 1),
        "biogas_L_dia": round(float(di["biogas"][10:].mean() * 1000)),
        "biogas_total_m3": round(float(di["biogas"].sum()), 1),          # total 60 días
        "pH_min": round(float(lg["pH"][m10].min()), 2),
        "cocina_min_dia": round(float(di["cocina_min"][10:].mean())),
        "e_res_kwh_dia": round(float(di["e_res_kwh"][10:].mean()), 2),
        "e_sol_kwh_dia": round(float(di["e_sol_kwh"][10:].mean()), 2),
        "riego_L_total": round(float(di["riego_L"].sum())),              # total 60 días
        "venteo_m3_total": round(float(di["venteo"].sum()), 2),          # total 60 días
        "dias_sin_cocina_post10": int((di["cocina_min"][10:] == 0).sum()),
    }
kpi["params"] = {"SV_in_kg_d": round(SV_IN, 3), "Q_in_L_d": round(Q_IN * 1000, 1), "TRH_d": round(TRH, 1),
                 "VCO_kgSV_m3d": round(SV_IN / V_LIQ, 2)}
with open(f"{OUT}/kpi.json", "w") as f:
    json.dump(kpi, f, indent=2, ensure_ascii=False)
print(json.dumps(kpi, indent=2, ensure_ascii=False))

# Series diarias para gráficos nativos de la presentación
series = {}
for e in "ABC":
    lg, di = res[e]
    dia = lg["t"].astype(int)
    series[e] = {
        "biogas_L": [round(float(v * 1000)) for v in di["biogas"]],
        "T_media": [round(float(lg["T"][dia == k].mean()), 1) for k in range(DIAS)],
        "pH_min": [round(float(lg["pH"][dia == k].min()), 2) for k in range(DIAS)],
    }
with open(f"{OUT}/series_diarias.json", "w") as f:
    json.dump(series, f)
