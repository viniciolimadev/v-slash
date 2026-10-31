class_name Game
extends Node
## Regras e fluxo do rally + o "plano de contato": quem joga a próxima bola,
## com qual ação (receber / levantar / atacar), ONDE (o anel) e QUANDO (tempo ideal).

signal point_scored(team: int, reason: String)
signal touch_made(player: Player, grade: String, quality: float)
signal whiffed(player: Player, why: String)
signal set_over(team: int, set_index: int, final: Vector2i)
signal match_over(team: int)
signal served(player: Player, serve_kind: int, grade: String)
## Mecânica da Fase 2 usada (pulo de bloqueio, largada, peixinho): estatística e testes.
## DINK não é planejado por _make_plan: é a variação do ATTACK decidida pela mira na hora.
signal action_used(player: Player, act: int)

## SERVE_TOSS: bola lançada no saque flutuante/viagem, esperando o toque (Fase 2).
enum State { SERVE_WAIT, PLAY, POINT_PAUSE, MATCH_OVER, SERVE_TOSS }
enum Act { NONE, SERVE, RECEIVE, SET_BALL, ATTACK, FREEBALL, BLOCK, DINK }

const ACT_LABELS := ["", "SACAR", "RECEBER", "LEVANTAR", "ATACAR", "PASSAR", "BLOQUEAR", "LARGAR"]

var state: int = State.SERVE_WAIT
var time := 0.0
var ball: Ball
var players: Array[Player] = []
var bots: Array[BotBrain] = []
var human: Player = null
var rules := MatchRules.new(0)      # infinito por padrão; a partida de verdade troca por regras com sets
var server_team := 0
var server: Player = null
var last_team := -1                 # time que tocou por último
var touches := 0                    # toques seguidos do last_team
var rally_touches := 0
var best_rally := 0
var rally_over := false
var plan: ContactPlan = null        # ver _make_plan()
var plan_id := 0
## Bloqueio possível para o time que defende um ataque (ver _update_block_plan()).
## t = quando a bola cruza a rede; pos = ponto na rede do seu lado.
var block_plan: ContactPlan = null
var blocks: Array[Block] = []       # mãos no ar agora
var last_kind: int = Act.NONE       # tipo do último toque (o ataque abre o bloqueio)
var land_point := Vector3.ZERO      # onde a bola cai se ninguém tocar
var land_in := true
var land_display := Vector3.ZERO    # ponto de queda "sem efeito" (flutuante); ver land_view()
var land_t := 0.0                   # relógio do pouso previsto
var bot_level := 0                  # começa no Fácil: a meta da Fase 0 é sentir o gesto
var rng := RandomNumberGenerator.new()
var resolver := HitResolver.new(rng)

var human_aiming := false
## Mira do humano: um ponto só, que se move apenas quando você arrasta.
## A bola vai para onde ela está (os ímãs ajudam quando ela está perto de um alvo).
var human_aim := Vector3.ZERO
var aim_sens := 1.0                 # opção do jogador: multiplica Tuning.AIM_SENS
var serve_type: Array[int] = [ServeType.Kind.UNDER, ServeType.Kind.UNDER]   # por time
var _pause_t := 0.0
var _next_server := 0
var _set_break := false             # a pausa atual é de fim de set
var _pending: Array[Dictionary] = []


func setup(p_ball: Ball, p_players: Array[Player], p_bots: Array[BotBrain]) -> void:
	ball = p_ball
	players = p_players
	bots = p_bots
	for p in players:
		if p.is_human:
			human = p
			# começa no fundo da quadra adversária
			human_aim = Vector3(0.0, 0.0, -side_of_team(p.team) * Tuning.AIM_DEEP)
	rng.randomize()
	_reset_for_serve(0)


func reset_match() -> void:
	rules = rules.fresh()
	best_rally = 0
	_set_break = false
	_reset_for_serve(rules.first_server(0))


func set_bot_level(lvl: int) -> void:
	bot_level = clampi(lvl, 0, 2)
	for b in bots:
		if b.p.team == 1:
			b.set_level(bot_level)


func level_name() -> String:
	return str(Tuning.BOT_NAMES[bot_level])


# ---------------------------------------------------------------- loop

