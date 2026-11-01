class_name CourtSpec
extends RefCounted
## Medidas da quadra de um modo de jogo (1v1 ou 2v2). Tudo que depende do tamanho lê daqui.
## Pontos de referência (zonas de mira, levantador) são escritos em metros da quadra do 1v1
## e levados para esta quadra por `scaled()`; no 1v1 a escala é exatamente 1.

var half_w: float
var depth: float
var net_half_len: float
var serve_back := 0.9               # m atrás da linha de fundo onde fica o sacador

static var _default: CourtSpec = null


func _init(p_half_w: float, p_depth: float) -> void:
	half_w = p_half_w
	depth = p_depth
	net_half_len = p_half_w + Tuning.NET_OVERHANG


static func for_mode(mode: int) -> CourtSpec:
	if mode == MatchConfig.Mode.TWO_V_TWO:
		return CourtSpec.new(Tuning.COURT_2V2.x, Tuning.COURT_2V2.y)
	return CourtSpec.new(Tuning.COURT_1V1.x, Tuning.COURT_1V1.y)


## Quadra do 1v1, compartilhada (BallSim e Player criados sem Game, como nos testes).
static func default_spec() -> CourtSpec:
	if _default == null:
		_default = for_mode(MatchConfig.Mode.ONE_V_ONE)
	return _default


func is_inside(v: Vector3) -> bool:
	var tol := Tuning.LINE_TOLERANCE
	return absf(v.x) <= half_w + tol and absf(v.z) <= depth + tol


## Assistência: traz o ponto para dentro da quadra (com folga das linhas).
func keep_inside(v: Vector3, margin: float = 0.3) -> Vector3:
	var w := half_w - margin
	var d := depth - margin
	return Vector3(clampf(v.x, -w, w), v.y, clampf(v.z, -d, d))


## (x, z) escrito para a quadra do 1v1, nesta quadra.
func scaled(x: float, z: float) -> Vector2:
	return Vector2(x * half_w / Tuning.COURT_1V1.x, z * depth / Tuning.COURT_1V1.y)
