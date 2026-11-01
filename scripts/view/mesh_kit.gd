class_name MeshKit
extends RefCounted
## Junta várias malhas simples (caixa, cilindro, esfera...) numa ArrayMesh só, com cor por vértice:
## uma chamada de desenho por objeto (orçamento RNF-4.02). Com bone >= 0 cada peça fica presa
## a um osso (peso 1), para um Skeleton3D animar a malha inteira.

var tris := 0

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
var _idx := PackedInt32Array()


## Acrescenta `mesh` transformada por `xf`, toda na cor `color`.
func add(mesh: Mesh, xf: Transform3D, color: Color, bone := -1) -> void:
	var arr := mesh.surface_get_arrays(0)
	var base := _verts.size()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
	var nb := xf.basis.inverse().transposed()
	for i in v.size():
		_verts.append(xf * v[i])
		_norms.append((nb * n[i]).normalized())
		_colors.append(color)
		_uvs.append((uv as PackedVector2Array)[i] if uv != null else Vector2.ZERO)
		if bone >= 0:
			_bones.append_array([bone, 0, 0, 0])
			_weights.append_array([1.0, 0.0, 0.0, 0.0])
	var ind: Variant = arr[Mesh.ARRAY_INDEX]
	if ind == null:
		for i in v.size():
			_idx.append(base + i)
	else:
		for i in (ind as PackedInt32Array):
			_idx.append(base + i)
	tris = _idx.size() / 3


## Triângulo solto (folhas, bandeirinhas): os três vértices na mesma cor, normal da face.
func tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var nrm := (c - a).cross(b - a).normalized()
	var base := _verts.size()
	for p in [a, b, c]:
		_verts.append(p)
		_norms.append(nrm)
		_colors.append(color)
		_uvs.append(Vector2.ZERO)
	_idx.append_array([base, base + 1, base + 2])
	tris = _idx.size() / 3


func build(material: Material = null) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _verts
	arr[Mesh.ARRAY_NORMAL] = _norms
	arr[Mesh.ARRAY_COLOR] = _colors
	arr[Mesh.ARRAY_TEX_UV] = _uvs
	arr[Mesh.ARRAY_INDEX] = _idx
	if not _bones.is_empty():
		arr[Mesh.ARRAY_BONES] = _bones
		arr[Mesh.ARRAY_WEIGHTS] = _weights
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, material if material != null else vertex_material())
	return m


## Material que usa a cor do vértice (em sRGB, como albedo_color).
static func vertex_material(unshaded := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.85
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


static func cyl(r_top: float, r_bottom: float, h: float, sides := 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return m


static func sphere(r: float, half := false, sides := 8) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * (1.0 if half else 2.0)
	m.radial_segments = sides
	m.rings = maxi(sides / 2 + 1, 3)
	m.is_hemisphere = half
	return m
