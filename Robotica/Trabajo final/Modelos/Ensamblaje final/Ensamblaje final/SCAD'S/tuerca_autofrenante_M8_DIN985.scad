// ==================================================================
// Tuerca autofrenante M8 con anillo de nylon — DIN 985 (ISO 10511)
// Valores por defecto según DIN 985, M8:
//   s = 13 (entre caras), e mín = 14.38 (entre vértices),
//   h = 8 (altura total), m mín = 4.7 (altura mínima de la parte roscada).
// Origen: centro de la cara de apoyo; la tuerca crece hacia +Z
// (el anillo de nylon queda arriba).
// ==================================================================

/* [Rosca] */
// Diámetro nominal (mm)
d = 8;
// Paso (mm) — M8 grueso = 1.25, fino = 1.0
paso = 1.25;

/* [Dimensiones DIN 985] */
// Entre caras (mm)
s = 13;
// Altura total h (mm)
h = 8;
// Altura de la parte hexagonal (mm) — DIN exige m ≥ 4.7; en tuercas reales ronda 5.5–6
h_hex = 6;
// Diámetro de la cara de apoyo dw (mm)
dw = 11.63;
// Diámetro del collar que encierra el nylon (mm)
d_collar = 11.8;
// Diámetro interior del anillo de nylon (≈ diámetro de núcleo)
d_nylon = 6.65;
// Espesor del borde de chapa plegado sobre el nylon (mm)
e_chapa = 0.6;

/* [Calidad] */
// true = rosca interior real; false = agujero liso de Ø d
roscado = true;
// Holgura radial de la rosca interior (mm), 0 = nominal
holgura = 0;
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

e = s / cos(30);   // entre vértices teórico

module cuerpo_hex() {
    intersection() {
        cylinder(d = e, h = h_hex, $fn = 6);
        // chaflanes de 30° en ambas caras del hexágono
        union() {
            cylinder(r1 = dw / 2, r2 = dw / 2 + h_hex / tan(30), h = h_hex);
        }
        translate([0, 0, h_hex]) mirror([0, 0, 1])
            cylinder(r1 = s / 2 * 0.98, r2 = s / 2 * 0.98 + h_hex / tan(30), h = h_hex);
    }
}

module collar() {
    // chapa que encierra el anillo de nylon, con borde superior redondeado
    r  = d_collar / 2;
    hc = h - h_hex;
    rc = hc * 0.6;   // radio del redondeo superior
    rotate_extrude()
        difference() {
            hull() {
                translate([d_nylon / 2 + 0.5, -0.01]) square([r - d_nylon / 2 - 0.5, 0.01]);
                translate([d_nylon / 2 + 0.5, hc - 0.01]) square([0.01, 0.01]);
                translate([r - rc, hc - rc]) intersection() { circle(r = rc); square(rc); }
                translate([r - 0.01, -0.01]) square([0.01, hc - rc + 0.01]);
            }
            // alojamiento del anillo de nylon
            translate([0, -1]) square([r - e_chapa, hc - e_chapa + 1]);
        }
}

module nylon() {
    hc = h - h_hex;
    translate([0, 0, h_hex])
        difference() {
            cylinder(d = d_collar - 2 * e_chapa, h = hc - e_chapa);
            translate([0, 0, -1]) cylinder(d = d_nylon, h = hc + 2);
        }
}

module agujero_roscado() {
    translate([0, 0, -1]) {
        if (roscado)
            rosca_iso(d + 2 * holgura, paso, h_hex + 2, chaf_inf = false, chaf_sup = false, fn = fn_rosca);
        else
            cylinder(d = d + 2 * holgura, h = h_hex + 2);
    }
    // avellanado de entrada (120°) en la cara de apoyo
    hav = 0.5 * paso;
    translate([0, 0, -0.01]) cylinder(d1 = d * 1.05, d2 = d * 1.05 - 2 * hav * tan(60), h = hav);
}

difference() {
    union() {
        color("silver") cuerpo_hex();
        color("silver") translate([0, 0, h_hex]) collar();
    }
    agujero_roscado();
}
color("white") nylon();