func tick(dt: float) -> void:
	time += dt
	for b in bots:
		b.tick(dt)
	for p in players:
		p.look_target = ball.position
		p.step(dt)
	_auto_jumps()
	_update_block_plan()
	for e in ball.step(dt):
		_on_ball_event(e)
	_run_pending()
	if state == State.POINT_PAUSE:
		_pause_t -= dt
		if _pause_t <= 0.0:
			if _set_break:
				_set_break = false
				rules.start_next_set()
			_reset_for_serve(_next_server)
	_update_assists()


# ---------------------------------------------------------------- consultas

static func side_of_team(team: int) -> float:
	return 1.0 if team == 0 else -1.0


static func side_of_point(v: Vector3) -> float:
	return 1.0 if v.z > 0.0 else -1.0


static func is_inside(v: Vector3) -> bool:
	var tol := Tuning.LINE_TOLERANCE
	return absf(v.x) <= Tuning.COURT_HALF_W + tol and absf(v.z) <= Tuning.COURT_DEPTH + tol


## Ação que o botão faria agora para este jogador.
func current_act(p: Player) -> int:
	if state == State.SERVE_WAIT:
		if p == server and ball.mode == Ball.Mode.HELD:
			return Act.SERVE
		return Act.NONE
	if not _in_rally():
		return Act.NONE
	if plan != null and plan.player == p:
		# o botão avisa a largada antes de soltar: a mira está numa zona curta
		if plan.act == Act.ATTACK and p == human and is_dink(p, clamp_aim(p, human_aim, Act.ATTACK)):
			return Act.DINK
		return plan.act
	if block_plan != null and block_plan.player == p:
		return Act.BLOCK
	return Act.NONE


func action_label(p: Player) -> String:
	return str(ACT_LABELS[current_act(p)])


## Está na hora de soltar? (o botão acende)
func is_hot(p: Player) -> bool:
	var act := current_act(p)
	if act == Act.BLOCK:
		return absf(time - block_release_t()) <= Tuning.GOOD
	if act == Act.NONE or plan == null:
		return false
	return absf(time - plan.t) <= Tuning.GOOD * window_scale()


## Hora ideal de soltar o BLOQUEAR: o pico do pulo cai quando a bola cruza a rede.
func block_release_t() -> float:
	return block_plan.t - Tuning.JUMP_TIME_UP if block_plan != null else INF


## Multiplicador da janela de timing do plano atual (a viagem tem janela menor).
func window_scale() -> float:
	if plan != null and plan.act == Act.SERVE:
		return float(Tuning.SERVE_WINDOW[serve_type[plan.team]])
	return 1.0


## Onde a tela e o bot enxergam o contato do plano: no flutuante, a trajetória sem oscilação
## até FLOAT_REVEAL s antes do toque; depois o anel desliza para o lugar certo.
func plan_view_pos(pl: ContactPlan) -> Vector3:
	return _reveal(pl.display_pos, pl.pos, pl.t)


## Ponto de queda que a tela mostra (mesma leitura atrasada do anel).
func land_view() -> Vector3:
	return _reveal(land_display, land_point, land_t)


func _reveal(fake: Vector3, real: Vector3, t_event: float) -> Vector3:
	var k := clampf((time - (t_event - Tuning.FLOAT_REVEAL)) / Tuning.FLOAT_SLIDE, 0.0, 1.0)
	return fake.lerp(real, k)


func opponent_of(team: int) -> Player:
	for p in players:
		if p.team != team:
			return p
	return null


## Alvos do levantamento com ímã. ALTA = bola alta na sua frente (padrão).
func set_magnets(team: int) -> Array:
	var s := side_of_team(team)
	return [
		{"name": "ALTA", "pos": _high_set_point(team), "quick": false},
		{"name": "PONTA", "pos": Vector3(-2.6 * s, 0.0, 1.0 * s), "quick": false},
		{"name": "RÁPIDA", "pos": Vector3(0.0, 0.0, 0.9 * s), "quick": true},
		{"name": "PIPE", "pos": Vector3(0.0, 0.0, 3.4 * s), "quick": false},
	]


