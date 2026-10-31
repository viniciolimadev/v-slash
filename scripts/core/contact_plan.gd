class_name ContactPlan
extends RefCounted
## Quem toca a próxima bola, com qual ação, onde (anel) e quando (tempo ideal).
## Criado por Game._make_plan(); null = ninguém joga esta bola.

var team: int
var n: int              # 1º, 2º ou 3º toque do lado
var act: int            # Game.Act
var t: float            # tempo ideal no relógio de Game.time
var pos: Vector3        # centro da bola no contato
var player: Player


func _init(p_team: int, p_n: int, p_act: int, p_t: float, p_pos: Vector3, p_player: Player) -> void:
	team = p_team
	n = p_n
	act = p_act
	t = p_t
	pos = p_pos
	player = p_player
