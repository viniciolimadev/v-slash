class_name BotBrain
extends RefCounted
## IA simples: lê o MESMO plano de contato que desenha o seu anel,
## com atraso de reação e erro de timing conforme o nível.

var p: Player
var game: Game
var level := 1
var rng := RandomNumberGenerator.new()

var _plan_seen := -1
var _react_until := 0.0
var _hit_at := INF
var _will_play := true
var _serve_at := INF


func _init(player: Player, g: Game, lvl: int) -> void:
	p = player
	game = g
	rng.randomize()
	set_level(lvl)


func set_level(lvl: int) -> void:
	level = clampi(lvl, 0, 2)
	p.speed = float(Tuning.BOT_SPEED[level])


func tick(_dt: float) -> void:
	p.move_input = Vector2.ZERO
	var s := Game.side_of_team(p.team)
	var home := Vector3(0.0, 0.0, s * 4.2)

	if game.state == Game.State.SERVE_WAIT or game.state == Game.State.SERVE_TOSS:
		p.holding = false
		if game.server != p:
			_go_to(home)
			return
		if game.state == Game.State.SERVE_TOSS:
			return
		if _serve_at == INF:
			_serve_at = game.time + rng.randf_range(0.8, 1.4)
		if game.time >= _serve_at:
			_serve_at = INF
			game.attempt_hit(p, _serve_target())
		return
	_serve_at = INF

	if game.state != Game.State.PLAY:
		p.holding = false
		return
	var plan := game.plan
	if plan == null or plan.player != p:
		p.holding = false
		_go_to(home)
		return

	if game.plan_id != _plan_seen:
		# bola nova: decide uma vez (reação, erro de timing, deixar cair se for fora)
		_plan_seen = game.plan_id
		var from_foe := plan.n == 1
		_react_until = game.time + (float(Tuning.BOT_REACTION[level]) if from_foe else 0.05)
		var err := rng.randfn(0.0, float(Tuning.BOT_TIMING_SIGMA[level]))
		_hit_at = plan.t + clampf(err, -0.3, 0.13)
		_will_play = true
		if from_foe and _clearly_out() and rng.randf() < float(Tuning.BOT_READS_OUT[level]):
			_will_play = false

	if game.time < _react_until:
		return
	if not _will_play:
		p.holding = false
		_go_to(home)
		return
	var target := plan.pos
	_go_to(target)
	var act := plan.act
	p.holding = act == Game.Act.ATTACK
	if game.time >= _hit_at:
		_hit_at = INF
		game.attempt_hit(p, _choose_aim(act), float(Tuning.BOT_POWER[level]))


func _go_to(target: Vector3) -> void:
	var d := Vector2(target.x - p.position.x, target.z - p.position.z)
	var dist := d.length()
	if dist < 0.08:
		return
	p.move_input = d / dist * clampf(dist / 0.6, 0.0, 1.0)


func _clearly_out() -> bool:
	var lp := game.land_point
	return absf(lp.x) > Tuning.COURT_HALF_W + 0.3 or absf(lp.z) > Tuning.COURT_DEPTH + 0.3


func _choose_aim(act: int) -> Vector3:
	var s := Game.side_of_team(p.team)
	if act == Game.Act.RECEIVE:
		return Vector3(Tuning.SETTER_SPOT.x * s, 0.0, Tuning.SETTER_SPOT.y * s) + _noise(0.3)
	if act == Game.Act.SET_BALL:
		return game.default_aim(p) + _noise(0.2)
	return _court_target(1.2)


## Ponto na quadra adversária. Fácil: perto de você. Médio: aleatório. Difícil: longe de você.
func _court_target(min_depth: float) -> Vector3:
	var foe_side := -Game.side_of_team(p.team)
	var w := Tuning.COURT_HALF_W - 0.6
	var d := Tuning.COURT_DEPTH - 0.6
	var foe := game.opponent_of(p.team)
	var best := Vector3(0.0, 0.0, foe_side * d * 0.6)
	var best_score := -INF
	for _i in 6:
		var c := Vector3(rng.randf_range(-w, w), 0.0, foe_side * rng.randf_range(min_depth, d))
		var dist := c.distance_to(foe.position) if foe != null else 0.0
		var score := rng.randf()
		if level == 0:
			score = -dist
		elif level == 2:
			score = dist + rng.randf_range(0.0, 0.5)
		if score > best_score:
			best_score = score
			best = c
	return best


func _serve_target() -> Vector3:
	return _court_target(2.0)


func _noise(r: float) -> Vector3:
	return Vector3(rng.randf_range(-r, r), 0.0, rng.randf_range(-r, r))
