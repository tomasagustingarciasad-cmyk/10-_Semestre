extends RefCounted
## Generador de las escenas del auto (se ejecuta desde build_scenes.gd).
##
## Arma el monoplaza únicamente con primitivas 3D (BoxMesh, CylinderMesh,
## SphereMesh y TorusMesh) ubicadas y rotadas con transformaciones, y guarda:
##   - assets/setups/car_setup_default.tres  (puesta a punto)
##   - scenes/car/wheel_visual.tscn          (una rueda)
##   - scenes/car/car_visual.tscn            (carrocería)
##   - scenes/car/car_model.tscn             (carrocería + 4 ruedas fijas)
##   - scenes/car/f1_car.tscn                (auto del jugador con física)
##   - scenes/car/rival_car.tscn             (auto rival)
##   - scenes/car/ghost_car.tscn             (fantasma)
##
## El auto mira hacia -Z. Origen del modelo: centro del auto a la altura del
## fondo plano. Medidas en metros.

const Utils := preload("res://tools/godot/builder_utils.gd")

const PATH_SETUP := "res://assets/setups/car_setup_default.tres"
const PATH_WHEEL := "res://scenes/car/wheel_visual.tscn"
const PATH_BODY := "res://scenes/car/car_visual.tscn"
const PATH_MODEL := "res://scenes/car/car_model.tscn"
const PATH_PLAYER := "res://scenes/car/f1_car.tscn"
const PATH_RIVAL := "res://scenes/car/rival_car.tscn"
const PATH_GHOST := "res://scenes/car/ghost_car.tscn"

# --- Geometría general ---------------------------------------------------------
const WHEEL_RADIUS := 0.34
const FRONT_WHEEL_WIDTH := 0.32
const REAR_WHEEL_WIDTH := 0.40
const FRONT_AXLE_Z := -1.75
const REAR_AXLE_Z := 1.65
const FRONT_HALF_TRACK := 0.80
const REAR_HALF_TRACK := 0.78
## Altura del centro de las ruedas sobre el origen del modelo, en reposo.
const WHEEL_CENTER_Y := 0.26
## Altura del origen del modelo sobre el piso, en reposo.
const RIDE_HEIGHT := 0.08
## Altura del anclaje de la suspensión (posición del nodo VehicleWheel3D).
const SUSPENSION_ANCHOR_Y := 0.353

# --- Capas de colisión -----------------------------------------------------------
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_RIVALS := 4

# --- Colores (decoración original del proyecto) -----------------------------------
const COLOR_PRIMARY := Color(0.05, 0.22, 0.72)
const COLOR_SECONDARY := Color(0.96, 0.78, 0.08)
const COLOR_CARBON := Color(0.06, 0.06, 0.07)
const COLOR_TYRE := Color(0.03, 0.03, 0.03)
const COLOR_RIM := Color(0.55, 0.57, 0.6)
const COLOR_HELMET := Color(0.92, 0.92, 0.92)


# --- Compuestos de neumáticos -------------------------------------------------------
const PATH_TYRES := "res://assets/tyres/"
## id, nombre, letra, color, agarre seco/mojado, desgaste seco/mojado,
## aquaplaning inicio/total [km/h].
const TYRE_COMPOUNDS := [
	["blando", "Blando", "B", Color(0.92, 0.2, 0.2), 1.03, 0.55, 2.0, 1.0, 150.0, 220.0],
	["medio", "Medio", "M", Color(0.95, 0.8, 0.1), 1.00, 0.55, 1.0, 1.0, 150.0, 220.0],
	["duro", "Duro", "D", Color(0.92, 0.92, 0.92), 0.97, 0.55, 0.55, 1.0, 150.0, 220.0],
	["intermedio", "Intermedio", "I", Color(0.2, 0.75, 0.3), 0.88, 0.80, 2.5, 1.0, 230.0, 290.0],
	["lluvia", "Lluvia extrema", "L", Color(0.2, 0.45, 0.95), 0.78, 0.86, 4.0, 1.0, 280.0, 340.0],
]

# --- Spray (nube de agua detrás del auto) ---------------------------------------------
const SPRAY_AMOUNT := 90
const SPRAY_LIFETIME := 1.4
const SPRAY_POSITION := Vector3(0.0, 0.4, 2.7)


