class_name OptionsScreen
extends Screen
## Sensibilidade da mira, modo canhoto e vibração. Cada mudança vale na hora (`changed`);
## o arquivo é gravado ao sair.

signal changed
signal closed

var save: SaveData


func _init() -> void:
	screen_name = "options"


func _build() -> void:
	add_title("OPÇÕES", 48)
	var sens_label := add_line("", 28, Color.WHITE)
	var slider := HSlider.new()
	slider.min_value = SaveData.AIM_SENS_MIN
	slider.max_value = SaveData.AIM_SENS_MAX
	slider.step = 0.1
	slider.value = save.aim_sens
	slider.custom_minimum_size = Vector2(BUTTON_SIZE.x, 56.0)
	slider.focus_mode = Control.FOCUS_NONE
	column.add_child(slider)
	var show_sens := func() -> void:
		sens_label.text = "Sensibilidade da mira: %d%%" % roundi(save.aim_sens * 100.0)
	show_sens.call()
	slider.value_changed.connect(func(v: float) -> void:
		save.aim_sens = v
		show_sens.call()
		changed.emit())
	_toggle("Modo canhoto", "left", save.left_handed, func(on: bool) -> void: save.left_handed = on)
	_toggle("Vibração", "vibration", save.vibration, func(on: bool) -> void: save.vibration = on)
	add_space(8.0)
	add_button("VOLTAR", "back", func() -> void:
		save.save_file()
		closed.emit())


func _toggle(text: String, key: String, on: bool, apply: Callable) -> void:
	var b := add_button("", key, func() -> void: pass)
	b.toggle_mode = true
	b.button_pressed = on
	var label_for := func(v: bool) -> void:
		b.text = "%s: %s" % [text, "LIGADO" if v else "DESLIGADO"]
	label_for.call(on)
	b.toggled.connect(func(v: bool) -> void:
		apply.call(v)
		label_for.call(v)
		changed.emit())
