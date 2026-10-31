extends SceneTree
## Testes sem tela. Na pasta do projeto:
##   godot --headless --import
##   godot --headless --script res://tests/run_tests.gd
## Sai com código 1 se algum teste falhar.

const DT := 1.0 / 60.0

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== física da bola ==")
	_test_physics()
	print("== câmera (enquadramento) ==")
	_test_camera()
	print("== bot x bot (20 min simulados) ==")
	_test_bot_vs_bot()
	print("== humano roteirizado: aperta, mira e solta no tempo ==")
	_test_scripted_human()
	print("== controles de toque ==")
	_test_touch_controls()
	print("== HUD (layout) ==")
	_test_hud_layout()
	print("== mira ==")
	_test_aim()
	print("== assistência de mira ==")
	_test_aim_assist()
	print("== plano de contato ==")
	_test_contact_plan()
	print("== HitResolver (mesmos números do código antigo) ==")
	_test_hit_resolver()
	print("== tipos de saque ==")
	_test_serve_types()
	print("== saque flutuante ==")
	_test_float_physics()
	print("== bloqueio ==")
	_test_block()
	print("== regras da partida (sets) ==")
	_test_match_rules()
	print("== partida completa bot x bot ==")
	_test_match_flow()
	print("== estatísticas da partida ==")
	_test_stats()
	print("== save ==")
	_test_save()
	print("== pausa ==")
	_test_pause()
	print("== modo canhoto ==")
	_test_left_handed()
	print("== tutorial ==")
	_test_tutorial()
	print("== fluxo de telas (App) ==")
	_test_app_flow()
	print("== duração: humano casual x Fácil ==")
	_test_match_duration()
	print("falhas: %d" % fails)
	quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok     ", what)
	else:
		fails += 1
		print("  FALHA  ", what)


func _test_physics() -> void:
	# 1) a bola passa exatamente pelo alvo no tempo pedido
	var p0 := Vector3(0.0, 3.05, 1.0)
	var p1 := Vector3(1.0, Tuning.BALL_RADIUS, -5.0)
	var b := BallSim.new()
	b.pos = p0
	b.vel = BallSim.launch_velocity(p0, p1, 0.5)
	var t := 0.0
	var crossed := false
	while not b.landed and t < 2.0:
		for e in b.advance(DT):
			if int(e["type"]) == BallSim.Ev.CROSS:
				crossed = true
		t += DT
	_check(b.landed and b.pos.distance_to(p1) < 0.001, "cortada cai exatamente no alvo")
	_check(crossed, "cortada cruza a rede (evento CROSS)")
	_check(absf(t - 0.5) <= DT + 1e-6, "tempo de voo bate (%.3f s)" % t)

	# 2) bola baixa bate na rede, volta, e o preditor (dt 1/120) = bola real (dt 1/60)
	var start := BallSim.new()
	start.pos = Vector3(0.5, 1.0, 3.0)
	start.vel = BallSim.launch_velocity(start.pos, Vector3(0.0, Tuning.BALL_RADIUS, -3.0), 0.6)
	var pred := start.predict()
	var real := start.copy()
	var n := 0
	while not real.landed and n < 1000:
		real.advance(DT)
		n += 1
	var land: Vector3 = pred["land"]
	_check(real.net_hits == 1, "bola baixa bate na rede")
	_check(real.pos.z > 0.0, "e cai do lado de quem tocou")
	_check(land.distance_to(real.pos) < 0.001, "preditor = bola real (erro %.5f m)" % land.distance_to(real.pos))

	# 3) por fora da antena
	var ant := BallSim.new()
	ant.pos = Vector3(3.0, 3.0, 2.0)
	ant.vel = BallSim.launch_velocity(ant.pos, Vector3(7.0, Tuning.BALL_RADIUS, -4.0), 1.0)
	var got_antenna := false
	for _i in 200:
		for e in ant.advance(DT):
			if int(e["type"]) == BallSim.Ev.ANTENNA:
				got_antenna = true
	_check(got_antenna, "bola por fora da antena é detectada")

	# 4) mirar curto perto da rede: o tempo de voo cresce até passar por cima
	var f := Vector3(0.0, 0.9, 1.0)
	var v := BallSim.clear_net_velocity(f, Vector3(0.0, Tuning.BALL_RADIUS, -1.5), 0.3)
	var h := BallSim.height_at_net(f, v)
	_check(h >= Tuning.NET_HEIGHT + Tuning.BALL_RADIUS, "ajuste passa a bola por cima da rede (%.2f m)" % h)

	# 5) o plano acha o ponto de levantamento no tempo certo
	var up := BallSim.new()
	up.pos = Vector3(0.0, 0.9, 5.0)
	up.vel = BallSim.launch_velocity(up.pos, Vector3(0.8, Tuning.H_SET, 1.6), Tuning.T_RECEIVE)
	var d := BallSim.find_descent(up.predict(), Tuning.H_SET, 1.0)
	_check(not d.is_empty() and absf(float(d["t"]) - Tuning.T_RECEIVE) < 0.01,
			"preditor acha o ponto de contato do levantamento")


func _test_camera() -> void:
	var main := _make_main(true)
	var cam: Camera3D = main.get("cam")
	for aspect: float in [16.0 / 9.0, 20.0 / 9.0]:
		var proj := Projection.create_perspective(cam.fov, aspect, cam.near, cam.far)
		var view := cam.global_transform.affine_inverse()
		var names := ["fundo dele", "rede", "sua linha de fundo", "seu sacador"]
		var pts := [Vector3(0, 0, -7), Vector3(0, 2.43, 0), Vector3(3.5, 0, 7), Vector3(0, 0, 7.9)]
		var line := "  aspecto %.2f:" % aspect
		var all_in := true
		for i in pts.size():
			var w: Vector3 = view * Vector3(pts[i])
			var c := proj * Vector4(w.x, w.y, w.z, 1.0)
			var ndc := Vector2(c.x / c.w, c.y / c.w)
			var px := Vector2((ndc.x + 1.0) * 0.5 * 720.0 * aspect, (1.0 - ndc.y) * 0.5 * 720.0)
			line += "  %s=(%d,%d)" % [names[i], int(px.x), int(px.y)]
			if absf(ndc.x) > 1.0 or absf(ndc.y) > 1.0:
				all_in = false
		print(line)
		_check(all_in, "quadra inteira + sacador visíveis no aspecto %.2f" % aspect)
	_free_main(main)


