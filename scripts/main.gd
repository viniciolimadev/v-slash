class_name MatchScene
extends Node3D
## Uma partida: monta tudo por código (quadra, câmera, jogadores, bola, marcadores e UI).
## O App define `config` (e `save`) antes de adicionar a cena; sozinha, roda em rally infinito.
## Demo bot x bot: rode com o argumento de usuário  -- --autoplay
## Só lógica (simulações rápidas, sem modelos, quadra nem efeitos):  -- --no-views
## Contador de fps (médio e p1):  -- --fps

signal match_finished(result: MatchResult)
signal exit_requested
signal tutorial_finished(skipped: bool)

const HOME_COLOR := Color(0.13, 0.58, 0.92)
const AWAY_COLOR := Color(0.95, 0.42, 0.24)

var autoplay := false               # os dois lados controlados pela IA
var views := true                   # false = --no-views: a lógica roda igual, sem nada de visual (ADR-09)
var config: MatchConfig = null      # null = padrão (rally infinito contra o Fácil)
var save: SaveData = null           # só com o App: habilita Opções e Sair na pausa
var game: Game
var court_spec: CourtSpec           # quadra do modo da config
var human: Player
var foe: Player
var partner: Player = null          # 2v2: seu parceiro (IA)
var foe2: Player = null             # 2v2: o segundo da dupla adversária
var controls: TouchControls
var hud: Hud
var markers: Markers
var cam: Camera3D
var court_view: CourtView = null    # praia (Fase 4); null com --no-views ou USE_MODEL_VIEWS = false
var fx: Fx = null                   # efeitos (rastro, areia, brilho, tremor); null com --no-views
var sfx: Sfx = null                 # sons e música da partida; null com --no-views
var fps: FpsMeter                   # fps médio/p1 (contador com -- --fps; e2e lê na Web)
var stats := MatchStats.new()
var pause_menu: PauseMenu
var tutorial: TutorialDirector = null
var _options: CanvasLayer = null
var _finished := false


func _ready() -> void:
	if "--autoplay" in OS.get_cmdline_user_args():
		autoplay = true
	if "--no-views" in OS.get_cmdline_user_args():
		views = false
	if config == null:
		config = MatchConfig.new()
	UiTheme.install()
	_setup_input()
	_build_world()
	_build_match()
	_build_ui()


func _physics_process(delta: float) -> void:
	if not autoplay:
		_me().move_input = controls.get_move()
	game.tick(delta)
	if tutorial != null:
		tutorial.tick(delta)


func _process(_delta: float) -> void:
	markers.refresh()
	controls.action_label = game.action_label(_me())
	controls.action_act = game.current_act(_me())
	controls.action_hot = game.is_hot(_me())
	controls.queue_redraw()
	hud.set_board(game.rules, game.rally_touches, game.best_rally)
	if court_view != null:
		court_view.react((game.rally_touches - 4) / 10.0)
	hud.show_serve_picker(_can_pick_serve(), game.serve_type[human.team])
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

	court_spec = CourtSpec.for_mode(config.mode)
	if views and Tuning.USE_MODEL_VIEWS:
		court_view = CourtView.new()
		court_view.spec = court_spec
		add_child(court_view)
	elif views:
		var court := Court.new()
		court.spec = court_spec
		add_child(court)

	# câmera atrás do seu lado, alta o bastante para ver as duas quadras
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.5
	cam.far = 200.0
	add_child(cam)
	var eye := Vector3(0.0, 14.0, 21.0)
	if config.mode == MatchConfig.Mode.TWO_V_TWO:
		# quadra 8 × 8: mais alto e mais aberto para caber a quadra inteira e os sacadores
		cam.fov = 40.0
		eye = Vector3(0.0, 16.0, 24.0)
	cam.look_at_from_position(eye, Vector3(0.0, 0.0, 0.5), Vector3.UP)
	cam.make_current()