## Escribe un recurso TyreCompound por cada compuesto de la tabla.
static func build_tyre_compounds() -> void:
	print("Generando compuestos de neumáticos...")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH_TYRES))
	for row: Array in TYRE_COMPOUNDS:
		var compound := TyreCompound.new()
		compound.id = row[0]
		compound.display_name = row[1]
		compound.letter = row[2]
		compound.color = row[3]
		compound.grip_dry = row[4]
		compound.grip_wet = row[5]
		compound.wear_dry = row[6]
		compound.wear_wet = row[7]
		compound.aquaplaning_start_kmh = row[8]
		compound.aquaplaning_full_kmh = row[9]
		ResourceSaver.save(compound, PATH_TYRES + compound.id + ".tres")
		print("  recurso guardado: ", PATH_TYRES + compound.id + ".tres")


# Partículas de spray: una nube blanquecina que sale hacia arriba y hacia
# atrás del auto y queda flotando en el lugar (coordenadas de mundo).
static func _make_spray() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.9, 0.1, 0.3)
	process.direction = Vector3(0.0, 1.0, 0.5)
	process.spread = 28.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 8.0
	process.gravity = Vector3(0.0, -2.5, 0.0)
	process.scale_min = 1.0
	process.scale_max = 2.6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.86, 0.89, 0.93, 0.14)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.5)
	quad.material = material
	var spray := GPUParticles3D.new()
	spray.name = "Spray"
	spray.set_script(load("res://scripts/car/spray.gd"))
	spray.position = SPRAY_POSITION
	spray.amount = SPRAY_AMOUNT
	spray.lifetime = SPRAY_LIFETIME
	spray.local_coords = false
	spray.emitting = false
	spray.process_material = process
	spray.draw_pass_1 = quad
	spray.visibility_aabb = AABB(Vector3(-30.0, -5.0, -30.0), Vector3(60.0, 20.0, 60.0))
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return spray


static func build_all() -> void:
	print("Generando escenas del auto...")
	_build_setup()
	_build_wheel()
	_build_body()
	_build_model()
	_build_player()
	_build_rival()
	_build_ghost()


# ------------------------------------------------------------------------------
# Puesta a punto por defecto (incluye la curva de par)
# ------------------------------------------------------------------------------
static func _build_setup() -> void:
	var setup := CarSetup.new()
	var curve := Curve.new()
	# X = rpm / rpm_max, Y = fracción del par máximo.
	curve.add_point(Vector2(0.0, 0.50))
	curve.add_point(Vector2(0.33, 0.70))
	curve.add_point(Vector2(0.60, 0.92))
	curve.add_point(Vector2(0.80, 1.00))
	curve.add_point(Vector2(0.92, 0.97))
	curve.add_point(Vector2(1.0, 0.88))
	setup.torque_curve = curve
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH_SETUP.get_base_dir()))
	ResourceSaver.save(setup, PATH_SETUP)
	print("  recurso guardado: ", PATH_SETUP)


# ------------------------------------------------------------------------------
# Rueda: neumático + llanta + una barra que deja ver el giro
# ------------------------------------------------------------------------------
static func _build_wheel() -> void:
	var root := Node3D.new()
	root.name = "RuedaVisual"
	var tyre := Utils.make_material(COLOR_TYRE, 0.95)
	var rim := Utils.make_material(COLOR_RIM, 0.3, 0.8)
	var accent := Utils.make_material(COLOR_SECONDARY, 0.5)
	# Los cilindros nacen con el eje en Y: se rotan 90° en Z para que el eje
	# de giro quede sobre X (el eje del auto).
	var lay_down := Vector3(0.0, 0.0, 90.0)
	Utils.add_cylinder(root, "Neumatico", WHEEL_RADIUS, WHEEL_RADIUS, REAR_WHEEL_WIDTH,
			Vector3.ZERO, tyre, lay_down)
	Utils.add_cylinder(root, "Llanta", 0.2, 0.2, REAR_WHEEL_WIDTH + 0.01, Vector3.ZERO, rim, lay_down)
	Utils.add_box(root, "Marca", Vector3(REAR_WHEEL_WIDTH + 0.02, 0.07, 0.36), Vector3.ZERO, accent)
	Utils.save_scene(root, PATH_WHEEL)
	root.free()


