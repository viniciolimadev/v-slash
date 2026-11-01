class_name Markers
extends Node3D
## Leitura visual no chão: sombra da bola, ponto de queda, anel de timing e mira.

var game: Game
var human: Player
var colorblind := false             # anel com padrão por ação além da cor (RF-5.08)
var ring_pattern := 0               # padrão mostrado agora: 0 cheio, 1 tracejado, 2 pontilhado, 3 duplo

var _shadow: MeshInstance3D
var _land: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _approach: MeshInstance3D
var _approach_mat: StandardMaterial3D
var _reticle: MeshInstance3D
var _reticle_label: Label3D
var _magnet_labels: Array[Label3D] = []
var _magnet_dots: Array[MeshInstance3D] = []
var _hl_dot: MeshInstance3D
var _hl_label: Label3D
var _hl_name := ""
var _block_shadow: MeshInstance3D
var _stamina_bars: Array[MeshInstance3D] = []
var _patterns: Array[Mesh] = []


func setup(g: Game, h: Player) -> void:
	game = g
	human = h
	_shadow = _disk(Tuning.BALL_RADIUS * 1.3, _flat(Color(0.0, 0.0, 0.0, 0.35)))
	_land = _disk(0.1, _flat(Color(1.0, 1.0, 1.0, 0.8)))
	_ring_mat = _flat(Color(0.25, 0.85, 0.75))
	_ring = _torus(0.38, 0.48, _ring_mat)
	_outline(_ring, 0.34, 0.52)
	_patterns = [_ring.mesh, _pattern_mesh(1), _pattern_mesh(2), _pattern_mesh(3)]
	_approach_mat = _flat(Color(1.0, 1.0, 1.0, 0.9))
	_approach = _torus(0.4, 0.47, _approach_mat)
	_outline(_approach, 0.37, 0.5)
	_reticle = _torus(0.2, 0.28, _flat(Color(1.0, 0.85, 0.2)))
	_outline(_reticle, 0.17, 0.31)
	_outline(_land, 0.1, 0.16)
	_reticle_label = _label(64)
	_reticle_label.pixel_size = 0.012
	_reticle_label.modulate = Color(1.0, 0.9, 0.3)
	_reticle_label.position = Vector3(0.0, 0.7, 0.0)
	_reticle.add_child(_reticle_label)
	for _i in 6:
		var l := _label(48)
		l.pixel_size = 0.01
		l.modulate = Color(1.0, 1.0, 1.0, 0.85)
		add_child(l)
		_magnet_labels.append(l)
		# ponto no chão de cada zona de mira (o escolhido fica amarelo)
		_magnet_dots.append(_disk(0.3, _flat(Color(1.0, 1.0, 1.0, 0.45))))
	_hl_dot = _disk(0.45, _flat(Color(0.3, 1.0, 0.45, 0.7)))
	# sombra do bloqueio adversário: faixa no chão atrás das mãos dele, enquanto você mira o ataque
	_block_shadow = MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3((Tuning.BLOCK_HALF_W + Tuning.BALL_RADIUS) * 2.0, 0.01, 1.0)
	_block_shadow.mesh = strip
	_block_shadow.material_override = _flat(Color(0.1, 0.0, 0.25, 0.35))
	add_child(_block_shadow)
	for _p in game.players:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 0.07, 0.02)
		bar.mesh = bm
		bar.material_override = _flat(Color(0.3, 1.0, 0.4))
		add_child(bar)
		_stamina_bars.append(bar)
	_hl_label = _label(56)
	_hl_label.pixel_size = 0.011
	_hl_label.modulate = Color(0.4, 1.0, 0.5)
	add_child(_hl_label)
	refresh()


## Tutorial: destaca uma zona de saque/ataque pelo nome ("" apaga).
func highlight_zone(zone: String) -> void:
	_hl_name = zone