## Alvos que "puxam" a mira em cada jogada. Levantamento vale para todos;
## saque/ataque e recepção são assistência só do humano.
func aim_magnets(p: Player, act: int) -> Array:
	var s := side_of_team(p.team)
	if act == Act.SET_BALL:
		return set_magnets(p.team)
	if not p.is_human:
		return []
	if act == Act.RECEIVE:
		return [{"name": "LEVANTADOR", "quick": false,
				"pos": Vector3(Tuning.SETTER_SPOT.x * s, 0.0, Tuning.SETTER_SPOT.y * s)}]
	var out := []
	for z in Tuning.ATTACK_ZONES:
		var v: Vector2 = z[1]
		# câmera atrás do time 0: direita da tela = +x; o time 1 vê espelhado
		out.append({"name": z[0], "quick": false, "pos": Vector3(v.x * s, 0.0, -v.y * s)})
	return out


func _magnet_radius(act: int) -> float:
	if act == Act.SET_BALL:
		return Tuning.SET_MAGNET_RADIUS
	if act == Act.RECEIVE:
		return Tuning.RECEIVE_MAGNET_RADIUS
	return Tuning.AIM_MAGNET_RADIUS


## Mira final: gruda no alvo mais próximo da jogada (se estiver perto).
## act < 0 = a ação atual do jogador.
func snap_aim(p: Player, raw: Vector3, act: int = -1) -> Dictionary:
	var out := {"pos": raw, "name": "", "quick": false}
	if act < 0:
		act = current_act(p)
	var mags := aim_magnets(p, act)
	if mags.is_empty():
		return out
	# só gruda se a mira estiver do mesmo lado dos alvos (mirar do outro lado = sua escolha)
	var mag_side := side_of_point(mags[0]["pos"])
	if side_of_point(raw) != mag_side:
		return out
	var best_d := _magnet_radius(act)
	for m in mags:
		var mp: Vector3 = m["pos"]
		var d := Vector2(mp.x - raw.x, mp.z - raw.z).length()
		if d < best_d:
			best_d = d
			out = {"pos": mp, "name": m["name"], "quick": m["quick"]}
	return out


## Ataque mirado curto vira largada: zona curta (CURTA ESQ/DIR) ou a menos de DINK_DIST da rede.
func is_dink(p: Player, aim: Vector3) -> bool:
	var info := snap_aim(p, aim, Act.ATTACK)
	var target: Vector3 = info["pos"]
	for z in Tuning.ATTACK_ZONES:
		if str(z[0]) == str(info["name"]) and bool(z[2]):
			return true
	return absf(target.z) < Tuning.DINK_DIST


func default_aim(p: Player) -> Vector3:
	var s := side_of_team(p.team)
	var act := current_act(p)
	if act == Act.NONE:
		return p.position
	if act == Act.RECEIVE:
		return Vector3(Tuning.SETTER_SPOT.x * s, 0.0, Tuning.SETTER_SPOT.y * s)
	if act == Act.SET_BALL:
		return _high_set_point(p.team)
	return Vector3(0.0, 0.0, -s * Tuning.COURT_DEPTH * 0.6)


func clamp_aim(p: Player, a: Vector3, act: int = -1) -> Vector3:
	var s := side_of_team(p.team)
	# assistência: a mira nunca sai da quadra
	var w := Tuning.COURT_HALF_W - Tuning.AIM_MARGIN
	var d := Tuning.COURT_DEPTH - Tuning.AIM_MARGIN
	var out := Vector3(clampf(a.x, -w, w), 0.0, clampf(a.z, -d, d))
	if act < 0:
		act = current_act(p)
	if act == Act.SERVE or act == Act.ATTACK or act == Act.DINK:
		out.z = minf(out.z, -0.6) if s > 0.0 else maxf(out.z, 0.6)
	return out


# ---------------------------------------------------------------- entrada do humano

func human_press(p: Player) -> void:
	p.holding = true
	human_aiming = true
	start_serve(p)


func human_drag(p: Player, rel: Vector2) -> void:
	if human_aiming:
		human_aim = clamp_aim(p, human_aim + Vector3(rel.x, 0.0, rel.y) * Tuning.AIM_SENS * aim_sens)


## Abandona a mira sem tocar (pausa no meio do gesto: soltar depois não dispara nada).
func cancel_aim() -> void:
	human_aiming = false
	if human != null:
		human.holding = false


func human_release(p: Player) -> void:
	p.holding = false
	if not human_aiming:
		return
	human_aiming = false
	attempt_hit(p, clamp_aim(p, human_aim))


## Mira que aparece na tela: sempre visível, onde você deixou ({} = sem humano).
func human_aim_view() -> Dictionary:
	if human == null:
		return {}
	return snap_aim(human, clamp_aim(human, human_aim))


# ---------------------------------------------------------------- toque

