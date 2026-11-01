class_name Team
extends RefCounted
## Jogadores de um time e a ordem de saque (no 2v2 o sacador alterna quando o time recupera o saque).

var index: int                      # 0 ou 1
var players: Array[Player] = []
var next_server := 0                # índice em players de quem saca quando o time recuperar o saque


func _init(p_index: int) -> void:
	index = p_index


## Próximo sacador ao recuperar o saque (sideout); alterna para a próxima vez.
func server_on_sideout() -> Player:
	var p := players[next_server % players.size()]
	next_server = (next_server + 1) % players.size()
	return p


## O parceiro (null no 1v1).
func other(p: Player) -> Player:
	for q in players:
		if q != p:
			return q
	return null
