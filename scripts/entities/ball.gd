class_name Ball
extends Node3D
## A bola em jogo (posição e modo). Quem calcula a física é o BallSim; quem desenha é a BallView.

signal launched(velocity: Vector3)

enum Mode { HELD, FLYING, DEAD }

var sim := BallSim.new()
var mode: int = Mode.HELD
var holder: Node3D = null
var court := CourtSpec.default_spec()   # passada a cada BallSim novo

var _dead_vel := Vector3.ZERO


func hold(by: Node3D) -> void:
	holder = by
	mode = Mode.HELD
	sim = BallSim.new()
	sim.court = court
	_follow_holder()


func launch(from: Vector3, velocity: Vector3, grav: float = Tuning.GRAVITY) -> void:
	holder = null
	mode = Mode.FLYING
	sim = BallSim.new()
	sim.court = court
	sim.pos = from
	sim.vel = velocity
	sim.g = grav
	position = from
	launched.emit(velocity)


## Avança a bola e devolve os eventos da física (rede, antena, chão).
func step(dt: float) -> Array:
	var events: Array = []
	if mode == Mode.HELD:
		_follow_holder()
	elif mode == Mode.FLYING:
		events = sim.advance(dt)
		position = sim.pos
		if sim.landed:
			mode = Mode.DEAD
			_dead_vel = Vector3(sim.vel.x * 0.5, absf(sim.vel.y) * Tuning.FLOOR_BOUNCE, sim.vel.z * 0.5)
	else:
		# quiques só visuais depois do ponto
		_dead_vel.y -= Tuning.GRAVITY * dt
		position += _dead_vel * dt
		if position.y < Tuning.BALL_RADIUS:
			position.y = Tuning.BALL_RADIUS
			_dead_vel = Vector3(_dead_vel.x * 0.7, absf(_dead_vel.y) * Tuning.FLOOR_BOUNCE, _dead_vel.z * 0.7)
			if _dead_vel.y < 0.4:
				_dead_vel.y = 0.0
	return events


func _follow_holder() -> void:
	if holder != null:
		position = holder.position + Vector3(0.3, 1.0, 0.0)
