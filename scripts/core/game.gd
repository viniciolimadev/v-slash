class_name Game
extends Node
## Regras e fluxo do rally + o "plano de contato": quem joga a próxima bola,
## com qual ação (receber / levantar / atacar), ONDE (o anel) e QUANDO (tempo ideal).

signal point_scored(team: int, reason: String)
signal touch_made(player: Player, grade: String, quality: float)
signal whiffed(player: Player, why: String)

enum State { SERVE_WAIT, PLAY, POINT_PAUSE }
enum Act { NONE, SERVE, RECEIVE, SET_BALL, ATTACK, FREEBALL }

const ACT_LABELS := ["", "SACAR", "RECEBER", "LEVANTAR", "ATACAR", "PASSAR"]

var state: int = State.SERVE_WAIT
var time := 0.0
var ball: Ball
var players: Array[Player] = []
var bots: Array[BotBrain] = []
var human: Player = null
var score: Array[int] = [0, 0]
var server_team := 0
var server: Player = null
var last_team := -1                 # time que tocou por último
var touches := 0                    # toques seguidos do last_team
var rally_touches := 0
var best_rally := 0
var rally_over := false
var plan: Dictionary = {}           # {team, n, act, t, pos, player} — ver _make_plan()
var plan_id := 0
var land_point := Vector3.ZERO      # onde a bola cai se ninguém tocar
var land_in := true
var bot_level := 0                  # começa no Fácil: a meta da Fase 0 é sentir o gesto
var rng := RandomNumberGenerator.new()

var human_aiming := false
## Mira do humano: uma por tipo de jogada (recepção, levantamento, bola pro outro lado),
## cada uma fica onde você deixou por último.
var human_aim: Vector3:
	get:
		return _aims.get(_aim_slot(), Vector3.ZERO)
	set(v):
		_aims[_aim_slot()] = v
var _aims := {}
var _pause_t := 0.0
var _pending: Array[Dictionary] = []


func setup(p_ball: Ball, p_players: Array[Player], p_bots: Array[BotBrain]) -> void:
	ball = p_ball
	players = p_players
	bots = p_bots
	for p in players:
		if p.is_human:
			human = p
			var s := side_of_team(p.team)
			_aims = {
				# saque/ataque/bola de graça começam no fundo da quadra adversária
				Act.ATTACK: Vector3(0.0, 0.0, -s * Tuning.AIM_DEEP),
				Act.RECEIVE: Vector3(Tuning.SETTER_SPOT.x * s, 0.0, Tuning.SETTER_SPOT.y * s),
				Act.SET_BALL: _high_set_point(p.team),
			}
	rng.randomize()
	_reset_for_serve(0)


func reset_match() -> void:
	score = [0, 0]
	best_rally = 0
	_reset_for_serve(0)


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
	for e in ball.step(dt):
		_on_ball_event(e)
	_run_pending()
	if state == State.POINT_PAUSE:
		_pause_t -= dt
		if _pause_t <= 0.0:
			_reset_for_serve(server_team)
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
	if state != State.PLAY or plan.is_empty() or plan["player"] != p:
		return Act.NONE
	return int(plan["act"])


func action_label(p: Player) -> String:
	return str(ACT_LABELS[current_act(p)])


## Está na hora de soltar? (o botão acende)
func is_hot(p: Player) -> bool:
	if plan.is_empty() or current_act(p) == Act.NONE:
		return false
	return absf(time - float(plan["t"])) <= Tuning.GOOD


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
func snap_aim(p: Player, raw: Vector3) -> Dictionary:
	var out := {"pos": raw, "name": "", "quick": false}
	var act := current_act(p)
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


func clamp_aim(p: Player, a: Vector3) -> Vector3:
	var s := side_of_team(p.team)
	# assistência: a mira nunca sai da quadra
	var w := Tuning.COURT_HALF_W - Tuning.AIM_MARGIN
	var d := Tuning.COURT_DEPTH - Tuning.AIM_MARGIN
	var out := Vector3(clampf(a.x, -w, w), 0.0, clampf(a.z, -d, d))
	var act := current_act(p)
	if act == Act.SERVE or act == Act.ATTACK:
		out.z = minf(out.z, -0.6) if s > 0.0 else maxf(out.z, 0.6)
	return out


# ---------------------------------------------------------------- entrada do humano

func human_press(p: Player) -> void:
	p.holding = true
	human_aiming = true


