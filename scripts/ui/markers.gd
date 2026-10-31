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
	_reticle_label = _label(56)
	_reticle_label.position = Vector3(0.0, 0.7, 0.0)
	_reticle.add_child(_reticle_label)
	for _i in 4:
		var l := _label(36)
		l.modulate = Color(1.0, 1.0, 1.0, 0.7)
		add_child(l)
		_magnet_labels.append(l)
	refresh()


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

	# anel de timing: só quando a bola é sua
	var plan := game.plan
	var mine: bool = flying and not plan.is_empty() and plan["player"] == human
	_ring.visible = mine
	_approach.visible = false
	if mine:
		var at: Vector3 = plan["pos"]
		_ring.position = Vector3(at.x, 0.04, at.z)
		_ring_mat.albedo_color = _act_color(int(plan["act"]))
		var remaining := float(plan["t"]) - game.time
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

	# mira (enquanto você segura o botão)
	var aim := game.human_aim_view()
	_reticle.visible = not aim.is_empty()
	var snapped_name := ""
	if not aim.is_empty():
		var ap: Vector3 = aim["pos"]
		_reticle.position = Vector3(ap.x, 0.05, ap.z)
		snapped_name = str(aim["name"])
		_reticle_label.text = snapped_name

	# alvos do levantamento
	var show_magnets := not aim.is_empty() and game.current_act(human) == Game.Act.SET_BALL
	var mags := game.set_magnets(human.team) if show_magnets else []
	for i in _magnet_labels.size():
		var l := _magnet_labels[i]
		l.visible = false
		if i < mags.size():
			var m: Dictionary = mags[i]
			var mp: Vector3 = m["pos"]
			l.visible = str(m["name"]) != snapped_name
			l.position = Vector3(mp.x, 0.35, mp.z)
			l.text = str(m["name"])


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