## Tenta tocar na bola (humano ao soltar o botão; bot quando decide).
## power_cap < 1 limita a força (usado pelo bot).
func attempt_hit(p: Player, aim: Vector3, power_cap: float = 1.0) -> void:
	if p.swing_cd > 0.0:
		return
	if state == State.SERVE_WAIT:
		# saque com lançamento: o toque vem depois, no anel (start_serve)
		if p == server and ball.mode == Ball.Mode.HELD and not ServeType.is_tossed(serve_type[p.team]):
			_serve(p, aim, Tuning.SERVE_Q_UNDER)
		return
	if not _in_rally() or rally_over:
		return
	if plan == null or plan.player != p:
		if block_plan != null and block_plan.player == p:
			_start_block(p)
			return
		_whiff(p, "SEM BOLA")
		return
	for item in _pending:
		if item["player"] == p:
			return
	var t_ideal := plan.t
	var err := time - t_ideal
	var w := window_scale()
	if err < -Tuning.WINDOW_EARLY * w:
		_whiff(p, "CEDO")
		return
	if err > Tuning.WINDOW_LATE * w:
		_whiff(p, "TARDE")
		return
	_pending.append({
		"player": p, "aim": aim, "err": err, "cap": power_cap,
		"at": maxf(time, t_ideal - Tuning.EARLY_SNAP), "plan_id": plan_id,
	})
	if plan.act == Act.ATTACK and p.is_grounded():
		p.start_jump(plan.pos)


func _run_pending() -> void:
	if _pending.is_empty():
		return
	var keep: Array[Dictionary] = []
	var due: Array[Dictionary] = []
	for item in _pending:
		if time + 1e-6 < float(item["at"]):
			keep.append(item)
		else:
			due.append(item)
	_pending = keep
	for item in due:
		if int(item["plan_id"]) != plan_id or not _in_rally() or rally_over:
			continue
		_execute(item["player"], item["aim"], float(item["err"]), float(item["cap"]))


func _execute(p: Player, aim: Vector3, err: float, cap: float) -> void:
	var from := ball.position
	if Vector2(from.x - p.position.x, from.z - p.position.z).length() > Tuning.REACH:
		_whiff(p, "LONGE")
		return
	var a := absf(err)
	var w := window_scale()
	var q := 1.0
	var grade := "PERFEITO!"
	if a > Tuning.PERFECT * w:
		if a <= Tuning.GOOD * w:
			q = 0.7
			grade = "BOM"
		else:
			q = 0.35
			grade = "CEDO" if err < 0.0 else "TARDE"
	if plan.act == Act.SERVE:
		_serve(p, aim, q, grade)
		return
	var act := plan.act
	if act == Act.ATTACK and is_dink(p, aim):
		act = Act.DINK
		action_used.emit(p, Act.DINK)
	var shot := resolver.resolve(self, p, act, aim, q, cap)
	_launch(shot)
	p.lunge(shot.from)
	if p.team != last_team:
		touches = 1
	else:
		touches += 1
	last_team = p.team
	last_kind = shot.kind
	rally_touches += 1
	p.swing_cd = 0.25
	p.swing(shot.kind)
	touch_made.emit(p, grade, q)
	_make_plan()


## Aperto do sacador: no flutuante e na viagem lança a bola para cima e cria o plano
## do saque (anel embaixo do sacador). Por baixo não faz nada: saca ao soltar.
func start_serve(p: Player) -> void:
	if state != State.SERVE_WAIT or p != server or ball.mode != Ball.Mode.HELD:
		return
	var kind := serve_type[p.team]
	if not ServeType.is_tossed(kind):
		return
	var s := side_of_team(p.team)
	var hand := p.position + Vector3(0.0, Tuning.SERVE_HAND_H, -0.3 * s)
	var up := sqrt(2.0 * Tuning.GRAVITY * float(Tuning.SERVE_TOSS_H[kind]))
	ball.launch(hand, Vector3(0.0, up, 0.0))
	state = State.SERVE_TOSS
	plan_id += 1
	var pred := ball.sim.predict()
	land_point = pred["land"]
	land_in = is_inside(land_point)
	var hit := BallSim.find_descent(pred, float(Tuning.SERVE_CONTACT_H[kind]), s)
	plan = ContactPlan.new(p.team, 0, Act.SERVE, time + float(hit["t"]), hit["pos"], p)


