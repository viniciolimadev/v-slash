class_name CameraFx
extends Node
## Tremor leve da câmera no ataque forte (RF-4.06). Mexe só em h_offset/v_offset:
## o enquadramento (transform da câmera) não muda.

var cam: Camera3D
var amp := 0.0                      # m de deslocamento no começo do tremor

var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_cam: Camera3D) -> void:
	cam = p_cam
	_rng.seed = 3


## strength 0..1 (força do golpe); o tremor dura Tuning.SHAKE_TIME.
func shake(strength: float) -> void:
	amp = maxf(amp * _t / Tuning.SHAKE_TIME, Tuning.SHAKE_AMP * clampf(strength, 0.0, 1.0))
	_t = Tuning.SHAKE_TIME


func _process(delta: float) -> void:
	if _t <= 0.0:
		return
	_t = maxf(_t - delta, 0.0)
	var k := amp * _t / Tuning.SHAKE_TIME
	cam.h_offset = _rng.randf_range(-k, k)
	cam.v_offset = _rng.randf_range(-k, k)
	if _t == 0.0:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
