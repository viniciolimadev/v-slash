class_name MatchResult
extends RefCounted
## O que a tela de resultado mostra e o que o save registra.

var winner: int
var level: int
var mode: int = MatchConfig.Mode.ONE_V_ONE
var sets: Array[Vector2i]
var stats: MatchStats
var unlocked := -1                  # nível liberado por esta vitória (-1 = nenhum); preenchido pelo save


func _init(p_winner: int, p_level: int, p_sets: Array[Vector2i], p_stats: MatchStats) -> void:
	winner = p_winner
	level = p_level
	sets = p_sets
	stats = p_stats
