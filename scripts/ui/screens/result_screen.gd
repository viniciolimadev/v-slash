class_name ResultScreen
extends Screen
## Fim de partida: quem venceu, placar dos sets e estatísticas.

signal rematch_pressed
signal change_level_pressed
signal menu_pressed

var result: MatchResult


func _init() -> void:
	screen_name = "result"


func _build() -> void:
	var won := result.winner == 0
	add_title("VOCÊ VENCEU!" if won else "O BOT VENCEU", 56).label_settings.font_color = \
			Color(0.55, 1.0, 0.65) if won else Color(1.0, 0.62, 0.52)
	var sets: PackedStringArray = []
	for s in result.sets:
		sets.append("%d × %d" % [s.x, s.y])
	add_line("%s   ·   Bot %s   ·   %s" % [SaveData.MODE_KEYS[result.mode], Tuning.BOT_NAMES[result.level],
			"   ".join(sets)], 30, Color.WHITE)
	var st := result.stats
	var secs := int(st.duration())
	add_line("Duração %d:%02d   ·   Maior rally %d   ·   Perfeitos %d%%" % [
			secs / 60, secs % 60, st.best_rally, roundi(100.0 * st.perfect_rate(0))])
	add_line(_reasons(st), 22)
	if result.unlocked >= 0:
		add_line("%s liberado!" % Tuning.BOT_NAMES[result.unlocked], 30, Color(1.0, 0.85, 0.3))
	add_space(10.0)
	add_button("REVANCHE", "rematch", func() -> void: rematch_pressed.emit())
	add_button("TROCAR BOT", "level", func() -> void: change_level_pressed.emit())
	add_button("MENU", "menu", func() -> void: menu_pressed.emit())


## "Seus pontos: Bola no chão 9 · Fora 4" — de onde vieram os seus pontos.
func _reasons(st: MatchStats) -> String:
	var parts: PackedStringArray = []
	var d: Dictionary = st.points_by_reason[0]
	for k in d:
		parts.append("%s %d" % [k, d[k]])
	return "Seus pontos: " + (" · ".join(parts) if not parts.is_empty() else "nenhum")