func human_drag(p: Player, rel: Vector2) -> void:
	if human_aiming:
		human_aim = clamp_aim(p, human_aim + Vector3(rel.x, 0.0, rel.y) * Tuning.AIM_SENS)


func human_release(p: Player) -> void:
	p.holding = false
	if not human_aiming:
		return
	human_aiming = false
	attempt_hit(p, clamp_aim(p, human_aim))


func _aim_slot() -> int:
	var act := current_act(human) if human != null else Act.NONE
	return act if act == Act.RECEIVE or act == Act.SET_BALL else Act.ATTACK


## Mira que aparece na tela: sempre visível, onde você deixou por último ({} = sem humano).
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
		if p == server and ball.mode == Ball.Mode.HELD:
			_serve(p, aim)
		return
	if state != State.PLAY or rally_over:
		return
	if plan.is_empty() or plan["player"] != p:
		_whiff(p, "SEM BOLA")
		return
	for item in _pending:
		if item["player"] == p:
			return
	var t_ideal: float = plan["t"]
	var err := time - t_ideal
	if err < -Tuning.WINDOW_EARLY:
		_whiff(p, "CEDO")
		return
	if err > Tuning.WINDOW_LATE:
		_whiff(p, "TARDE")
		return
	_pending.append({
		"player": p, "aim": aim, "err": err, "cap": power_cap,
		"at": maxf(time, t_ideal - Tuning.EARLY_SNAP), "plan_id": plan_id,
	})
	if int(plan["act"]) == Act.ATTACK and p.is_grounded():
		p.start_jump(plan["pos"])


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
		if int(item["plan_id"]) != plan_id or state != State.PLAY or rally_over:
			continue
		_execute(item["player"], item["aim"], float(item["err"]), float(item["cap"]))


func _execute(p: Player, aim: Vector3, err: float, cap: float) -> void:
	var from := ball.position
	if Vector2(from.x - p.position.x, from.z - p.position.z).length() > Tuning.REACH:
		_whiff(p, "LONGE")
		return
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
	var power := minf(q, cap)          # timing = precisão; o bot só limita a FORÇA
	var act := int(plan["act"])
	var info := snap_aim(p, aim)
	var target: Vector3 = info["pos"]
	var s := side_of_team(p.team)
	var over := side_of_point(target) != s or act == Act.ATTACK
	var kind := act
	if over and (act == Act.RECEIVE or act == Act.SET_BALL):
		kind = Act.FREEBALL
	target = _scatter(target, kind, q)
	target = _keep_side(target, -s if over else s, 0.4)
	if p.is_human and q >= Tuning.ASSIST_KEEP_IN_Q:
		target = keep_inside(target)
	var v := Vector3.ZERO
	var grav := Tuning.GRAVITY
	if kind == Act.RECEIVE:
		var to := Vector3(target.x, Tuning.H_SET, target.z)
		v = BallSim.launch_velocity(from, to, Tuning.T_RECEIVE * lerpf(0.82, 1.0, q))
	elif kind == Act.SET_BALL:
		var to := Vector3(target.x, Tuning.H_ATTACK, target.z)
		var t_set := Tuning.T_SET_QUICK if bool(info["quick"]) else Tuning.T_SET_HIGH
		v = BallSim.launch_velocity(from, to, t_set)
	elif kind == Act.ATTACK:
		var to := Vector3(target.x, Tuning.BALL_RADIUS, target.z)
		var dist := Vector2(to.x - from.x, to.z - from.z).length()
		var spd := lerpf(Tuning.ATTACK_SPEED_MIN, Tuning.ATTACK_SPEED_MAX, power)
		grav = Tuning.SPIKE_GRAVITY
		v = BallSim.clear_net_velocity(from, to, maxf(dist / spd, 0.25), grav)
	else:
		var to := Vector3(target.x, Tuning.BALL_RADIUS, target.z)
		v = BallSim.clear_net_velocity(from, to, Tuning.T_FREEBALL)
	ball.launch(from, v, grav)
	p.lunge(from)
	if p.team != last_team:
		touches = 1
	else:
		touches += 1
	last_team = p.team
	rally_touches += 1
	p.swing_cd = 0.25
	p.swing(kind)
	touch_made.emit(p, grade, q)
	_make_plan()


