extends AudioStreamPlayer
## Sonido de motor generado por síntesis (sin archivos de audio).
##
## Usa un AudioStreamGenerator: en cada frame se calculan las muestras que
## faltan en el buffer. La nota fundamental es proporcional a las RPM
## (frecuencia de encendido del motor) y se le suman armónicos para que no
## suene a un tono puro. El acelerador modifica el volumen y el "filo".

# Frecuencia de muestreo del generador [Hz] (baja a propósito: alcanza para
# un motor y cuesta menos CPU).
const MIX_RATE := 22050.0
const BUFFER_LENGTH := 0.1
# Pulsos de encendido por vuelta del cigüeñal (motor de 6 cilindros y 4
# tiempos = 3) reducidos para que el tono no resulte demasiado agudo.
const PULSES_PER_REVOLUTION := 0.7
# Régimen máximo de referencia [rpm] para convertir rpm normalizadas a Hz.
const REFERENCE_MAX_RPM := 12000.0
# Volumen (lineal) con el acelerador suelto y a fondo.
const VOLUME_IDLE := 0.16
const VOLUME_FULL := 0.42
# Máximo de muestras generadas por frame (evita picos de CPU).
const MAX_FRAMES_PER_UPDATE := 2048
# Suavizado de los cambios de tono y de volumen.
const PITCH_SMOOTHING := 14.0
const VOLUME_SMOOTHING := 10.0

var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _rpm_normalized: float = 0.3
var _throttle: float = 0.0
var _current_frequency: float = 100.0
var _current_volume: float = VOLUME_IDLE


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = BUFFER_LENGTH
	stream = generator
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


## El auto informa el régimen (0..1 respecto del máximo) y el acelerador (0..1).
func set_engine_state(rpm_normalized: float, throttle: float) -> void:
	_rpm_normalized = clampf(rpm_normalized, 0.0, 1.0)
	_throttle = clampf(throttle, 0.0, 1.0)


func _process(delta: float) -> void:
	if _playback == null:
		return
	var target_frequency := _rpm_normalized * REFERENCE_MAX_RPM / 60.0 * PULSES_PER_REVOLUTION
	_current_frequency = lerpf(_current_frequency, target_frequency, 1.0 - exp(-PITCH_SMOOTHING * delta))
	var target_volume := lerpf(VOLUME_IDLE, VOLUME_FULL, _throttle)
	_current_volume = lerpf(_current_volume, target_volume, 1.0 - exp(-VOLUME_SMOOTHING * delta))

	var frames := mini(_playback.get_frames_available(), MAX_FRAMES_PER_UPDATE)
	if frames <= 0:
		return
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	var phase_step := _current_frequency / MIX_RATE
	# Más acelerador = más armónicos altos (sonido más "abierto").
	var edge := lerpf(0.05, 0.15, _throttle)
	for i in frames:
		_phase = fmod(_phase + phase_step, 1.0)
		# Diente de sierra (fundamental) + segundo armónico + subarmónico grave.
		var sample := (2.0 * _phase - 1.0) * edge
		sample += sin(TAU * _phase * 2.0) * 0.22
		sample += sin(TAU * _phase * 0.5) * 0.7
		sample *= _current_volume
		buffer[i] = Vector2(sample, sample)
	_playback.push_buffer(buffer)