func _test_bot_vs_bot() -> void:
	var main := _make_main(true)
	var game: Game = main.get("game")
	# "gap" = maior tempo sem NENHUM evento (toque ou ponto): mede travamento, não rally longo
	var stats := {"rallies": [], "last": 0.0, "gap": 0.0}
	var mark := func() -> void:
		stats["gap"] = maxf(float(stats["gap"]), game.time - float(stats["last"]))
		stats["last"] = game.time
	game.touch_made.connect(func(_p: Player, _g: String, _q: float) -> void: mark.call())
	game.point_scored.connect(func(_team: int, _why: String) -> void:
		stats["rallies"].append(game.rally_touches)
		mark.call())
	for _i in int(1200.0 / DT):
		game.tick(DT)
	var rallies: Array = stats["rallies"]
	var total := 0
	var long5 := 0
	for r in rallies:
		total += int(r)
		if int(r) >= 5:
			long5 += 1
	var count := maxi(rallies.size(), 1)
	print("  pontos=%d  placar=%d x %d  média de toques=%.1f  rallies 5+=%.0f%%  maior tempo sem evento=%.1f s" % [
			rallies.size(), game.rules.points[0], game.rules.points[1], float(total) / count,
			100.0 * long5 / count, float(stats["gap"])])
	_check(rallies.size() > 40, "partida anda (pontos saem)")
	_check(float(stats["gap"]) < 8.0, "nunca trava (sempre há toque ou ponto em < 8 s)")
	_check(float(total) / count >= 3.0, "bot devolve bola (média >= 3 toques)")
	_free_main(main)


func _test_scripted_human() -> void:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var stats := {"touches": 0, "perfect": 0, "points": 0, "whiffs": 0}
	game.touch_made.connect(func(p: Player, grade: String, _q: float) -> void:
		if p == human and grade != "SAQUE":
			stats["touches"] += 1
			if grade == "PERFEITO!":
				stats["perfect"] += 1)
	game.whiffed.connect(func(p: Player, _why: String) -> void:
		if p == human:
			stats["whiffs"] += 1)
	game.point_scored.connect(func(_team: int, _why: String) -> void:
		stats["points"] += 1)
	var pressed := false
	var serve_timer := 0.0
	for _i in int(600.0 / DT):
		human.move_input = Vector2.ZERO
		var act := _phase1_act(game, human)
		if act == Game.Act.SERVE:
			serve_timer += DT
			if not pressed and serve_timer > 0.5:
				game.human_press(human)
				pressed = true
			elif pressed and serve_timer > 0.8:
				game.human_release(human)
				pressed = false
				serve_timer = 0.0
		elif act != Game.Act.NONE:
			var at := game.plan.pos
			var to := Vector2(at.x - human.position.x, at.z - human.position.z)
			if to.length() > 0.1:
				human.move_input = to.normalized() * clampf(to.length() / 0.5, 0.0, 1.0)
			var t_ideal := game.plan.t
			if not pressed and game.time >= t_ideal - 0.5:
				game.human_press(human)
				# como uma pessoa: olha onde a mira está e arrasta até o alvo (a mira persiste)
				var want := game.default_aim(human) + Vector3(0.8, 0.0, -0.6)
				var d := (want - game.human_aim) / Tuning.AIM_SENS
				game.human_drag(human, Vector2(d.x, d.z))
				pressed = true
			elif pressed and game.time >= t_ideal - DT * 0.5:
				game.human_release(human)
				pressed = false
		elif pressed:
			game.human_release(human)
			pressed = false
		game.tick(DT)
	var touches := int(stats["touches"])
	print("  toques=%d  perfeitos=%d  erros=%d  pontos=%d  placar=%d x %d" % [
			touches, int(stats["perfect"]), int(stats["whiffs"]), int(stats["points"]),
			game.rules.points[0], game.rules.points[1]])
	_check(touches > 50, "humano consegue tocar na bola")
	_check(int(stats["perfect"]) >= touches * 0.8, "soltar no anel fechado = PERFEITO")
	_check(int(stats["points"]) > 10, "pontos saem com o humano jogando")
	_free_main(main)


func _test_touch_controls() -> void:
	var main := _make_main(false)
	var c: TouchControls = main.get("controls")
	var screen := c.get_viewport_rect().size
	var presses := [0]
	c.action_pressed.connect(func() -> void: presses[0] += 1)
	# polegar esquerdo encosta e arrasta para a direita
	var left := Vector2(screen.x * 0.15, screen.y * 0.75)
	c._input(_touch(0, left, true))
	c._input(_drag(0, left + Vector2(c.JOY_RADIUS, 0.0)))
	var move := c.get_move()
	_check(move.x > 0.9 and absf(move.y) < 0.1, "joystick: toque na esquerda + arrastar move (%s)" % move)
	_check(presses[0] == 0, "joystick: toque na esquerda não aperta o botão de ação")
	# segundo dedo na direita = botão de ação, sem soltar o joystick
	c._input(_touch(1, Vector2(screen.x * 0.85, screen.y * 0.75), true))
	_check(presses[0] == 1, "botão: toque na direita aperta o botão de ação")
	_check(c.get_move().x > 0.9, "multitoque: joystick continua ativo com o botão apertado")
	c._input(_touch(0, left, false))
	_check(c.get_move() == Vector2.ZERO, "joystick: soltar o dedo para o jogador")
	_free_main(main)


func _test_hud_layout() -> void:
	var main := _make_main(false)
	var hud: Hud = main.get("hud")
	var c: TouchControls = main.get("controls")
	var screen := hud.get_viewport().get_visible_rect().size
	var root := hud.get_child(0) as Control
	_check(root.size.is_equal_approx(screen), "HUD ocupa a tela toda (%s)" % root.size)
	_check(c.size.is_equal_approx(screen), "controles de toque ocupam a tela toda (%s)" % c.size)
	var score := hud.get("_score") as Label
	_check(absf(score.get_global_rect().get_center().x - screen.x * 0.5) < 2.0, "placar centralizado")
	var lvl := hud.get("_level_btn") as Button
	var r := lvl.get_global_rect()
	_check(r.position.x >= 0.0 and r.end.x <= screen.x and r.position.x > screen.x * 0.5,
			"botão do nível do bot visível no canto direito (%s)" % r)
	_free_main(main)