func _serve(p: Player, aim: Vector3, q: float, grade: String = "SAQUE") -> void:
	var s := side_of_team(p.team)
	var kind := serve_type[p.team]
	var from := ball.position
	if ball.mode == Ball.Mode.HELD:
		from = p.position + Vector3(0.0, float(Tuning.SERVE_CONTACT_H[kind]), -0.3 * s)
	var shot := resolver.serve(self, p, kind, from, aim, q)
	_launch(shot)
	p.serving = false
	state = State.PLAY
	last_team = p.team
	last_kind = Act.SERVE
	touches = 3          # quem sacou não pode tocar de novo antes da bola passar
	rally_touches = 1
	p.swing(Act.SERVE)
	touch_made.emit(p, "SAQUE", q)
	served.emit(p, kind, grade)
	_make_plan()


## Treino (tutorial): lança uma bola do lado do adversário para o seu, como se ele
## tivesse passado a bola. Sem saque; quem estava sacando é liberado.
func feed_ball(to: Vector3, flight_time: float) -> void:
	for p in players:
		p.serving = false
		p.holding = false
	server = null
	state = State.PLAY
	rally_over = false
	rally_touches = 0
	last_team = 1
	touches = 1
	_pending.clear()
	human_aiming = false
	var from := Vector3(0.0, 2.6, -3.0)
	var at := Vector3(to.x, Tuning.BALL_RADIUS, to.z)
	ball.launch(from, BallSim.clear_net_velocity(from, at, flight_time))
	_make_plan()


## Lança a bola real com o relógio e as mãos de bloqueio no ar (o preditor herda os dois).
func _launch(shot: HitResolver.Shot) -> void:
	ball.launch(shot.from, shot.vel, shot.grav)
	ball.sim.set_wobble(shot.wobble_amp, Tuning.FLOAT_FREQ, shot.wobble_phase)
	ball.sim.clock = time
	ball.sim.blocks = blocks.duplicate()


# ---------------------------------------------------------------- bloqueio

## Quem pode bloquear o ataque que vem: o defensor mais perto da rede, se estiver na zona.
## Antes do ataque, x e tempo estimados pelo plano do atacante; depois, exatos pelo preditor.
func _update_block_plan() -> void:
	block_plan = null
	var now := time
	blocks = blocks.filter(func(bk: Block) -> bool: return bk.t_end() > now)
	if state != State.PLAY or rally_over:
		return
	var atk_team := -1
	var x := 0.0
	var t_cross := 0.0
	if plan != null and plan.act == Act.ATTACK:
		atk_team = plan.team
		x = plan.pos.x
		t_cross = plan.t + absf(plan.pos.z) / Tuning.ATTACK_SPEED_MAX
	elif last_kind == Act.ATTACK and ball.mode == Ball.Mode.FLYING and not ball.sim.stopped \
			and side_of_point(ball.position) == side_of_team(last_team) and absf(ball.sim.vel.z) > 1e-6:
		atk_team = last_team
		var tc := -ball.sim.pos.z / ball.sim.vel.z
		x = ball.sim.pos_after(tc).x
		t_cross = time + tc
	else:
		return
	var s := side_of_team(1 - atk_team)
	var best: Player = null
	for p in players:
		if p.team != atk_team and p.is_grounded() and absf(p.position.z) <= Tuning.BLOCK_ZONE:
			if best == null or absf(p.position.z) < absf(best.position.z):
				best = p
	if best == null:
		return
	block_plan = ContactPlan.new(best.team, 0, Act.BLOCK, t_cross, Vector3(x, 0.0, s * 0.5), best)


## Soltar com BLOQUEAR: pula no lugar; as mãos valem enquanto passam da fita.
func _start_block(p: Player) -> void:
	if not p.is_grounded():
		return
	p.start_jump(p.position)
	var bk := Block.new(p, time, Tuning.JUMP_HEIGHT)
	blocks.append(bk)
	p.swing_cd = Tuning.JUMP_TIME_UP * 2.0 + Tuning.BLOCK_RECOVER
	p.swing(Act.BLOCK)
	action_used.emit(p, Act.BLOCK)
	if ball.mode == Ball.Mode.FLYING:
		ball.sim.blocks.append(bk)
		# o preditor já sabe do bloqueio: se esta bola vai bater nas mãos, o plano muda
		if bool(ball.sim.predict()["blocked"]):
			_make_plan()


