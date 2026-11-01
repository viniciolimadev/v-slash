class_name Court
extends Node3D
## Quadra, linhas, rede e antenas com formas simples (arte entra na Fase 4).

var spec := CourtSpec.default_spec()    # defina antes de entrar na árvore


func _ready() -> void:
	var w := spec.half_w
	var d := spec.depth
	var nh := Tuning.NET_HEIGHT
	var nl := spec.net_half_len
	# chão, área livre e quadra (alturas diferentes para não piscar)
	_box(Vector3(80.0, 0.1, 80.0), Vector3(0.0, -0.06, 0.0), Color(0.2, 0.45, 0.38))
	_box(Vector3(w * 2.0 + 5.0, 0.02, d * 2.0 + 6.0), Vector3(0.0, -0.01, 0.0), Color(0.33, 0.55, 0.72))
	_box(Vector3(w * 2.0, 0.02, d * 2.0), Vector3(0.0, -0.006, 0.0), Color(0.93, 0.6, 0.33))
	# linhas (fazem parte da quadra: bola na linha = dentro)
	var lc := Color(0.97, 0.97, 0.97)
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.01, d * 2.0 + 0.06), Vector3(sx * w, 0.003, 0.0), lc)
		_box(Vector3(w * 2.0 + 0.06, 0.01, 0.06), Vector3(0.0, 0.003, sx * d), lc)
	_box(Vector3(w * 2.0, 0.01, 0.06), Vector3(0.0, 0.003, 0.0), lc)
	# rede, faixa branca, postes e antenas
	_box(Vector3(nl * 2.0, 1.0, 0.03), Vector3(0.0, nh - 0.5, 0.0), Color(0.08, 0.08, 0.1, 0.55))
	_box(Vector3(nl * 2.0, 0.07, 0.05), Vector3(0.0, nh - 0.035, 0.0), Color(0.98, 0.98, 0.98))
	for sx: float in [-1.0, 1.0]:
		_cyl(0.06, nh + 0.15, Vector3(sx * (nl + 0.15), (nh + 0.15) * 0.5, 0.0), Color(0.55, 0.57, 0.6))
		_cyl(0.02, 1.8, Vector3(sx * w, nh - 0.1, 0.0), Color(0.95, 0.2, 0.2))


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _box(box_size: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c)
	add_child(mi)


func _cyl(radius: float, height: float, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	add_child(mi)