func _test_aim() -> void:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	game.tick(DT)
	var view := game.human_aim_view()
	_check(not view.is_empty(), "mira aparece sem segurar o botão")
	var s := Game.side_of_team(human.team)
	var z: float = (view["pos"] as Vector3).z if not view.is_empty() else 0.0
	_check(z * -s >= Tuning.AIM_DEEP - 0.01, "mira começa no fundo da quadra adversária (z=%.1f)" % z)
	# arrasta e solta: a mira fica onde estava, também nas jogadas seguintes
	var act := _phase1_act(game, human)
	game.human_press(human)
	game.human_drag(human, Vector2(-120.0, 60.0))
	var left_at: Vector3 = game.human_aim
	_check(left_at.distance_to(Vector3(0.0, 0.0, -s * Tuning.AIM_DEEP)) > 1.0, "arrastar move a mira")
	game.human_release(human)
	var changed := false
	for _i in int(6.0 / DT):
		game.tick(DT)
		if game.current_act(human) != act:
			changed = true
			break
	_check(changed and game.human_aim.is_equal_approx(left_at), "jogada nova: mira continua onde você deixou")
	game.human_press(human)
	_check(game.human_aim.is_equal_approx(left_at), "apertar o botão não reposiciona a mira")
	game.human_release(human)
	_check(not game.human_aim_view().is_empty(), "mira continua visível depois do toque")
	# a mira não pula quando a jogada muda (ex.: o bot ataca e vira recepção)
	# determinístico: semente fixa e você saca quando é a sua vez (senão o jogo para)
	game.rng.seed = 7
	var before: Vector3 = game.human_aim
	var acts := {}
	for _i in int(60.0 / DT):
		var now_act := game.current_act(human)
		acts[now_act] = true
		if now_act == Game.Act.RECEIVE:
			break
		if now_act == Game.Act.SERVE:
			game.human_press(human)
			game.human_release(human)
		game.tick(DT)
		if not game.human_aim.is_equal_approx(before):
			break
	_check(game.human_aim.is_equal_approx(before) and acts.has(Game.Act.RECEIVE),
			"bot ataca e vira recepção: a mira não se move sozinha (jogadas vistas: %s)" % [acts.keys()])
	_free_main(main)


func _test_aim_assist() -> void:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var foe: Player = main.get("foe")
	var s := Game.side_of_team(human.team)
	game.tick(DT)
	# a mira não sai da quadra, por mais que você arraste
	game.human_press(human)
	game.human_drag(human, Vector2(5000.0, -5000.0))
	var a: Vector3 = game.human_aim
	_check(Game.is_inside(a) and absf(a.x) <= Tuning.COURT_HALF_W - Tuning.AIM_MARGIN + 0.01,
			"mira presa dentro da quadra (%s)" % a)
	# ímã: perto do canto do fundo gruda em FUNDO DIR/ESQ
	game.human_aim = Vector3(2.0 * s, 0.0, -5.2 * s)
	var v := game.human_aim_view()
	_check(str(v["name"]) == "FUNDO DIR", "ímã de ataque: perto do canto gruda em FUNDO DIR (%s)" % v["name"])
	game.human_release(human)
	# recepção gruda no levantador
	var spot := Vector3(Tuning.SETTER_SPOT.x * s, 0.0, Tuning.SETTER_SPOT.y * s)
	game.plan = ContactPlan.new(human.team, 1, Game.Act.RECEIVE, game.time, human.position, human)
	game.state = Game.State.PLAY
	var info := game.snap_aim(human, spot + Vector3(1.0, 0.0, 0.8))
	_check(str(info["name"]) == "LEVANTADOR", "ímã de recepção: gruda no levantador")
	# bot não ganha ímã de ataque/recepção
	_check(game.aim_magnets(foe, Game.Act.ATTACK).is_empty(), "bot sem assistência de mira")
	# toque bom: alvo fora da quadra é trazido para dentro
	var k := Game.keep_inside(Vector3(9.0, 0.0, -12.0))
	_check(Game.is_inside(k), "toque BOM não manda a bola para fora (%s)" % k)
	_free_main(main)


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func _test_contact_plan() -> void:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	# bola subindo e caindo do seu lado, depois de toques do seu time
	game.state = Game.State.PLAY
	game.ball.launch(Vector3(0.0, 2.0, 3.0), Vector3(0.0, 5.0, 0.0))
	game.last_team = human.team
	game.touches = Tuning.MAX_TOUCHES - 1
	game._make_plan()
	_check(game.plan is ContactPlan and game.plan.n == Tuning.MAX_TOUCHES and game.plan.player == human,
			"último toque permitido gera plano para você")
	game.touches = Tuning.MAX_TOUCHES
	game._make_plan()
	_check(game.plan == null, "toque além de MAX_TOUCHES não gera plano (a bola cai)")
	_free_main(main)


func _test_hit_resolver() -> void:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var foe: Player = main.get("foe")
	# [time, ação, bola no contato, mira, q, cap, velocidade de saída gravada da Fase 1 (semente 100 + i)]
	var cases := [
		[0, Game.Act.RECEIVE, Vector3(0.0, 0.9, 4.0), Vector3(0.8, 0, 1.6), 1.0, 1.0, Vector3(0.5925926, 8.425, -1.7777778)],
		[0, Game.Act.RECEIVE, Vector3(1.0, 0.9, 5.0), Vector3(2.0, 0, 3.0), 0.35, 1.0, Vector3(0.74478984, 7.688778, -1.7320404)],
		[0, Game.Act.SET_BALL, Vector3(0.5, 2.25, 1.8), Vector3(0.0, 0, 0.9), 0.7, 1.0, Vector3(-0.60652065, 5.1916666, -0.7462158)],
		[0, Game.Act.SET_BALL, Vector3(0.5, 2.25, 1.8), Vector3(-1.0, 0, -3.0), 0.7, 1.0, Vector3(-1.0793442, 6.8566666, -3.3409824)],
		[0, Game.Act.ATTACK, Vector3(0.0, 3.05, 1.5), Vector3(2.6, 0, -5.8), 1.0, 1.0, Vector3(4.697263, -0.79307765, -13.18847)],
		[0, Game.Act.ATTACK, Vector3(0.0, 3.05, 1.5), Vector3(-2.0, 0, -3.0), 0.35, 1.0, Vector3(-3.6223698, 0.6058035, -6.7545953)],
		[1, Game.Act.ATTACK, Vector3(0.0, 3.05, -1.5), Vector3(1.0, 0, 4.0), 0.7, 0.5, Vector3(1.2948216, -0.42196736, 8.677219)],
		[0, Game.Act.FREEBALL, Vector3(0.0, 2.25, 3.0), Vector3(0.0, 0, -4.0), 0.7, 1.0, Vector3(-0.081518985, 6.8566666, -3.9796379)],
	]
	var worst := 0.0
	for i in cases.size():
		var c: Array = cases[i]
		var p: Player = human if c[0] == 0 else foe
		game.rng.seed = 100 + i
		game.state = Game.State.PLAY
		var from: Vector3 = c[2]
		p.position = Vector3(from.x, 0.0, from.z)
		game.ball.launch(from, Vector3.ZERO)
		game.plan = ContactPlan.new(p.team, 1, c[1], game.time, from, p)
		var shot := game.resolver.resolve(game, p, c[1], c[3], c[4], c[5])
		worst = maxf(worst, shot.vel.distance_to(c[6]))
	_check(worst < 1e-4, "mesma semente = mesma saída da bola que a Fase 1 (diferença %.6f)" % worst)
	_free_main(main)