func _build_match() -> void:
	human = Player.new()
	add_child(human)
	human.setup(0, not autoplay, HOME_COLOR)
	foe = Player.new()
	add_child(foe)
	foe.setup(1, false, AWAY_COLOR)
	var two := config.mode == MatchConfig.Mode.TWO_V_TWO
	if two:
		partner = Player.new()
		add_child(partner)
		partner.setup(0, false, HOME_COLOR.darkened(0.25))
		foe2 = Player.new()
		add_child(foe2)
		foe2.setup(1, false, AWAY_COLOR.darkened(0.25))
	var ball := Ball.new()
	add_child(ball)
	game = Game.new()
	game.court = court_spec
	add_child(game)
	var players: Array[Player] = [human, foe]
	var bots: Array[BotBrain] = []
	if not config.tutorial:
		bots.append(BotBrain.new(foe, game, config.bot_level))
	if autoplay:
		bots.append(BotBrain.new(human, game, 1))
	if two:
		players = [human, partner, foe, foe2]
		bots.append(BotBrain.new(foe2, game, config.bot_level))
		bots.append(BotBrain.new(partner, game, Tuning.PARTNER_LEVEL))
		if not autoplay:
			# quando o controle passa para o parceiro, este jogador vira IA de parceiro
			bots.append(BotBrain.new(human, game, Tuning.PARTNER_LEVEL))
			for b in bots:
				b.partner_mode = b.p.team == human.team
	game.rules = MatchRules.new(0 if config.endless else Tuning.SET_POINTS).for_mode(config.mode)
	game.setup(ball, players, bots)
	game.set_bot_level(config.bot_level)
	game.aim_sens = config.aim_sens
	game.serve_type[human.team] = config.serve_type
	if two and not autoplay:
		partner.set_ring(1, false)
		game.control_changed.connect(func(p: Player) -> void:
			for q in game.teams[p.team].players:
				q.set_ring(2 if q == p else 1, q == p))
	stats.attach(game)
	if views:
		_attach_views(ball)
	markers = Markers.new()
	add_child(markers)
	markers.setup(game, human)
	if config.tutorial:
		tutorial = TutorialDirector.new()
		tutorial.setup(game, human, markers)
		add_child(tutorial)
		tutorial.finished.connect(func(skipped: bool) -> void: tutorial_finished.emit(skipped))


## Views (ADR-09): filhas da lógica, só observam. Sem elas (--no-views) a partida é a mesma.
func _attach_views(ball: Ball) -> void:
	for p in game.players:
		var v: PlayerView
		if Tuning.USE_MODEL_VIEWS:
			var m := PlayerViewModel.new()
			m.uniform = game.teams[p.team].players.find(p)     # o segundo da dupla usa o 2º uniforme
			v = m
		else:
			v = PlayerViewSimple.new()
		p.add_child(v)
		v.bind(p, game)
	var bv := BallView.new()
	ball.add_child(bv)
	bv.bind(ball)
	fx = Fx.new()
	add_child(fx)
	fx.bind(game, cam)
	sfx = Sfx.new()
	add_child(sfx)
	sfx.bind(game, human.team)


## Primeira partida 2v2: faixa explicando a troca de controle (uma vez por save).
func _show_first_hint() -> void:
	if config.mode != MatchConfig.Mode.TWO_V_TWO or autoplay or save == null or save.hint_2v2_done:
		return
	hud.banner("O controle passa para quem vai tocar na bola", Color(1.0, 0.95, 0.65), Tuning.HINT_SECS)
	save.hint_2v2_done = true
	save.save_file()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	controls = TouchControls.new()
	controls.left_handed = config.left_handed
	layer.add_child(controls)
	hud = Hud.new()
	hud.layer = 2
	add_child(hud)
	hud.set_level_name(game.level_name())
	if config.tutorial:
		hud.set_mode(Hud.Mode.TUTORIAL)
	elif not config.endless:
		hud.set_mode(Hud.Mode.MATCH)
	fps = FpsMeter.new()
	add_child(fps)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	hud.pause_pressed.connect(pause_game)
	pause_menu.resume_pressed.connect(resume_game)
	pause_menu.restart_pressed.connect(func() -> void:
		resume_game()
		_on_reset())
	pause_menu.options_pressed.connect(_open_options)
	pause_menu.quit_pressed.connect(func() -> void:
		resume_game()
		exit_requested.emit())
	controls.action_pressed.connect(_on_action_pressed)
	controls.action_released.connect(_on_action_released)
	controls.aim_dragged.connect(_on_aim_dragged)
	hud.reset_pressed.connect(_on_reset)
	hud.level_pressed.connect(_on_level)
	hud.serve_type_chosen.connect(_on_serve_type)
	game.served.connect(_on_served)
	game.touch_made.connect(_on_touch)
	game.whiffed.connect(_on_whiff)
	game.point_scored.connect(_on_point)
	game.set_over.connect(_on_set_over)
	game.match_over.connect(_on_match_over)
	_show_first_hint()


