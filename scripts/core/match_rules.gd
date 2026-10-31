class_name MatchRules
extends RefCounted
## Pontos e sets (rally point). set_points = 0 → rally infinito (demo, testes, tutorial).

var set_points: int
var sets_to_win: int
var win_by: int
var points: Array[int] = [0, 0]      # do set atual
var sets: Array[int] = [0, 0]
var set_index := 0                   # 0, 1, 2
var history: Array[Vector2i] = []    # placar final de cada set (x = time 0)
var winner := -1                     # time vencedor da partida (-1 = em andamento)
var set_closed := false              # set acabou e o próximo ainda não começou


func _init(p_set_points := Tuning.SET_POINTS, p_sets_to_win := Tuning.SETS_TO_WIN,
		p_win_by := Tuning.WIN_BY) -> void:
	set_points = p_set_points
	sets_to_win = p_sets_to_win
	win_by = p_win_by


## Mesmas regras, placar zerado.
func fresh() -> MatchRules:
	return MatchRules.new(set_points, sets_to_win, win_by)


func is_endless() -> bool:
	return set_points <= 0


## Registra um ponto. Retorna {"set_over": bool, "match_over": bool}.
func add_point(team: int) -> Dictionary:
	var out := {"set_over": false, "match_over": false}
	if winner >= 0 or set_closed:
		return out
	points[team] += 1
	if is_endless() or not _closes_set(points[team], points[1 - team]):
		return out
	sets[team] += 1
	set_closed = true
	history.append(Vector2i(points[0], points[1]))
	out["set_over"] = true
	if sets[team] >= sets_to_win:
		winner = team
		out["match_over"] = true
	return out


## Mais um ponto deste time fecha o set.
func is_set_point(team: int) -> bool:
	if is_endless() or set_closed:
		return false
	return _closes_set(points[team] + 1, points[1 - team])


## Mais um ponto deste time fecha a partida.
func is_match_point(team: int) -> bool:
	return is_set_point(team) and sets[team] == sets_to_win - 1


## Quem saca primeiro no set idx: alterna (set 1 você, set 2 o adversário, set 3 você).
func first_server(idx: int) -> int:
	return idx % 2


func start_next_set() -> void:
	points = [0, 0]
	set_index += 1
	set_closed = false


func _closes_set(mine: int, theirs: int) -> bool:
	return mine >= set_points and mine - theirs >= win_by