func _serve(p: Player, aim: Vector3) -> void:
	var s := side_of_team(p.team)
	var q := 0.85                      # Fase 0: saque sem timing (barra de força chega na Fase 2)
	var snapped: Vector3 = snap_aim(p, aim)["pos"]
	var target := _keep_side(_scatter(snapped, Act.SERVE, q), -s, 0.8)
	if p.is_human and q >= Tuning.ASSIST_KEEP_IN_Q:
		target = keep_inside(target)
	var from := p.position + Vector3(0.0, 1.05, -0.3 * s)
	var to := Vector3(target.x, Tuning.BALL_RADIUS, target.z)
	ball.launch(from, BallSim.clear_net_velocity(from, to, Tuning.T_SERVE))
	p.serving = false
	state = State.PLAY
	last_team = p.team
	touches = 3          # quem sacou não pode tocar de novo antes da bola passar
	rally_touches = 1
	p.swing(Act.SERVE)
	touch_made.emit(p, "SAQUE", q)
	_make_plan()


func _whiff(p: Player, why: String) -> void:
	p.swing_cd = Tuning.WHIFF_COOLDOWN
	p.swing(Act.NONE)
	whiffed.emit(p, why)


func _scatter(target: Vector3, kind: int, q: float) -> Vector3:
	var base := Tuning.SCATTER_RECEIVE
	if kind == Act.SET_BALL:
		base = Tuning.SCATTER_SET
	elif kind == Act.ATTACK or kind == Act.FREEBALL:
		base = Tuning.SCATTER_ATTACK
	elif kind == Act.SERVE:
		base = Tuning.SCATTER_SERVE
	var r := base * (1.0 - q) * sqrt(rng.randf())
	var ang := rng.randf() * TAU
	return target + Vector3(cos(ang) * r, 0.0, sin(ang) * r)


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
	plan = {}
	if ball.mode != Ball.Mode.FLYING:
		return
	var pred := ball.sim.predict()
	land_point = pred["land"]
	land_in = is_inside(land_point)
	var recv_side := side_of_point(land_point)
	var recv_team := 0 if recv_side > 0.0 else 1
	var n := 1 if recv_team != last_team else touches + 1
	if n > 3:
		return              # 4º toque não existe: a bola vai cair
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
		plan = {
			"team": recv_team,
			"n": n,
			"act": int(opt[0]),
			"t": time + float(hit["t"]),
			"pos": at,
			"player": _closest_player(recv_team, at),
		}
		return


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
	if not plan.is_empty() and int(plan["team"]) == team:
		base = plan["pos"]
	return Vector3(clampf(base.x, -2.5, 2.5), 0.0, s * clampf(absf(base.z) - 0.5, 1.2, 4.0))


## Pulo automático: segurando o botão no ataque, o jogador sobe na hora certa.
func _auto_jumps() -> void:
	if state != State.PLAY or plan.is_empty() or int(plan["act"]) != Act.ATTACK:
		return
	var t_ideal: float = plan["t"]
	if time < t_ideal - Tuning.JUMP_TIME_UP or time > t_ideal + 0.1:
		return
	var at: Vector3 = plan["pos"]
	var who: Player = plan["player"]
	if who == null or not who.is_grounded() or not (who.holding or _has_pending(who)):
		return
	if Vector2(at.x - who.position.x, at.z - who.position.z).length() <= Tuning.REACH + 1.2:
		who.start_jump(at)


func _has_pending(p: Player) -> bool:
	for item in _pending:
		if item["player"] == p:
			return true
	return false


func _update_assists() -> void:
	for p in players:
		p.magnet_on = false
	if state != State.PLAY or plan.is_empty():
		return
	var who: Player = plan["player"]
	if who != null:
		who.magnet_on = true
		who.magnet_point = plan["pos"]


# ---------------------------------------------------------------- pontos

func _on_ball_event(e: Dictionary) -> void:
	var kind: int = e["type"]
	var pos: Vector3 = e["pos"]
	if state != State.PLAY or rally_over:
		return
	if kind == BallSim.Ev.NET:
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
	score[team] += 1
	best_rally = maxi(best_rally, rally_touches)
	server_team = team
	state = State.POINT_PAUSE
	_pause_t = 1.8
	plan = {}
	plan_id += 1
	_pending.clear()
	human_aiming = false
	for p in players:
		p.holding = false
	point_scored.emit(team, reason)


func _reset_for_serve(team: int) -> void:
	state = State.SERVE_WAIT
	rally_over = false
	rally_touches = 0
	touches = 0
	last_team = -1
	plan = {}
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
