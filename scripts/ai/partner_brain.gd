class_name PartnerBrain
extends RefCounted
## Posicionamento sem bola no 2v2, por papel. Usado pelo seu parceiro e pela dupla do bot quando
## o jogador não é o do plano (quem toca continua decidido pelo plano de contato do Game).
## Cada time tem dois lados fixos: players[0] fica à esquerda (x < 0), players[1] à direita.

enum Role { BASE, SERVE_PARTNER, RECEIVE, SETTER_PREP, ATTACKER, COVER, FRONT, DIGGER }

const SIDE_X := 1.8                 # m do meio no lado de cada um (base e defesa)
const RECEIVE_X := 2.0              # recepção lado a lado
const FRONT_Z := 2.0                # defensor da frente, fora da zona de bloqueio (só sobe se for bloquear)


static func role_of(p: Player, game: Game) -> int:
	if game.state == Game.State.SERVE_WAIT or game.state == Game.State.SERVE_TOSS:
		return Role.SERVE_PARTNER if game.server_team == p.team else Role.RECEIVE
	var plan := game.plan
	if plan != null and plan.team == p.team:
		if plan.n == 1:
			return Role.SETTER_PREP
		if plan.n == 2:
			return Role.ATTACKER
		return Role.COVER
	if plan != null or game.last_team == p.team:
		# a bola é (ou vai ser) do adversário: um na frente, um no fundo
		return Role.FRONT if _is_front(p, game) else Role.DIGGER
	return Role.BASE


## Posição desejada agora (no lado do time).
static func target_for(p: Player, game: Game) -> Vector3:
	var s := Game.side_of_team(p.team)
	var d := game.court.depth
	var lane := _lane(p, game)
	var plan := game.plan
	match role_of(p, game):
		Role.SERVE_PARTNER:
			return Vector3(-1.5 * s, 0.0, s * d * 0.45)
		Role.RECEIVE:
			return Vector3(lane * RECEIVE_X, 0.0, s * d * 0.6)
		Role.SETTER_PREP:
			return game.spot(p.team, Tuning.SETTER_SPOT)
		Role.ATTACKER:
			# corrida: um passo atrás e para o seu lado do levantamento
			return Vector3(clampf(plan.pos.x + lane, -game.court.half_w + 0.5, game.court.half_w - 0.5), 0.0, s * d * 0.45)
		Role.COVER:
			return Vector3(plan.pos.x * 0.5, 0.0, s * d * 0.35)
		Role.FRONT:
			return Vector3(_attack_x(game, p.team), 0.0, s * FRONT_Z)
		Role.DIGGER:
			# na diagonal do ataque previsto
			return Vector3(clampf(-_attack_x(game, p.team) * 0.5 + lane * 0.8, -game.court.half_w, game.court.half_w), 0.0, s * d * 0.6)
	return Vector3(lane * SIDE_X, 0.0, s * d * 0.5)


## −1 para quem fica à esquerda, +1 para quem fica à direita.
static func _lane(p: Player, game: Game) -> float:
	return -1.0 if game.teams[p.team].players[0] == p else 1.0


## O da frente na defesa: quem está mais perto da rede (empate: o da esquerda).
static func _is_front(p: Player, game: Game) -> bool:
	var mate := game.teams[p.team].other(p)
	if mate == null:
		return true
	var mine := absf(p.position.z)
	var theirs := absf(mate.position.z)
	return mine < theirs or (mine == theirs and _lane(p, game) < 0.0)


## x de onde o adversário deve atacar (o plano dele; senão, o meio).
static func _attack_x(game: Game, team: int) -> float:
	var plan := game.plan
	if plan != null and plan.team != team:
		return clampf(plan.pos.x, -game.court.half_w, game.court.half_w)
	return 0.0
