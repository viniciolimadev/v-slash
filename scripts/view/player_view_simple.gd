class_name PlayerViewSimple
extends PlayerView
## Jogador com formas simples (o visual das Fases 0–3): cápsula, "nariz" e braços que giram no toque.
## Fica como alternativa leve ao modelo (Tuning.USE_MODEL_VIEWS = false).

var _arms: Node3D
var _swing_tw: Tween


func _build() -> void:
	var torso := CapsuleMesh.new()
	torso.radius = 0.28
	torso.height = 1.75
	add_mesh(body, torso, Vector3(0.0, 0.875, 0.0), player.color)
	var nose := BoxMesh.new()
	nose.size = Vector3(0.16, 0.1, 0.24)
	add_mesh(body, nose, Vector3(0.0, 1.52, -0.3), player.color.darkened(0.5))
	_arms = Node3D.new()
	_arms.position = Vector3(0.0, 1.38, 0.0)
	body.add_child(_arms)
	for sx: float in [-0.36, 0.36]:
		var arm := BoxMesh.new()
		arm.size = Vector3(0.11, 0.64, 0.11)
		add_mesh(_arms, arm, Vector3(sx, -0.32, 0.0), player.color.lightened(0.3))


func _animate(_delta: float) -> void:
	body.rotation.x = -deg_to_rad(80.0) * player.dive_tilt()


func _on_swung(kind: int, _contact_t: float) -> void:
	if _swing_tw != null and _swing_tw.is_valid():
		_swing_tw.kill()
	_swing_tw = create_tween()
	var peak := 1.2                         # manchete: braços à frente
	if kind == Game.Act.SET_BALL or kind == Game.Act.BLOCK or kind == Game.Act.DINK:
		peak = 2.9                          # toque, bloqueio e largada: braços para cima
	elif kind == Game.Act.ATTACK:
		_arms.rotation.x = 3.0
		peak = 0.5                          # cortada: de cima para baixo
	elif kind == Game.Act.SERVE:
		peak = 1.7
	_swing_tw.tween_property(_arms, "rotation:x", peak, 0.07)
	_swing_tw.tween_property(_arms, "rotation:x", 0.0, 0.3).set_delay(0.08)
	var pop := create_tween()
	pop.tween_property(body, "scale", Vector3(1.12, 0.92, 1.12), 0.05)
	pop.tween_property(body, "scale", Vector3.ONE, 0.18)