## Partida nova com você sacando o tipo `kind`. Para o flutuante/viagem, já aperta (lança a bola).
func _serve_setup(kind: int, press: bool) -> Node:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	game.serve_type[human.team] = kind
	game.tick(DT)
	if press:
		game.human_press(human)
	return main


## Solta o botão `err` segundos depois do tempo ideal do plano (relógio ajustado, sem esperar).
func _release_at(game: Game, human: Player, err: float) -> Array:
	var got := [""]
	game.served.connect(func(_p: Player, _k: int, grade: String) -> void: got[0] = grade)
	game.whiffed.connect(func(_p: Player, why: String) -> void: got[0] = "ERRO " + why)
	while game.time < game.plan.t - 0.4:
		game.tick(DT)
	game.time = game.plan.t + err
	game.human_release(human)
	for _i in 30:
		game.tick(DT)
	return got


func _test_serve_types() -> void:
	var main := _serve_setup(ServeType.Kind.UNDER, true)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	_check(game.state == Game.State.SERVE_WAIT, "POR BAIXO: apertar não lança a bola")
	game.human_release(human)
	_check(game.state == Game.State.PLAY and game.last_team == human.team, "POR BAIXO: soltar saca direto")
	_free_main(main)

	main = _serve_setup(ServeType.Kind.FLOAT, true)
	game = main.get("game")
	human = main.get("human")
	var plan: ContactPlan = game.plan
	_check(game.state == Game.State.SERVE_TOSS and plan != null and plan.act == Game.Act.SERVE
			and plan.player == human and plan.t > game.time + 0.3,
			"FLUTUANTE: apertar lança a bola e cria o plano de saque")
	_check(game.action_label(human) == "SACAR", "botão continua SACAR com a bola no ar")
	var got := _release_at(game, human, 0.0)
	_check(got[0] == "PERFEITO!" and game.state == Game.State.PLAY, "soltar no tempo ideal = saque PERFEITO (%s)" % got[0])
	_free_main(main)

	main = _serve_setup(ServeType.Kind.FLOAT, true)
	game = main.get("game")
	var point := [-1, ""]
	game.point_scored.connect(func(team: int, why: String) -> void:
		point[0] = team
		point[1] = why)
	for _i in int(3.0 / DT):
		game.tick(DT)
	_check(point[0] == 1 and point[1] == "Saque perdido", "bola lançada que cai = ponto do adversário (%s)" % point[1])
	_free_main(main)

	var grades := []
	for kind in [ServeType.Kind.FLOAT, ServeType.Kind.JUMP]:
		main = _serve_setup(kind, true)
		grades.append(_release_at(main.get("game"), main.get("human"), -0.12)[0])
		_free_main(main)
	_check(grades == ["BOM", "CEDO"], "soltar 0,12 s antes: BOM no flutuante, CEDO na viagem (%s)" % [grades])

	# nunca trava: cada tipo saca e a bola chega do outro lado
	for kind in ServeType.NAMES.size():
		main = _serve_setup(kind, true)
		game = main.get("game")
		human = main.get("human")
		if ServeType.is_tossed(kind):
			_release_at(game, human, 0.0)
		else:
			game.human_release(human)
		var crossed := false
		for _i in int(3.0 / DT):
			game.tick(DT)
			if game.ball.position.z < 0.0:
				crossed = true
		_check(crossed, "%s perfeito passa a rede" % ServeType.NAMES[kind])
		_free_main(main)

	# seletor no topo: aparece no seu saque, fica na faixa que não aciona o botão de ação
	main = _serve_setup(ServeType.Kind.UNDER, false)
	game = main.get("game")
	human = main.get("human")
	var hud: Hud = main.get("hud")
	main.call("_process", DT)
	var box := hud.get("_serve_box") as HBoxContainer
	var btns: Array[Button] = hud.get("_serve_btns")
	var r := box.get_global_rect()
	var lvl := (hud.get("_level_btn") as Button).get_global_rect()
	_check(box.visible and r.end.y <= TouchControls.TOP_BAR and r.size.x > 300.0 and not r.intersects(lvl),
			"seletor de saque visível no topo, fora da área do botão de ação (%s)" % r)
	btns[ServeType.Kind.FLOAT].pressed.emit()
	_check(game.serve_type[human.team] == ServeType.Kind.FLOAT, "tocar em FLUTUANTE troca o seu tipo de saque")
	game.human_press(human)
	main.call("_process", DT)
	_check(not box.visible and game.state == Game.State.SERVE_TOSS, "apertar lança a bola e esconde o seletor")
	_free_main(main)

	var path := "user://test_serve.cfg"
	var sv := SaveData.new(path)
	sv.serve_type = ServeType.Kind.JUMP
	sv.save_file()
	var back := SaveData.new(path)
	back.load_file()
	var v1 := ConfigFile.new()
	v1.set_value("meta", "version", 1)
	v1.set_value("options", "aim_sens", 1.2)
	v1.save(path)
	var old := SaveData.new(path)
	old.load_file()
	_check(back.serve_type == ServeType.Kind.JUMP and old.serve_type == ServeType.Kind.UNDER
			and MatchConfig.from_save(back, 0).serve_type == ServeType.Kind.JUMP,
			"tipo de saque salvo e recarregado; save versão 1 usa POR BAIXO")
	DirAccess.remove_absolute(path)