# ------------------------------------------------------------------------------
# Carrocería
# ------------------------------------------------------------------------------
static func _build_body() -> void:
	var root := Node3D.new()
	root.name = "Carroceria"
	root.set_script(load("res://scripts/car/car_visual.gd"))

	var primary := Utils.make_material(COLOR_PRIMARY, 0.35, 0.3)
	var secondary := Utils.make_material(COLOR_SECONDARY, 0.35, 0.3)
	var carbon := Utils.make_material(COLOR_CARBON, 0.6)
	var helmet := Utils.make_material(COLOR_HELMET, 0.3)
	var rear_light := Utils.make_emissive(Color(1.0, 0.1, 0.1), 1.5)

	# Fondo plano.
	Utils.add_box(root, "Fondo", Vector3(1.5, 0.05, 3.6), Vector3(0.0, 0.03, 0.15), carbon)
	# Monocasco (habitáculo).
	_paint(Utils.add_box(root, "Monocasco", Vector3(0.82, 0.38, 2.3), Vector3(0.0, 0.26, -0.35), primary), true)
	# Trompa: cono acostado (un cilindro con radio superior chico) apuntando a -Z.
	_paint(Utils.add_cylinder(root, "Trompa", 0.07, 0.3, 1.5, Vector3(0.0, 0.24, -2.15), primary,
			Vector3(-90.0, 0.0, 0.0), 12), true)
	# Pontones laterales.
	for side in [-1.0, 1.0]:
		var suffix := "Izq" if side < 0.0 else "Der"
		_paint(Utils.add_box(root, "Ponton" + suffix, Vector3(0.48, 0.34, 1.7),
				Vector3(side * 0.62, 0.24, 0.45), primary), true)
		_paint(Utils.add_box(root, "TomaPonton" + suffix, Vector3(0.44, 0.24, 0.08),
				Vector3(side * 0.62, 0.27, -0.42), secondary), false)
	# Capó motor y toma de aire superior.
	_paint(Utils.add_box(root, "CapoMotor", Vector3(0.5, 0.42, 1.9), Vector3(0.0, 0.42, 1.0), primary), true)
	_paint(Utils.add_box(root, "TomaAire", Vector3(0.3, 0.3, 0.5), Vector3(0.0, 0.8, 0.25), secondary), false)
	_paint(Utils.add_box(root, "AletaTiburon", Vector3(0.04, 0.38, 1.3), Vector3(0.0, 0.78, 1.25), primary), true)

	# Alerón delantero: plano principal + derivas.
	var front_wing := Node3D.new()
	front_wing.name = "AleronDelantero"
	front_wing.position = Vector3(0.0, 0.08, -2.62)
	root.add_child(front_wing)
	_paint(Utils.add_box(front_wing, "Plano", Vector3(1.9, 0.04, 0.5), Vector3.ZERO, secondary), false)
	Utils.add_box(front_wing, "Flap", Vector3(1.7, 0.03, 0.22), Vector3(0.0, 0.09, 0.16), carbon,
			Vector3(18.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var suffix := "Izq" if side < 0.0 else "Der"
		_paint(Utils.add_box(front_wing, "Deriva" + suffix, Vector3(0.04, 0.22, 0.55),
				Vector3(side * 0.95, 0.08, 0.02), primary), true)

	# Alerón trasero: plano principal, flap móvil (DRS), derivas y soporte.
	var rear_wing := Node3D.new()
	rear_wing.name = "AleronTrasero"
	rear_wing.position = Vector3(0.0, 0.0, 2.3)
	root.add_child(rear_wing)
	_paint(Utils.add_box(rear_wing, "Plano", Vector3(1.0, 0.05, 0.34), Vector3(0.0, 0.84, 0.0), primary), true)
	# El flap del DRS gira alrededor de su borde delantero: por eso va dentro
	# de un nodo "bisagra" ubicado en ese borde.
	var flap_pivot := Node3D.new()
	flap_pivot.name = "FlapDRS"
	flap_pivot.position = Vector3(0.0, 0.97, -0.12)
	rear_wing.add_child(flap_pivot)
	_paint(Utils.add_box(flap_pivot, "Flap", Vector3(1.0, 0.03, 0.26), Vector3(0.0, 0.0, 0.13), secondary), false)
	for side in [-1.0, 1.0]:
		var suffix := "Izq" if side < 0.0 else "Der"
		_paint(Utils.add_box(rear_wing, "Deriva" + suffix, Vector3(0.04, 0.55, 0.6),
				Vector3(side * 0.52, 0.78, 0.0), primary), true)
	Utils.add_box(rear_wing, "Soporte", Vector3(0.08, 0.5, 0.18), Vector3(0.0, 0.58, -0.05), carbon)
	# Estructura de impacto trasera con la luz de lluvia en la punta.
	Utils.add_box(rear_wing, "EstructuraTrasera", Vector3(0.22, 0.2, 0.7), Vector3(0.0, 0.3, -0.25), carbon)
	Utils.add_box(rear_wing, "LuzTrasera", Vector3(0.12, 0.14, 0.05), Vector3(0.0, 0.3, 0.12), rear_light)

	# Halo: un toro (aro) horizontal + pilar central delantero.
	Utils.add_torus(root, "HaloAro", 0.29, 0.325, Vector3(0.0, 0.83, -0.2), carbon)
	Utils.add_box(root, "HaloPilar", Vector3(0.04, 0.42, 0.04), Vector3(0.0, 0.64, -0.55), carbon,
			Vector3(-14.0, 0.0, 0.0))
	# Casco del piloto.
	Utils.add_sphere(root, "Casco", 0.14, Vector3(0.0, 0.6, -0.15), helmet)

	# Brazos de suspensión (estáticos): una barra por eje.
	Utils.add_box(root, "SuspensionDelantera", Vector3(1.5, 0.04, 0.12),
			Vector3(0.0, WHEEL_CENTER_Y + 0.04, FRONT_AXLE_Z), carbon)
	Utils.add_box(root, "SuspensionTrasera", Vector3(1.4, 0.04, 0.12),
			Vector3(0.0, WHEEL_CENTER_Y + 0.04, REAR_AXLE_Z), carbon)

	Utils.save_scene(root, PATH_BODY)
	root.free()


# ------------------------------------------------------------------------------
# Modelo completo sin física (rivales y fantasma)
# ------------------------------------------------------------------------------
static func _build_model() -> void:
	var root := Node3D.new()
	root.name = "ModeloAuto"
	root.set_script(load("res://scripts/car/car_visual.gd"))
	Utils.add_instance(root, PATH_BODY, "Carroceria")
	var wheels := Node3D.new()
	wheels.name = "Ruedas"
	root.add_child(wheels)
	var index := 0
	for position in _wheel_positions(WHEEL_CENTER_Y):
		var wheel := Utils.add_instance(wheels, PATH_WHEEL, "Rueda%d" % index, position) as Node3D
		if index < 2:
			# Las ruedas delanteras son más angostas.
			wheel.scale = Vector3(FRONT_WHEEL_WIDTH / REAR_WHEEL_WIDTH, 1.0, 1.0)
		index += 1
	Utils.save_scene(root, PATH_MODEL)
	root.free()


# ------------------------------------------------------------------------------
# Auto del jugador: VehicleBody3D + 4 VehicleWheel3D
# ------------------------------------------------------------------------------
static func _build_player() -> void:
	var car := VehicleBody3D.new()
	car.name = "Auto"
	car.set_script(load("res://scripts/car/f1_car.gd"))
	car.set("setup", load(PATH_SETUP))
	car.collision_layer = LAYER_PLAYER
	car.collision_mask = LAYER_WORLD | LAYER_RIVALS
	car.continuous_cd = true
	car.can_sleep = false

	# Colisión: una caja que envuelve carrocería y ruedas.
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 0.5, 5.3)
	var collision := CollisionShape3D.new()
	collision.name = "Colision"
	collision.shape = shape
	collision.position = Vector3(0.0, 0.33, 0.05)
	car.add_child(collision)

	Utils.add_instance(car, PATH_BODY, "Carroceria")

	# Ruedas: las delanteras dirigen, las traseras traccionan.
	var names := ["RuedaDI", "RuedaDD", "RuedaTI", "RuedaTD"]
	var positions := _wheel_positions(SUSPENSION_ANCHOR_Y)
	for i in 4:
		var wheel := VehicleWheel3D.new()
		wheel.name = names[i]
		wheel.position = positions[i]
		wheel.use_as_steering = i < 2
		wheel.use_as_traction = i >= 2
		wheel.wheel_radius = WHEEL_RADIUS
		car.add_child(wheel)
		var visual := Utils.add_instance(wheel, PATH_WHEEL, "Visual") as Node3D
		if i < 2:
			visual.scale = Vector3(FRONT_WHEEL_WIDTH / REAR_WHEEL_WIDTH, 1.0, 1.0)

	# Cámaras.
	var rig := Node3D.new()
	rig.name = "Camaras"
	rig.set_script(load("res://scripts/car/camera_rig.gd"))
	car.add_child(rig)
	var chase := Camera3D.new()
	chase.name = "CamaraPersecucion"
	chase.position = Vector3(0.0, 2.7, 7.5)
	chase.fov = 68.0
	chase.near = 0.2
	chase.far = 2500.0
	rig.add_child(chase)
	var onboard := Camera3D.new()
	onboard.name = "CamaraOnboard"
	onboard.position = Vector3(0.0, 0.62, -0.1)
	onboard.fov = 82.0
	onboard.near = 0.05
	onboard.far = 2500.0
	rig.add_child(onboard)
	var tcam := Camera3D.new()
	tcam.name = "CamaraT"
	tcam.position = Vector3(0.0, 1.06, -0.02)
	tcam.rotation_degrees = Vector3(-9.0, 0.0, 0.0)
	tcam.fov = 78.0
	tcam.near = 0.1
	tcam.far = 2500.0
	rig.add_child(tcam)

	# Sonido del motor (síntesis).
	var sound := AudioStreamPlayer.new()
	sound.name = "SonidoMotor"
	sound.set_script(load("res://scripts/car/engine_sound.gd"))
	car.add_child(sound)
	car.add_child(_make_spray())

	Utils.save_scene(car, PATH_PLAYER)
	car.free()


# ------------------------------------------------------------------------------
# Auto rival: cuerpo cinemático (lo mueve el script) + modelo
# ------------------------------------------------------------------------------
static func _build_rival() -> void:
	var rival := AnimatableBody3D.new()
	rival.name = "Rival"
	rival.set_script(load("res://scripts/car/ai_car.gd"))
	rival.collision_layer = LAYER_RIVALS
	rival.collision_mask = 0
	rival.sync_to_physics = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 0.9, 5.3)
	var collision := CollisionShape3D.new()
	collision.name = "Colision"
	collision.shape = shape
	collision.position = Vector3(0.0, 0.55, 0.05)
	rival.add_child(collision)
	# El origen del rival está a nivel del piso: el modelo se eleva la altura
	# de marcha.
	Utils.add_instance(rival, PATH_MODEL, "Modelo", Vector3(0.0, RIDE_HEIGHT, 0.0))
	rival.add_child(_make_spray())
	Utils.save_scene(rival, PATH_RIVAL)
	rival.free()


