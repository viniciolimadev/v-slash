class_name HitResolver
extends RefCounted
## Dado quem toca, a ação, a mira e a qualidade, devolve para onde e como a bola sai.
## Não guarda estado da jogada: as regras (contadores, sinais, plano) ficam no Game.


## Saída de um toque: de onde, com que velocidade e gravidade, e o alvo final (depois da dispersão).
class Shot:
	extends RefCounted
	var from: Vector3
	var vel: Vector3
	var grav: float
	var kind: int           # Game.Act efetivo (recepção mandada para o outro lado vira FREEBALL)
	var target: Vector3
	var wobble_amp := 0.0   # m; só o saque flutuante oscila
	var wobble_phase := 0.0


var rng: RandomNumberGenerator      # o mesmo do Game (testes com semente continuam iguais)


func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng


func resolve(game: Game, p: Player, act: int, aim: Vector3, q: float, cap: float) -> Shot:
	var from := game.ball.position
	var power := minf(q, cap)          # timing = precisão; o bot só limita a FORÇA
	var info := game.snap_aim(p, aim)
	var target: Vector3 = info["pos"]
	var s := Game.side_of_team(p.team)
	var over := Game.side_of_point(target) != s or act == Game.Act.ATTACK
	var kind := act
	if over and (act == Game.Act.RECEIVE or act == Game.Act.SET_BALL):
		kind = Game.Act.FREEBALL
	target = scatter(target, kind, q)
	target = Game._keep_side(target, -s if over else s, 0.4)
	if p.is_human and q >= Tuning.ASSIST_KEEP_IN_Q:
		target = Game.keep_inside(target)
	var v := Vector3.ZERO
	var grav := Tuning.GRAVITY
	if kind == Game.Act.RECEIVE:
		var to := Vector3(target.x, Tuning.H_SET, target.z)
		v = BallSim.launch_velocity(from, to, Tuning.T_RECEIVE * lerpf(0.82, 1.0, q))
	elif kind == Game.Act.SET_BALL:
		var to := Vector3(target.x, Tuning.H_ATTACK, target.z)
		var t_set := Tuning.T_SET_QUICK if bool(info["quick"]) else Tuning.T_SET_HIGH
		v = BallSim.launch_velocity(from, to, t_set)
	elif kind == Game.Act.ATTACK:
		var to := Vector3(target.x, Tuning.BALL_RADIUS, target.z)
		var dist := Vector2(to.x - from.x, to.z - from.z).length()
		var spd := lerpf(Tuning.ATTACK_SPEED_MIN, Tuning.ATTACK_SPEED_MAX, power)
		grav = Tuning.SPIKE_GRAVITY
		v = BallSim.clear_net_velocity(from, to, maxf(dist / spd, 0.25), grav)
	else:
		var to := Vector3(target.x, Tuning.BALL_RADIUS, target.z)
		v = BallSim.clear_net_velocity(from, to, Tuning.T_FREEBALL)
	var shot := Shot.new()
	shot.from = from
	shot.vel = v
	shot.grav = grav
	shot.kind = kind
	shot.target = target
	return shot


## Saque do tipo `serve_kind` saindo de `from` (mão do sacador ou bola lançada).
func serve(game: Game, p: Player, serve_kind: int, from: Vector3, aim: Vector3, q: float) -> Shot:
	var s := Game.side_of_team(p.team)
	var snapped: Vector3 = game.snap_aim(p, aim)["pos"]
	var target := Game._keep_side(_scatter_by(snapped, float(Tuning.SERVE_SCATTER[serve_kind]), q), -s, 0.8)
	var risky := serve_kind == ServeType.Kind.JUMP
	# assistência "toque BOM fica dentro": não vale para a viagem (é o risco do saque forte)
	if p.is_human and q >= Tuning.ASSIST_KEEP_IN_Q and not risky:
		target = Game.keep_inside(target)
	var to := Vector3(target.x, Tuning.BALL_RADIUS, target.z)
	var t := float(Tuning.SERVE_TIME[serve_kind])
	var grav := float(Tuning.SERVE_GRAV[serve_kind])
	var shot := Shot.new()
	shot.from = from
	shot.grav = grav
	shot.kind = Game.Act.SERVE
	shot.target = target
	# viagem mal batida não ganha o ajuste de passar a rede: pode ir na rede
	if risky and q < Tuning.ASSIST_KEEP_IN_Q:
		shot.vel = BallSim.launch_velocity(from, to, t, grav)
	else:
		shot.vel = BallSim.clear_net_velocity(from, to, t, grav)
	if serve_kind == ServeType.Kind.FLOAT:
		shot.wobble_amp = lerpf(Tuning.FLOAT_AMP.x, Tuning.FLOAT_AMP.y, q)   # saque melhor = mais oscilação
		shot.wobble_phase = rng.randf() * TAU
		_cancel_drift(shot)
	return shot