func _test_float_physics() -> void:
	# 1) preditor (passo 1/120) = bola real (passo 1/60) com oscilação
	var b := BallSim.new()
	b.pos = Vector3(1.0, 2.45, 7.6)
	b.vel = BallSim.clear_net_velocity(b.pos, Vector3(-1.0, Tuning.BALL_RADIUS, -5.0), 1.3)
	b.set_wobble(0.7, Tuning.FLOAT_FREQ, 0.9)
	var pred := b.predict()
	var real := b.copy()
	var plain := b.copy()
	plain.wobble_amp = 0.0
	var max_dx := 0.0
	while not real.landed:
		real.advance(DT)
		plain.advance(DT)
		max_dx = maxf(max_dx, absf(real.pos.x - plain.pos.x))
	var land: Vector3 = pred["land"]
	_check(land.distance_to(real.pos) < 0.001, "flutuante: preditor = bola real (erro %.5f m)" % land.distance_to(real.pos))
	_check(max_dx > 0.2, "flutuante: a bola oscila de lado no caminho (%.2f m)" % max_dx)

	# 2) a oscilação muda o caminho, não o destino
	var main := _serve_setup(ServeType.Kind.FLOAT, true)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var worst := 0.0
	for i in 12:
		game.rng.seed = 40 + i
		var aim := Vector3(-2.6 + 0.47 * i, 0.0, -5.5 + 0.35 * i)
		var shot := game.resolver.serve(game, human, ServeType.Kind.FLOAT, Vector3(0.6, 2.45, 7.6), aim, 1.0)
		var sim := BallSim.new()
		sim.pos = shot.from
		sim.vel = shot.vel
		sim.g = shot.grav
		sim.set_wobble(shot.wobble_amp, Tuning.FLOAT_FREQ, shot.wobble_phase)
		var p2 := sim.predict()
		var hit: Vector3 = p2["land"]
		worst = maxf(worst, Vector2(hit.x - shot.target.x, hit.z - shot.target.z).length())
	_check(worst < 0.001, "flutuante cai no ponto mirado (pior erro %.5f m)" % worst)

	# 3) leitura atrasada: anel do recebedor na trajetória "sem efeito" até FLOAT_REVEAL
	game.rng.seed = 5
	_release_at(game, human, 0.0)
	var plan: ContactPlan = game.plan
	var ok_plan := plan != null and plan.act == Game.Act.RECEIVE
	var gap := plan.display_pos.distance_to(plan.pos) if ok_plan else 0.0
	_check(ok_plan and gap > 0.05, "flutuante: anel mostrado ≠ contato real antes da revelação (%.2f m)" % gap)
	var before_ok := ok_plan and game.plan_view_pos(plan).is_equal_approx(plan.display_pos)
	while ok_plan and game.time < plan.t - Tuning.FLOAT_REVEAL + Tuning.FLOAT_SLIDE + DT:
		game.tick(DT)
		if game.plan != plan:
			break
	_check(before_ok and game.plan == plan and game.plan_view_pos(plan).is_equal_approx(plan.pos),
			"anel desliza para a posição certa nos últimos %.2f s" % Tuning.FLOAT_REVEAL)
	_free_main(main)

	# 4) antena: o x oscilando é que leva a bola para fora
	for amp: float in [0.0, 0.7]:
		var a := BallSim.new()
		a.pos = Vector3(3.3, 2.6, 4.0)
		a.vel = BallSim.clear_net_velocity(a.pos, Vector3(3.3, Tuning.BALL_RADIUS, -4.0), 1.0)
		var t_net := -a.pos.z / a.vel.z
		a.set_wobble(amp, Tuning.FLOAT_FREQ, PI * 0.5 - Tuning.FLOAT_FREQ * t_net)
		var seen := -1
		while not a.landed and seen < 0:
			for e in a.advance(DT):
				if int(e["type"]) == BallSim.Ev.ANTENNA or int(e["type"]) == BallSim.Ev.CROSS:
					seen = int(e["type"])
		if amp == 0.0:
			_check(seen == BallSim.Ev.CROSS, "sem oscilação a bola passa dentro da antena")
		else:
			_check(seen == BallSim.Ev.ANTENNA, "com oscilação a mesma bola sai pela antena")


## Bola no ponto de ataque do bot (2,5 m da rede), plano ATTACK dele, você em `human_at`.
## Sem cérebro de bot: o teste decide tudo.
func _attack_setup(game: Game, foe: Player, human: Player, human_at: Vector3) -> void:
	game.bots.clear()
	game.state = Game.State.PLAY
	game.rally_over = false
	human.reset_state()
	human.position = human_at
	var at := Vector3(0.0, Tuning.H_ATTACK, -2.5)
	foe.reset_state()
	foe.position = Vector3(at.x, 0.0, at.z)
	game.ball.launch(at, Vector3.ZERO)
	game.last_team = foe.team
	game.touches = 2
	game.plan = ContactPlan.new(foe.team, 3, Game.Act.ATTACK, game.time, at, foe)
	game._update_block_plan()


## Instante (relógio do Game) em que a bola chega ao plano das mãos de quem defende o lado +z.
func _time_at_block_plane(game: Game) -> float:
	var pred := game.ball.sim.predict()
	var pts: PackedVector3Array = pred["points"]
	var times: PackedFloat64Array = pred["times"]
	for i in range(1, pts.size()):
		var z0 := pts[i - 1].z + Tuning.BLOCK_DEPTH
		var z1 := pts[i].z + Tuning.BLOCK_DEPTH
		if z0 < 0.0 and z1 >= 0.0:
			return game.time + lerpf(times[i - 1], times[i], -z0 / (z1 - z0))
	return INF


func _test_block() -> void:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var foe: Player = main.get("foe")
	_attack_setup(game, foe, human, Vector3(0.0, 0.0, 3.0))
	_check(game.current_act(human) == Game.Act.NONE, "longe da rede: sem bloqueio")
	_attack_setup(game, foe, human, Vector3(0.0, 0.0, 0.8))
	_check(game.current_act(human) == Game.Act.BLOCK and game.action_label(human) == "BLOQUEAR",
			"perto da rede com o ataque vindo: o botão vira BLOQUEAR")

	# pula antes do ataque: o preditor já sabe que a cortada para nas mãos
	game.human_press(human)
	game.human_release(human)
	_check(not human.is_grounded() and game.blocks.size() == 1, "soltar BLOQUEAR pula")
	for _i in int(0.25 / DT):
		game.tick(DT)
	game._execute(foe, Vector3(0.0, 0.0, 5.0), 0.0, 1.0)
	_check(bool(game.ball.sim.predict()["blocked"]) and game.plan == null,
			"cortada no bloqueio: o preditor mostra a bola parando nas mãos")
	var hit := [""]
	game.touch_made.connect(func(p: Player, grade: String, _q: float) -> void:
		if p == human:
			hit[0] = grade)
	for _i in int(0.5 / DT):
		game.tick(DT)
	_check(hit[0] != "" and game.last_team == human.team, "a bola bate nas mãos (%s)" % hit[0])

	# graus pelo erro do pico (bloqueio colocado direto, sem esperar o pulo)
	var expect := {0.0: "PERFEITO!", 0.12: "BOM", -0.22: "CEDO"}
	for e: float in expect:
		_attack_setup(game, foe, human, Vector3(0.0, 0.0, 0.6))
		game._execute(foe, Vector3(0.0, 0.0, 5.0), 0.0, 1.0)
		var t_hit := _time_at_block_plane(game)
		var bk := Block.new(human, t_hit + e - Tuning.JUMP_TIME_UP, Tuning.JUMP_HEIGHT)
		game.blocks.append(bk)
		game.ball.sim.blocks.append(bk)
		hit[0] = ""
		var landed_z := 0.0
		for _i in int(0.3 / DT):
			game.tick(DT)
			if hit[0] != "":
				break
		var target := game.ball.sim.copy().predict()["land"] as Vector3
		landed_z = target.z
		var ok: bool = hit[0] == expect[e] and game.last_team == human.team and game.touches == 0
		if e == 0.0:
			ok = ok and landed_z < 0.0
		elif e == 0.12:
			ok = ok and landed_z > 0.0 and game.plan != null and game.plan.player == human \
					and game.plan.act == Game.Act.RECEIVE and game.plan.n == 1
		else:
			ok = ok and absf(target.x) > Tuning.COURT_HALF_W
		_check(ok, "pico %+.2f s: %s, bloqueio não conta toque (%s, cai em %s)" % [e, expect[e], hit[0], target])

	# cortada mirada longe das mãos passa
	_attack_setup(game, foe, human, Vector3(-1.5, 0.0, 0.6))
	var away := Block.new(human, game.time - Tuning.JUMP_TIME_UP + 0.1, Tuning.JUMP_HEIGHT)
	game.blocks.append(away)
	game._execute(foe, Vector3(2.5, 0.0, 5.0), 0.0, 1.0)
	_check(not bool(game.ball.sim.predict()["blocked"]), "cortada na diagonal, longe das mãos, passa")
	_free_main(main)


