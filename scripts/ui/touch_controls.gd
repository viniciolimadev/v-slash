class_name TouchControls
extends Control
## Controles de toque.
##   Metade esquerda: joystick flutuante (nasce onde o polegar encosta).
##   Metade direita: botão de ação. Segurar = mira aparece; arrastar = move a mira;
##   soltar = toca na bola. O texto do botão muda com o contexto (SACAR, RECEBER...).
## No PC: WASD/setas andam; espaço (ou J) = botão de ação; mouse imita o toque.

signal action_pressed
signal action_released
signal aim_dragged(rel: Vector2)

const JOY_RADIUS := 95.0
const KNOB_RADIUS := 42.0
const BTN_RADIUS := 88.0
const TOP_BAR := 80.0               # faixa dos botões do topo (não conta como toque de jogo)
const DEAD_ZONE := 0.12

var action_label := ""
var action_act := 0                 # Game.Act do botão agora (ícone acima do texto)
var action_hot := false             # true quando está na hora de soltar
var left_handed := false            # canhoto: botão de ação à esquerda, joystick à direita

var _move := Vector2.ZERO
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _act_index := -1
var _act_start := Vector2.ZERO
var _act_pos := Vector2.ZERO
var _key_down := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Direção do movimento: joystick tem prioridade; senão, teclado.
func get_move() -> Vector2:
	if _joy_index != -1:
		return _move if _move.length() > DEAD_ZONE else Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if st.position.y < TOP_BAR:
				return
			if _is_move_side(st.position.x):
				if _joy_index == -1:
					_joy_index = st.index
					_joy_origin = st.position
					_joy_pos = st.position
					_move = Vector2.ZERO
			elif _act_index == -1:
				_act_index = st.index
				_act_start = st.position
				_act_pos = st.position
				action_pressed.emit()
		elif st.index == _joy_index:
			_joy_index = -1
			_move = Vector2.ZERO
		elif st.index == _act_index:
			_act_index = -1
			action_released.emit()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_index:
			_joy_pos = sd.position
			_move = (_joy_pos - _joy_origin).limit_length(JOY_RADIUS) / JOY_RADIUS
			queue_redraw()
		elif sd.index == _act_index:
			_act_pos = sd.position
			aim_dragged.emit(sd.relative)
			queue_redraw()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.echo or not (k.physical_keycode == KEY_SPACE or k.physical_keycode == KEY_J):
			return
		if k.pressed and not _key_down:
			_key_down = true
			action_pressed.emit()
		elif not k.pressed and _key_down:
			_key_down = false
			action_released.emit()


## Tamanho da tela. Não usa `size`: este Control fica direto num CanvasLayer
## e o tamanho dele pode ficar 0x0 (aí o joystick nunca era ativado).
func _screen() -> Vector2:
	return get_viewport_rect().size


func _is_move_side(x: float) -> bool:
	return (x < _screen().x * 0.5) != left_handed


func _joy_home() -> Vector2:
	if left_handed:
		return Vector2(_screen().x - 170.0, _screen().y - 170.0)
	return Vector2(170.0, _screen().y - 170.0)


func _button_center() -> Vector2:
	if left_handed:
		return Vector2(170.0, _screen().y - 170.0)
	return Vector2(_screen().x - 170.0, _screen().y - 170.0)


func _draw() -> void:
	# joystick
	# fundo escuro translúcido: lê bem sobre a areia clara
	var base := _joy_origin if _joy_index != -1 else _joy_home()
	draw_circle(base, JOY_RADIUS, Color(0.03, 0.1, 0.16, 0.28))
	draw_arc(base, JOY_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.55), 3.0, true)
	var knob := base
	if _joy_index != -1:
		knob = base + (_joy_pos - base).limit_length(JOY_RADIUS)
	draw_circle(knob, KNOB_RADIUS, Color(1.0, 1.0, 1.0, 0.7))
	draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 32, Color(0.03, 0.1, 0.16, 0.5), 2.0, true)

	# botão de ação: ícone da ação em cima, texto embaixo (o texto ensina, o ícone se lê rápido)
	var c := _button_center()
	var col := Color(0.03, 0.1, 0.16, 0.3)
	if action_label != "":
		col = Color(0.1, 0.62, 0.58, 0.75)
	if action_hot:
		col = Color(0.3, 1.0, 0.45, 0.9)
	if _act_index != -1 or _key_down:
		col = col.lightened(0.25)
	draw_circle(c, BTN_RADIUS + 4.0, Color(0.03, 0.1, 0.16, 0.35))
	draw_circle(c, BTN_RADIUS, col)
	draw_arc(c, BTN_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.75), 3.0, true)
	var text := action_label if action_label != "" else "—"
	var ink := Color(0.05, 0.12, 0.2) if action_hot else Color.WHITE
	if action_label != "":
		Icons.draw_act(self, action_act, c + Vector2(0.0, -24.0), 24.0, ink)
	var font := ThemeDB.fallback_font
	var y := 40.0 if action_label != "" else 10.0
	draw_string_outline(font, c + Vector2(-BTN_RADIUS, y), text, HORIZONTAL_ALIGNMENT_CENTER, BTN_RADIUS * 2.0, 24,
			6, Color(0.05, 0.12, 0.2, 0.0 if action_hot else 0.8))
	draw_string(font, c + Vector2(-BTN_RADIUS, y), text, HORIZONTAL_ALIGNMENT_CENTER, BTN_RADIUS * 2.0, 24, ink)

	# rastro do dedo enquanto mira
	if _act_index != -1 and _act_pos.distance_to(_act_start) > 8.0:
		draw_line(_act_start, _act_pos, Color(1.0, 1.0, 1.0, 0.5), 3.0, true)
		draw_circle(_act_pos, 10.0, Color(1.0, 1.0, 1.0, 0.6))
