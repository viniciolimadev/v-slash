class_name Hud
extends CanvasLayer
## Placar, contador de rally (meta da Fase 0: 5+ toques), feedback de timing e botões do topo.

signal reset_pressed
signal level_pressed

var _score: Label
var _rally: Label
var _popup: Label
var _message: Label
var _level_btn: Button
var _popup_tw: Tween
var _msg_tw: Tween


func _ready() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score = _make_label(root, 34, 8.0, 46.0)
	_rally = _make_label(root, 20, 52.0, 28.0)
	_popup = _make_label(root, 46, 84.0, 60.0)
	_message = _make_label(root, 30, 142.0, 44.0)
	_popup.modulate.a = 0.0
	_message.modulate.a = 0.0

	var reset := _make_button(root, "↺ Reiniciar")
	reset.position = Vector2(14.0, 12.0)
	reset.pressed.connect(func() -> void: reset_pressed.emit())

	_level_btn = _make_button(root, "Bot: Médio")
	_level_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_level_btn.offset_left = -204.0
	_level_btn.offset_right = -14.0
	_level_btn.offset_top = 12.0
	_level_btn.offset_bottom = 58.0
	_level_btn.pressed.connect(func() -> void: level_pressed.emit())


func set_board(score: Array[int], rally: int, best: int) -> void:
	_score.text = "VOCÊ %d  ×  %d BOT" % [score[0], score[1]]
	_rally.text = "Rally: %d toques   ·   Recorde: %d" % [rally, best]


func set_level_name(level_text: String) -> void:
	_level_btn.text = "Bot: " + level_text


## Feedback rápido do toque (PERFEITO!, BOM, CEDO, LONGE...).
func popup(text: String, color: Color) -> void:
	_popup.text = text
	_popup.modulate = color
	if _popup_tw != null and _popup_tw.is_valid():
		_popup_tw.kill()
	_popup_tw = create_tween()
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


func _make_label(parent: Control, font_size: int, top: float, height: float) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.outline_size = maxi(4, int(font_size * 0.2))
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.offset_bottom = top + height
	return l


func _make_button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(190.0, 46.0)
	parent.add_child(b)
	return b