## Bola bateu nas mãos: a saída vem do timing do pulo (erro = pico − contato; pulou cedo = CEDO).
## O bloqueio não conta como toque: o time do bloqueador ainda tem os 3.
func _on_block(e: Dictionary) -> void:
	var bk: Block = e["block"]
	var from: Vector3 = e["pos"]
	blocks.erase(bk)
	var err := bk.t_peak() - ball.sim.clock
	var a := absf(err)
	var q := 1.0
	var grade := "PERFEITO!"
	if a > Tuning.PERFECT:
		if a <= Tuning.GOOD:
			q = 0.7
			grade = "BOM"
		else:
			q = 0.35
			grade = "CEDO" if err < 0.0 else "TARDE"
	var shot := resolver.block_exit(from, bk, q)
	_launch(shot)
	last_team = bk.team
	last_kind = Act.BLOCK
	touches = 0
	rally_touches += 1
	touch_made.emit(bk.player, grade, q)
	_make_plan()


func _whiff(p: Player, why: String) -> void:
	p.swing_cd = Tuning.WHIFF_COOLDOWN
	p.swing(Act.NONE)
	whiffed.emit(p, why)


## Assistência: traz o alvo para dentro da quadra (com folga das linhas).
static func keep_inside(v: Vector3, margin: float = 0.3) -> Vector3:
	var w := Tuning.COURT_HALF_W - margin
	var d := Tuning.COURT_DEPTH - margin
	return Vector3(clampf(v.x, -w, w), v.y, clampf(v.z, -d, d))


## Garante o alvo do lado `s` (+1/-1), a pelo menos min_dist da rede.
static func _keep_side(v: Vector3, s: float, min_dist: float) -> Vector3:
	return Vector3(v.x, v.y, s * maxf(v.z * s, min_dist))


# ---------------------------------------------------------------- plano de contato

## Prevê a bola e decide: quem toca, qual ação, onde fica o anel e o tempo ideal.
func _make_plan() -> void:
	plan_id += 1
	plan = null
	if ball.mode != Ball.Mode.FLYING:
		return
	var pred := ball.sim.predict()
	land_point = pred["land"]
	land_in = is_inside(land_point)
	land_t = time + _last_time(pred)
	land_display = land_point
	var plain := {}
	if ball.sim.wobble_amp != 0.0:
		# leitura atrasada: a mesma conta sem a oscilação (é o que "parece" que vai acontecer)
		var no_wobble := ball.sim.copy()
		no_wobble.wobble_amp = 0.0
		plain = no_wobble.predict()
		land_display = plain["land"]
	var recv_side := side_of_point(land_point)
	var recv_team := 0 if recv_side > 0.0 else 1
	var n := 1 if recv_team != last_team else touches + 1
	if n > Tuning.MAX_TOUCHES:
		return              # toque além do limite não existe: a bola vai cair
	var options: Array = []
	if n == 1:
		options = [[Act.RECEIVE, Tuning.H_RECEIVE]]
	elif n == 2:
		options = [[Act.SET_BALL, Tuning.H_SET], [Act.SET_BALL, Tuning.H_RECEIVE]]
	else:
		options = [[Act.ATTACK, Tuning.H_ATTACK], [Act.FREEBALL, Tuning.H_SET], [Act.FREEBALL, Tuning.H_RECEIVE]]
	for opt in options:
		var hit := BallSim.find_descent(pred, float(opt[1]), recv_side)
		if hit.is_empty():
			continue
		var at: Vector3 = hit["pos"]
		var shown := at
		if not plain.is_empty():
			var fake := BallSim.find_descent(plain, float(opt[1]), recv_side)
			if not fake.is_empty():
				shown = fake["pos"]
		plan = ContactPlan.new(recv_team, n, int(opt[0]), time + float(hit["t"]), at,
				_closest_player(recv_team, shown))
		plan.display_pos = shown
		return


static func _last_time(pred: Dictionary) -> float:
	var times: PackedFloat64Array = pred["times"]
	return times[times.size() - 1]