## Joga pontos seguidos de um time.
func _points(r: MatchRules, team: int, n: int) -> Dictionary:
	var last := {}
	for _i in n:
		last = r.add_point(team)
	return last


func _test_match_rules() -> void:
	var r := MatchRules.new(15, 2, 2)
	_points(r, 1, 13)
	var res := _points(r, 0, 15)
	_check(bool(res["set_over"]) and r.sets[0] == 1 and r.history[0] == Vector2i(15, 13), "15–13 fecha o set")
	r = MatchRules.new(15, 2, 2)
	_points(r, 0, 14)
	_points(r, 1, 13)
	_check(r.is_set_point(0) and not r.is_set_point(1), "14–13: set point de quem está na frente")
	_check(not r.is_match_point(0), "set point no 1º set não é match point")
	_points(r, 1, 1)
	_check(not r.is_set_point(0) and not r.is_set_point(1), "14–14: ninguém tem set point")
	res = _points(r, 0, 1)
	_check(not bool(res["set_over"]), "15–14 não fecha o set")
	res = _points(r, 0, 1)
	_check(bool(res["set_over"]) and r.history[0] == Vector2i(16, 14), "16–14 fecha o set")
	_check(not r.is_set_point(0) and not r.is_match_point(0), "entre um set e outro não há selo de set/match point")
	r.start_next_set()
	_check(r.points == [0, 0] and r.set_index == 1, "set seguinte começa zerado")
	_points(r, 0, 14)
	_check(r.is_match_point(0), "1 set a 0 e 14–0: match point")
	_points(r, 1, 16)
	_check(r.sets == [1, 1] and r.winner == -1, "1–1 vai para o 3º set")
	r.start_next_set()
	res = _points(r, 1, 15)
	_check(bool(res["match_over"]) and r.winner == 1, "2 sets fecham a partida")
	res = r.add_point(0)
	_check(not bool(res["set_over"]) and r.points[0] == 0, "depois do fim, ponto não conta")
	_check([r.first_server(0), r.first_server(1), r.first_server(2)] == [0, 1, 0],
			"1º saque alterna por set: você, adversário, você")
	var endless := MatchRules.new(0)
	res = _points(endless, 0, 100)
	_check(not bool(res["set_over"]) and not endless.is_set_point(0) and endless.points[0] == 100,
			"modo infinito nunca fecha set")


func _test_match_flow() -> void:
	var main := _make_main(true)
	var game: Game = main.get("game")
	game.set_bot_level(1)
	game.rules = MatchRules.new()
	game.reset_match()
	var seen := {"sets": 0, "matches": 0, "touch_after": 0, "server_ok": true, "check_server": false}
	game.set_over.connect(func(_t: int, _i: int, _f: Vector2i) -> void:
		seen["sets"] += 1
		seen["check_server"] = true)
	game.match_over.connect(func(_t: int) -> void: seen["matches"] += 1)
	var t0 := game.time
	while game.state != Game.State.MATCH_OVER and game.time - t0 < 3600.0:
		game.tick(DT)
		# 1º saque de cada set novo: alterna
		if seen["check_server"] and game.state == Game.State.SERVE_WAIT:
			seen["check_server"] = false
			if game.server_team != game.rules.first_server(game.rules.set_index):
				seen["server_ok"] = false
	var minutes := (game.time - t0) / 60.0
	print("  sets=%s  placares=%s  duração=%.1f min" % [game.rules.sets, game.rules.history, minutes])
	_check(game.state == Game.State.MATCH_OVER and int(seen["matches"]) == 1, "partida bot x bot termina")
	_check(int(seen["sets"]) == game.rules.history.size() and int(seen["sets"]) >= 2, "um set_over por set (%d)" % seen["sets"])
	_check(bool(seen["server_ok"]), "1º saque de cada set segue a alternância")
	game.touch_made.connect(func(_p: Player, _g: String, _q: float) -> void: seen["touch_after"] += 1)
	for _i in int(10.0 / DT):
		game.tick(DT)
	_check(int(seen["touch_after"]) == 0 and game.state == Game.State.MATCH_OVER,
			"depois do fim ninguém saca nem toca")
	_free_main(main)


func _test_stats() -> void:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var foe: Player = main.get("foe")
	var st: MatchStats = main.get("stats")
	game.touch_made.emit(human, "SAQUE", 0.85)
	game.touch_made.emit(foe, "PERFEITO!", 1.0)
	game.touch_made.emit(human, "PERFEITO!", 1.0)
	game.touch_made.emit(human, "BOM", 0.7)
	game.touch_made.emit(human, "TARDE", 0.35)
	game.whiffed.emit(human, "CEDO")
	game.whiffed.emit(human, "LONGE")
	game.whiffed.emit(foe, "SEM BOLA")
	game.rally_touches = 6
	game.point_scored.emit(1, "Bola no chão")
	game.point_scored.emit(0, "Fora")
	game.point_scored.emit(0, "Fora")
	_check(st.touches == [3, 1], "saque não conta como toque (%s)" % [st.touches])
	_check(st.perfect == [1, 1] and st.good == [1, 0], "perfeitos e bons por time")
	_check(st.timing_errors == [2, 0] and st.far == [1, 0], "erros de tempo e LONGE contados")
	_check(st.points(0) == 2 and int(st.points_by_reason[0]["Fora"]) == 2 and st.points(1) == 1,
			"pontos por motivo")
	_check(st.best_rally == 6 and is_equal_approx(st.perfect_rate(0), 1.0 / 3.0), "maior rally e % de perfeitos")
	st.reset()
	_check(st.touches == [0, 0] and st.points(0) == 0, "Reiniciar zera as estatísticas")
	_free_main(main)


