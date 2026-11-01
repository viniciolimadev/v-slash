class_name Ball
extends Node3D
## A bola que aparece na tela. Quem calcula a física é o BallSim.

enum Mode { HELD, FLYING, DEAD }

var sim := BallSim.new()
var mode: int = Mode.HELD
var holder: Node3D = null
var court := CourtSpec.default_spec()   # passada a cada BallSim novo

var _mesh: MeshInstance3D
var _dead_vel := Vector3.ZERO
var _spin := Vector3.ZERO


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.BALL_RADIUS
	sphere.height = Tuning.BALL_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.86, 0.2)
	mat.roughness = 0.6
	sphere.material = mat
	_mesh.mesh = sphere
	add_child(_mesh)
	# faixa azul para dar para ver o giro
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Tuning.BALL_RADIUS * 0.93
	torus.outer_radius = Tuning.BALL_RADIUS * 1.04
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.12, 0.35, 0.85)
	torus.material = band_mat
	band.mesh = torus
	_mesh.add_child(band)


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
	_spin = Vector3(velocity.z, 0.0, -velocity.x) * 1.5


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
	if _mesh != null and mode != Mode.HELD:
		_mesh.rotation += _spin * dt
	return events


func _follow_holder() -> void:
	if holder != null:
		position = holder.position + Vector3(0.3, 1.0, 0.0)
