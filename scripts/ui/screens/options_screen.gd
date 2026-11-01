class_name OptionsScreen
extends Screen
## Sensibilidade da mira, volumes, modo canhoto e vibração. Cada mudança vale na hora (`changed`);
## o arquivo é gravado ao sair.

signal changed
signal closed
signal lang_changed
signal privacy_pressed

var save: SaveData


func _init() -> void:
	screen_name = "options"


func _build() -> void:
	add_title(tr("OPÇÕES"), 48)
	# duas colunas (cabe em 720p): controles deslizantes à esquerda, chaves e Voltar à direita
	var top := column
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	top.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", int(GAP))
	row.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", int(GAP))
	row.add_child(right)
	column = left
	_slider(tr("Sensibilidade da mira"), "sens", SaveData.AIM_SENS_MIN, SaveData.AIM_SENS_MAX, save.aim_sens,
			func(v: float) -> void: save.aim_sens = v)
	_slider(tr("Música"), "music", 0.0, 1.0, save.music_vol, func(v: float) -> void:
		save.music_vol = v
		Sfx.apply_volumes(save.music_vol, save.sfx_vol))
	_slider(tr("Efeitos"), "sfx", 0.0, 1.0, save.sfx_vol, func(v: float) -> void:
		save.sfx_vol = v
		Sfx.apply_volumes(save.music_vol, save.sfx_vol))
	column = right
	add_button("%s: %s" % [tr("Idioma"), Lang.NAMES[Lang.resolve(save.lang)]], "lang", func() -> void:
		save.lang = Lang.next(save.lang)
		Lang.apply(save.lang)
		save.save_file()
		lang_changed.emit())
	_toggle(tr("Modo canhoto"), "left", save.left_handed, func(on: bool) -> void: save.left_handed = on)
	_toggle(tr("Vibração"), "vibration", save.vibration, func(on: bool) -> void: save.vibration = on)
	if privacy_pressed.get_connections().size() > 0:
		add_button(tr("PRIVACIDADE"), "privacy", func() -> void:
			save.save_file()
			privacy_pressed.emit())
	add_button(tr("VOLTAR"), "back", func() -> void:
		save.save_file()
		closed.emit())


## Rótulo "Nome: 80%" e o controle deslizante logo abaixo.
func _slider(text: String, key: String, lo: float, hi: float, value: float, apply: Callable) -> HSlider:
	var label := add_line("", 26, Color.WHITE)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 0.05 if hi <= 1.0 else 0.1
	slider.value = value
	slider.custom_minimum_size = Vector2(BUTTON_SIZE.x, 64.0)
	slider.focus_mode = Control.FOCUS_NONE
	column.add_child(slider)
	E2eHooks.publish(screen_name + "/" + key, slider)
	var show := func(v: float) -> void: label.text = "%s: %d%%" % [text, roundi(v * 100.0)]
	show.call(value)
	slider.value_changed.connect(func(v: float) -> void:
		apply.call(v)
		show.call(v)
		changed.emit())
	return slider


func _toggle(text: String, key: String, on: bool, apply: Callable) -> void:
	var b := add_button("", key, func() -> void: pass)
	b.toggle_mode = true
	b.button_pressed = on
	var label_for := func(v: bool) -> void:
		b.text = "%s: %s" % [text, tr("LIGADO") if v else tr("DESLIGADO")]
	label_for.call(on)
	b.toggled.connect(func(v: bool) -> void:
		apply.call(v)
		label_for.call(v)
		changed.emit())
