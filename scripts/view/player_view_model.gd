class_name PlayerViewModel
extends PlayerView
## Jogador low-poly com "rig" de juntas (Node3D) e clipes de AnimTable (RF-4.01).
## Locomoção: parado/corrida/lateral misturados pela velocidade. Toques: um clipe por vez,
## agendado pelo plano de contato para a mão chegar na bola no tempo ideal (RF-4.02).

const HIP_H := 0.95                 # m: altura do quadril em pé
const BLEND := 0.1                  # s de mistura quando um clipe entra no meio ou é corrigido
const FADE_OUT := 0.15              # s finais do clipe voltando para a locomoção
const SKINS := [Color(0.96, 0.8, 0.66), Color(0.78, 0.57, 0.4), Color(0.55, 0.37, 0.24), Color(0.9, 0.7, 0.55)]
const HAIRS := [Color(0.15, 0.1, 0.07), Color(0.45, 0.28, 0.12), Color(0.9, 0.75, 0.4), Color(0.08, 0.06, 0.05)]

var uniform := 0                    # 0 = titular, 1 = segundo uniforme (o parceiro no 2v2)
var number_label: Label3D = null    # número nas costas (modo daltônico, RF-5.08)
var skeleton: Skeleton3D
var tris := 0                       # triângulos do modelo (orçamento: ≤ 5 k)
var shot_clip := ""                 # clipe de toque agendado ou tocando ("" = só locomoção)
var shot_start := 0.0               # início do clipe no relógio do Game
var pose := {}                      # última pose aplicada

var _tilt: Node3D
var _bone_idx := {}                 # nome da junta → índice do osso
var _plan_seen := -1
var _shot_live := false
var _phase := 0.0
var _blend_from := {}
var _blend_t := 0.0


## Um Skeleton3D (11 ossos) e uma malha só, com cada peça presa ao seu osso: 1 chamada de desenho.
func _build() -> void:
	var idx := maxi(game.players.find(player), 0)
	var skin: Color = SKINS[idx % SKINS.size()]
	var hair: Color = HAIRS[idx % HAIRS.size()]
	var jersey := player.color
	var trim := Color(0.97, 0.97, 0.97) if uniform == 0 else player.color.darkened(0.55)
	var shorts := player.color.darkened(0.6) if uniform == 0 else Color(0.95, 0.95, 0.95)
	_tilt = Node3D.new()
	body.add_child(_tilt)
	skeleton = Skeleton3D.new()
	_tilt.add_child(skeleton)
	var kit := MeshKit.new()
	var hips := _bone("hips", -1, Vector3(0.0, HIP_H, 0.0))
	_part(kit, hips, MeshKit.box(Vector3(0.36, 0.2, 0.22)), Vector3(0.0, -0.02, 0.0), shorts)
	for side: float in [-1.0, 1.0]:
		var s := "l" if side < 0.0 else "r"
		var leg := _bone("leg_" + s, hips, Vector3(side * 0.1, -0.06, 0.0))
		_part(kit, leg, MeshKit.cyl(0.075, 0.064, 0.46), Vector3(0.0, -0.23, 0.0), skin)
		_part(kit, leg, MeshKit.box(Vector3(0.17, 0.12, 0.2)), Vector3(0.0, -0.04, 0.0), shorts)
		var shin := _bone("shin_" + s, leg, Vector3(0.0, -0.45, 0.0))
		_part(kit, shin, MeshKit.cyl(0.06, 0.05, 0.44), Vector3(0.0, -0.22, 0.0), skin)
		_part(kit, shin, MeshKit.box(Vector3(0.11, 0.08, 0.24)), Vector3(0.0, -0.46, -0.05), trim)
	var spine := _bone("spine", hips, Vector3(0.0, 0.06, 0.0))
	# camisa: bloco de costas reto (a cor do time precisa ler bem de costas, ver e2e)
	_part(kit, spine, MeshKit.box(Vector3(0.46, 0.58, 0.24)), Vector3(0.0, 0.3, 0.0), jersey)
	_part(kit, spine, MeshKit.box(Vector3(0.48, 0.07, 0.26)), Vector3(0.0, 0.58, 0.0), trim)
	var head := _bone("head", spine, Vector3(0.0, 0.62, 0.0))
	_part(kit, head, MeshKit.cyl(0.055, 0.055, 0.1), Vector3(0.0, 0.04, 0.0), skin)
	_part(kit, head, MeshKit.sphere(0.13), Vector3(0.0, 0.2, 0.0), skin)
	_part(kit, head, MeshKit.sphere(0.135, true), Vector3(0.0, 0.22, 0.02), hair)
	_part(kit, head, MeshKit.box(Vector3(0.05, 0.04, 0.06)), Vector3(0.0, 0.18, -0.13), skin.darkened(0.15))
	for side: float in [-1.0, 1.0]:
		var s := "l" if side < 0.0 else "r"
		var arm := _bone("arm_" + s, spine, Vector3(side * 0.29, 0.52, 0.0))
		_part(kit, arm, MeshKit.box(Vector3(0.14, 0.14, 0.15)), Vector3(0.0, -0.03, 0.0), jersey)
		_part(kit, arm, MeshKit.cyl(0.055, 0.047, 0.3), Vector3(0.0, -0.15, 0.0), skin)
		var fore := _bone("fore_" + s, arm, Vector3(0.0, -0.3, 0.0))
		_part(kit, fore, MeshKit.cyl(0.05, 0.042, 0.28), Vector3(0.0, -0.14, 0.0), skin)
		_part(kit, fore, MeshKit.box(Vector3(0.08, 0.1, 0.05)), Vector3(0.0, -0.32, 0.0), skin)
	tris = kit.tris
	# número nas costas: lê de trás (o modelo olha para -Z); cor do time no contorno
	number_label = Label3D.new()
	number_label.text = str(uniform + 1)
	number_label.font_size = 64
	number_label.pixel_size = 0.005
	number_label.outline_size = 14
	number_label.outline_modulate = player.color.darkened(0.5)
	number_label.position = Vector3(0.0, HIP_H + 0.4, 0.13)
	number_label.visible = false
	_tilt.add_child(number_label)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.build()
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = skeleton.create_skin_from_rest_transforms()
	game.point_scored.connect(_on_point)
	_apply(AnimTable.READY)


