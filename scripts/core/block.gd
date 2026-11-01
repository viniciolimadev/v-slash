class_name Block
extends RefCounted
## Mãos do bloqueador: um retângulo vertical logo depois da rede, do lado do atacante
## (z = −side·BLOCK_DEPTH: as mãos passam a fita), ativo enquanto estão acima da rede.
## Conhecido assim que o pulo começa, então o preditor já sabe do bloqueio.

var side: float               # lado do bloqueador (+1/−1)
var x_center: float
var half_w := Tuning.BLOCK_HALF_W
var t_start: float            # relógio do Game: começo do pulo
var jump_h := Tuning.JUMP_HEIGHT
var team: int
var player: Player


func _init(p: Player, t0: float, p_jump_h: float) -> void:
	player = p
	team = p.team
	side = Game.side_of_team(p.team)
	x_center = p.position.x
	t_start = t0
	jump_h = p_jump_h


func plane_z() -> float:
	return -side * Tuning.BLOCK_DEPTH


## Pico do pulo: o instante de referência do timing do bloqueio.
func t_peak() -> float:
	return t_start + Tuning.JUMP_TIME_UP


func t_end() -> float:
	return t_start + Tuning.JUMP_TIME_UP * 2.0


## Altura do topo das mãos no instante t (mesma curva do pulo do Player).
func top_at(t: float) -> float:
	var stand := Tuning.NET_HEIGHT + Tuning.BLOCK_REACH - Tuning.JUMP_HEIGHT
	var u := (t - t_start) / (Tuning.JUMP_TIME_UP * 2.0)
	if u <= 0.0 or u >= 1.0:
		return stand
	return stand + 4.0 * jump_h * u * (1.0 - u)


func active_at(t: float) -> bool:
	return top_at(t) > Tuning.NET_HEIGHT


## A bola com centro em `pos` no instante t bate nas mãos?
func catches(pos: Vector3, t: float) -> bool:
	var r := Tuning.BALL_RADIUS
	return active_at(t) and absf(pos.x - x_center) <= half_w + r \
			and pos.y <= top_at(t) + r and pos.y >= Tuning.NET_HEIGHT - r
