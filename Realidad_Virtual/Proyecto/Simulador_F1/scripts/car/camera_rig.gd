class_name CameraRig
extends Node3D
## Cámaras del auto: onboard (cockpit), T-cam y persecución.
##
## Las dos primeras son hijas fijas del auto. La de persecución es
## independiente (top_level) y sigue al auto con suavizado para que se note
## el movimiento de la carrocería. Se cicla con la acción `camera_next`.

enum Mode { CHASE, ONBOARD, T_CAM }

const MODE_LABELS := {
	Mode.CHASE: "Persecución",
	Mode.ONBOARD: "Onboard",
	Mode.T_CAM: "T-Cam",
}

# Cámara de persecución: distancia detrás del auto, altura y punto de mira.
const CHASE_DISTANCE := 7.5
const CHASE_HEIGHT := 2.7
const CHASE_LOOK_AHEAD := 5.0
const CHASE_LOOK_HEIGHT := 0.9
# Rapidez con la que la cámara alcanza su posición ideal (1/s).
const CHASE_POSITION_SMOOTHING := 9.0
# Campo visual base y extra a máxima velocidad (sensación de velocidad).
const CHASE_FOV := 68.0
const CHASE_FOV_SPEED_BONUS := 12.0
const FOV_FULL_SPEED := 90.0

signal mode_changed(mode: Mode)

var mode: Mode = Mode.CHASE

@onready var _chase: Camera3D = $CamaraPersecucion
@onready var _onboard: Camera3D = $CamaraOnboard
@onready var _tcam: Camera3D = $CamaraT

var _car: Node3D


func _ready() -> void:
	_car = get_parent() as Node3D
	_chase.top_level = true
	snap()
	_apply_mode()


func _physics_process(delta: float) -> void:
	if _car == null:
		return
	var ideal := _ideal_chase_position()
	var weight := 1.0 - exp(-CHASE_POSITION_SMOOTHING * delta)
	_chase.global_position = _chase.global_position.lerp(ideal, weight)
	_aim_chase()
	if mode == Mode.CHASE and _car is RigidBody3D:
		var speed := (_car as RigidBody3D).linear_velocity.length()
		_chase.fov = CHASE_FOV + CHASE_FOV_SPEED_BONUS * clampf(speed / FOV_FULL_SPEED, 0.0, 1.0)


## Pasa a la cámara siguiente.
func next() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode
	_apply_mode()
	mode_changed.emit(mode)


## Nombre de la cámara activa.
func get_mode_label() -> String:
	return MODE_LABELS[mode]


## Cámara activa.
func get_active_camera() -> Camera3D:
	match mode:
		Mode.ONBOARD: return _onboard
		Mode.T_CAM: return _tcam
	return _chase


## Coloca la cámara de persecución en su lugar sin suavizado (después de
## reubicar el auto).
func snap() -> void:
	if _car == null:
		return
	_chase.global_position = _ideal_chase_position()
	_aim_chase()


func _apply_mode() -> void:
	get_active_camera().make_current()


# Posición ideal: detrás del auto según su rumbo (sin heredar cabeceo ni rolido).
func _ideal_chase_position() -> Vector3:
	var back := _car.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	return _car.global_position + back * CHASE_DISTANCE + Vector3.UP * CHASE_HEIGHT


func _aim_chase() -> void:
	var forward := -_car.global_basis.z
	forward.y = 0.0
	var look_target := _car.global_position + forward.normalized() * CHASE_LOOK_AHEAD \
			+ Vector3.UP * CHASE_LOOK_HEIGHT
	if not _chase.global_position.is_equal_approx(look_target):
		_chase.look_at(look_target, Vector3.UP)
