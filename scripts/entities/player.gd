class_name Player
extends Node3D
## Jogador: anda (joystick ou bot), pula sozinho no ataque, mergulha no peixinho e anima o toque.

var team := 0
var is_human := false
var speed := Tuning.MOVE_SPEED
var move_input := Vector2.ZERO      # -1..1; x = direita da tela, y = baixo da tela
var holding := false                # segurando o botão de ação
var serving := false                # travado atrás da linha de fundo
var magnet_on := false              # assistência: há bola para você
var magnet_point := Vector3.ZERO
var look_target := Vector3.ZERO
var vel := Vector3.ZERO
var swing_cd := 0.0
var can_dive := true                # o bot no Fácil não faz peixinho
var diving_t := 0.0                 # s que ainda faltam no chão depois do peixinho
var stamina := 1.0                  # 0..1; só vale com Game.stamina_on (Tuning.STAMINA_ENABLED)
var stamina_on := false
var court := CourtSpec.default_spec()

var _jump_t := -1.0
var _jump_target := Vector3.ZERO
var _body: Node3D
var _arms: Node3D
var _swing_tw: Tween
var _color := Color.WHITE
var _ring_full: MeshInstance3D = null
var _ring_thin: MeshInstance3D = null


func setup(p_team: int, p_human: bool, color: Color) -> void:
	team = p_team
	is_human = p_human
	_color = color
	_body = Node3D.new()
	add_child(_body)
	_body.rotation.y = 0.0 if team == 0 else PI
	var torso := CapsuleMesh.new()
	torso.radius = 0.28
	torso.height = 1.75
	_add_mesh(_body, torso, Vector3(0.0, 0.875, 0.0), color)
	var nose := BoxMesh.new()
	nose.size = Vector3(0.16, 0.1, 0.24)
	_add_mesh(_body, nose, Vector3(0.0, 1.52, -0.3), color.darkened(0.5))
	_arms = Node3D.new()
	_arms.position = Vector3(0.0, 1.38, 0.0)
	_body.add_child(_arms)
	for sx: float in [-0.36, 0.36]:
		var arm := BoxMesh.new()
		arm.size = Vector3(0.11, 0.64, 0.11)
		_add_mesh(_arms, arm, Vector3(sx, -0.32, 0.0), color.lightened(0.3))
	if is_human:
		set_ring(2, false)


## Anel no pé: 0 = nenhum, 1 = fino (seu parceiro no 2v2), 2 = cheio (quem você controla).
## pulse = pulso rápido para mostrar que o controle chegou neste jogador.
func set_ring(kind: int, pulse: bool = true) -> void:
	if _ring_full == null:
		# anel no pé para você se achar rápido
		var full := TorusMesh.new()
		full.inner_radius = 0.42
		full.outer_radius = 0.5
		_ring_full = _add_mesh(self, full, Vector3(0.0, 0.03, 0.0), _color.lightened(0.35))
		var thin := TorusMesh.new()
		thin.inner_radius = 0.46
		thin.outer_radius = 0.49
		_ring_thin = _add_mesh(self, thin, Vector3(0.0, 0.03, 0.0), _color.lightened(0.2))
	_ring_full.visible = kind == 2
	_ring_thin.visible = kind == 1
	if kind == 2 and pulse:
		_ring_full.scale = Vector3(1.6, 1.0, 1.6)
		create_tween().tween_property(_ring_full, "scale", Vector3.ONE, 0.15)


func reset_state() -> void:
	holding = false
	serving = false
	magnet_on = false
	move_input = Vector2.ZERO
	vel = Vector3.ZERO
	swing_cd = 0.0
	diving_t = 0.0
	_jump_t = -1.0
	position.y = 0.0
	if _body != null:
		_body.rotation.x = 0.0


