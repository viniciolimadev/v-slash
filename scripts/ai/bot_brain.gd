class_name BotBrain
extends RefCounted
## IA simples: lê o MESMO plano de contato que desenha o seu anel,
## com atraso de reação e erro de timing conforme o nível.
## Fase 2: escolhe o tipo de saque, sobe para bloquear, larga e (Médio+) faz peixinho,
## sempre pelos mesmos caminhos do humano (start_serve, attempt_hit).

var p: Player
var game: Game
var level := 1
## Parceiro do humano no 2v2: só se posiciona. Quem toca é sempre quem você controla
## (com o dedo no botão o controle não troca; ao soltar, o toque vai para quem tem o plano).
var partner_mode := false
var rng := RandomNumberGenerator.new()

var _plan_seen := -1
var _react_until := 0.0
var _hit_at := INF
var _will_play := true
var _serve_at := INF
var _toss_hit_at := INF             # saque com lançamento: quando soltar
var _foe_seen := -1                 # plano do adversário em que já decidiu se vai bloquear
var _will_block := false
var _block_err := 0.0
var _block_err_set := false


func _init(player: Player, g: Game, lvl: int) -> void:
	p = player
	game = g
	rng.randomize()
	set_level(lvl)


func set_level(lvl: int) -> void:
	level = clampi(lvl, 0, 2)
	if not p.is_human:
		_apply_level()


func _apply_level() -> void:
	p.speed = float(Tuning.BOT_SPEED[level])
	p.can_dive = level >= 1             # o Fácil não faz peixinho


func tick(_dt: float) -> void:
	if p.is_human:
		return              # 2v2: você está controlando este jogador agora
	_apply_level()          # volta a jogar como bot depois de você largar o controle
	p.move_input = Vector2.ZERO
	if partner_mode:
		p.holding = false
		var plan := game.plan
		if plan != null and plan.player == p and game.state == Game.State.PLAY:
			_go_to(game.plan_view_pos(plan))
		else:
			_go_to(_idle_target(Game.side_of_team(p.team)))
		return
	var s := Game.side_of_team(p.team)
	var home := _idle_target(s)

	if game.state == Game.State.SERVE_WAIT or game.state == Game.State.SERVE_TOSS:
		p.holding = false
		if game.server != p:
			_go_to(home)
			return
		if game.state == Game.State.SERVE_TOSS:
			_toss_tick()
			return
		if _serve_at == INF:
			_serve_at = game.time + rng.randf_range(0.8, 1.4)
		if game.time >= _serve_at:
			_serve_at = INF
			game.serve_type[p.team] = _pick_serve()
			if ServeType.is_tossed(game.serve_type[p.team]):
				game.start_serve(p)
				_toss_hit_at = INF
			else:
				game.attempt_hit(p, _serve_target())
		return
	_serve_at = INF

	if game.state != Game.State.PLAY:
		p.holding = false
		return
	var plan := game.plan
	if plan == null or plan.player != p:
		p.holding = false
		if not _block_tick(plan):
			_go_to(home)
		return
	_will_block = false

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
	# mesma leitura do humano: no flutuante, a posição certa só perto do contato
	_go_to(game.plan_view_pos(plan))
	var act := plan.act
	p.holding = act == Game.Act.ATTACK
	if game.time >= _hit_at:
		_hit_at = INF
		game.attempt_hit(p, _choose_aim(act), float(Tuning.BOT_POWER[level]))


## Bola lançada no seu saque: segura (a viagem pula sozinha) e solta com o erro do nível.
func _toss_tick() -> void:
	var plan := game.plan
	if plan == null or plan.player != p:
		return
	p.holding = true
	if _toss_hit_at == INF:
		var err := rng.randfn(0.0, float(Tuning.BOT_TIMING_SIGMA[level]))
		_toss_hit_at = plan.t + clampf(err, -0.3, 0.13)
	if game.time >= _toss_hit_at:
		_toss_hit_at = -INF             # já soltou (não tenta de novo nesta bola)
		game.attempt_hit(p, _serve_target())


func _pick_serve() -> int:
	var mix: Array = Tuning.BOT_SERVE_MIX[level]
	var r := rng.randf()
	for kind in mix.size():
		r -= float(mix[kind])
		if r < 0.0:
			return kind
	return ServeType.Kind.UNDER