## Agenda o clipe do plano deste jogador (um por plan_id) e mistura tudo na pose do quadro.
func _animate(delta: float) -> void:
	sync_plan()
	var now := game.time
	var target := _loco_pose(delta)
	if shot_clip != "":
		var u := now - shot_start
		var length := AnimTable.length(shot_clip)
		if u >= length:
			shot_clip = ""
			_shot_live = false
		elif u >= 0.0 and _wants_shot():
			if not _shot_live:
				_shot_live = true
				if u > 0.03:
					_start_blend()          # entrou no meio do clipe: não teleporta
			var w := clampf((length - u) / FADE_OUT, 0.0, 1.0)
			target = AnimTable.mix(target, AnimTable.sample(shot_clip, u), w)
	if player.is_diving():
		target = AnimTable.sample("dive", Tuning.DIVE_RECOVER - player.diving_t)
	if _blend_t > 0.0:
		target = AnimTable.mix(_blend_from, target, 1.0 - _blend_t / BLEND)
		_blend_t = maxf(_blend_t - delta, 0.0)
	_apply(target)
	_tilt.rotation.x = -deg_to_rad(80.0) * player.dive_tilt()


## Plano novo para este jogador: o clipe começa em plan.t − contact (mão na bola no tempo ideal).
func sync_plan() -> void:
	var pl := game.plan
	if pl == null or pl.player != player or game.plan_id == _plan_seen:
		return
	_plan_seen = game.plan_id
	var clip := AnimTable.clip_for(pl.act, game.serve_type[player.team])
	if clip == "" or AnimTable.contact(clip) < 0.0:
		return
	_set_shot(clip, pl.t - AnimTable.contact(clip))


## O toque aconteceu: confirma o clipe; se veio cedo/tarde, corrige o início com uma mistura curta.
func _on_swung(kind: int, contact_t: float) -> void:
	var clip := AnimTable.clip_for(kind, game.serve_type[player.team])
	if clip == "":
		return
	# o bloqueio avisa no pulo: o contato do clipe é o pico (JUMP_TIME_UP depois)
	var at := contact_t + (Tuning.JUMP_TIME_UP if kind == Game.Act.BLOCK else 0.0)
	var start := at - AnimTable.contact(clip)
	if clip == shot_clip and absf(start - shot_start) <= 1.0 / 60.0:
		return
	_set_shot(clip, start)
	if _shot_live or game.time - start > 0.03:
		_start_blend()
	_shot_live = game.time >= start


func _on_point(team: int, _reason: String) -> void:
	_set_shot("celebrate" if team == player.team else "lament", game.time + 0.25)


func _set_shot(clip: String, start: float) -> void:
	shot_clip = clip
	shot_start = start
	_shot_live = false


## O humano só "arma" o toque quando segura o botão (ou já soltou e o toque está agendado).
func _wants_shot() -> bool:
	if not player.is_human or game.plan == null or game.plan.player != player:
		return true
	return player.holding or game.has_pending(player)


func _start_blend() -> void:
	if pose.is_empty():
		return
	_blend_from = pose
	_blend_t = BLEND


## Parado → corrida (para a frente) ou lateral, pela velocidade no referencial do corpo.
func _loco_pose(delta: float) -> Dictionary:
	var v := player.vel
	v.y = 0.0
	var speed := v.length()
	_phase += speed * delta / 3.0                    # ~1 ciclo (2 passos) a cada 3 m
	var idle := AnimTable.sample("idle", game.time)
	if speed < 0.3:
		return idle
	var fwd := -body.global_transform.basis.z
	var side := absf(v.normalized().cross(Vector3.UP).dot(fwd))     # 1 = andando de lado
	var move := AnimTable.mix(AnimTable.sample("run", _phase * 0.5), AnimTable.sample("strafe", _phase * 0.5), side)
	return AnimTable.mix(idle, move, clampf(speed / 3.0, 0.0, 1.0))


func _apply(p: Dictionary) -> void:
	pose = p
	skeleton.set_bone_pose_position(_bone_idx["hips"], Vector3(0.0, HIP_H + float(p.get("drop", 0.0)), 0.0))
	for j in AnimTable.JOINTS:
		var e: Vector3 = p.get(j, Vector3.ZERO)
		skeleton.set_bone_pose_rotation(_bone_idx[j], Quaternion.from_euler(e * (PI / 180.0)))


## Osso com a posição de repouso relativa ao pai (o mesmo layout de juntas da AnimTable).
func _bone(bone_name: String, parent: int, pos: Vector3) -> int:
	var i := skeleton.add_bone(bone_name)
	if parent >= 0:
		skeleton.set_bone_parent(i, parent)
	skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, pos))
	skeleton.set_bone_pose_position(i, pos)
	_bone_idx[bone_name] = i
	return i


## Peça presa ao osso, posicionada em coordenadas do osso.
func _part(kit: MeshKit, bone: int, mesh: Mesh, at: Vector3, color: Color) -> void:
	kit.add(mesh, skeleton.get_bone_global_rest(bone) * Transform3D(Basis.IDENTITY, at), color, bone)