## Quem você controla agora (no 2v2 muda durante o rally; no 1v1 é sempre `human`).
func _me() -> Player:
	return game.human if game.human != null else human


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
		game.human_press(_me())


func _on_action_released() -> void:
	if not autoplay:
		game.human_release(_me())


func _on_aim_dragged(rel: Vector2) -> void:
	if not autoplay:
		game.human_drag(_me(), rel)


func _on_reset() -> void:
	game.reset_match()
	stats.reset()
	hud.banner("", Color.WHITE, 0.0)


func _on_level() -> void:
	game.set_bot_level((game.bot_level + 1) % 3)
	hud.set_level_name(game.level_name())


## Escolher o saque só faz sentido parado no seu saque (no tutorial, não).
func _can_pick_serve() -> bool:
	return not autoplay and tutorial == null and game.state == Game.State.SERVE_WAIT \
			and game.server == _me() and not game.human_aiming


func _on_serve_type(kind: int) -> void:
	game.serve_type[human.team] = kind
	config.serve_type = kind
	if save != null:
		save.serve_type = kind
		save.save_file()


func _on_served(p: Player, _kind: int, grade: String) -> void:
	# saque com timing mostra a nota como os outros toques; por baixo não tem nota
	if p == _me() and grade != "SAQUE":
		var perfect := grade == "PERFEITO!"
		hud.popup(grade, Color(0.45, 1.0, 0.55) if perfect else Color(1.0, 0.95, 0.65), perfect)


func _on_touch(p: Player, grade: String, quality: float) -> void:
	if p != _me() or grade == "SAQUE":
		return
	var perfect := quality >= 1.0
	hud.popup(grade, Color(0.45, 1.0, 0.55) if perfect else Color(1.0, 0.95, 0.65), perfect)
	if game.last_kind == Game.Act.BLOCK:
		_vibrate(Tuning.VIBRATE_BLOCK)
	else:
		_vibrate(Tuning.VIBRATE_PERFECT if perfect else Tuning.VIBRATE_GOOD)


func _vibrate(ms: int, times := 1) -> void:
	if not config.vibration or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(ms)
	if times > 1:
		get_tree().create_timer(0.1).timeout.connect(func() -> void: _vibrate(ms, times - 1))


func _on_whiff(p: Player, why: String) -> void:
	if p == _me():
		hud.popup(why, Color(1.0, 0.45, 0.4))


func _on_point(team: int, reason: String) -> void:
	if court_view != null:
		court_view.react(0.0, 1.2)
	if team == human.team:
		hud.message("Ponto seu! " + reason, Color(0.55, 1.0, 0.65))
		_vibrate(Tuning.VIBRATE_POINT, 2)
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
	get_tree().create_timer(Tuning.MATCH_END_DELAY).timeout.connect(finish_match)


## Entrega o resultado (uma vez só) para quem abriu a partida.
func finish_match() -> void:
	if _finished or game.rules.winner < 0:
		return
	_finished = true
	var r := MatchResult.new(game.rules.winner, config.bot_level, game.rules.history, stats)
	r.mode = config.mode
	match_finished.emit(r)


# ---------------------------------------------------------------- pausa e opções

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		pause_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and _is_touch_device():
		pause_game()        # no PC perder o foco da janela não pausa (atrapalharia o e2e e o dev)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:
			resume_game()
		else:
			pause_game()


func pause_game() -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	game.cancel_aim()       # soltar o dedo depois de voltar não pode disparar um toque
	get_tree().paused = true
	pause_menu.open(save != null)


func resume_game() -> void:
	_close_options()
	pause_menu.close()
	get_tree().paused = false


## Opções lidas do save valem na hora, inclusive com a partida pausada.
func apply_options() -> void:
	if save == null:
		return
	config.aim_sens = save.aim_sens
	config.left_handed = save.left_handed
	config.vibration = save.vibration
	game.aim_sens = save.aim_sens
	controls.left_handed = save.left_handed
	controls.queue_redraw()


func _open_options() -> void:
	if save == null or _options != null:
		return
	pause_menu.close()
	_options = CanvasLayer.new()
	_options.layer = 6
	_options.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_options)
	var scr := OptionsScreen.new()
	scr.save = save
	scr.changed.connect(apply_options)
	scr.closed.connect(func() -> void:
		_close_options()
		pause_menu.open(true))
	_options.add_child(scr)


func _close_options() -> void:
	if _options != null:
		_options.queue_free()
		_options = null


func _is_touch_device() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


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
