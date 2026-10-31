extends Node3D
## Monta tudo por código: quadra, câmera, jogadores, bola, marcadores e UI.
## Demo bot x bot: rode com o argumento de usuário  -- --autoplay

const HOME_COLOR := Color(0.13, 0.58, 0.92)
const AWAY_COLOR := Color(0.95, 0.42, 0.24)

var autoplay := false               # os dois lados controlados pela IA
var game: Game
var human: Player
var foe: Player
var controls: TouchControls
var hud: Hud
var markers: Markers
var cam: Camera3D


func _ready() -> void:
	if "--autoplay" in OS.get_cmdline_user_args():
		autoplay = true
	_setup_input()
	_build_world()
	_build_match()
	_build_ui()


func _physics_process(delta: float) -> void:
	if not autoplay:
		human.move_input = controls.get_move()
	game.tick(delta)


func _process(_delta: float) -> void:
	markers.refresh()
	controls.action_label = game.action_label(human)
	controls.action_hot = game.is_hot(human)
	controls.queue_redraw()
	hud.set_board(game.rules, game.rally_touches, game.best_rally)
	_update_badge()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.76, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.0
	add_child(sun)

	add_child(Court.new())

	# câmera atrás do seu lado, alta o bastante para ver as duas quadras
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.5
	cam.far = 200.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 14.0, 21.0), Vector3(0.0, 0.0, 0.5), Vector3.UP)
	cam.make_current()


func _build_match() -> void:
	human = Player.new()
	add_child(human)
	human.setup(0, not autoplay, HOME_COLOR)
	foe = Player.new()
	add_child(foe)
	foe.setup(1, false, AWAY_COLOR)
	var ball := Ball.new()
	add_child(ball)
	game = Game.new()
	add_child(game)
	var players: Array[Player] = [human, foe]
	var bots: Array[BotBrain] = [BotBrain.new(foe, game, game.bot_level)]
	if autoplay:
		bots.append(BotBrain.new(human, game, 1))
	game.setup(ball, players, bots)
	markers = Markers.new()
	add_child(markers)
	markers.setup(game, human)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	controls = TouchControls.new()
	layer.add_child(controls)
	hud = Hud.new()
	hud.layer = 2
	add_child(hud)
	hud.set_level_name(game.level_name())
	controls.action_pressed.connect(_on_action_pressed)
	controls.action_released.connect(_on_action_released)
	controls.aim_dragged.connect(_on_aim_dragged)
	hud.reset_pressed.connect(_on_reset)
	hud.level_pressed.connect(_on_level)
	game.touch_made.connect(_on_touch)
	game.whiffed.connect(_on_whiff)
	game.point_scored.connect(_on_point)
	game.set_over.connect(_on_set_over)
	game.match_over.connect(_on_match_over)


func _setup_input() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])


func _add_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _on_action_pressed() -> void:
	if not autoplay:
		game.human_press(human)


func _on_action_released() -> void:
	if not autoplay:
		game.human_release(human)


func _on_aim_dragged(rel: Vector2) -> void:
	if not autoplay:
		game.human_drag(human, rel)


func _on_reset() -> void:
	game.reset_match()
	hud.banner("", Color.WHITE, 0.0)


func _on_level() -> void:
	game.set_bot_level((game.bot_level + 1) % 3)
	hud.set_level_name(game.level_name())


func _on_touch(p: Player, grade: String, quality: float) -> void:
	if p != human or grade == "SAQUE":
		return
	var perfect := quality >= 1.0
	hud.popup(grade, Color(0.45, 1.0, 0.55) if perfect else Color(1.0, 0.95, 0.65))
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(45 if perfect else 20)


func _on_whiff(p: Player, why: String) -> void:
	if p == human:
		hud.popup(why, Color(1.0, 0.45, 0.4))


func _on_point(team: int, reason: String) -> void:
	if team == human.team:
		hud.message("Ponto seu! " + reason, Color(0.55, 1.0, 0.65))
	else:
		hud.message("Ponto do bot. " + reason, Color(1.0, 0.62, 0.52))


func _on_set_over(team: int, set_index: int, final: Vector2i) -> void:
	if game.rules.winner >= 0:
		return              # último set: a faixa de fim de partida cobre
	hud.banner("Fim do %dº set — %d × %d" % [set_index + 1, final.x, final.y],
			_team_color(team), Tuning.SET_PAUSE)


func _on_match_over(team: int) -> void:
	var text := "VOCÊ VENCEU!" if team == human.team else "O BOT VENCEU"
	hud.banner(text, _team_color(team), 3600.0)


func _update_badge() -> void:
	var rules := game.rules
	for team in [0, 1]:
		if rules.is_match_point(team):
			hud.set_badge("MATCH POINT", _team_color(team))
			return
		if rules.is_set_point(team):
			hud.set_badge("SET POINT", _team_color(team))
			return
	hud.set_badge("", Color.WHITE)


func _team_color(team: int) -> Color:
	return (HOME_COLOR if team == 0 else AWAY_COLOR).lightened(0.35)
