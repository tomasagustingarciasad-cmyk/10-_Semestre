extends RefCounted
## Generador de las escenas de interfaz y de los dos niveles.
##
##   - scenes/main_menu.tscn, options_menu.tscn, calibration.tscn
##   - scenes/ui/hud.tscn, pause_menu.tscn, results_screen.tscn
##   - scenes/session_setup.tscn         (elección de circuito, clima y neumáticos)
##   - scenes/levels/clasificacion.tscn  (Nivel 1)
##   - scenes/levels/carrera.tscn        (Nivel 2: agrega los rivales)
##
## Las escenas de interfaz son solo un nodo raíz con su script (los controles
## se crean por código al iniciar). Los niveles combinan por INSTANCIACIÓN las
## escenas del auto y de la interfaz, y agregan iluminación, cielo y clima.
## El circuito NO va en la escena del nivel: la sesión carga solo el elegido.

const Utils := preload("res://tools/godot/builder_utils.gd")

const PATH_PLAYER := "res://scenes/car/f1_car.tscn"
const PATH_RIVAL := "res://scenes/car/rival_car.tscn"
const PATH_HUD := "res://scenes/ui/hud.tscn"
const PATH_PAUSE := "res://scenes/ui/pause_menu.tscn"

## Rivales del nivel Carrera: nombre, colores, habilidad y carril preferido.
const RIVALS := [
	{"name": "Rival Rojo", "primary": Color(0.8, 0.1, 0.1), "secondary": Color(0.95, 0.95, 0.95), "skill": 0.96, "lane": -2.6},
	{"name": "Rival Verde", "primary": Color(0.1, 0.55, 0.2), "secondary": Color(0.08, 0.08, 0.08), "skill": 0.94, "lane": 2.6},
	{"name": "Rival Naranja", "primary": Color(0.95, 0.45, 0.05), "secondary": Color(0.1, 0.1, 0.1), "skill": 0.92, "lane": -1.2},
	{"name": "Rival Blanco", "primary": Color(0.9, 0.9, 0.9), "secondary": Color(0.1, 0.3, 0.8), "skill": 0.90, "lane": 1.2},
]

# Lluvia: cantidad de gotas, vida [s] y tamaño de la zona de emisión [m].
const RAIN_AMOUNT := 3500
const RAIN_LIFETIME := 0.8
const RAIN_BOX_EXTENTS := Vector3(22.0, 1.0, 22.0)
const RAIN_DROP_SIZE := Vector2(0.03, 0.8)


# ==============================================================================
# Interfaz
# ==============================================================================
static func build_ui() -> void:
	print("Generando escenas de interfaz...")
	_save_script_scene(Control.new(), "MenuPrincipal", "res://scripts/ui/main_menu.gd", "res://scenes/main_menu.tscn")
	_save_script_scene(Control.new(), "MenuOpciones", "res://scripts/ui/options_menu.gd", "res://scenes/options_menu.tscn")
	_save_script_scene(Control.new(), "Calibracion", "res://scripts/ui/calibration_screen.gd", "res://scenes/calibration.tscn")
	_save_script_scene(Control.new(), "PrepararSesion", "res://scripts/ui/session_setup.gd", "res://scenes/session_setup.tscn")
	_save_script_scene(CanvasLayer.new(), "HUD", "res://scripts/ui/hud.gd", PATH_HUD)
	_save_script_scene(CanvasLayer.new(), "MenuPausa", "res://scripts/ui/pause_menu.gd", PATH_PAUSE)
	_save_script_scene(CanvasLayer.new(), "Resultados", "res://scripts/ui/results_screen.gd", "res://scenes/ui/results_screen.tscn")


static func _save_script_scene(root: Node, node_name: String, script_path: String, scene_path: String) -> void:
	root.name = node_name
	root.set_script(load(script_path))
	if root is Control:
		(root as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	Utils.save_scene(root, scene_path)
	root.free()


# ==============================================================================
# Niveles
# ==============================================================================
static func build_levels() -> void:
	print("Generando niveles...")
	_build_qualifying()
	_build_race()


# Nivel 1: Clasificación.
static func _build_qualifying() -> void:
	var root := Node3D.new()
	root.name = "Clasificacion"
	root.set_script(load("res://scripts/race/qualifying_session.gd"))
	_add_common_nodes(root)
	Utils.save_scene(root, "res://scenes/levels/clasificacion.tscn")
	root.free()


# Nivel 2: Carrera (agrega los rivales).
static func _build_race() -> void:
	var root := Node3D.new()
	root.name = "Carrera"
	root.set_script(load("res://scripts/race/race_session.gd"))
	_add_common_nodes(root)

	var rivals := Node3D.new()
	rivals.name = "Rivales"
	root.add_child(rivals)
	for i in RIVALS.size():
		var data: Dictionary = RIVALS[i]
		var rival := Utils.add_instance(rivals, PATH_RIVAL, "Rival%d" % (i + 1))
		rival.set("driver_name", data["name"])
		rival.set("primary_color", data["primary"])
		rival.set("secondary_color", data["secondary"])
		rival.set("skill", data["skill"])
		rival.set("lane", data["lane"])

	Utils.save_scene(root, "res://scenes/levels/carrera.tscn")
	root.free()


# Nodos iguales en los dos niveles: cielo y sol, clima, auto del jugador, HUD
# y menú de pausa. El CIRCUITO no está acá: la sesión carga el elegido al
# iniciar. El cielo, la niebla y el sol quedan en valores neutros de día
# seco: el nodo Clima los ajusta al iniciar según el clima elegido.
static func _add_common_nodes(root: Node) -> void:
	_add_environment(root)
	var weather := Node3D.new()
	weather.name = "Clima"
	weather.set_script(load("res://scripts/track/weather.gd"))
	root.add_child(weather)
	weather.add_child(_make_rain())
	Utils.add_instance(root, PATH_PLAYER, "Auto", Vector3(0.0, 1.0, 0.0))
	Utils.add_instance(root, PATH_HUD, "HUD")
	Utils.add_instance(root, PATH_PAUSE, "MenuPausa")


# Cielo, luz ambiente y sol (valores de día seco; ver weather.gd).
static func _add_environment(root: Node) -> void:
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world := WorldEnvironment.new()
	world.name = "Ambiente"
	world.environment = environment
	root.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sol"
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	root.add_child(sun)


# Partículas de lluvia: gotas (rectángulos finos) que caen dentro de una caja
# que el script del clima mantiene alrededor de la cámara.
static func _make_rain() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = RAIN_BOX_EXTENTS
	process.direction = Vector3.DOWN
	process.spread = 2.0
	process.initial_velocity_min = 22.0
	process.initial_velocity_max = 26.0
	process.gravity = Vector3(0.0, -9.8, 0.0)

	var drop_material := StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.albedo_color = Color(0.8, 0.86, 0.95, 0.45)
	drop_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var drop := QuadMesh.new()
	drop.size = RAIN_DROP_SIZE
	drop.material = drop_material

	var rain := GPUParticles3D.new()
	rain.name = "Lluvia"
	rain.amount = RAIN_AMOUNT
	rain.lifetime = RAIN_LIFETIME
	rain.preprocess = RAIN_LIFETIME
	rain.local_coords = true
	rain.process_material = process
	rain.draw_pass_1 = drop
	# Cada gota se orienta según su velocidad y siempre de frente a la cámara.
	rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	rain.visibility_aabb = AABB(Vector3(-40.0, -40.0, -40.0), Vector3(80.0, 80.0, 80.0))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	return rain
