class_name CourtView
extends Node3D
## Quadra de praia (RF-4.04): areia com luz "assada" nas cores dos vértices, linhas, rede com postes
## e antenas, mar ao fundo, coqueiros, guarda-sóis e torcida em quads. Poucas chamadas de desenho:
## cada grupo de peças estáticas vira uma malha só (MeshKit).
## A torcida pula quando o rally fica longo e no ponto (react()).

const SAND := Color(0.84, 0.73, 0.53)
const SAND_COURT := Color(0.8, 0.68, 0.48)
const SEA := Color(0.1, 0.55, 0.62)             # sem azul "de camisa": o e2e acha o jogador pela cor
const SHORE_Z := -24.0                           # m: onde a areia encontra o mar (fundo da tela)
const SHIRTS := [Color(0.9, 0.25, 0.2), Color(0.98, 0.8, 0.2), Color(0.95, 0.95, 0.92), Color(0.3, 0.7, 0.3),
		Color(0.95, 0.5, 0.65), Color(0.6, 0.35, 0.75)]

var spec := CourtSpec.default_spec()    # defina antes de entrar na árvore
var crowd_count := 0
var tris := 0

var _crowd: Array[MultiMeshInstance3D] = []
var _crowd_base: Array = []             # por grupo: Array[Transform3D] de cada pessoa
var _jump_t := 0.0                      # s restantes de pulo da torcida
var _excite := 0.0                      # 0..1: torcida agitada (rally longo)
var _foam: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	_ground()
	_court()
	_net()
	_sea()
	_props()
	_stands()


func _process(delta: float) -> void:
	_time += delta
	_foam.position.z = SHORE_Z + 0.5 + 0.35 * sin(_time * 0.8)
	_jump_t = maxf(_jump_t - delta, 0.0)
	for g in _crowd.size():
		var mm := _crowd[g].multimesh
		var base: Array = _crowd_base[g]
		for i in base.size():
			var t: Transform3D = base[i]
			var ph := float(i) * 1.7 + float(g)
			var hop := 0.0
			if _jump_t > 0.0:
				hop = absf(sin(_time * 9.0 + ph)) * 0.35
			elif _excite > 0.0:
				hop = absf(sin(_time * 5.0 + ph)) * 0.12 * _excite
			mm.set_instance_transform(i, t.translated(Vector3(0.0, hop, 0.0)))


## excite 0..1 = agitação contínua (rally); jump = comemoração do ponto (s).
func react(excite: float, jump := 0.0) -> void:
	_excite = clampf(excite, 0.0, 1.0)
	_jump_t = maxf(_jump_t, jump)


func _ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.06
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := 2.0
	var n := 40
	var x0 := -n * cell * 0.5
	var z_end := 46.0
	var rows := int((z_end - SHORE_Z) / cell)
	for iz in rows:
		for ix in n:
			var quad := [Vector2(ix, iz), Vector2(ix + 1, iz), Vector2(ix + 1, iz + 1), Vector2(ix, iz), Vector2(ix + 1, iz + 1), Vector2(ix, iz + 1)]
			for q: Vector2 in quad:
				var x := x0 + q.x * cell
				var z := SHORE_Z + q.y * cell
				var c := SAND.darkened(0.06 * noise.get_noise_2d(x, z) + 0.03)
				# areia molhada perto do mar
				c = c.lerp(Color(0.62, 0.53, 0.38), clampf(1.0 - (z - SHORE_Z) / 4.0, 0.0, 1.0))
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(x, -0.02, z))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := MeshKit.vertex_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	tris += n * rows * 2


func _court() -> void:
	var w := spec.half_w
	var d := spec.depth
	var kit := MeshKit.new()
	# areia rastelada da quadra (um pouco mais escura que a de fora)
	kit.add(MeshKit.box(Vector3(w * 2.0, 0.02, d * 2.0)), _at(Vector3(0.0, -0.012, 0.0)), SAND_COURT)
	# linhas (fazem parte da quadra: bola na linha = dentro); fita branca
	var lc := Color(0.98, 0.98, 0.96)
	var lw := 0.08
	for sx: float in [-1.0, 1.0]:
		kit.add(MeshKit.box(Vector3(lw, 0.012, d * 2.0 + lw)), _at(Vector3(sx * w, 0.004, 0.0)), lc)
		kit.add(MeshKit.box(Vector3(w * 2.0 + lw, 0.012, lw)), _at(Vector3(0.0, 0.004, sx * d)), lc)
	kit.add(MeshKit.box(Vector3(w * 2.0, 0.012, lw)), _at(Vector3(0.0, 0.004, 0.0)), lc.darkened(0.08))
	_add(kit)