func _test_save() -> void:
	var path := "user://test_save.cfg"
	DirAccess.remove_absolute(path)
	var s := SaveData.new(path)
	s.load_file()
	_check(s.unlocked_level == 0 and not s.tutorial_done and s.aim_sens == 1.0 and s.vibration,
			"sem arquivo: valores padrão")
	s.unlocked_level = 1
	s.tutorial_done = true
	s.best_rally = 12
	s.wins = [3, 1, 0]
	s.losses = [0, 2, 0]
	s.aim_sens = 1.4
	s.left_handed = true
	s.vibration = false
	_check(s.save_file() == OK and not FileAccess.file_exists(path + ".tmp"), "grava sem deixar arquivo temporário")
	var r := SaveData.new(path)
	r.load_file()
	_check(r.unlocked_level == 1 and r.tutorial_done and r.best_rally == 12 and r.wins == [3, 1, 0]
			and r.losses == [0, 2, 0] and is_equal_approx(r.aim_sens, 1.4) and r.left_handed and not r.vibration,
			"ida e volta de todos os campos")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("isto não é um ConfigFile [[[")
	f.close()
	r = SaveData.new(path)
	r.load_file()
	_check(r.unlocked_level == 0 and r.wins == [0, 0, 0], "arquivo ilegível: valores padrão")
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_level", 9)
	cfg.set_value("options", "aim_sens", 50.0)
	cfg.set_value("records", "wins", ["x", -4])
	cfg.save(path)
	r.load_file()
	_check(r.unlocked_level == 2 and r.aim_sens == SaveData.AIM_SENS_MAX and r.wins == [0, 0, 0],
			"valores fora do limite são cortados")
	var st := MatchStats.new()
	st.best_rally = 9
	var fresh := SaveData.new(path)
	var win := MatchResult.new(0, 0, [Vector2i(15, 3), Vector2i(15, 4)], st)
	fresh.record_result(win)
	_check(fresh.unlocked_level == 1 and win.unlocked == 1 and fresh.wins[0] == 1 and fresh.best_rally == 9,
			"vencer o Fácil libera o Médio")
	var again := MatchResult.new(0, 0, [], st)
	fresh.record_result(again)
	_check(fresh.unlocked_level == 1 and again.unlocked == -1, "vencer de novo não libera nada novo")
	var loss := MatchResult.new(1, 1, [], st)
	fresh.record_result(loss)
	_check(fresh.losses[1] == 1 and fresh.unlocked_level == 1, "derrota conta e não libera")
	fresh.unlocked_level = 2
	var top := MatchResult.new(0, 2, [], st)
	fresh.record_result(top)
	_check(fresh.unlocked_level == 2 and top.unlocked == -1, "vencer o Difícil mantém o nível 2")
	DirAccess.remove_absolute(path)


func _test_pause() -> void:
	var main := _make_main(false)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var pm: PauseMenu = main.get("pause_menu")
	var hits := [0]
	game.touch_made.connect(func(_p: Player, _g: String, _q: float) -> void: hits[0] += 1)
	game.whiffed.connect(func(_p: Player, _w: String) -> void: hits[0] += 1)
	game.human_press(human)
	main.call("pause_game")
	_check(paused and not main.can_process() and pm.can_process() and pm.visible,
			"pausa congela a partida e o menu continua ativo")
	main.call("resume_game")
	game.human_release(human)
	_check(not paused and not pm.visible and hits[0] == 0, "soltar o dedo depois da pausa não dispara toque")
	_free_main(main)


func _test_left_handed() -> void:
	var main := _make_main(false)
	var c: TouchControls = main.get("controls")
	c.left_handed = true
	var screen := c.get_viewport_rect().size
	var presses := [0]
	c.action_pressed.connect(func() -> void: presses[0] += 1)
	var right := Vector2(screen.x * 0.85, screen.y * 0.75)
	c._input(_touch(0, right, true))
	c._input(_drag(0, right + Vector2(c.JOY_RADIUS, 0.0)))
	_check(c.get_move().x > 0.9 and presses[0] == 0, "canhoto: toque na direita é o joystick")
	c._input(_touch(1, Vector2(screen.x * 0.15, screen.y * 0.75), true))
	_check(presses[0] == 1, "canhoto: toque na esquerda é o botão de ação")
	_free_main(main)


## Humano roteirizado: anda até o anel e solta no tempo ideal. Só saca quando `serve` for true,
## mirando em `serve_at`. Devolve o novo estado de "apertado".
func _script_human(game: Game, human: Player, pressed: bool, serve: bool, serve_at: Vector3) -> bool:
	human.move_input = Vector2.ZERO
	var act := _phase1_act(game, human)
	if act == Game.Act.SERVE:
		if not serve:
			return pressed
		if not pressed:
			game.human_press(human)
			var d := (serve_at - game.human_aim) / (Tuning.AIM_SENS * game.aim_sens)
			game.human_drag(human, Vector2(d.x, d.z))
			return true
		game.human_release(human)
		return false
	if act != Game.Act.NONE:
		var at := game.plan.pos
		var to := Vector2(at.x - human.position.x, at.z - human.position.z)
		if to.length() > 0.1:
			human.move_input = to.normalized() * clampf(to.length() / 0.5, 0.0, 1.0)
		if not pressed and game.time >= game.plan.t - 0.5:
			game.human_press(human)
			return true
		if pressed and game.time >= game.plan.t - DT * 0.5:
			game.human_release(human)
			return false
		return pressed
	if pressed:
		game.human_release(human)
	return false


## Os roteiros de humano da Fase 1 não bloqueiam: os números das simulações continuam comparáveis.
func _phase1_act(game: Game, human: Player) -> int:
	var act := game.current_act(human)
	return Game.Act.NONE if act == Game.Act.BLOCK else act


func _zone_pos(game: Game, human: Player, zone: String) -> Vector3:
	for m in game.aim_magnets(human, Game.Act.SERVE):
		if str(m["name"]) == zone:
			return m["pos"]
	return Vector3.ZERO


