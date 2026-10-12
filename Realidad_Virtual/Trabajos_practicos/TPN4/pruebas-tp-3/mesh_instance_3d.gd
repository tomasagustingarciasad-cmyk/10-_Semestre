class_name FiguraCompuesta
extends MeshInstance3D


class Controlador:
	var vel_x: float = 0.0
	var vel_y: float = 0.0
	const VELOCIDAD: float = 1.5
	var patron_actual: int = 0

	func procesar_tecla(keycode: Key) -> String:
		match keycode:
			KEY_UP:
				vel_x = -VELOCIDAD
				vel_y = 0.0
			KEY_DOWN:
				vel_x = VELOCIDAD
				vel_y = 0.0
			KEY_LEFT:
				vel_y = -VELOCIDAD
				vel_x = 0.0
			KEY_RIGHT:
				vel_y = VELOCIDAD
				vel_x = 0.0
			KEY_D:
				vel_x = 0.0
				vel_y = 0.0
			KEY_R:
				vel_x = 0.0
				vel_y = 0.0
				patron_actual = (patron_actual + 1) % 3
				return "reiniciar"
		return ""

# --- Variables de la Figura ---
var ctrl: Controlador = Controlador.new()
var material_planos: StandardMaterial3D
var texturas: Array[ImageTexture] = []

func _ready() -> void:
	# Quitamos el cubo blanco sólido del Ejercicio 2
	mesh = null
	
	texturas.append(crear_patron_ajedrez())
	texturas.append(crear_patron_rayas())
	texturas.append(crear_patron_ruido())
	
	# Material para que los planos se vean de ambos lados y con tu textura
	material_planos = StandardMaterial3D.new()
	material_planos.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_planos.albedo_texture = texturas[0]
	material_planos.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	construir_escena_processing()

func _process(delta: float) -> void:
	rotate_x(ctrl.vel_x * delta)
	rotate_y(ctrl.vel_y * delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var accion: String = ctrl.procesar_tecla(event.keycode)
		if accion == "reiniciar":
			rotation = Vector3.ZERO
			material_planos.albedo_texture = texturas[ctrl.patron_actual]

func construir_escena_processing() -> void:
	# Crear los 3 planos ortogonales (XY, YZ, XZ)
	var rotaciones: Array[Vector3] = [
		Vector3(0, 0, 0),
		Vector3(0, deg_to_rad(90), 0),
		Vector3(deg_to_rad(90), 0, 0)
	]
	
	for rot in rotaciones:
		var plano := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.2, 2.2)
		plano.mesh = quad
		plano.material_override = material_planos
		plano.rotation = rot
		add_child(plano)
	
	# Crear el cubo blanco en wireframe del centro
	var cubo_wire := MeshInstance3D.new()
	cubo_wire.mesh = crear_cubo_wireframe(1.1)
	add_child(cubo_wire)

func crear_cubo_wireframe(tam: float) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	
	var m: float = tam / 2.0
	var v: Array[Vector3] = [
		Vector3(-m, -m, -m), Vector3(m, -m, -m), Vector3(m, m, -m), Vector3(-m, m, -m),
		Vector3(-m, -m, m), Vector3(m, -m, m), Vector3(m, m, m), Vector3(-m, m, m)
	]
	var aristas: Array[int] = [
		0,1, 1,2, 2,3, 3,0, # Cara trasera
		4,5, 5,6, 6,7, 7,4, # Cara delantera
		0,4, 1,5, 2,6, 3,7  # Uniones
	]
	
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in aristas:
		im.surface_add_vertex(v[i])
	im.surface_end()
	return im

func crear_patron_ajedrez() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var celeste := Color8(80, 170, 255)
	var naranja := Color8(255, 140, 60)
	for x in range(256):
		for y in range(256):
			var es_par: bool = ((x / 32) + (y / 32)) % 2 == 0
			img.set_pixel(x, y, celeste if es_par else naranja)
	return ImageTexture.create_from_image(img)

func crear_patron_rayas() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for x in range(256):
		for y in range(256):
			var c := Color8(50, 220, 120) if ((x + y) / 16) % 2 == 0 else Color8(40, 40, 180)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func crear_patron_ruido() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for x in range(256):
		for y in range(256):
			var r: int = (x / 8) * 32
			var g: int = (y / 8) * 32
			img.set_pixel(x, y, Color8(randi() % 256, (r + g) % 256, randi() % 256))
	return ImageTexture.create_from_image(img)
