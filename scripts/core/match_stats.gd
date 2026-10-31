class_name MatchStats
extends RefCounted
## Estatísticas da partida por time. Só escuta os sinais do Game (não mexe nele).

var touches: Array[int] = [0, 0]          # toques na bola, sem contar o saque
var perfect: Array[int] = [0, 0]
var good: Array[int] = [0, 0]
var timing_errors: Array[int] = [0, 0]    # toques CEDO/TARDE + tentativas fora da janela
var far: Array[int] = [0, 0]              # tentativas LONGE
var points_by_reason: Array[Dictionary] = [{}, {}]
var best_rally := 0
var started_at := 0.0                     # relógio de Game.time
var ended_at := -1.0                      # -1 = partida em andamento

var _game: Game


func attach(game: Game) -> void:
	_game = game
	game.touch_made.connect(_on_touch)
	game.whiffed.connect(_on_whiff)
	game.point_scored.connect(_on_point)
	game.match_over.connect(_on_match_over)
	reset()


## Zera tudo (Reiniciar / revanche na mesma partida).
func reset() -> void:
	touches = [0, 0]
	perfect = [0, 0]
	good = [0, 0]
	timing_errors = [0, 0]
	far = [0, 0]
	points_by_reason = [{}, {}]
	best_rally = 0
	started_at = _game.time if _game != null else 0.0
	ended_at = -1.0


func perfect_rate(team: int) -> float:
	return float(perfect[team]) / maxf(touches[team], 1.0)


func points(team: int) -> int:
	var total := 0
	for n in points_by_reason[team].values():
		total += int(n)
	return total


## Segundos de partida (até agora, se ainda não acabou).
func duration() -> float:
	var end := ended_at if ended_at >= 0.0 else (_game.time if _game != null else started_at)
	return end - started_at


func _on_touch(p: Player, grade: String, _q: float) -> void:
	if grade == "SAQUE":
		return
	touches[p.team] += 1
	if grade == "PERFEITO!":
		perfect[p.team] += 1
	elif grade == "BOM":
		good[p.team] += 1
	else:
		timing_errors[p.team] += 1


func _on_whiff(p: Player, why: String) -> void:
	if why == "CEDO" or why == "TARDE":
		timing_errors[p.team] += 1
	elif why == "LONGE":
		far[p.team] += 1


func _on_point(team: int, reason: String) -> void:
	var d := points_by_reason[team]
	d[reason] = int(d.get(reason, 0)) + 1
	best_rally = maxi(best_rally, _game.rally_touches)


func _on_match_over(_team: int) -> void:
	ended_at = _game.time
