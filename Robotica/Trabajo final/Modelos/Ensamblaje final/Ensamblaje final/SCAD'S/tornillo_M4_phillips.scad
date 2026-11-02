// ==================================================================
// Tornillo M4 cabeza cilíndrica (común) Phillips — paramétrico
// Origen: centro de la cara de apoyo de la cabeza (bajo la cabeza).
// La cabeza crece hacia +Z y el vástago hacia -Z.
// Abrí el Customizer (Ventana > Customizer) para cambiar los valores.
// ==================================================================

/* [Vástago] */
// Largo bajo cabeza (mm)
largo = 20;
// Largo roscado desde la punta (0 = rosca completa)
largo_rosca = 0;
// Diámetro nominal (mm)
d = 4;
// Paso (mm) — M4 grueso = 0.7, fino = 0.5
paso = 0.7;
// Chaflán en la punta
chaflan_punta = true;

/* [Cabeza] */
// Diámetro de cabeza (mm)
d_cabeza = 7.6;
// Altura de cabeza (mm)
h_cabeza = 3.5;
// Radio del borde superior (0 = cilindro con canto vivo)
radio_borde = 0.8;

/* [Phillips] */
phillips = true;
// Diámetro de la cruz en la cara superior (PH2 en M4 ≈ 4.4)
ph_diametro = 4.4;
// Profundidad de la cruz (mm)
ph_profundidad = 2.4;
// Ancho de cada brazo de la cruz (mm)
ph_ancho = 0.95;

/* [Calidad] */
// true = rosca real; false = cilindro liso (más liviano para ensambles)
roscado = true;
// Puntos del perfil por vuelta
fn_rosca = 40;
// Resolución de cabeza/cilindros
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

module cabeza() {
    rb = min(radio_borde, h_cabeza, d_cabeza / 2);
    rotate_extrude()
        hull() {
            square([0.01, h_cabeza]);
            square([d_cabeza / 2, 0.01]);
            square([d_cabeza / 2, h_cabeza - rb]);
            square([d_cabeza / 2 - rb, h_cabeza]);
            if (rb > 0) translate([d_cabeza / 2 - rb, h_cabeza - rb]) circle(r = rb);
        }
}

module cruz_phillips() {
    eps = 0.01;
    translate([0, 0, h_cabeza - ph_profundidad]) {
        // brazos en V
        for (a = [0, 90]) rotate([0, 0, a])
            hull() {
                translate([-ph_diametro / 2, -ph_ancho / 2, ph_profundidad - eps])
                    cube([ph_diametro, ph_ancho, 1]);
                translate([-ph_ancho / 2, -ph_ancho / 2, 0]) cube([ph_ancho, ph_ancho, eps]);
            }
        // cono central
        cylinder(d1 = 0.4, d2 = ph_diametro * 0.5, h = ph_profundidad + eps);
    }
}

module vastago() {
    lr = (largo_rosca <= 0 || largo_rosca > largo) ? largo : largo_rosca;
    translate([0, 0, -largo]) {
        if (roscado)
            // si la rosca es completa se mete 0.5 mm en la cabeza para una unión limpia
            rosca_iso(d, paso, lr + (lr == largo ? 0.5 : 0), chaf_inf = chaflan_punta, chaf_sup = false, fn = fn_rosca);
        else
            hull() {
                cylinder(d = d - (chaflan_punta ? 1.2 * paso : 0), h = 0.01);
                translate([0, 0, chaflan_punta ? 0.6 * paso : 0]) cylinder(d = d, h = lr - (chaflan_punta ? 0.6 * paso : 0));
            }
        // parte lisa (si la rosca no es completa)
        if (lr < largo) translate([0, 0, lr - 0.01]) cylinder(d = d, h = largo - lr + 0.5);
    }
}

color("silver")
difference() {
    union() {
        cabeza();
        vastago();
    }
    if (phillips) cruz_phillips();
}
