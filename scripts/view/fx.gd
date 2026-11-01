class_name Fx
extends Node3D
## Efeitos da partida (RF-4.06): rastro da cortada e do saque viagem, areia quando a bola cai
## e no peixinho, brilho no chão no toque PERFEITO e tremor de câmera no ataque forte.
## Só observa os sinais do Game.

const TRAIL_LEN := 14               # posições guardadas do rastro (≈ 0,23 s a 60 fps)

var game: Game
var camera_fx: CameraFx
var trail_on := false
var bursts := 0                     # quantos brilhos de PERFEITO já saíram (testes)

var _trail: MeshInstance3D
var _im: ImmediateMesh
var _points: Array[Vector3] = []
var _sand: Array[CPUParticles3D] = []
var _sand_next := 0
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _glow_tw: Tween


func bind(g: Game, cam: Camera3D) -> void:
	game = g
	camera_fx = CameraFx.new(cam)
	add_child(camera_fx)
	_im = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _im
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.vertex_color_use_as_albedo = true
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = tm
	add_child(_trail)
	for _i in 3:
		_sand.append(_make_sand())
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Color(0.5, 1.0, 0.6, 0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.45
	ring.outer_radius = 0.6
	ring.rings = 32
	ring.ring_segments = 4
	_glow = MeshInstance3D.new()
	_glow.mesh = ring
	_glow.material_override = _glow_mat
	_glow.visible = false
	add_child(_glow)
	g.touch_made.connect(_on_touch)
	g.ball_event.connect(_on_ball_event)
	g.action_used.connect(func(p: Player, act: int) -> void:
		if act == Game.Act.DIVE:
			sand_at(p.position, 0.8))


func _process(_delta: float) -> void:
	var b := game.ball
	if trail_on and b.mode == Ball.Mode.FLYING:
		_points.push_front(b.position)
		if _points.size() > TRAIL_LEN:
			_points.pop_back()
	elif not _points.is_empty():
		_points.pop_back()              # some aos poucos quando o rastro desliga
		trail_on = false
	_draw_trail()


func _on_touch(p: Player, _grade: String, q: float) -> void:
	var kind := game.last_kind
	var jump_serve := kind == Game.Act.SERVE and game.serve_type[p.team] == ServeType.Kind.JUMP
	trail_on = kind == Game.Act.ATTACK or jump_serve
	_points.clear()
	if trail_on:
		var speed := game.ball.sim.vel.length() / Tuning.ATTACK_SPEED_MAX
		camera_fx.shake(speed * q)
	if q >= 1.0 and kind != Game.Act.SERVE:
		_perfect_glow(p.position)


func _on_ball_event(kind: int, pos: Vector3) -> void:
	if kind == BallSim.Ev.LAND:
		sand_at(pos, 1.0)
		trail_on = false


## Nuvem de areia no chão (pool de emissores: eventos seguidos não cortam o anterior).
func sand_at(pos: Vector3, amount: float) -> void:
	var e := _sand[_sand_next]
	_sand_next = (_sand_next + 1) % _sand.size()
	e.position = Vector3(pos.x, 0.05, pos.z)
	e.initial_velocity_max = 2.6 * clampf(amount, 0.5, 1.0)
	e.restart()


func _perfect_glow(at: Vector3) -> void:
	bursts += 1
	_glow.visible = true
	_glow.position = Vector3(at.x, 0.06, at.z)
	_glow.scale = Vector3.ONE * 0.6
	_glow_mat.albedo_color = Color(0.5, 1.0, 0.6, 0.9)
	if _glow_tw != null and _glow_tw.is_valid():
		_glow_tw.kill()
	_glow_tw = create_tween().set_parallel()
	_glow_tw.tween_property(_glow, "scale", Vector3(2.2, 1.0, 2.2), 0.35).set_ease(Tween.EASE_OUT)
	_glow_tw.tween_property(_glow_mat, "albedo_color:a", 0.0, 0.35)
	_glow_tw.chain().tween_callback(func() -> void: _glow.visible = false)


## Fita virada para a câmera atrás da bola, afinando e sumindo na ponta.
func _draw_trail() -> void:
	_im.clear_surfaces()
	if _points.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3(0.0, 14.0, 21.0)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _points.size():
		var p := _points[i]
		var nxt := _points[mini(i + 1, _points.size() - 1)]
		var prv := _points[maxi(i - 1, 0)]
		var dir := (prv - nxt).normalized()
		var side := dir.cross(eye - p).normalized()
		var k := 1.0 - float(i) / float(_points.size() - 1)
		var half := Tuning.BALL_RADIUS * 0.9 * k
		var c := Color(1.0, 0.95, 0.75, 0.75 * k)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p + side * half)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p - side * half)
	_im.surface_end()


func _make_sand() -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.emitting = false
	e.one_shot = true
	e.amount = 18
	e.lifetime = 0.6
	e.explosiveness = 0.95
	e.direction = Vector3.UP
	e.spread = 60.0
	e.initial_velocity_min = 1.2
	e.initial_velocity_max = 2.6
	e.gravity = Vector3(0.0, -9.0, 0.0)
	e.scale_amount_min = 0.6
	e.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.85, 0.74, 0.55)
	q.material = m
	e.mesh = q
	add_child(e)
	return e
