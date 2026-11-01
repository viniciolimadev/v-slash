class_name BallSim
extends RefCounted
## Física determinística da bola: parábola exata + rede + chão.
## A bola real e o preditor (anel, ponto de queda, bot) usam a MESMA função,
## então o marcador mostra exatamente onde a bola vai estar.
## Saque flutuante: oscilação lateral analítica em x (wobble), somada à parábola.
## Bloqueio: as mãos (Block) são conhecidas desde o começo do pulo; bater nelas para a bola
## (evento BLOCK) e o Game decide a saída, como faz com o ponto.

enum Ev { CROSS, NET, ANTENNA, LAND, BLOCK }

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var g := Tuning.GRAVITY             # gravidade deste voo (a cortada usa mais: efeito topspin)
var landed := false
var net_hits := 0
var age := 0.0                      # s desde o lançamento
var wobble_amp := 0.0               # m (0 = bola normal)
var wobble_freq := 0.0              # rad/s
var wobble_phase := 0.0
var clock := 0.0                    # relógio do Game (os bloqueios são marcados nele)
var blocks: Array[Block] = []
var stopped := false                # parada nas mãos do bloqueio, esperando o Game relançar
var court := CourtSpec.default_spec()   # antenas e comprimento da rede


func copy() -> BallSim:
	var b := BallSim.new()
	b.pos = pos
	b.vel = vel
	b.g = g
	b.landed = landed
	b.net_hits = net_hits
	b.age = age
	b.wobble_amp = wobble_amp
	b.wobble_freq = wobble_freq
	b.wobble_phase = wobble_phase
	b.clock = clock
	b.blocks = blocks.duplicate()
	b.stopped = stopped
	b.court = court
	return b


func set_wobble(amp: float, freq: float, phase: float) -> void:
	wobble_amp = amp
	wobble_freq = freq
	wobble_phase = phase


## Deslocamento em x que a oscilação causa entre o lançamento e o instante t.
static func wobble_offset(amp: float, freq: float, phase: float, t: float) -> float:
	return amp * (sin(freq * t + phase) - sin(phase))


## Tempo de voo de p0 até o centro da bola chegar ao chão (sem rede).
static func flight_time(p0: Vector3, v0: Vector3, grav: float = Tuning.GRAVITY) -> float:
	var b := BallSim.new()
	b.pos = p0
	b.vel = v0
	b.g = grav
	return b._time_to_height(Tuning.BALL_RADIUS)


## Velocidade inicial para sair de p0 e passar por p1 depois de t segundos.
static func launch_velocity(p0: Vector3, p1: Vector3, t: float, grav: float = Tuning.GRAVITY) -> Vector3:
	var v := (p1 - p0) / t
	v.y = (p1.y - p0.y) / t + 0.5 * grav * t
	return v


static func pos_at(p0: Vector3, v0: Vector3, t: float, grav: float = Tuning.GRAVITY) -> Vector3:
	return p0 + v0 * t + Vector3(0.0, -0.5 * grav * t * t, 0.0)


## Altura do centro da bola ao cruzar o plano da rede (INF se não cruza).
static func height_at_net(p0: Vector3, v0: Vector3, grav: float = Tuning.GRAVITY) -> float:
	return height_at_z(p0, v0, 0.0, grav)


## Altura do centro da bola ao cruzar o plano z (INF se não cruza).
static func height_at_z(p0: Vector3, v0: Vector3, z: float, grav: float = Tuning.GRAVITY) -> float:
	if absf(v0.z) < 1e-6:
		return INF
	var t := (z - p0.z) / v0.z
	if t <= 0.0:
		return INF
	return pos_at(p0, v0, t, grav).y


## Aumenta o tempo de voo até a bola passar acima da rede com folga.
## (Mirar curto perto da rede vira "largada" sozinho.)
static func clear_net_velocity(from: Vector3, to: Vector3, t0: float, grav: float = Tuning.GRAVITY) -> Vector3:
	var t := maxf(t0, 0.05)
	var v := launch_velocity(from, to, t, grav)
	if signf(from.z) == signf(to.z):
		return v
	var need := Tuning.NET_HEIGHT + Tuning.BALL_RADIUS + Tuning.NET_CLEARANCE
	for _i in 40:
		if height_at_net(from, v, grav) >= need:
			break
		t *= 1.07
		v = launch_velocity(from, to, t, grav)
	return v


