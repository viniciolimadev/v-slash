class_name BallView
extends Node3D
## Bola na tela (ADR-09): filha da Ball, gira conforme a velocidade do último lançamento.

var ball: Ball
var mesh: MeshInstance3D

var _spin := Vector3.ZERO


func bind(b: Ball) -> void:
	ball = b
	mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Tuning.BALL_RADIUS
	sphere.height = Tuning.BALL_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.86, 0.2)
	mat.roughness = 0.6
	sphere.material = mat
	mesh.mesh = sphere
	add_child(mesh)
	# faixa azul para dar para ver o giro
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Tuning.BALL_RADIUS * 0.93
	torus.outer_radius = Tuning.BALL_RADIUS * 1.04
	torus.rings = 16
	torus.ring_segments = 6
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.12, 0.35, 0.85)
	torus.material = band_mat
	band.mesh = torus
	mesh.add_child(band)
	b.launched.connect(func(v: Vector3) -> void: _spin = Vector3(v.z, 0.0, -v.x) * 1.5)


func _process(delta: float) -> void:
	if ball != null and ball.mode != Ball.Mode.HELD:
		mesh.rotation += _spin * delta