func refresh() -> void:
	if game == null:
		return
	if game.human != null:
		human = game.human          # 2v2: o controle troca de jogador
	var b := game.ball
	var flying := b.mode == Ball.Mode.FLYING

	# sombra: sempre embaixo da bola (é o que dá noção de altura)
	_shadow.position = Vector3(b.position.x, 0.015, b.position.z)
	var k := clampf(1.0 - (b.position.y - Tuning.BALL_RADIUS) * 0.07, 0.5, 1.0)
	_shadow.scale = Vector3(k, 1.0, k)

	# ponto de queda (se ninguém tocar)
	_land.visible = flying and game.state != Game.State.SERVE_TOSS
	var lv := game.land_view()
	_land.position = Vector3(lv.x, 0.02, lv.z)

	# zona destacada (tutorial)
	_hl_dot.visible = false
	_hl_label.visible = false
	if _hl_name != "":
		for m in game.aim_magnets(human, Game.Act.SERVE):
			if str(m["name"]) == _hl_name:
				var hp: Vector3 = m["pos"]
				_hl_dot.position = Vector3(hp.x, 0.025, hp.z)
				_hl_label.position = Vector3(hp.x, 0.6, hp.z)
				_hl_label.text = tr(_hl_name)
				_hl_dot.visible = true
				_hl_label.visible = true

	# anel de timing: só quando a bola é sua (ou o bloqueio: anel na rede, solte quando fechar)
	var plan := game.plan
	var act := game.current_act(human)
	var mine: bool = flying and plan != null and plan.player == human
	var block: bool = flying and act == Game.Act.BLOCK
	_ring.visible = mine or block
	_approach.visible = false
	if mine or block:
		var at := game.plan_view_pos(plan) if mine else game.block_plan.pos
		_ring.position = Vector3(at.x, 0.04, at.z)
		_ring_mat.albedo_color = _act_color(act)
		ring_pattern = pattern_for(act)
		_ring.mesh = _patterns[ring_pattern]
		var remaining := (plan.t if mine else game.block_release_t()) - game.time
		if remaining > -Tuning.WINDOW_LATE:
			_approach.visible = true
			_approach.position = _ring.position
			var sc := 1.0 + 2.2 * clampf(remaining / Tuning.RING_LEAD, 0.0, 1.0)
			_approach.scale = Vector3(sc, 1.0, sc)
			if absf(remaining) <= Tuning.PERFECT * game.window_scale():
				_approach_mat.albedo_color = Color(0.3, 1.0, 0.4)
			elif remaining < 0.0:
				_approach_mat.albedo_color = Color(1.0, 0.35, 0.3)
			else:
				_approach_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)

	_update_block_shadow(act)
	_update_stamina_bars()

	# mira (sempre visível; fica onde você deixou por último)
	var aim := game.human_aim_view()
	_reticle.visible = not aim.is_empty()
	var snapped_name := ""
	if not aim.is_empty():
		var ap: Vector3 = aim["pos"]
		_reticle.position = Vector3(ap.x, 0.05, ap.z)
		snapped_name = str(aim["name"])
		_reticle_label.text = tr(snapped_name)

	# alvos da jogada (enquanto você segura o botão)
	var show_magnets := not aim.is_empty() and game.human_aiming
	var mags := game.aim_magnets(human, game.aim_act(human)) if show_magnets else []
	# nomes só no levantamento (no resto, o nome da zona escolhida aparece na mira)
	var named := game.aim_act(human) == Game.Act.SET_BALL
	for i in _magnet_labels.size():
		var l := _magnet_labels[i]
		var dot := _magnet_dots[i]
		l.visible = false
		dot.visible = false
		if i < mags.size():
			var m: Dictionary = mags[i]
			var mp: Vector3 = m["pos"]
			var picked := str(m["name"]) == snapped_name
			l.visible = named and not picked
			l.position = Vector3(mp.x, 0.45, mp.z)
			l.text = tr(str(m["name"]))
			dot.visible = true
			dot.position = Vector3(mp.x, 0.03, mp.z)
			(dot.material_override as StandardMaterial3D).albedo_color = \
					Color(1.0, 0.85, 0.2, 0.9) if picked else Color(1.0, 1.0, 1.0, 0.45)


