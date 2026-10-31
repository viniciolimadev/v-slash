class_name Markers
extends Node3D
## Leitura visual no chão: sombra da bola, ponto de queda, anel de timing e mira.

var game: Game
var human: Player

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


func setup(g: Game, h: Player) -> void:
	game = g
	human = h
	_shadow = _disk(Tuning.BALL_RADIUS * 1.3, _flat(Color(0.0, 0.0, 0.0, 0.35)))
	_land = _disk(0.1, _flat(Color(1.0, 1.0, 1.0, 0.8)))
	_ring_mat = _flat(Color(0.25, 0.85, 0.75))
	_ring = _torus(0.38, 0.48, _ring_mat)
	_approach_mat = _flat(Color(1.0, 1.0, 1.0, 0.9))
	_approach = _torus(0.4, 0.47, _approach_mat)
	_reticle = _torus(0.2, 0.28, _flat(Color(1.0, 0.85, 0.2)))
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
	var b := game.ball
	var flying := b.mode == Ball.Mode.FLYING

	# sombra: sempre embaixo da bola (é o que dá noção de altura)
	_shadow.position = Vector3(b.position.x, 0.015, b.position.z)
	var k := clampf(1.0 - (b.position.y - Tuning.BALL_RADIUS) * 0.07, 0.5, 1.0)
	_shadow.scale = Vector3(k, 1.0, k)

	# ponto de queda (se ninguém tocar)
	_land.visible = flying
	_land.position = Vector3(game.land_point.x, 0.02, game.land_point.z)

	# zona destacada (tutorial)
	_hl_dot.visible = false
	_hl_label.visible = false
	if _hl_name != "":
		for m in game.aim_magnets(human, Game.Act.SERVE):
			if str(m["name"]) == _hl_name:
				var hp: Vector3 = m["pos"]
				_hl_dot.position = Vector3(hp.x, 0.025, hp.z)
				_hl_label.position = Vector3(hp.x, 0.6, hp.z)
				_hl_label.text = _hl_name
				_hl_dot.visible = true
				_hl_label.visible = true

	# anel de timing: só quando a bola é sua
	var plan := game.plan
	var mine: bool = flying and plan != null and plan.player == human
	_ring.visible = mine
	_approach.visible = false
	if mine:
		var at := plan.pos
		_ring.position = Vector3(at.x, 0.04, at.z)
		_ring_mat.albedo_color = _act_color(plan.act)
		var remaining := plan.t - game.time
		if remaining > -Tuning.WINDOW_LATE:
			_approach.visible = true
			_approach.position = _ring.position
			var sc := 1.0 + 2.2 * clampf(remaining / Tuning.RING_LEAD, 0.0, 1.0)
			_approach.scale = Vector3(sc, 1.0, sc)
			if absf(remaining) <= Tuning.PERFECT:
				_approach_mat.albedo_color = Color(0.3, 1.0, 0.4)
			elif remaining < 0.0:
				_approach_mat.albedo_color = Color(1.0, 0.35, 0.3)
			else:
				_approach_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)

	# mira (sempre visível; fica onde você deixou por último)
	var aim := game.human_aim_view()
	_reticle.visible = not aim.is_empty()
	var snapped_name := ""
	if not aim.is_empty():
		var ap: Vector3 = aim["pos"]
		_reticle.position = Vector3(ap.x, 0.05, ap.z)
		snapped_name = str(aim["name"])
		_reticle_label.text = snapped_name

	# alvos da jogada (enquanto você segura o botão)
	var show_magnets := not aim.is_empty() and game.human_aiming
	var mags := game.aim_magnets(human, game.current_act(human)) if show_magnets else []
	# nomes só no levantamento (no resto, o nome da zona escolhida aparece na mira)
	var named := game.current_act(human) == Game.Act.SET_BALL
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
			l.text = str(m["name"])
			dot.visible = true
			dot.position = Vector3(mp.x, 0.03, mp.z)
			(dot.material_override as StandardMaterial3D).albedo_color = \
					Color(1.0, 0.85, 0.2, 0.9) if picked else Color(1.0, 1.0, 1.0, 0.45)


func _act_color(act: int) -> Color:
	if act == Game.Act.SET_BALL:
		return Color(0.35, 0.6, 1.0)
	if act == Game.Act.ATTACK:
		return Color(1.0, 0.55, 0.2)
	if act == Game.Act.FREEBALL:
		return Color(0.85, 0.85, 0.85)
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
