class_name TutorialDirector
extends Node
## Tutorial jogável em 3 passos: andar até o anel, soltar no tempo, mirar uma zona.
## Usa o Game em rally infinito e sem bot; cada passo se repete até dar certo.
## main.gd chama tick() a cada quadro de física, depois de game.tick().

signal finished(skipped: bool)

enum Step { MOVE, TIMING, AIM, DONE }

const TARGET_ZONE := "FUNDO ESQ"
const HINT_AFTER := 3               # falhas seguidas antes de mostrar a dica
const DONE_TIME := 2.0
const MOVE_DIST := 0.5              # m do anel para contar "chegou"
const MOVE_FLIGHT := 2.2            # s: bola lenta no 1º passo
const TEXTS := [
	"1/3 · Ande até o anel colorido no chão (joystick)",
	"2/3 · Segure o botão e solte quando o anel branco encostar no colorido",
	"3/3 · Segure o botão, arraste a mira até FUNDO ESQ e solte para sacar",
	"Pronto! Agora é contra o bot.",
]
const HINTS := [
	"Dica: o anel aparece onde a bola vai chegar — chegue lá antes dela.",
	"Dica: solte no instante em que os anéis se encostam (o botão fica verde).",
	"Dica: arraste para a esquerda e para cima até a mira grudar em FUNDO ESQ.",
	"",
]

var game: Game
var human: Player
var markers: Markers
var step: int = Step.MOVE
var fails := 0

var _ok := false                    # objetivo do passo cumprido nesta bola
var _zone := ""                     # zona em que a mira estava antes de sacar
var _done_t := 0.0
var _ended := false
var _text: Label


func setup(g: Game, h: Player, m: Markers) -> void:
	game = g
	human = h
	markers = m
	game.touch_made.connect(_on_touch)
	game.point_scored.connect(_on_point)


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font_size = 28
	ls.outline_size = 6
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	_text.label_settings = ls
	root.add_child(_text)
	_text.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_text.offset_left = 110.0           # livre do botão de pausa
	_text.offset_right = -230.0         # e do PULAR
	_text.offset_top = 12.0
	_text.offset_bottom = 100.0
	var skip_btn := Button.new()
	skip_btn.text = "PULAR"
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.add_theme_font_size_override("font_size", 24)
	root.add_child(skip_btn)
	skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.offset_left = -204.0
	skip_btn.offset_right = -14.0
	skip_btn.offset_top = 12.0
	skip_btn.offset_bottom = 68.0
	skip_btn.pressed.connect(skip)
	E2eHooks.publish("tutorial/skip", skip_btn)
	_show_text()


func tick(dt: float) -> void:
	if _ended:
		return
	if step == Step.MOVE or step == Step.TIMING:
		if game.state == Game.State.SERVE_WAIT:
			_feed()
		var plan := game.plan
		if step == Step.MOVE and not _ok and plan != null and plan.player == human and game.time <= plan.t:
			if Vector2(plan.pos.x - human.position.x, plan.pos.z - human.position.z).length() <= MOVE_DIST:
				_ok = true
				_say("Isso! Esse é o lugar do próximo toque.")
	elif step == Step.AIM:
		if game.state == Game.State.SERVE_WAIT:
			if game.server != human:
				game.reset_match()          # quem saca neste passo é você
			var view := game.human_aim_view()
			_zone = str(view.get("name", ""))
	elif step == Step.DONE:
		_done_t -= dt
		if _done_t <= 0.0:
			_end(false)


func skip() -> void:
	_end(true)


func _feed() -> void:
	var w := Tuning.COURT_HALF_W - 0.6
	if step == Step.MOVE:
		var to := human.position + Vector3(2.3 if human.position.x < 0.5 else -2.3, 0.0, 0.6)
		game.feed_ball(Vector3(clampf(to.x, -w, w), 0.0, clampf(to.z, 1.5, Tuning.COURT_DEPTH - 0.6)), MOVE_FLIGHT)
	else:
		var to := human.position + Vector3(0.6, 0.0, 0.3)
		game.feed_ball(Vector3(clampf(to.x, -w, w), 0.0, clampf(to.z, 1.5, Tuning.COURT_DEPTH - 0.6)),
				Tuning.T_RECEIVE)


func _on_touch(p: Player, grade: String, _q: float) -> void:
	if p != human or _ended:
		return
	if step == Step.TIMING and (grade == "PERFEITO!" or grade == "BOM"):
		_ok = true
		_say("Boa! " + grade)
	elif step == Step.AIM and grade == "SAQUE" and _zone == TARGET_ZONE:
		_ok = true


## A bola caiu: conclui o passo ou conta uma tentativa.
func _on_point(_team: int, _why: String) -> void:
	if _ended or step == Step.DONE:
		return
	if _ok:
		_next()
	else:
		fails += 1
		_show_text()
	_ok = false


func _next() -> void:
	step += 1
	fails = 0
	markers.highlight_zone(TARGET_ZONE if step == Step.AIM else "")
	if step == Step.DONE:
		_done_t = DONE_TIME
	_show_text()


func _show_text() -> void:
	var t: String = TEXTS[step]
	if fails >= HINT_AFTER and str(HINTS[step]) != "":
		t += "\n" + str(HINTS[step])
	_say(t)


func _say(t: String) -> void:
	if _text != null:
		_text.text = t


func _end(skipped: bool) -> void:
	if _ended:
		return
	_ended = true
	markers.highlight_zone("")
	finished.emit(skipped)
