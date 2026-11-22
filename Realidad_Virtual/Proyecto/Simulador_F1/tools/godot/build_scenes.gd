extends SceneTree
## Generador de escenas del proyecto.
##
## Las escenas `.tscn` de este proyecto no se armaron a mano en el editor:
## se generan con código a partir de los datos de diseño (medidas del auto,
## puntos de control del circuito, etc.). Así el proceso queda documentado y
## es reproducible: cambiar un dato y volver a ejecutar regenera todo.
##
## Uso (desde la carpeta del proyecto, con Godot 4.7 en el PATH):
##
##     godot --headless --import                  (solo la primera vez)
##     godot --headless --script res://tools/godot/build_scenes.gd
##
## Opcionalmente se puede generar solo una parte:
##
##     godot --headless --script res://tools/godot/build_scenes.gd -- autos
##     godot --headless --script res://tools/godot/build_scenes.gd -- circuitos niveles
##     godot --headless --script res://tools/godot/build_scenes.gd -- circuito monaco
##     godot --headless --script res://tools/godot/build_scenes.gd -- circuito monaco spa
##
## ATENCIÓN: regenerar pisa los cambios hechos a mano en esas escenas.

const STEPS := ["autos", "neumaticos", "circuitos", "interfaz", "niveles"]
## Palabra que, seguida de uno o más identificadores, genera solo esos circuitos.
const SINGLE_CIRCUIT_KEYWORD := "circuito"


func _initialize() -> void:
	var requested := OS.get_cmdline_user_args()
	if requested.size() >= 2 and requested[0] == SINGLE_CIRCUIT_KEYWORD:
		print("Generando circuitos...")
		load("res://tools/godot/track_builder.gd").build_all(requested.slice(1))
		print("Listo.")
		quit()
		return
	if requested.is_empty():
		requested = PackedStringArray(STEPS)
	# Se respeta el orden de dependencias aunque se pidan en otro orden.
	for step: String in STEPS:
		if not requested.has(step):
			continue
		match step:
			"autos":
				load("res://tools/godot/car_builder.gd").build_all()
			"neumaticos":
				load("res://tools/godot/car_builder.gd").build_tyre_compounds()
			"circuitos":
				print("Generando circuitos...")
				load("res://tools/godot/track_builder.gd").build_all()
			"interfaz":
				load("res://tools/godot/level_builder.gd").build_ui()
			"niveles":
				load("res://tools/godot/level_builder.gd").build_levels()
	print("Listo.")
	quit()