## Avança dt segundos. Retorna os eventos em ordem: [{"type": Ev, "pos": Vector3}]
## (o BLOCK traz também "block": Block).
func advance(dt: float) -> Array:
	var events: Array = []
	var remaining := dt
	var guard := 0
	while remaining > 1e-9 and not landed and not stopped and guard < 8:
		guard += 1
		var t_cross := INF
		if absf(vel.z) > 1e-6:
			var tc := -pos.z / vel.z
			if tc >= 0.0 and tc <= remaining:     # >= 0: pega também a bola parada exatamente no plano
				t_cross = tc
		var t_floor := _time_to_height(Tuning.BALL_RADIUS)
		if t_floor > remaining:
			t_floor = INF
		var t_block := INF
		var hit_block: Block = null
		for bk in blocks:
			if vel.z * bk.side <= 0.0:
				continue            # só a bola indo para o lado do bloqueador
			var tb := (bk.plane_z() - pos.z) / vel.z
			if tb < 0.0 or tb > remaining or tb >= t_block:
				continue
			if bk.catches(pos_after(tb), clock + tb):
				t_block = tb
				hit_block = bk
		if t_cross == INF and t_floor == INF and t_block == INF:
			_move(remaining)
			break
		if t_block <= t_cross and t_block < t_floor:
			_move(t_block)
			vel = Vector3.ZERO
			stopped = true
			events.append({"type": Ev.BLOCK, "pos": pos, "block": hit_block})
			break
		if t_floor <= t_cross:
			_move(t_floor)
			pos.y = Tuning.BALL_RADIUS
			landed = true
			events.append({"type": Ev.LAND, "pos": pos})
			break
		_move(t_cross)
		remaining -= t_cross
		pos.z = 0.0
		if absf(pos.x) <= court.net_half_len and pos.y < Tuning.NET_HEIGHT + Tuning.BALL_RADIUS:
			# bateu na rede: volta para o lado de quem tocou
			net_hits += 1
			var from_side := -signf(vel.z)
			pos.z = from_side * (Tuning.BALL_RADIUS + 0.01)
			vel = Vector3(vel.x * 0.5, minf(vel.y, 0.0) * 0.5, -vel.z * Tuning.NET_BOUNCE)
			wobble_amp = 0.0        # bola morta na rede não flutua mais
			events.append({"type": Ev.NET, "pos": pos})
		else:
			var outside := absf(pos.x) > court.half_w + Tuning.BALL_RADIUS
			events.append({"type": Ev.ANTENNA if outside else Ev.CROSS, "pos": pos})
			pos.z = signf(vel.z) * 1e-4
	return events


## Simula sem mexer na bola real. Amostras a cada `step` segundos até cair.
func predict(max_t: float = 6.0, step: float = 1.0 / 120.0) -> Dictionary:
	var sim := copy()
	var pts := PackedVector3Array([sim.pos])
	var times := PackedFloat64Array([0.0])
	var t := 0.0
	while t < max_t and not sim.landed and not sim.stopped:
		sim.advance(step)
		t += step
		pts.append(sim.pos)
		times.append(t)
	return {"points": pts, "times": times, "land": sim.pos, "landed": sim.landed, "blocked": sim.stopped}


## Primeiro instante (relativo) em que a bola DESCE pela altura h no lado `side` (+1/-1).
## Retorna {"t": float, "pos": Vector3} ou {} se isso não acontece.
static func find_descent(pred: Dictionary, h: float, side: float) -> Dictionary:
	var pts: PackedVector3Array = pred["points"]
	var times: PackedFloat64Array = pred["times"]
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		if a.y >= h and b.y < h and signf(b.z) == side:
			var f := (a.y - h) / (a.y - b.y)
			return {"t": lerpf(times[i - 1], times[i], f), "pos": a.lerp(b, f)}
	return {}


## Posição daqui a t segundos, sem mexer na bola (sem rede nem chão).
func pos_after(t: float) -> Vector3:
	var p := pos + (vel * t + Vector3(0.0, -0.5 * g * t * t, 0.0))
	if wobble_amp != 0.0:
		# termo exato (não integrado): o preditor com outro passo dá o mesmo x
		p.x += wobble_amp * (sin(wobble_freq * (age + t) + wobble_phase) - sin(wobble_freq * age + wobble_phase))
	return p


func _move(t: float) -> void:
	pos = pos_after(t)
	vel.y -= g * t
	age += t
	clock += t


## Tempo até o centro da bola descer até a altura h (INF se nunca).
func _time_to_height(h: float) -> float:
	if pos.y <= h and vel.y <= 0.0:
		return 0.0
	var disc := vel.y * vel.y + 2.0 * g * (pos.y - h)
	if disc < 0.0:
		return INF
	var t := (vel.y + sqrt(disc)) / g
	return t if t > 0.0 else INF
