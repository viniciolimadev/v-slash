class_name Hud
extends CanvasLayer
## Placar (pontos e sets), selo de set/match point, rally, feedback de timing e botões do topo.

signal reset_pressed
signal level_pressed
signal pause_pressed
signal serve_type_chosen(kind: int)

## STANDALONE: main.tscn sozinha (Reiniciar + nível do bot). MATCH: partida do App (pausa).
## TUTORIAL: sem placar, só pausa.
enum Mode { STANDALONE, MATCH, TUTORIAL }

var _score: Label
var _plate: PanelContainer
var _rally: Label
var _badge: Label
var _banner: Label
var _popup: Label
var _message: Label
var _level_btn: Button
var _reset_btn: Button
var _pause_btn: Button
var _serve_box: HBoxContainer
var _serve_btns: Array[Button] = []
var _popup_tw: Tween
var _msg_tw: Tween
var _banner_tw: Tween


func _ready() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# "and_offsets": só set_anchors_preset() mantém o retângulo atual (0x0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# placar numa "plaquinha" no centro do topo
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.offset_top = 6.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	plate.add_child(box)
	_score = _plain_label(box, 34)
	_rally = _plain_label(box, 18)
	_plate = plate
	_badge = _make_label(root, 22, 96.0, 28.0)
	_popup = _make_label(root, 46, 120.0, 60.0)
	_message = _make_label(root, 30, 178.0, 44.0)
	_banner = _make_label(root, 44, 250.0, 84.0)
	var band := StyleBoxFlat.new()
	band.bg_color = UiTheme.PANEL
	_banner.add_theme_stylebox_override("normal", band)
	_popup.modulate.a = 0.0
	_message.modulate.a = 0.0
	_banner.modulate.a = 0.0

	_reset_btn = _make_button(root, "Reiniciar")
	_reset_btn.position = Vector2(14.0, 12.0)
	_reset_btn.pressed.connect(func() -> void: reset_pressed.emit())

	_pause_btn = _make_button(root, "II")
	_pause_btn.custom_minimum_size = Vector2(76.0, 64.0)
	_pause_btn.add_theme_font_size_override("font_size", 28)
	_pause_btn.size = _pause_btn.custom_minimum_size
	_pause_btn.position = Vector2(14.0, 12.0)
	_pause_btn.visible = false
	_pause_btn.pressed.connect(func() -> void: pause_pressed.emit())

	_level_btn = _make_button(root, "Bot: Médio")
	_level_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_level_btn.offset_left = -204.0
	_level_btn.offset_right = -14.0
	_level_btn.offset_top = 12.0
	_level_btn.offset_bottom = 58.0
	_level_btn.pressed.connect(func() -> void: level_pressed.emit())

	# seletor do tipo de saque (topo direito, dentro da faixa que não conta como toque de jogo)
	_serve_box = HBoxContainer.new()
	_serve_box.add_theme_constant_override("separation", 6)
	root.add_child(_serve_box)
	_serve_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_serve_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_serve_box.offset_top = 10.0
	_serve_box.offset_bottom = 74.0
	_place_serve_box(Mode.STANDALONE)
	_serve_box.visible = false
	var group := ButtonGroup.new()
	for kind in ServeType.NAMES.size():
		var b := Button.new()
		b.text = str(ServeType.NAMES[kind])
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_group = group
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_constant_override("outline_size", 4)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := b.get_theme_stylebox(st).duplicate() as StyleBoxFlat
			sb.content_margin_left = 6.0
			sb.content_margin_right = 6.0
			b.add_theme_stylebox_override(st, sb)
		b.custom_minimum_size = Vector2(128.0, 64.0)
		b.pressed.connect(func() -> void: serve_type_chosen.emit(kind))
		_serve_box.add_child(b)
		_serve_btns.append(b)


func set_mode(mode: Mode) -> void:
	_reset_btn.visible = mode == Mode.STANDALONE
	_level_btn.visible = mode == Mode.STANDALONE
	_pause_btn.visible = mode != Mode.STANDALONE
	_plate.visible = mode != Mode.TUTORIAL
	_place_serve_box(mode)
	if mode != Mode.STANDALONE:
		E2eHooks.publish("hud/pause", _pause_btn)


func set_board(rules: MatchRules, rally: int, best: int) -> void:
	_score.text = "VOCÊ %d  ×  %d BOT" % [rules.points[0], rules.points[1]]
	var line := "Rally: %d toques   ·   Recorde: %d" % [rally, best]
	if not rules.is_endless():
		line = "Sets %d – %d   ·   " % [rules.sets[0], rules.sets[1]] + line
	_rally.text = line


## Selo fixo sob o placar ("SET POINT", "MATCH POINT"); texto vazio esconde.
func set_badge(text: String, color: Color) -> void:
	_badge.text = text
	_badge.modulate = color


## Seletor de saque: aparece só antes do seu saque, com o tipo atual marcado.
func show_serve_picker(on: bool, kind: int) -> void:
	if on and not _serve_box.visible:
		for i in _serve_btns.size():
			E2eHooks.publish("hud/serve/%d" % i, _serve_btns[i])
	_serve_box.visible = on
	if on and not _serve_btns[kind].button_pressed:
		_serve_btns[kind].set_pressed_no_signal(true)


func set_level_name(level_text: String) -> void:
	_level_btn.text = "Bot: " + level_text


## Feedback rápido do toque (PERFEITO!, BOM, CEDO, LONGE...). punch = entra grande (PERFEITO).
func popup(text: String, color: Color, punch := false) -> void:
	_popup.text = text
	_popup.modulate = color
	if _popup_tw != null and _popup_tw.is_valid():
		_popup_tw.kill()
	_popup.pivot_offset = _popup.size * 0.5
	_popup.scale = Vector2.ONE * (1.6 if punch else 1.0)
	_popup_tw = create_tween()
	if punch:
		_popup_tw.tween_property(_popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_popup_tw.tween_interval(0.45)
	_popup_tw.tween_property(_popup, "modulate:a", 0.0, 0.35)


## Mensagem de ponto.
func message(text: String, color: Color) -> void:
	_message.text = text
	_message.modulate = color
	if _msg_tw != null and _msg_tw.is_valid():
		_msg_tw.kill()
	_msg_tw = create_tween()
	_msg_tw.tween_interval(1.2)
	_msg_tw.tween_property(_message, "modulate:a", 0.0, 0.4)


## Faixa grande no meio da tela (fim de set, fim de partida).
func banner(text: String, color: Color, secs: float) -> void:
	_banner.text = text
	_banner.modulate = color
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_tw.tween_interval(secs)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


## Sozinha (F6) o botão do nível ocupa o canto: o seletor de saque fica à esquerda dele.
func _place_serve_box(mode: Mode) -> void:
	_serve_box.offset_right = -214.0 if mode == Mode.STANDALONE else -14.0
	_serve_box.offset_left = _serve_box.offset_right


func _make_label(parent: Control, font_size: int, top: float, height: float) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.outline_size = maxi(4, int(font_size * 0.2))
	ls.outline_color = UiTheme.INK
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.offset_bottom = top + height
	return l


func _plain_label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.outline_size = maxi(4, int(font_size * 0.2))
	ls.outline_color = UiTheme.INK
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _make_button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(190.0, 56.0)
	parent.add_child(b)
	return b