func _test_tutorial() -> void:
	var cfg := MatchConfig.new()
	cfg.tutorial = true
	var main := _make_main_cfg(cfg)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var tut: TutorialDirector = main.get("tutorial")
	var done := [-1]
	tut.finished.connect(func(skipped: bool) -> void: done[0] = 1 if skipped else 0)
	var target := _zone_pos(game, human, TutorialDirector.TARGET_ZONE)
	var pressed := false
	var steps_seen := {}
	for _i in int(180.0 / DT):
		pressed = _script_human(game, human, pressed, tut.step == TutorialDirector.Step.AIM, target)
		game.tick(DT)
		tut.tick(DT)
		steps_seen[tut.step] = true
		if done[0] >= 0:
			break
	_check(steps_seen.size() == 4 and done[0] == 0, "humano roteirizado completa os 3 passos (%s)" % [steps_seen.keys()])
	_check(game.bots.is_empty(), "tutorial sem bot")
	_free_main(main)
	main = _make_main_cfg(cfg)
	tut = main.get("tutorial")
	done[0] = -1
	tut.finished.connect(func(skipped: bool) -> void: done[0] = 1 if skipped else 0)
	tut.skip()
	_check(done[0] == 1, "PULAR encerra o tutorial")
	_free_main(main)


func _buttons(scr: Screen) -> Array[Button]:
	var out: Array[Button] = []
	for c in scr.column.get_children():
		if c is Button:
			out.append(c)
	return out


func _test_app_flow() -> void:
	var path := "user://test_app.cfg"
	DirAccess.remove_absolute(path)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	var save := SaveData.new(path)
	app.set("save", save)
	root.add_child(app)
	_check(app.get("screen") is TitleScreen, "app abre no título")
	app.call("show_level_select")
	var btns := _buttons(app.get("screen"))
	_check(btns.size() == 4 and not btns[0].disabled and btns[1].disabled and btns[2].disabled,
			"save novo: só o Fácil liberado")
	btns[0].pressed.emit()
	var m: MatchScene = app.get("match_node")
	_check(m != null and m.tutorial != null, "primeira partida passa pelo tutorial")
	m.tutorial.skip()
	m = app.get("match_node")
	_check(save.tutorial_done and m != null and m.tutorial == null, "pular o tutorial abre a partida")
	var game := m.game
	_check(not game.rules.is_endless() and game.bot_level == 0 and game.bots.size() == 1,
			"partida de verdade (sets) contra o Fácil")
	# fim forçado: 1 set a 0 e match point
	game.rules.sets = [1, 0]
	game.rules.history = [Vector2i(15, 9)]
	game.rules.points = [14, 3]
	game.state = Game.State.PLAY
	game.rally_over = false
	game._award(0, "Teste")
	_check(game.state == Game.State.MATCH_OVER, "match point convertido encerra a partida")
	m.finish_match()
	var res = app.get("screen")
	_check(res is ResultScreen and (res as ResultScreen).result.unlocked == 1, "resultado aparece e avisa o Médio liberado")
	var r := SaveData.new(path)
	r.load_file()
	_check(r.wins[0] == 1 and r.unlocked_level == 1 and r.tutorial_done, "vitória gravada no arquivo")
	app.call("start_match", 1)
	m = app.get("match_node")
	m.pause_game()
	_check(paused and m.pause_menu.visible, "partida do App pausa")
	m.pause_menu.quit_pressed.emit()
	_check(app.get("screen") is TitleScreen and not paused, "Sair para o menu volta ao título e despausa")
	root.remove_child(app)
	app.free()
	DirAccess.remove_absolute(path)


## Partida inteira com um humano "casual" (reação 0,4 s, erro de timing ~90 ms) contra o Fácil.
func _test_match_duration() -> void:
	var minutes: Array[float] = []
	var won := 0
	for seed in [3, 5, 7, 9, 11, 13, 17, 19]:
		var cfg := MatchConfig.new()
		cfg.endless = false
		var main := _make_main_cfg(cfg)
		var game: Game = main.get("game")
		var human: Player = main.get("human")
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		game.rng.seed = seed
		for b in game.bots:
			b.rng.seed = seed
		var zones := game.aim_magnets(human, Game.Act.SERVE)
		var st := {"seen": -1, "react": 0.0, "release": 0.0, "pressed": false, "serve_t": 0.0}
		var t0 := game.time
		while game.state != Game.State.MATCH_OVER and game.time - t0 < 3600.0:
			human.move_input = Vector2.ZERO
			var act := _phase1_act(game, human)
			if act == Game.Act.SERVE:
				st["serve_t"] = float(st["serve_t"]) + DT
				if not st["pressed"] and float(st["serve_t"]) > 0.8:
					game.human_press(human)
					_drag_to(game, human, zones[rng.randi() % zones.size()]["pos"])
					st["pressed"] = true
				elif st["pressed"] and float(st["serve_t"]) > 1.1:
					game.human_release(human)
					st["pressed"] = false
					st["serve_t"] = 0.0
			elif act != Game.Act.NONE:
				var plan := game.plan
				if game.plan_id != int(st["seen"]):
					st["seen"] = game.plan_id
					st["react"] = game.time + (0.4 if plan.n == 1 else 0.05)
					st["release"] = plan.t + rng.randfn(0.0, 0.09)
				if game.time >= float(st["react"]):
					var to := Vector2(plan.pos.x - human.position.x, plan.pos.z - human.position.z)
					if to.length() > 0.1:
						human.move_input = to.normalized() * clampf(to.length() / 0.5, 0.0, 1.0)
					if not st["pressed"] and game.time >= float(st["release"]) - 0.5:
						game.human_press(human)
						var aim := game.default_aim(human)
						if act == Game.Act.ATTACK or act == Game.Act.FREEBALL:
							aim = zones[rng.randi() % zones.size()]["pos"]
						_drag_to(game, human, aim)
						st["pressed"] = true
					elif st["pressed"] and game.time >= float(st["release"]):
						game.human_release(human)
						st["pressed"] = false
			elif st["pressed"]:
				game.human_release(human)
				st["pressed"] = false
			game.tick(DT)
		var mins := (game.time - t0) / 60.0
		minutes.append(mins)
		if game.rules.winner == 0:
			won += 1
		print("  semente %d: %s  %s  %.1f min" % [seed, "venceu" if game.rules.winner == 0 else "perdeu",
				game.rules.history, mins])
		_free_main(main)
	var avg := 0.0
	for mm in minutes:
		avg += mm / minutes.size()
	# RNF-1.01 (DP-05): melhor de 3 sets de 15 dá ~6–7 min em 2 sets e ~9–11 min em 3 sets
	_check(avg >= 6.0 and avg <= 9.0, "partida casual x Fácil dura 6–9 min em média (%.1f min)" % avg)


func _drag_to(game: Game, human: Player, target: Vector3) -> void:
	var d := (target - game.human_aim) / (Tuning.AIM_SENS * game.aim_sens)
	game.human_drag(human, Vector2(d.x, d.z))


func _make_main_cfg(cfg: MatchConfig) -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("config", cfg)
	root.add_child(main)
	return main


func _make_main(autoplay: bool) -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("autoplay", autoplay)
	root.add_child(main)
	return main


func _free_main(main: Node) -> void:
	root.remove_child(main)
	main.free()