## Onde o bloqueio do adversário pegaria se ele pulasse agora: da bola, passando pelas mãos dele.
func _update_block_shadow(act: int) -> void:
	_block_shadow.visible = false
	if act != Game.Act.ATTACK or game.plan == null:
		return
	var foe := game.opponent_of(human.team)
	if foe == null or absf(foe.position.z) > Tuning.BLOCK_ZONE:
		return
	var from := game.plan.pos
	var hands := Vector3(foe.position.x, 0.0, -Game.side_of_team(human.team) * Tuning.BLOCK_DEPTH)
	var dir := Vector3(hands.x - from.x, 0.0, hands.z - from.z)
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var length := game.court.depth
	var mid := hands + dir * (length * 0.5)
	_block_shadow.visible = true
	_block_shadow.position = Vector3(mid.x, 0.02, mid.z)
	_block_shadow.rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)
	_block_shadow.scale = Vector3(1.0, 1.0, length)


## Barra fina sobre cada jogador (só com a stamina ligada); vermelha quando cansado.
func _update_stamina_bars() -> void:
	for i in _stamina_bars.size():
		var bar := _stamina_bars[i]
		var p := game.players[i]
		bar.visible = game.stamina_on
		if not bar.visible:
			continue
		var k := maxf(p.stamina, 0.02)
		bar.position = p.position + Vector3(0.35 * (k - 1.0), 2.25, 0.0)
		bar.scale = Vector3(k, 1.0, 1.0)
		(bar.material_override as StandardMaterial3D).albedo_color = \
				Color(1.0, 0.3, 0.25) if p.is_tired() else Color(0.3, 1.0, 0.4)


## Modo daltônico: cada ação também tem forma (cheio = receber, tracejado = levantar,
## pontilhado = atacar/largar, duplo = bloquear/peixinho). Desligado: sempre cheio.
func pattern_for(act: int) -> int:
	if not colorblind:
		return 0
	match act:
		Game.Act.SET_BALL:
			return 1
		Game.Act.ATTACK, Game.Act.DINK:
			return 2
		Game.Act.BLOCK, Game.Act.DIVE:
			return 3
	return 0


func _pattern_mesh(kind: int) -> Mesh:
	var kit := MeshKit.new()
	if kind == 1:
		for i in 10:
			var a := TAU * i / 10.0
			kit.add(MeshKit.box(Vector3(0.18, 0.03, 0.1)), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0.0, sin(a)) * 0.43),
					Color.WHITE)
	elif kind == 2:
		for i in 12:
			var a := TAU * i / 12.0
			kit.add(MeshKit.sphere(0.065, false, 6), Transform3D(Basis.IDENTITY, Vector3(cos(a), 0.0, sin(a)) * 0.43), Color.WHITE)
	else:
		for r: Vector2 in [Vector2(0.4, 0.48), Vector2(0.22, 0.29)]:
			var t := TorusMesh.new()
			t.inner_radius = r.x
			t.outer_radius = r.y
			t.rings = 32
			t.ring_segments = 6
			kit.add(t, Transform3D.IDENTITY, Color.WHITE)
	return kit.build()


func _act_color(act: int) -> Color:
	if act == Game.Act.SET_BALL:
		return Color(0.35, 0.6, 1.0)
	if act == Game.Act.ATTACK:
		return Color(1.0, 0.55, 0.2)
	if act == Game.Act.DINK:
		return Color(1.0, 0.8, 0.35)
	if act == Game.Act.FREEBALL:
		return Color(0.85, 0.85, 0.85)
	if act == Game.Act.BLOCK:
		return Color(0.75, 0.4, 1.0)
	if act == Game.Act.DIVE:
		return Color(1.0, 0.45, 0.1)
	return Color(0.25, 0.85, 0.75)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _torus(inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 48
	t.ring_segments = 8
	mi.mesh = t
	mi.material_override = mat
	add_child(mi)
	return mi


## Contorno escuro embaixo do marcador: mantém a leitura sobre a areia clara (RF-4.05).
func _outline(of: MeshInstance3D, inner: float, outer: float) -> void:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 48
	t.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = _flat(Color(0.05, 0.05, 0.1, 0.5))
	mi.position = Vector3(0.0, -0.01, 0.0)
	mi.scale = Vector3(1.0, 0.15, 1.0)  # achatado: fica por baixo do marcador, não por cima
	of.add_child(mi)


func _disk(radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.01
	mi.mesh = c
	mi.material_override = mat
	add_child(mi)
	return mi


func _label(font_size: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = font_size
	l.pixel_size = 0.006
	l.outline_size = 10
	l.no_depth_test = true
	return l
