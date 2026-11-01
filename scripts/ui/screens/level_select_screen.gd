class_name LevelSelectScreen
extends Screen
## Escolha do modo (1v1 / 2v2) e do bot. Cada modo tem seus níveis liberados e recordes;
## níveis ainda não liberados aparecem desativados com o que falta fazer.

signal level_chosen(level: int, mode: int)
signal back_pressed

var save: SaveData
var mode: int = MatchConfig.Mode.ONE_V_ONE


func _init() -> void:
	screen_name = "level"


func _build() -> void:
	add_title("ESCOLHA O BOT", 48)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(GAP))
	column.add_child(row)
	for m in SaveData.MODE_KEYS.size():
		var key := str(SaveData.MODE_KEYS[m])
		var t := Button.new()
		t.text = key
		t.focus_mode = Control.FOCUS_NONE
		t.toggle_mode = true
		t.button_pressed = m == mode
		t.custom_minimum_size = Vector2(BUTTON_SIZE.x * 0.5 - GAP * 0.5, 64.0)
		t.add_theme_font_size_override("font_size", 30)
		t.pressed.connect(func() -> void: set_mode(m))
		row.add_child(t)
		E2eHooks.publish(screen_name + "/" + key, t)
	add_space(4.0)
	var r := save.rec(mode)
	for lvl in 3:
		var lvl_name := str(Tuning.BOT_NAMES[lvl]).to_upper()
		var text := "%s   ·   %dV  %dD" % [lvl_name, r.wins[lvl], r.losses[lvl]]
		var locked := lvl > r.unlocked_level
		if locked:
			text = "%s   ·   vença o %s" % [lvl_name, Tuning.BOT_NAMES[lvl - 1]]
		var b := add_button(text, str(lvl), func() -> void: level_chosen.emit(lvl, mode))
		b.disabled = locked
	add_space(8.0)
	add_button("VOLTAR", "back", func() -> void: back_pressed.emit())


## Troca o modo e remonta os cartões com o progresso dele.
func set_mode(m: int) -> void:
	mode = m
	for c in column.get_children():
		column.remove_child(c)
		c.queue_free()
	_build()