## A oscilação muda o caminho, não o destino: tira da velocidade em x o deslocamento que ela
## causaria até o pouso. Se o balanço levaria a bola para fora da antena, inverte a fase.
func _cancel_drift(shot: Shot) -> void:
	var base := shot.vel
	var t_land := BallSim.flight_time(shot.from, base, shot.grav)
	var t_net := -shot.from.z / base.z if absf(base.z) > 1e-6 else 0.0
	for flip in 2:
		var drift := BallSim.wobble_offset(shot.wobble_amp, Tuning.FLOAT_FREQ, shot.wobble_phase, t_land)
		shot.vel = Vector3(base.x - drift / t_land, base.y, base.z)
		var x_net := shot.from.x + shot.vel.x * t_net \
				+ BallSim.wobble_offset(shot.wobble_amp, Tuning.FLOAT_FREQ, shot.wobble_phase, t_net)
		if absf(x_net) <= Tuning.COURT_HALF_W - 0.2 or flip == 1:
			return
		shot.wobble_phase += PI


## Saída da bola que bateu nas mãos do bloqueio `bk`, pela qualidade do timing:
## PERFEITO = para baixo do lado do atacante; BOM = amortece e sobe do lado do bloqueador;
## ruim = desvia para fora, pela lateral mais perto.
func block_exit(from: Vector3, bk: Block, q: float) -> Shot:
	var s := bk.side
	var w := Tuning.COURT_HALF_W - 0.5
	var shot := Shot.new()
	shot.from = from
	shot.grav = Tuning.GRAVITY
	shot.kind = Game.Act.BLOCK
	if q >= 1.0:
		var dist := rng.randf_range(Tuning.BLOCK_DOWN_DIST.x, Tuning.BLOCK_DOWN_DIST.y)
		shot.target = Vector3(clampf(from.x + rng.randf_range(-1.0, 1.0), -w, w), Tuning.BALL_RADIUS, -s * dist)
		shot.vel = BallSim.launch_velocity(from, shot.target, Tuning.BLOCK_T_DOWN)
	elif q >= Tuning.ASSIST_KEEP_IN_Q:
		shot.target = Vector3(clampf(from.x, -w, w), Tuning.BALL_RADIUS, s * Tuning.BLOCK_SOFT_DIST)
		shot.vel = BallSim.clear_net_velocity(from, shot.target, Tuning.BLOCK_T_SOFT)
	else:
		var out := 1.0 if from.x >= 0.0 else -1.0
		shot.target = Vector3(out * (Tuning.COURT_HALF_W + 1.5), Tuning.BALL_RADIUS, s * rng.randf_range(1.0, 4.0))
		shot.vel = BallSim.clear_net_velocity(from, shot.target, Tuning.BLOCK_T_DEFLECT)
	return shot


## Erro de mira pela qualidade: até base·(1 − q) metros, distribuído no disco.
func scatter(target: Vector3, kind: int, q: float) -> Vector3:
	var base := Tuning.SCATTER_RECEIVE
	if kind == Game.Act.SET_BALL:
		base = Tuning.SCATTER_SET
	elif kind == Game.Act.ATTACK or kind == Game.Act.FREEBALL:
		base = Tuning.SCATTER_ATTACK
	return _scatter_by(target, base, q)


func _scatter_by(target: Vector3, base: float, q: float) -> Vector3:
	var r := base * (1.0 - q) * sqrt(rng.randf())
	var ang := rng.randf() * TAU
	return target + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
