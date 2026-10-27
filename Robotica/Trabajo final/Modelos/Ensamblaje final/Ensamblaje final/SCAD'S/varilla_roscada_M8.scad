// ==================================================================
// Varilla roscada M8 — paramétrica
// Origen: centro de la cara inferior; la varilla crece hacia +Z.
// Abrí el Customizer (Ventana > Customizer) para cambiar los valores.
// ==================================================================

/* [Varilla] */
// Largo total (mm)
largo = 100;
// Diámetro nominal (mm)
d = 8;
// Paso (mm) — M8 grueso = 1.25, fino = 1.0
paso = 1.25;
// Chaflán en el extremo inferior
chaflan_inferior = true;
// Chaflán en el extremo superior
chaflan_superior = true;

/* [Calidad] */
// true = rosca real; false = cilindro liso (más liviano para ensambles)
roscado = true;
// Puntos del perfil por vuelta
fn_rosca = 48;
$fn = 64;

// ------------------------------------------------------------------
// Rosca métrica ISO (perfil básico, 60°, derecha) como un solo poliedro.
// Cada punto del perfil sigue su hélice, así las crestas quedan lisas.
// ------------------------------------------------------------------
// Radio del perfil básico ISO 68-1 según la fase axial u (0..P).
function _perfil_iso(u, P, d) =
    let(x = min(u, P - u), H = sqrt(3) / 2 * P)
    x <= P / 16    ? d / 2 :                              // cresta plana (P/8)
    x <= 3 * P / 8 ? d / 2 - (x - P / 16) * sqrt(3) :     // flanco a 30°
                     d / 2 - 5 * H / 8;                    // fondo plano (P/4)

// d: diámetro nominal, P: paso, L: largo
// chaf_inf / chaf_sup: chaflán a 45° hasta el diámetro de núcleo en cada punta
// fn: puntos del perfil por vuelta, pasos: anillos por vuelta
module rosca_iso(d, P, L, chaf_inf = true, chaf_sup = true, fn = 48, pasos = 24) {
    nv    = max(1, ceil(L / P * pasos));
    dz    = L / nv;
    delta = 360 * dz / P;                       // giro por anillo = sigue la hélice
    rmin  = d / 2 - 5 * sqrt(3) / 16 * P;       // radio de núcleo (d1/2)
    pts = concat(
        [ for (k = [0 : nv]) for (i = [0 : fn - 1])
            let(u  = P * i / fn,
                z  = k * dz,
                a  = 360 * i / fn + k * delta,
                rb = chaf_inf ? rmin + z       : 1e9,
                rt = chaf_sup ? rmin + (L - z) : 1e9,
                r  = min(_perfil_iso(u, P, d), rb, rt))
            [r * cos(a), r * sin(a), z] ],
        [[0, 0, 0], [0, 0, L]]);
    cb = (nv + 1) * fn;   // centro abajo
    ct = cb + 1;          // centro arriba
    caras = concat(
        [ for (k = [0 : nv - 1]) for (i = [0 : fn - 1])
            let(a = k * fn + i, b = k * fn + (i + 1) % fn,
                c = (k + 1) * fn + (i + 1) % fn, e = (k + 1) * fn + i)
            each [[a, c, b], [a, e, c]] ],
        [ for (i = [0 : fn - 1]) [cb, i, (i + 1) % fn] ],
        [ for (i = [0 : fn - 1]) [ct, nv * fn + (i + 1) % fn, nv * fn + i] ]);
    polyhedron(points = pts, faces = caras, convexity = 10);
}

color("silver")
if (roscado)
    rosca_iso(d, paso, largo, chaf_inf = chaflan_inferior, chaf_sup = chaflan_superior, fn = fn_rosca);
else {
    c = 0.6 * paso;
    ci = chaflan_inferior ? c : 0;
    cs = chaflan_superior ? c : 0;
    hull() {
        cylinder(d = d - 2 * ci, h = 0.01);
        translate([0, 0, ci]) cylinder(d = d, h = largo - ci - cs);
        translate([0, 0, largo - 0.01]) cylinder(d = d - 2 * cs, h = 0.01);
    }
}
