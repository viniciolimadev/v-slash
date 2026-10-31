class_name MatchConfig
extends RefCounted
## Parâmetros de uma partida, definidos por quem abre main.tscn antes de ela entrar na árvore.
## Sem config (F5 na cena, --autoplay, testes) = padrão: rally infinito contra o Fácil.

var bot_level := 0
var endless := true
var tutorial := false
var aim_sens := 1.0
var left_handed := false
var vibration := true
var serve_type := ServeType.Kind.UNDER


static func from_save(save: SaveData, level: int) -> MatchConfig:
	var c := MatchConfig.new()
	c.bot_level = level
	c.endless = false
	c.aim_sens = save.aim_sens
	c.left_handed = save.left_handed
	c.vibration = save.vibration
	c.serve_type = save.serve_type
	return c
