class_name Screen
extends Control
## Base das telas de menu: fundo, coluna centralizada e botões grandes para o polegar.
## Cada tela monta o conteúdo em _build() e avisa o App por sinais.

const ENTER_TIME := 0.2                      # s do esmaecer de entrada
const BUTTON_SIZE := Vector2(420.0, 72.0)    # alvo de toque >= 64 px de altura (RNF-1.04)
const GAP := 14.0

var screen_name := "screen"                  # chave do e2e (window.__vs.screen)
var column: VBoxContainer
var dim := false                             # true = fundo escuro translúcido (pausa) em vez da praia


func _ready() -> void:
	UiTheme.install()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: Control
	if dim:
		var rect := ColorRect.new()
		rect.color = Color(0.0, 0.0, 0.0, 0.6)
		bg = rect
	else:
		bg = ScreenBackdrop.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(GAP))
	center.add_child(column)
	_build()
	E2eHooks.set_screen(screen_name)
	# entrada: só esmaece (não desloca: o e2e mede os botões no primeiro quadro)
	center.modulate.a = 0.0
	create_tween().tween_property(center, "modulate:a", 1.0, ENTER_TIME)


func _build() -> void:
	pass


func add_title(text: String, font_size := 56) -> Label:
	return add_line(text, font_size, Color.WHITE)


func add_line(text: String, font_size := 26, color := Color(0.85, 0.9, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = maxi(4, int(font_size * 0.18))
	ls.outline_color = UiTheme.INK
	l.label_settings = ls
	column.add_child(l)
	return l


## Botão grande; `key` é o nome para o e2e ("<tela>/<key>").
func add_button(text: String, key: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = BUTTON_SIZE
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func() -> void: get_tree().call_group("ui_click", "play"))
	b.pressed.connect(on_press)
	column.add_child(b)
	E2eHooks.publish(screen_name + "/" + key, b)
	return b


func add_space(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	column.add_child(c)
