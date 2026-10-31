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
			rallies.size(), game.score[0], game.score[1], float(total) / count,
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
		var act := game.current_act(human)
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
			var at: Vector3 = game.plan["pos"]
			var to := Vector2(at.x - human.position.x, at.z - human.position.z)
			if to.length() > 0.1:
				human.move_input = to.normalized() * clampf(to.length() / 0.5, 0.0, 1.0)
			var t_ideal: float = game.plan["t"]
			if not pressed and game.time >= t_ideal - 0.5:
				game.human_press(human)
				game.human_drag(human, Vector2(30.0, -20.0))
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
			game.score[0], game.score[1]])
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


func _make_main(autoplay: bool) -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("autoplay", autoplay)
	root.add_child(main)
	return main


func _free_main(main: Node) -> void:
	root.remove_child(main)
	main.free()
