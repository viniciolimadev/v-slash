class_name PlayerView
extends Node3D
## Base das views do jogador (ADR-09): filha do Player, só observa a lógica.
## A posição vem do pai; aqui ficam o anel no pé e o giro do corpo para a bola.
## As filhas montam o corpo em _build() e animam em _on_swung()/_animate().

var player: Player
var game: Game
var body: Node3D                    # gira para a bola; o modelo fica pendurado aqui

var _ring_full: MeshInstance3D
var _ring_thin: MeshInstance3D


func bind(p: Player, g: Game) -> void:
	player = p
	game = g
	body = Node3D.new()
	add_child(body)
	body.rotation.y = 0.0 if p.team == 0 else PI
	_build()
	# anel no pé para você se achar rápido
	var full := TorusMesh.new()
	full.inner_radius = 0.42
	full.outer_radius = 0.5
	_ring_full = add_mesh(self, full, Vector3(0.0, 0.03, 0.0), p.color.lightened(0.35))
	var thin := TorusMesh.new()
	thin.inner_radius = 0.46
	thin.outer_radius = 0.49
	_ring_thin = add_mesh(self, thin, Vector3(0.0, 0.03, 0.0), p.color.lightened(0.2))
	_on_ring(p.ring_kind, false)
	p.ring_changed.connect(_on_ring)
	p.swung.connect(_on_swung)


func _process(delta: float) -> void:
	if player == null:
		return
	var look := player.look_target - player.position
	look.y = 0.0
	if look.length() > 0.05:
		var yaw := atan2(-look.x, -look.z)
		body.rotation.y = lerp_angle(body.rotation.y, yaw, minf(1.0, 12.0 * delta))
	_animate(delta)


func _build() -> void:
	pass


func _on_swung(_kind: int, _contact_t: float) -> void:
	pass


func _animate(_delta: float) -> void:
	pass


func _on_ring(kind: int, pulse: bool) -> void:
	_ring_full.visible = kind == 2
	_ring_thin.visible = kind == 1
	if kind == 2 and pulse:
		_ring_full.scale = Vector3(1.6, 1.0, 1.6)
		create_tween().tween_property(_ring_full, "scale", Vector3.ONE, 0.15)


static func add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
	return mi