# ------------------------------------------------------------------------------
# Fantasma: solo el modelo, sin colisión
# ------------------------------------------------------------------------------
static func _build_ghost() -> void:
	var ghost := Node3D.new()
	ghost.name = "Fantasma"
	ghost.set_script(load("res://scripts/car/ghost_car.gd"))
	Utils.add_instance(ghost, PATH_MODEL, "Modelo")
	Utils.save_scene(ghost, PATH_GHOST)
	ghost.free()


# Posiciones de las 4 ruedas (DI, DD, TI, TD) a la altura indicada.
static func _wheel_positions(height: float) -> Array[Vector3]:
	return [
		Vector3(-FRONT_HALF_TRACK, height, FRONT_AXLE_Z),
		Vector3(FRONT_HALF_TRACK, height, FRONT_AXLE_Z),
		Vector3(-REAR_HALF_TRACK, height, REAR_AXLE_Z),
		Vector3(REAR_HALF_TRACK, height, REAR_AXLE_Z),
	]


# Marca una pieza con el color de decoración que le corresponde.
static func _paint(mesh_instance: MeshInstance3D, primary: bool) -> void:
	mesh_instance.set_meta(CarVisual.META_LIVERY,
			CarVisual.LIVERY_PRIMARY if primary else CarVisual.LIVERY_SECONDARY)
