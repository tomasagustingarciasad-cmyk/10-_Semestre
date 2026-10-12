extends Node2D

# Variables de estado del juego
var game_state: int = 3 # 0: Jugando, 1: Éxito, 2: Choque, 3: Inicio

# Variables cinemáticas de la nave 
var ship_x: float
var ship_y: float
var vx: float
var vy: float
var angle: float = 0.0

# Constantes físicas
var gravity: float = 0.015
var thrust: float = 0.02

# Variables de control de teclas
var left_pressed: bool = false
var right_pressed: bool = false
var thrust_pressed: bool = false

# Constantes de terreno, plataforma y colisión
var ground_y: float = 550.0
var pad_x: float = 350.0
var pad_width: float = 100.0
var max_safe_velocity: float = 1.5

# Arreglos para el fondo de estrellas
var stars: Array = []
var textura_tierra: Texture2D

func _ready():
	# Inicialización de estrellas
	for i in range(100):
		stars.append(Vector2(randf_range(0, 800), randf_range(0, ground_y)))
	
	# Carga de la textura. Si no existe, textura_tierra será null
	if ResourceLoader.exists("res://Textura_tierra.jpg"):
		textura_tierra = load("res://Textura_tierra.jpg")
		
	reiniciar_juego()
	game_state = 3

func _process(_delta):
	# Fuerza el redibujado en cada frame (equivalente al bucle draw de Processing)
	queue_redraw()
	
	if game_state == 0:
		# 1. Lógica de física y controles
		if left_pressed: angle -= 0.05
		if right_pressed: angle += 0.05
		if thrust_pressed:
			vx += sin(angle) * thrust
			vy -= cos(angle) * thrust
			
		vy += gravity
		ship_x += vx
		ship_y += vy
		
		# 4. Detección de colisiones
		if ship_y + 15 >= ground_y:
			ship_y = ground_y - 15
			
			var on_pad = ship_x >= pad_x and ship_x <= pad_x + pad_width
			var safe_speed = vy < max_safe_velocity
			var safe_angle = cos(angle) > cos(deg_to_rad(30))
			
			if on_pad and safe_speed and safe_angle:
				game_state = 1 # Éxito
			else:
				game_state = 2 # Choque

func _input(event):
	if event is InputEventKey:
		var is_pressed = event.pressed
		
		# Inicio del simulador
		if game_state == 3 and event.keycode == KEY_S and is_pressed:
			game_state = 0
			
		# Reinicio
		if event.keycode == KEY_R and is_pressed:
			if game_state == 1 or game_state == 2:
				reiniciar_juego()
				
		# Controles de vuelo (incluye flechas y WASD)
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			left_pressed = is_pressed
		if event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			right_pressed = is_pressed
		if event.keycode == KEY_SPACE or event.keycode == KEY_UP or event.keycode == KEY_W:
			thrust_pressed = is_pressed

func _draw():
	# Fondo negro
	draw_rect(Rect2(0, 0, 800, 600), Color.BLACK)
	
	# Dibujo del espacio estrellado
	for star in stars:
		draw_circle(star, 1.0, Color.WHITE)
		
	if game_state == 0:
		# 2. Dibujo de la nave (traslación y rotación)
		draw_set_transform(Vector2(ship_x, ship_y), angle, Vector2.ONE)
		
		if thrust_pressed:
			# Color naranja para el fuego
			var colors = PackedColorArray([Color(1.0, 0.59, 0.0)])
			var points = PackedVector2Array([Vector2(-6, 10), Vector2(6, 10), Vector2(randf_range(-4, 4), randf_range(20, 30))])
			draw_polygon(points, colors)
			
		# Cuerpo principal (gris 180)
		draw_rect(Rect2(-10, -5, 20, 15), Color(0.7, 0.7, 0.7))
		
		# Cabina superior 
		draw_circle(Vector2(0, -5), 8, Color(0.39, 0.78, 1.0))
		
		# Patas
		draw_line(Vector2(-10, 10), Vector2(-15, 15), Color.WHITE, 2.0)
		draw_line(Vector2(10, 10), Vector2(15, 15), Color.WHITE, 2.0)
		
		# Restaura la transformación para los elementos fijos
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		
		# 3. Dibujo del terreno y plataforma
		if textura_tierra != null:
			draw_texture_rect(textura_tierra, Rect2(0, ground_y, 800, 600 - ground_y), false)
		else:
			# Color base del terreno si no carga la textura (gris oscuro 50)
			draw_rect(Rect2(0, ground_y, 800, 600 - ground_y), Color(0.2, 0.2, 0.2))
			
		# Plataforma en verde
		draw_line(Vector2(pad_x, ground_y), Vector2(pad_x + pad_width, ground_y), Color.GREEN, 4.0)
		
		# 5. Interfaz de telemetría (HUD)
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(30, 40), "ÁNGULO: " + str(snapped(rad_to_deg(angle), 0.01)) + "°", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, Vector2(30, 65), "Angulo maximo permitido = +/- 30°", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, Vector2(30, 90), "VELOCIDAD: " + str(snapped(vy*10, 0.01)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, Vector2(30, 115), "Velocidad máxima permitida = 15", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		
		var altitud_real = max(0, ground_y - (ship_y + 15))
		draw_string(font, Vector2(0, 40), "ALTITUD: " + str(snapped(altitud_real, 0.01)), HORIZONTAL_ALIGNMENT_RIGHT, 770, 16)
		
	elif game_state == 1:
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(0, 300), "Aterrizaje exitoso. Presione 'R' para reiniciar", HORIZONTAL_ALIGNMENT_CENTER, 800, 32)
	elif game_state == 2:
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(0, 300), "Nave destruida. Presione 'R' para reiniciar", HORIZONTAL_ALIGNMENT_CENTER, 800, 32)
	elif game_state == 3:
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(0, 300), "Presione 'S' para comenzar el simulador", HORIZONTAL_ALIGNMENT_CENTER, 800, 32)

func reiniciar_juego():
	ship_x = randf_range(50, 800 - 50)
	ship_y = 50.0
	vx = 0.0
	vy = 0.0
	angle = PI / 2.0 # Equivalente a HALF_PI
	pad_x = randf_range(0, 800 - pad_width)
	game_state = 0