func _net() -> void:
	var nh := Tuning.NET_HEIGHT
	var nl := spec.net_half_len
	var w := spec.half_w
	var kit := MeshKit.new()
	kit.add(MeshKit.box(Vector3(nl * 2.0, 0.07, 0.05)), _at(Vector3(0.0, nh - 0.035, 0.0)), Color(0.98, 0.98, 0.98))
	kit.add(MeshKit.box(Vector3(nl * 2.0, 0.05, 0.04)), _at(Vector3(0.0, nh - 1.0, 0.0)), Color(0.15, 0.2, 0.35))
	for sx: float in [-1.0, 1.0]:
		var px := sx * (nl + 0.15)
		kit.add(MeshKit.cyl(0.07, 0.07, nh + 0.2), _at(Vector3(px, (nh + 0.2) * 0.5, 0.0)), Color(0.55, 0.57, 0.6))
		# protetor do poste
		kit.add(MeshKit.cyl(0.13, 0.13, 1.6, 8), _at(Vector3(px, 0.8, 0.0)), Color(0.95, 0.75, 0.15))
		# cabo até a areia
		var top := Vector3(px, nh, 0.0)
		var peg := Vector3(px + sx * 1.6, 0.0, 0.0)
		var mid := (top + peg) * 0.5
		var cable := Transform3D(Basis(Vector3.FORWARD, -sx * atan2(1.6, nh)), mid)
		kit.add(MeshKit.cyl(0.012, 0.012, top.distance_to(peg), 4), cable, Color(0.3, 0.3, 0.3))
		# antena listrada (vermelho/branco) em cima da linha lateral
		for k in 8:
			var c := Color(0.92, 0.15, 0.15) if k % 2 == 0 else Color(0.98, 0.98, 0.98)
			kit.add(MeshKit.cyl(0.022, 0.022, 0.225, 6), _at(Vector3(sx * w, nh - 0.1 - 0.9 + 0.1125 + k * 0.225, 0.0)), c)
	_add(kit)
	# malha da rede: quadradinhos numa textura gerada, recortada por alfa
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 32:
		for j in [0, 1]:
			img.set_pixel(i, j, Color(0.08, 0.08, 0.1, 1.0))
			img.set_pixel(j, i, Color(0.08, 0.08, 0.1, 1.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.uv1_scale = Vector3(nl * 2.0 / 0.1, 1.0 / 0.1, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(nl * 2.0, 1.0)
	var net := MeshInstance3D.new()
	net.mesh = quad
	net.material_override = mat
	net.position = Vector3(0.0, nh - 0.5, 0.0)
	add_child(net)
	tris += 2


func _sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(260.0, 120.0)
	sea.mesh = plane
	sea.position = Vector3(0.0, -0.06, SHORE_Z - 60.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SEA
	sea.material_override = mat
	add_child(sea)
	_foam = MeshInstance3D.new()
	var strip := PlaneMesh.new()
	strip.size = Vector2(260.0, 1.2)
	_foam.mesh = strip
	_foam.position = Vector3(0.0, -0.04, SHORE_Z + 0.5)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.9, 0.96, 0.95, 0.85)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam.material_override = fm
	add_child(_foam)
	tris += 4


## Coqueiros, guarda-sóis e cadeira do árbitro: uma malha só.
func _props() -> void:
	var w := spec.half_w
	var d := spec.depth
	var kit := MeshKit.new()
	for p: Vector3 in [Vector3(-w - 11.0, 0.0, -d - 4.0), Vector3(w + 12.0, 0.0, -d - 2.0),
			Vector3(-w - 13.0, 0.0, 4.0), Vector3(w + 13.0, 0.0, 8.0), Vector3(-w - 6.0, 0.0, -d - 9.0)]:
		_palm(kit, p, p.x * 0.37)
	var umb := [Color(0.95, 0.3, 0.25), Color(1.0, 0.85, 0.25), Color(0.25, 0.75, 0.45), Color(0.98, 0.55, 0.2)]
	var spots := [Vector3(-w - 4.0, 0.0, -d - 5.0), Vector3(-1.5, 0.0, -d - 6.5), Vector3(2.5, 0.0, -d - 5.5),
			Vector3(w + 5.0, 0.0, -d - 6.0), Vector3(w + 9.0, 0.0, -d - 10.0), Vector3(-w - 9.0, 0.0, -d - 12.0)]
	for i in spots.size():
		var at: Vector3 = spots[i]
		kit.add(MeshKit.cyl(0.03, 0.03, 2.2, 4), _at(at + Vector3(0.0, 1.1, 0.0)), Color(0.9, 0.9, 0.9))
		kit.add(MeshKit.cyl(0.02, 1.2, 0.45, 8), _at(at + Vector3(0.0, 2.25, 0.0)), umb[i % umb.size()])
		kit.add(MeshKit.box(Vector3(0.6, 0.08, 1.5)), _at(at + Vector3(0.7, 0.2, 0.3)), Color(0.98, 0.98, 0.95))
	# cadeira do árbitro ao lado do poste
	var rx := spec.net_half_len + 0.9
	kit.add(MeshKit.box(Vector3(0.6, 1.6, 0.6)), _at(Vector3(rx, 0.8, 0.0)), Color(0.85, 0.85, 0.85))
	kit.add(MeshKit.box(Vector3(0.4, 0.6, 0.35)), _at(Vector3(rx, 1.9, 0.0)), Color(0.15, 0.15, 0.15))
	_add(kit)


func _palm(kit: MeshKit, at: Vector3, lean_deg: float) -> void:
	var lean := deg_to_rad(clampf(lean_deg, -18.0, 18.0))
	var basis := Basis(Vector3.FORWARD, lean)
	var trunk := Color(0.55, 0.4, 0.25)
	var y := 0.0
	for k in 5:
		var seg := Transform3D(basis, at + basis * Vector3(0.0, y + 0.6, 0.0))
		kit.add(MeshKit.cyl(0.16 - k * 0.015, 0.2 - k * 0.015, 1.2, 6), seg, trunk.darkened(0.08 * (k % 2)))
		y += 1.2
	var top := at + basis * Vector3(0.0, y, 0.0)
	for k in 7:
		var ang := TAU * k / 7.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := dir.cross(Vector3.UP) * 0.45
		var tip := top + dir * 3.0 + Vector3(0.0, -1.3, 0.0)
		var mid := top + dir * 1.5 + Vector3(0.0, 0.25, 0.0)
		var leaf := Color(0.2, 0.55, 0.22).darkened(0.1 * (k % 2))
		kit.tri(top, mid + side, mid - side, leaf)
		kit.tri(mid - side, mid + side, tip, leaf)
		kit.tri(top, mid - side, mid + side, leaf)
		kit.tri(mid + side, mid - side, tip, leaf)


## Arquibancadas dos dois lados e a torcida em quads virados para a câmera (MultiMesh por cor).
func _stands() -> void:
	var w := spec.half_w
	var d := spec.depth
	var kit := MeshKit.new()
	var seats: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for tier in 3:
			var x := sx * (w + 4.0 + tier * 1.1)
			var h := 0.35 + tier * 0.45
			kit.add(MeshKit.box(Vector3(1.1, h, d * 1.6)), _at(Vector3(x, h * 0.5, -d * 0.15)), Color(0.75, 0.68, 0.58).darkened(0.07 * tier))
			var n := int(d * 1.6 / 0.75)
			for i in n:
				seats.append(Vector3(x, h, -d * 0.95 + i * 0.75 + 0.3 * (tier % 2)))
	# gente em pé atrás da quadra adversária
	for i in 14:
		seats.append(Vector3(-6.0 + i * 0.9, 0.0, -d - 3.2 - 0.5 * (i % 3)))
	_add(kit)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11                       # sempre a mesma torcida (e nada da lógica usa este rng)
	var groups: Array = []
	for _g in SHIRTS.size():
		groups.append([])
	var cam := Vector3(0.0, 15.0, 22.0)
	for s in seats:
		if rng.randf() < 0.18:
			continue                    # lugares vazios
		var to := cam - s
		var yaw := atan2(to.x, to.z)
		var sc := rng.randf_range(0.9, 1.1)
		var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)), s + Vector3(0.0, 0.55 * sc, 0.0))
		groups[rng.randi() % SHIRTS.size()].append(t)
	for g in SHIRTS.size():
		var list: Array = groups[g]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var quad := QuadMesh.new()
		quad.size = Vector2(0.55, 1.1)
		mm.mesh = quad
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _person_texture(SHIRTS[g], rng)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mmi.material_override = mat
		add_child(mmi)
		_crowd.append(mmi)
		_crowd_base.append(list)
		crowd_count += list.size()
		tris += list.size() * 2


## Silhueta (cabeça, cabelo, tronco com a camisa, braços) desenhada pixel a pixel.
func _person_texture(shirt: Color, rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin: Color = PlayerViewModel.SKINS[rng.randi() % PlayerViewModel.SKINS.size()]
	var hair: Color = PlayerViewModel.HAIRS[rng.randi() % PlayerViewModel.HAIRS.size()]
	for y in 32:
		for x in 16:
			var c := Color(0, 0, 0, 0)
			var head := Vector2(x - 7.5, y - 6.0).length()
			if head < 4.0:
				c = hair if y < 5 else skin
			elif y >= 10 and y < 24 and absf(x - 7.5) < 5.5:
				c = shirt
			elif y >= 10 and y < 20 and absf(x - 7.5) < 7.5:
				c = skin                # braços
			elif y >= 24 and absf(x - 7.5) < 4.5:
				c = Color(0.25, 0.25, 0.3)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _add(kit: MeshKit) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.build()
	add_child(mi)
	tris += kit.tris


func _at(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)