## Bloqueio: quando o adversário vai levantar/atacar, decide uma vez se sobe para a rede;
## lá, solta BLOQUEAR com erro de timing do nível. true = está cuidando disso.
func _block_tick(plan: ContactPlan) -> bool:
	var s := Game.side_of_team(p.team)
	if game.current_act(p) == Game.Act.BLOCK:
		var bp := game.block_plan
		_go_to(Vector3(bp.pos.x, 0.0, s * 0.6))
		if not _block_err_set:
			_block_err_set = true
			_block_err = rng.randfn(0.0, float(Tuning.BOT_BLOCK_SIGMA[level]))
		if game.time >= game.block_release_t() + _block_err:
			game.attempt_hit(p, p.position)
			_will_block = false
		return true
	if plan == null or plan.team == p.team or not p.is_grounded():
		return false
	if plan.act != Game.Act.SET_BALL and plan.act != Game.Act.ATTACK:
		return false
	if plan.n == 2 and game.plan_id != _foe_seen:
		_foe_seen = game.plan_id
		_will_block = rng.randf() < float(Tuning.BOT_BLOCK_CHANCE[level])
		_block_err_set = false
	if not _will_block:
		return false
	# antes do levantamento, espera no meio da rede; depois, na frente do atacante
	var x := plan.pos.x if plan.act == Game.Act.ATTACK else 0.0
	_go_to(Vector3(x, 0.0, s * 0.6))
	return true


## Onde ficar sem bola: no 1v1, a base; no 2v2, a posição do papel (PartnerBrain).
func _idle_target(s: float) -> Vector3:
	if game.teams.size() > p.team and game.teams[p.team].players.size() > 1:
		return PartnerBrain.target_for(p, game)
	return Vector3(0.0, 0.0, s * 4.2)


func _go_to(target: Vector3) -> void:
	var d := Vector2(target.x - p.position.x, target.z - p.position.z)
	var dist := d.length()
	if dist < 0.08:
		return
	p.move_input = d / dist * clampf(dist / 0.6, 0.0, 1.0)


func _clearly_out() -> bool:
	var lp := game.land_view()
	return absf(lp.x) > game.court.half_w + 0.3 or absf(lp.z) > game.court.depth + 0.3


func _choose_aim(act: int) -> Vector3:
	var s := Game.side_of_team(p.team)
	if act == Game.Act.RECEIVE:
		return game.spot(p.team, Tuning.SETTER_SPOT) + _noise(0.3)
	if act == Game.Act.SET_BALL:
		return game.default_aim(p) + _noise(0.2)
	if act == Game.Act.ATTACK:
		return _attack_target()
	return _court_target(1.2)


## Cortada fora da faixa da largada (senão vira largada sem querer). Médio/Difícil às vezes largam;
## o Difícil larga mais quando você está no bloqueio e, se cortar, corta longe das suas mãos.
func _attack_target() -> Vector3:
	var foe := game.opponent_of(p.team)
	var foe_blocks := foe != null and absf(foe.position.z) <= Tuning.BLOCK_ZONE
	var foe_side := -Game.side_of_team(p.team)
	var dink_chance := float(Tuning.BOT_DINK_CHANCE[level])
	if level == 2 and not foe_blocks:
		dink_chance *= 0.4
	if rng.randf() < dink_chance:
		var w := game.court.half_w - 0.8
		return Vector3(rng.randf_range(-w, w), 0.0, foe_side * rng.randf_range(1.4, 2.0))
	if level == 2 and foe_blocks:
		return _away_from_block(foe)
	return _court_target(Tuning.DINK_DIST + 0.3)


func _away_from_block(foe: Player) -> Vector3:
	var foe_side := -Game.side_of_team(p.team)
	var w := game.court.half_w - 0.6
	var d := game.court.depth - 0.6
	var from := game.plan.pos if game.plan != null else p.position
	var best := Vector3(0.0, 0.0, foe_side * d * 0.6)
	var best_gap := -INF
	for _i in 8:
		var c := Vector3(rng.randf_range(-w, w), 0.0, foe_side * rng.randf_range(Tuning.DINK_DIST + 0.3, d))
		# x onde a cortada cruza a rede (linha reta do ponto de ataque até o alvo)
		var k := -from.z / (c.z - from.z)
		var gap := absf(lerpf(from.x, c.x, k) - foe.position.x)
		if gap > best_gap:
			best_gap = gap
			best = c
	return best


## Ponto na quadra adversária. Fácil: perto de você. Médio: aleatório. Difícil: longe de você.
func _court_target(min_depth: float) -> Vector3:
	var foe_side := -Game.side_of_team(p.team)
	var w := game.court.half_w - 0.6
	var d := game.court.depth - 0.6
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
