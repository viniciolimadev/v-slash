class_name LevelSelectScreen
extends Screen
## Escolha do bot. Níveis ainda não liberados aparecem desativados com o que falta fazer.

signal level_chosen(level: int)
signal back_pressed

var save: SaveData


func _init() -> void:
	screen_name = "level"


func _build() -> void:
	add_title("ESCOLHA O BOT", 48)
	add_space(8.0)
	for lvl in 3:
		var lvl_name := str(Tuning.BOT_NAMES[lvl]).to_upper()
		var text := "%s   ·   %dV  %dD" % [lvl_name, save.wins[lvl], save.losses[lvl]]
		var locked := lvl > save.unlocked_level
		if locked:
			text = "%s   ·   vença o %s" % [lvl_name, Tuning.BOT_NAMES[lvl - 1]]
		var b := add_button(text, str(lvl), func() -> void: level_chosen.emit(lvl))
		b.disabled = locked
	add_space(8.0)
	add_button("VOLTAR", "back", func() -> void: back_pressed.emit())
