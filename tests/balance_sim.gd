extends SceneTree
## Simulação de equilíbrio (tabela do README). Não roda no CI: é para comparar antes/depois
## de mexer em Tuning, bot ou assistência.
##   godot --headless --script res://tests/balance_sim.gd [-- --matches=48]
## Humano roteirizado igual ao de _test_match_duration (reação, erro de timing, mira em zona
## sorteada no saque e no ataque; não bloqueia), em dois perfis. O "bom" também lê a sombra do
## bloqueio: com o bot na rede, ataca no fundo, na zona mais longe das mãos dele.

const DT := 1.0 / 60.0
const PROFILES := [["bom", 0.25, 0.05, true], ["casual", 0.4, 0.09, false]]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== pontos em 4 × 20 min de rally infinito (% do humano) ==")
	for prof in PROFILES:
		var line := "  %-7s" % prof[0]
		for lvl in 3:
			var won := 0
			var lost := 0
			for k in 4:
				var r := _play(lvl, float(prof[1]), float(prof[2]), 11 + lvl + 7 * k, false, bool(prof[3]))
				won += int(r["won"])
				lost += int(r["lost"])
			line += "  %s %3.0f%%" % [Tuning.BOT_NAMES[lvl], 100.0 * won / maxf(won + lost, 1.0)]
		print(line)
	var n := 24
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			n = int(arg.trim_prefix("--matches="))
	print("== partidas inteiras: casual x Fácil (%d sementes) ==" % n)
	var wins := 0
	var total := 0.0
	var points := 0
	for i in n:
		var r := _play(0, 0.4, 0.09, 101 + i, true, false)
		wins += int(r["match_won"])
		total += float(r["minutes"])
		points += int(r["won"]) + int(r["lost"])
		if OS.get_cmdline_user_args().has("--verbose"):
			print("    semente %d: %d x %d  %.1f min" % [101 + i, r["won"], r["lost"], r["minutes"]])
	print("  vence %d de %d (%.0f%%)  duração média %.1f min  %.1f pontos/partida  %.1f s/ponto" % [
			wins, n, 100.0 * wins / n, total / n, float(points) / n, total * 60.0 / maxf(points, 1.0)])
	quit()


## Uma sessão: 20 min de rally infinito ou uma partida inteira (full).
func _play(level: int, reaction: float, sigma: float, seed: int, full: bool, reads_block: bool) -> Dictionary:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var cfg := MatchConfig.new()
	cfg.bot_level = level
	cfg.endless = not full
	main.set("config", cfg)
	root.add_child(main)
	var game: Game = main.get("game")
	var human: Player = main.get("human")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	game.rng.seed = seed
	for b in game.bots:
		b.rng.seed = seed
	var zones := game.aim_magnets(human, Game.Act.SERVE)
	var pts := [0, 0]
	game.point_scored.connect(func(team: int, _why: String) -> void: pts[team] += 1)
	var st := {"seen": -1, "react": 0.0, "release": 0.0, "pressed": false, "serve_t": 0.0}
	var t0 := game.time
	var limit := 3600.0 if full else 1200.0
	while game.time - t0 < limit and game.state != Game.State.MATCH_OVER:
		human.move_input = Vector2.ZERO
		var act := game.current_act(human)
		if str(Game.ACT_LABELS[act]) == "BLOQUEAR":
			act = Game.Act.NONE
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
				st["react"] = game.time + (reaction if plan.n == 1 else 0.05)
				st["release"] = plan.t + rng.randfn(0.0, sigma)
			if game.time >= float(st["react"]):
				# leitura do flutuante: o anel mostrado (o script também roda na Fase 1, sem ele)
				var at: Vector3 = game.call("plan_view_pos", plan) if game.has_method("plan_view_pos") else plan.pos
				var to := Vector2(at.x - human.position.x, at.z - human.position.z)
				if to.length() > 0.1:
					human.move_input = to.normalized() * clampf(to.length() / 0.5, 0.0, 1.0)
				if not st["pressed"] and game.time >= float(st["release"]) - 0.5:
					game.human_press(human)
					var aim := game.default_aim(human)
					if plan.act == Game.Act.ATTACK or plan.act == Game.Act.FREEBALL:
						aim = zones[rng.randi() % zones.size()]["pos"]
						var foe := game.opponent_of(human.team)
						if reads_block and plan.act == Game.Act.ATTACK and absf(foe.position.z) <= 1.2:
							aim = _away_from(zones, foe)
					_drag_to(game, human, aim)
					st["pressed"] = true
				elif st["pressed"] and game.time >= float(st["release"]):
					game.human_release(human)
					st["pressed"] = false
		elif st["pressed"]:
			game.human_release(human)
			st["pressed"] = false
		game.tick(DT)
	var out := {"won": pts[0], "lost": pts[1], "match_won": game.rules.winner == 0,
			"minutes": (game.time - t0) / 60.0}
	root.remove_child(main)
	main.free()
	return out


## Zona do fundo mais longe (em x) do bloqueador.
func _away_from(zones: Array, foe: Player) -> Vector3:
	var best: Vector3 = zones[0]["pos"]
	for z in zones:
		var zp: Vector3 = z["pos"]
		if absf(zp.z) > 5.0 and absf(zp.x - foe.position.x) > absf(best.x - foe.position.x):
			best = zp
	return best


func _drag_to(game: Game, human: Player, target: Vector3) -> void:
	var d := (target - game.human_aim) / (Tuning.AIM_SENS * game.aim_sens)
	game.human_drag(human, Vector2(d.x, d.z))