func _closest_player(team: int, at: Vector3) -> Player:
	var best: Player = null
	var best_d := INF
	for p in players:
		if p.team != team:
			continue
		var d := Vector2(at.x - p.position.x, at.z - p.position.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best


func _high_set_point(team: int) -> Vector3:
	var s := side_of_team(team)
	var base := Vector3(Tuning.SETTER_SPOT.x * s, 0.0, Tuning.SETTER_SPOT.y * s)
	if plan != null and plan.team == team:
		base = plan.pos
	return Vector3(clampf(base.x, -2.5, 2.5), 0.0, s * clampf(absf(base.z) - 0.5, 1.2, 4.0))


## Pulo automático: segurando o botão no ataque, o jogador sobe na hora certa.
func _auto_jumps() -> void:
	if not _in_rally() or plan == null:
		return
	var jump_serve := plan.act == Act.SERVE and serve_type[plan.team] == ServeType.Kind.JUMP
	if plan.act != Act.ATTACK and not jump_serve:
		return
	var t_ideal := plan.t
	if time < t_ideal - Tuning.JUMP_TIME_UP or time > t_ideal + 0.1:
		return
	var at := plan.pos
	var who := plan.player
	if who == null or not who.is_grounded() or not (who.holding or _has_pending(who)):
		return
	if Vector2(at.x - who.position.x, at.z - who.position.z).length() <= Tuning.REACH + 1.2:
		who.start_jump(at)


## Bola em jogo e tocável: rally ou bola lançada no saque.
func _in_rally() -> bool:
	return state == State.PLAY or state == State.SERVE_TOSS


func _has_pending(p: Player) -> bool:
	for item in _pending:
		if item["player"] == p:
			return true
	return false


func _update_assists() -> void:
	for p in players:
		p.magnet_on = false
	if state != State.PLAY or plan == null:
		return
	var who := plan.player
	if who != null:
		who.magnet_on = true
		who.magnet_point = plan_view_pos(plan)


# ---------------------------------------------------------------- pontos

func _on_ball_event(e: Dictionary) -> void:
	var kind: int = e["type"]
	var pos: Vector3 = e["pos"]
	if state == State.SERVE_TOSS and kind == BallSim.Ev.LAND:
		_award(1 - server_team, "Saque perdido")
		return
	if state != State.PLAY or rally_over:
		return
	if kind == BallSim.Ev.BLOCK:
		_on_block(e)
	elif kind == BallSim.Ev.NET:
		_make_plan()        # a trajetória mudou: novo anel
	elif kind == BallSim.Ev.ANTENNA:
		_award(1 - last_team, "Fora (antena)")
	elif kind == BallSim.Ev.LAND:
		var side_team := 0 if pos.z > 0.0 else 1
		if is_inside(pos):
			var why := "Bola no chão"
			if side_team == last_team and ball.sim.net_hits > 0:
				why = "Rede"
			_award(1 - side_team, why)
		else:
			_award(1 - last_team, "Fora")


func _award(team: int, reason: String) -> void:
	if rally_over or team < 0 or team > 1:
		return
	rally_over = true
	best_rally = maxi(best_rally, rally_touches)
	state = State.POINT_PAUSE
	_pause_t = Tuning.POINT_PAUSE
	_next_server = team                 # rally point: saca quem fez o ponto
	plan = null
	plan_id += 1
	_pending.clear()
	human_aiming = false
	for p in players:
		p.holding = false
	var r := rules.add_point(team)
	if bool(r["match_over"]):
		state = State.MATCH_OVER        # fim: ninguém saca mais
	elif bool(r["set_over"]):
		_set_break = true
		_pause_t = Tuning.SET_PAUSE
		_next_server = rules.first_server(rules.set_index + 1)
	point_scored.emit(team, reason)
	if bool(r["set_over"]):
		set_over.emit(team, rules.set_index, rules.history[-1])
	if bool(r["match_over"]):
		match_over.emit(team)


func _reset_for_serve(team: int) -> void:
	state = State.SERVE_WAIT
	rally_over = false
	rally_touches = 0
	touches = 0
	last_team = -1
	last_kind = Act.NONE
	blocks.clear()
	block_plan = null
	plan = null
	plan_id += 1
	_pending.clear()
	human_aiming = false
	server_team = team
	server = null
	for p in players:
		if p.team == team and server == null:
			server = p
	for p in players:
		var s := side_of_team(p.team)
		p.reset_state()
		p.serving = p == server
		if p == server:
			p.position = Vector3(1.2 * s, 0.0, s * (Tuning.COURT_DEPTH + 0.9))
		else:
			p.position = Vector3(0.0, 0.0, s * 4.2)
	ball.hold(server)
