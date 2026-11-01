class_name UiTheme
extends RefCounted
## Tema do jogo (RF-4.09): fonte Fredoka, botões "pílula" com borda de baixo, controles deslizantes,
## painéis. Montado por código e instalado no tema padrão do Godot: vale para todas as telas,
## HUD e pausa (CanvasLayer não herda tema do pai, o tema padrão sim).

const FONT := "res://assets/fonts/Fredoka.ttf"
const INK := Color(0.05, 0.12, 0.2)            # contorno do texto e sombras
const PANEL := Color(0.05, 0.16, 0.26, 0.86)   # placas (placar, faixas)
const PRIMARY := Color(0.98, 0.5, 0.22)        # botões (laranja pôr do sol)
const TOGGLED := Color(0.1, 0.62, 0.58)        # botão ligado (verde-água)
const DISABLED := Color(0.36, 0.42, 0.48)


## Instala uma vez (App e partida sozinha chamam; a segunda chamada não faz nada).
static func install() -> void:
	var base := ThemeDB.get_default_theme()
	if base.has_constant("installed", "UiTheme"):
		return
	var t := build()
	base.merge_with(t)
	base.set_constant("installed", "UiTheme", 1)
	ThemeDB.fallback_font = t.default_font


static func font(weight := 500) -> Font:
	var f := FontVariation.new()
	f.base_font = load(FONT)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 28
	t.set_font("font", "Label", font(500))
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 6)
	# botões
	t.set_stylebox("normal", "Button", _pill(PRIMARY))
	t.set_stylebox("hover", "Button", _pill(PRIMARY.lightened(0.1)))
	t.set_stylebox("pressed", "Button", _pill(TOGGLED, true))
	t.set_stylebox("hover_pressed", "Button", _pill(TOGGLED.lightened(0.08), true))
	t.set_stylebox("disabled", "Button", _pill(DISABLED))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.85, 0.88, 0.9, 0.8))
	t.set_color("font_outline_color", "Button", INK.lerp(PRIMARY, 0.2))
	t.set_constant("outline_size", "Button", 6)
	# controle deslizante: trilho grosso e bolinha grande (fácil de pegar com o dedo)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1.0, 1.0, 1.0, 0.25)
	_round(track, 10)
	track.content_margin_top = 8.0
	track.content_margin_bottom = 8.0
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = PRIMARY
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := _circle(36, Color.WHITE, PRIMARY.darkened(0.3))
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	# placas (placar do HUD, faixas)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	_round(panel, 16)
	panel.border_color = Color(1.0, 1.0, 1.0, 0.18)
	panel.set_border_width_all(2)
	panel.content_margin_left = 22.0
	panel.content_margin_right = 22.0
	panel.content_margin_top = 4.0
	panel.content_margin_bottom = 6.0
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


static func _pill(c: Color, pressed := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	_round(s, 20)
	# borda de baixo mais escura dá volume; apertado "afunda" (borda some)
	s.border_color = c.darkened(0.35)
	s.border_width_bottom = 2 if pressed else 6
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 8.0 + (4.0 if pressed else 0.0)
	s.content_margin_bottom = 8.0
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	s.shadow_size = 0 if pressed else 4
	s.shadow_offset = Vector2(0.0, 3.0)
	return s


static func _round(s: StyleBoxFlat, r: int) -> void:
	s.corner_radius_top_left = r
	s.corner_radius_top_right = r
	s.corner_radius_bottom_left = r
	s.corner_radius_bottom_right = r


static func _circle(d: int, fill: Color, rim: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in d:
		for x in d:
			var k := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - k, 0.0, 1.0)
			img.set_pixel(x, y, Color(rim if k > r - 4.0 else fill, a))
	return ImageTexture.create_from_image(img)