func step(dt: float) -> void:
	swing_cd = maxf(swing_cd - dt, 0.0)
	if _jump_t >= 0.0:
		_jump_t += dt
		# no ar: corrige um pouco a posição em direção à bola (assistência)
		var to := _jump_target - position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.15:
			position += to / dist * minf(dist - 0.15, Tuning.JUMP_DRIFT * dt)
		if _jump_t >= Tuning.JUMP_TIME_UP * 2.0:
			_jump_t = -1.0
		vel = Vector3.ZERO
	elif diving_t > 0.0:
		# no chão: o embalo do mergulho acaba logo e o joystick não move até levantar
		diving_t = maxf(diving_t - dt, 0.0)
		vel = vel.move_toward(Vector3.ZERO, Tuning.ACCEL * dt)
		position += vel * dt
	else:
		var wish := Vector3(move_input.x, 0.0, move_input.y)
		if wish.length() > 1.0:
			wish = wish.normalized()
		var desired := wish * speed * (Tuning.TIRED_SPEED if is_tired() else 1.0)
		if magnet_on and wish.length() < 0.1:
			var to_m := magnet_point - position
			to_m.y = 0.0
			var dm := to_m.length()
			if dm < Tuning.MAGNET_RADIUS and dm > 0.05:
				desired = to_m / dm * minf(Tuning.MAGNET_SPEED, dm * 6.0)
		vel = vel.move_toward(desired, Tuning.ACCEL * dt)
		position += vel * dt
	_clamp_to_court()
	position.y = _jump_offset()
	if _body != null:
		_body.rotation.x = -deg_to_rad(80.0) * _dive_tilt()
	var look := look_target - position
	look.y = 0.0
	if look.length() > 0.05 and _body != null:
		var yaw := atan2(-look.x, -look.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, yaw, minf(1.0, 12.0 * dt))


## Passo rápido em direção à bola no instante do toque (disfarça o alcance assistido).
func lunge(toward: Vector3) -> void:
	if not is_grounded():
		return
	var d := Vector3(toward.x - position.x, 0.0, toward.z - position.z)
	var dist := d.length()
	if dist > 0.5:
		vel = d / dist * minf(9.0, dist * 6.0)


## Peixinho: mergulha em direção à bola e fica DIVE_RECOVER s no chão.
func dive(toward: Vector3) -> void:
	diving_t = Tuning.DIVE_RECOVER
	var d := Vector3(toward.x - position.x, 0.0, toward.z - position.z)
	var dist := d.length()
	if dist > 0.5:
		# embalo que, freando em ACCEL, cobre a distância que faltava até a bola
		vel = d / dist * minf(sqrt(2.0 * Tuning.ACCEL * (dist - 0.5)), 10.0)
	else:
		vel = Vector3.ZERO


func is_diving() -> bool:
	return diving_t > 0.0


## 0 = em pé, 1 = deitado: deita rápido e levanta no fim do tempo no chão.
func _dive_tilt() -> float:
	if diving_t <= 0.0:
		return 0.0
	var elapsed := Tuning.DIVE_RECOVER - diving_t
	return minf(clampf(elapsed / 0.12, 0.0, 1.0), clampf(diving_t / 0.3, 0.0, 1.0))


func is_tired() -> bool:
	return stamina_on and stamina < Tuning.STAMINA_TIRED


## Altura do pulo agora (cansado pula menos; o bloqueio usa a mesma conta).
func jump_height() -> float:
	return Tuning.JUMP_HEIGHT * (Tuning.TIRED_JUMP if is_tired() else 1.0)


## Gasta stamina (sem stamina a ação sai mesmo assim, só que "cansada").
func spend(cost: float) -> void:
	if stamina_on:
		stamina = maxf(stamina - cost, 0.0)


func recover(amount: float) -> void:
	if stamina_on:
		stamina = minf(stamina + amount, 1.0)


func is_grounded() -> bool:
	return _jump_t < 0.0


func start_jump(target: Vector3) -> void:
	if _jump_t >= 0.0:
		return
	_jump_t = 0.0
	_jump_target = Vector3(target.x, 0.0, target.z)


func swing(kind: int) -> void:
	if _arms == null:
		return
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
	pop.tween_property(_body, "scale", Vector3(1.12, 0.92, 1.12), 0.05)
	pop.tween_property(_body, "scale", Vector3.ONE, 0.18)


func _clamp_to_court() -> void:
	var s := 1.0 if team == 0 else -1.0
	var w := court.half_w
	var d := court.depth
	if serving:
		position.z = s * (d + court.serve_back)
		position.x = clampf(position.x, -w + 0.3, w - 0.3)
		return
	position.x = clampf(position.x, -w - 2.5, w + 2.5)
	if team == 0:
		position.z = clampf(position.z, 0.35, d + 3.0)
	else:
		position.z = clampf(position.z, -d - 3.0, -0.35)


func _jump_offset() -> float:
	if _jump_t < 0.0:
		return 0.0
	var u := clampf(_jump_t / (Tuning.JUMP_TIME_UP * 2.0), 0.0, 1.0)
	return 4.0 * jump_height() * u * (1.0 - u)


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
	return mi
