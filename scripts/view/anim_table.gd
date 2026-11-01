class_name AnimTable
extends RefCounted
## Clipes do jogador como tabelas de poses (graus por junta + "drop" = m que o quadril desce).
## Cada clipe de toque tem `contact`: o segundo do clipe em que a mão encosta na bola (RF-4.02).
## A PlayerViewModel começa o clipe em plan.t − contact para o contato cair no tempo ideal.

## Juntas do "rig" (Node3D) da PlayerViewModel. Eixo x > 0 = gira para a frente (braço sobe à frente,
## coxa levanta o joelho); canela < 0 dobra o joelho; tronco/cabeça < 0 inclinam para a frente.
const JOINTS := ["spine", "head", "arm_l", "arm_r", "fore_l", "fore_r", "leg_l", "leg_r", "shin_l", "shin_r"]

const READY := {"drop": -0.08, "spine": Vector3(-12, 0, 0), "arm_l": Vector3(25, 0, -8), "arm_r": Vector3(25, 0, 8),
		"fore_l": Vector3(35, 0, 0), "fore_r": Vector3(35, 0, 0), "leg_l": Vector3(20, 0, -4), "leg_r": Vector3(20, 0, 4),
		"shin_l": Vector3(-35, 0, 0), "shin_r": Vector3(-35, 0, 0)}

## nome → {length (s), contact (s; -1 = sem contato), loop, keys: [[t, pose], ...]}
## Pose com "_ready" = READY com as juntas indicadas trocadas.
const CLIPS := {
	"idle": {"length": 1.6, "contact": -1.0, "loop": true, "keys": [
		[0.0, READY],
		[0.8, {"_ready": true, "drop": -0.11, "spine": Vector3(-15, 0, 0)}],
		[1.6, READY]]},
	"run": {"length": 0.5, "contact": -1.0, "loop": true, "keys": [
		[0.0, {"drop": -0.05, "spine": Vector3(-16, 0, 0), "leg_l": Vector3(40, 0, 0), "leg_r": Vector3(-30, 0, 0),
				"shin_l": Vector3(-25, 0, 0), "shin_r": Vector3(-70, 0, 0), "arm_l": Vector3(-35, 0, -6),
				"arm_r": Vector3(40, 0, 6), "fore_l": Vector3(70, 0, 0), "fore_r": Vector3(70, 0, 0)}],
		[0.25, {"drop": -0.05, "spine": Vector3(-16, 0, 0), "leg_l": Vector3(-30, 0, 0), "leg_r": Vector3(40, 0, 0),
				"shin_l": Vector3(-70, 0, 0), "shin_r": Vector3(-25, 0, 0), "arm_l": Vector3(40, 0, -6),
				"arm_r": Vector3(-35, 0, 6), "fore_l": Vector3(70, 0, 0), "fore_r": Vector3(70, 0, 0)}],
		[0.5, {"drop": -0.05, "spine": Vector3(-16, 0, 0), "leg_l": Vector3(40, 0, 0), "leg_r": Vector3(-30, 0, 0),
				"shin_l": Vector3(-25, 0, 0), "shin_r": Vector3(-70, 0, 0), "arm_l": Vector3(-35, 0, -6),
				"arm_r": Vector3(40, 0, 6), "fore_l": Vector3(70, 0, 0), "fore_r": Vector3(70, 0, 0)}]]},
	"strafe": {"length": 0.5, "contact": -1.0, "loop": true, "keys": [
		[0.0, {"_ready": true, "drop": -0.14, "leg_l": Vector3(25, 0, -22), "leg_r": Vector3(25, 0, 6)}],
		[0.25, {"_ready": true, "drop": -0.1, "leg_l": Vector3(25, 0, -6), "leg_r": Vector3(25, 0, 22)}],
		[0.5, {"_ready": true, "drop": -0.14, "leg_l": Vector3(25, 0, -22), "leg_r": Vector3(25, 0, 6)}]]},
	# manchete: braços esticados juntos à frente, pernas dobradas, sobe no contato
	"bump": {"length": 0.7, "contact": 0.3, "loop": false, "keys": [
		[0.0, READY],
		[0.18, {"_ready": true, "drop": -0.3, "spine": Vector3(-28, 0, 0), "arm_l": Vector3(55, 0, 12), "arm_r": Vector3(55, 0, -12),
				"fore_l": Vector3(0, 0, 0), "fore_r": Vector3(0, 0, 0), "leg_l": Vector3(55, 0, -6), "leg_r": Vector3(55, 0, 6),
				"shin_l": Vector3(-85, 0, 0), "shin_r": Vector3(-85, 0, 0)}],
		[0.3, {"_ready": true, "drop": -0.22, "spine": Vector3(-22, 0, 0), "arm_l": Vector3(75, 0, 12), "arm_r": Vector3(75, 0, -12),
				"fore_l": Vector3(0, 0, 0), "fore_r": Vector3(0, 0, 0), "leg_l": Vector3(40, 0, -6), "leg_r": Vector3(40, 0, 6),
				"shin_l": Vector3(-60, 0, 0), "shin_r": Vector3(-60, 0, 0)}],
		[0.45, {"_ready": true, "drop": -0.08, "spine": Vector3(-12, 0, 0), "arm_l": Vector3(85, 0, 10), "arm_r": Vector3(85, 0, -10),
				"fore_l": Vector3(0, 0, 0), "fore_r": Vector3(0, 0, 0)}],
		[0.7, READY]]},
	# toque: mãos acima da testa, empurra para cima
	"set": {"length": 0.7, "contact": 0.3, "loop": false, "keys": [
		[0.0, READY],
		[0.18, {"_ready": true, "drop": -0.18, "spine": Vector3(-4, 0, 0), "head": Vector3(15, 0, 0), "arm_l": Vector3(150, 0, -18),
				"arm_r": Vector3(150, 0, 18), "fore_l": Vector3(70, 0, 0), "fore_r": Vector3(70, 0, 0)}],
		[0.3, {"_ready": true, "drop": -0.02, "spine": Vector3(2, 0, 0), "head": Vector3(15, 0, 0), "arm_l": Vector3(165, 0, -12),
				"arm_r": Vector3(165, 0, 12), "fore_l": Vector3(25, 0, 0), "fore_r": Vector3(25, 0, 0),
				"leg_l": Vector3(5, 0, -4), "leg_r": Vector3(5, 0, 4), "shin_l": Vector3(-5, 0, 0), "shin_r": Vector3(-5, 0, 0)}],
		[0.45, {"_ready": true, "drop": -0.04, "arm_l": Vector3(150, 0, -15), "arm_r": Vector3(150, 0, 15),
				"fore_l": Vector3(10, 0, 0), "fore_r": Vector3(10, 0, 0)}],
		[0.7, READY]]},
	# cortada: braços para trás na corrida, sobe, arma o braço e bate no alto (contato = pico do pulo)
	"spike": {"length": 0.95, "contact": 0.42, "loop": false, "keys": [
		[0.0, {"_ready": true, "drop": -0.28, "spine": Vector3(-30, 0, 0), "arm_l": Vector3(-45, 0, -10), "arm_r": Vector3(-45, 0, 10),
				"fore_l": Vector3(10, 0, 0), "fore_r": Vector3(10, 0, 0), "leg_l": Vector3(50, 0, 0), "leg_r": Vector3(50, 0, 0),
				"shin_l": Vector3(-80, 0, 0), "shin_r": Vector3(-80, 0, 0)}],
		[0.15, {"drop": 0.0, "spine": Vector3(5, 0, 0), "arm_l": Vector3(160, 0, -10), "arm_r": Vector3(160, 0, 10),
				"fore_l": Vector3(10, 0, 0), "fore_r": Vector3(10, 0, 0), "leg_l": Vector3(10, 0, 0), "leg_r": Vector3(-5, 0, 0),
				"shin_l": Vector3(-30, 0, 0), "shin_r": Vector3(-40, 0, 0)}],
		[0.32, {"drop": 0.0, "spine": Vector3(12, 25, 0), "arm_l": Vector3(140, 0, -10), "arm_r": Vector3(195, 0, 20),
				"fore_l": Vector3(20, 0, 0), "fore_r": Vector3(110, 0, 0), "leg_l": Vector3(25, 0, 0), "leg_r": Vector3(-10, 0, 0),
				"shin_l": Vector3(-60, 0, 0), "shin_r": Vector3(-70, 0, 0)}],
		[0.42, {"drop": 0.0, "spine": Vector3(-18, -15, 0), "arm_l": Vector3(60, 0, -10), "arm_r": Vector3(150, 0, 8),
				"fore_l": Vector3(40, 0, 0), "fore_r": Vector3(0, 0, 0), "leg_l": Vector3(30, 0, 0), "leg_r": Vector3(20, 0, 0),
				"shin_l": Vector3(-60, 0, 0), "shin_r": Vector3(-50, 0, 0)}],
		[0.6, {"drop": 0.0, "spine": Vector3(-25, -10, 0), "arm_l": Vector3(20, 0, -10), "arm_r": Vector3(30, 0, 8),
				"fore_l": Vector3(20, 0, 0), "fore_r": Vector3(10, 0, 0), "leg_l": Vector3(25, 0, 0), "leg_r": Vector3(25, 0, 0),
				"shin_l": Vector3(-45, 0, 0), "shin_r": Vector3(-45, 0, 0)}],
		[0.95, READY]]},
	# largada: como a cortada, mas a mão empurra devagar por cima do bloqueio
	"dink": {"length": 0.8, "contact": 0.42, "loop": false, "keys": [
		[0.0, {"_ready": true, "drop": -0.25, "spine": Vector3(-25, 0, 0), "arm_l": Vector3(-30, 0, -10), "arm_r": Vector3(-30, 0, 10)}],
		[0.25, {"drop": 0.0, "arm_l": Vector3(140, 0, -10), "arm_r": Vector3(185, 0, 15), "fore_l": Vector3(20, 0, 0),
				"fore_r": Vector3(70, 0, 0), "leg_l": Vector3(20, 0, 0), "shin_l": Vector3(-50, 0, 0), "shin_r": Vector3(-40, 0, 0)}],
		[0.42, {"drop": 0.0, "arm_l": Vector3(100, 0, -10), "arm_r": Vector3(170, 0, 8), "fore_l": Vector3(30, 0, 0),
				"fore_r": Vector3(25, 0, 0), "leg_l": Vector3(20, 0, 0), "shin_l": Vector3(-50, 0, 0), "shin_r": Vector3(-40, 0, 0)}],
		[0.8, READY]]},
	# bloqueio: mãos sobem retas e passam da rede no pico (contato = topo do pulo)
	"block": {"length": 0.9, "contact": 0.42, "loop": false, "keys": [
		[0.0, {"_ready": true, "drop": -0.25, "arm_l": Vector3(110, 0, -10), "arm_r": Vector3(110, 0, 10),
				"fore_l": Vector3(40, 0, 0), "fore_r": Vector3(40, 0, 0), "leg_l": Vector3(45, 0, 0), "leg_r": Vector3(45, 0, 0),
				"shin_l": Vector3(-75, 0, 0), "shin_r": Vector3(-75, 0, 0)}],
		[0.2, {"drop": 0.0, "arm_l": Vector3(175, 0, -6), "arm_r": Vector3(175, 0, 6)}],
		[0.42, {"drop": 0.0, "spine": Vector3(-6, 0, 0), "arm_l": Vector3(160, 0, -8), "arm_r": Vector3(160, 0, 8),
				"fore_l": Vector3(-10, 0, 0), "fore_r": Vector3(-10, 0, 0)}],
		[0.65, {"drop": 0.0, "arm_l": Vector3(170, 0, -6), "arm_r": Vector3(170, 0, 6)}],
		[0.9, READY]]},
	# peixinho: braços esticados à frente; o corpo deita pela lógica (Player.dive_tilt)
	"dive": {"length": Tuning.DIVE_RECOVER, "contact": 0.0, "loop": false, "keys": [
		[0.0, {"drop": -0.2, "arm_l": Vector3(150, 0, -10), "arm_r": Vector3(150, 0, 10), "leg_l": Vector3(-15, 0, 0),
				"leg_r": Vector3(-5, 0, 0), "shin_l": Vector3(-20, 0, 0), "shin_r": Vector3(-10, 0, 0), "head": Vector3(30, 0, 0)}],
		[0.55, {"drop": -0.2, "arm_l": Vector3(130, 0, -20), "arm_r": Vector3(140, 0, 20), "leg_l": Vector3(-10, 0, 0),
				"shin_l": Vector3(-40, 0, 0), "shin_r": Vector3(-30, 0, 0), "head": Vector3(25, 0, 0)}],
		[Tuning.DIVE_RECOVER, {"_ready": true, "drop": -0.3, "leg_l": Vector3(70, 0, 0), "leg_r": Vector3(50, 0, 0),
				"shin_l": Vector3(-100, 0, 0), "shin_r": Vector3(-90, 0, 0)}]]},
	"serve_under": {"length": 0.9, "contact": 0.45, "loop": false, "keys": [
		[0.0, {"_ready": true, "arm_l": Vector3(60, 0, 5), "fore_l": Vector3(30, 0, 0), "arm_r": Vector3(10, 0, 8)}],
		[0.25, {"_ready": true, "drop": -0.15, "spine": Vector3(-25, 0, 0), "arm_l": Vector3(60, 0, 5), "fore_l": Vector3(30, 0, 0),
				"arm_r": Vector3(-55, 0, 8), "fore_r": Vector3(0, 0, 0), "leg_l": Vector3(35, 0, 0), "leg_r": Vector3(-15, 0, 0)}],
		[0.45, {"_ready": true, "drop": -0.1, "spine": Vector3(-20, 0, 0), "arm_l": Vector3(30, 0, -10), "arm_r": Vector3(60, 0, 4),
				"fore_r": Vector3(0, 0, 0), "leg_l": Vector3(35, 0, 0), "leg_r": Vector3(-15, 0, 0)}],
		[0.6, {"_ready": true, "spine": Vector3(-10, 0, 0), "arm_r": Vector3(110, 0, 4), "fore_r": Vector3(0, 0, 0)}],
		[0.9, READY]]},
	"serve_float": {"length": 1.1, "contact": 0.55, "loop": false, "keys": [
		[0.0, {"_ready": true, "drop": 0.0, "arm_l": Vector3(60, 0, 0), "fore_l": Vector3(20, 0, 0)}],
		[0.2, {"drop": 0.0, "arm_l": Vector3(165, 0, -5), "fore_l": Vector3(0, 0, 0), "arm_r": Vector3(120, 0, 20),
				"fore_r": Vector3(100, 0, 0)}],
		[0.4, {"drop": 0.0, "spine": Vector3(8, 20, 0), "arm_l": Vector3(100, 0, -5), "arm_r": Vector3(185, 0, 25),
				"fore_r": Vector3(120, 0, 0)}],
		[0.55, {"drop": 0.0, "spine": Vector3(-8, -10, 0), "arm_l": Vector3(40, 0, -8), "arm_r": Vector3(170, 0, 5),
				"fore_r": Vector3(5, 0, 0)}],
		[0.75, {"drop": 0.0, "arm_l": Vector3(20, 0, -8), "arm_r": Vector3(150, 0, 5), "fore_r": Vector3(5, 0, 0)}],
		[1.1, READY]]},
	"serve_jump": {"length": 1.3, "contact": 0.75, "loop": false, "keys": [
		[0.0, {"_ready": true, "arm_l": Vector3(70, 0, 0), "arm_r": Vector3(70, 0, 0)}],
		[0.15, {"drop": 0.0, "arm_l": Vector3(170, 0, -5), "arm_r": Vector3(170, 0, 5), "fore_l": Vector3(0, 0, 0)}],
		[0.4, {"_ready": true, "drop": -0.3, "spine": Vector3(-30, 0, 0), "arm_l": Vector3(-45, 0, -10), "arm_r": Vector3(-45, 0, 10),
				"fore_l": Vector3(10, 0, 0), "fore_r": Vector3(10, 0, 0), "leg_l": Vector3(55, 0, 0), "leg_r": Vector3(55, 0, 0),
				"shin_l": Vector3(-85, 0, 0), "shin_r": Vector3(-85, 0, 0)}],
		[0.62, {"drop": 0.0, "spine": Vector3(12, 25, 0), "arm_l": Vector3(140, 0, -10), "arm_r": Vector3(195, 0, 20),
				"fore_r": Vector3(110, 0, 0), "leg_l": Vector3(25, 0, 0), "shin_l": Vector3(-60, 0, 0), "shin_r": Vector3(-70, 0, 0)}],
		[0.75, {"drop": 0.0, "spine": Vector3(-18, -15, 0), "arm_l": Vector3(60, 0, -10), "arm_r": Vector3(150, 0, 8),
				"fore_r": Vector3(0, 0, 0), "leg_l": Vector3(30, 0, 0), "leg_r": Vector3(20, 0, 0), "shin_l": Vector3(-60, 0, 0)}],
		[0.95, {"drop": -0.1, "spine": Vector3(-25, 0, 0), "arm_l": Vector3(20, 0, -10), "arm_r": Vector3(30, 0, 8)}],
		[1.3, READY]]},
	"celebrate": {"length": 1.5, "contact": -1.0, "loop": false, "keys": [
		[0.0, READY],
		[0.2, {"drop": 0.0, "spine": Vector3(8, 0, 0), "head": Vector3(-15, 0, 0), "arm_l": Vector3(170, 0, -30),
				"arm_r": Vector3(170, 0, 30), "fore_l": Vector3(20, 0, 0), "fore_r": Vector3(20, 0, 0)}],
		[0.45, {"drop": -0.05, "arm_l": Vector3(150, 0, -35), "arm_r": Vector3(150, 0, 35), "fore_l": Vector3(70, 0, 0),
				"fore_r": Vector3(70, 0, 0)}],
		[0.7, {"drop": 0.0, "head": Vector3(-15, 0, 0), "arm_l": Vector3(175, 0, -30), "arm_r": Vector3(175, 0, 30)}],
		[1.0, {"drop": -0.05, "arm_l": Vector3(150, 0, -35), "arm_r": Vector3(150, 0, 35), "fore_l": Vector3(70, 0, 0),
				"fore_r": Vector3(70, 0, 0)}],
		[1.5, READY]]},
	"lament": {"length": 1.5, "contact": -1.0, "loop": false, "keys": [
		[0.0, READY],
		[0.35, {"drop": -0.12, "spine": Vector3(-38, 0, 0), "head": Vector3(-25, 0, 0), "arm_l": Vector3(40, 0, -5),
				"arm_r": Vector3(40, 0, 5), "fore_l": Vector3(15, 0, 0), "fore_r": Vector3(15, 0, 0), "leg_l": Vector3(20, 0, 0),
				"leg_r": Vector3(20, 0, 0), "shin_l": Vector3(-30, 0, 0), "shin_r": Vector3(-30, 0, 0)}],
		[1.1, {"drop": -0.12, "spine": Vector3(-38, 0, 0), "head": Vector3(-30, 0, 0), "arm_l": Vector3(40, 0, -5),
				"arm_r": Vector3(40, 0, 5), "fore_l": Vector3(15, 0, 0), "fore_r": Vector3(15, 0, 0), "leg_l": Vector3(20, 0, 0),
				"leg_r": Vector3(20, 0, 0), "shin_l": Vector3(-30, 0, 0), "shin_r": Vector3(-30, 0, 0)}],
		[1.5, READY]]},
}


## Clipe do toque por ação (Game.Act); no saque, pelo tipo (ServeType.Kind). "" = sem clipe.
static func clip_for(act: int, serve_kind: int = ServeType.Kind.UNDER) -> String:
	match act:
		Game.Act.RECEIVE, Game.Act.FREEBALL, Game.Act.NONE:
			return "bump"
		Game.Act.SET_BALL:
			return "set"
		Game.Act.ATTACK:
			return "spike"
		Game.Act.DINK:
			return "dink"
		Game.Act.BLOCK:
			return "block"
		Game.Act.DIVE:
			return "dive"
		Game.Act.SERVE:
			return ["serve_under", "serve_float", "serve_jump"][serve_kind]
	return ""


static func length(clip: String) -> float:
	return float(CLIPS[clip]["length"])


static func contact(clip: String) -> float:
	return float(CLIPS[clip]["contact"])


## Pose do clipe no segundo t (em loop, t dá a volta). Entre chaves: suavizado (smoothstep).
static func sample(clip: String, t: float) -> Dictionary:
	var c: Dictionary = CLIPS[clip]
	var keys: Array = c["keys"]
	if bool(c["loop"]):
		t = fposmod(t, float(c["length"]))
	if t <= float(keys[0][0]):
		return _full(keys[0][1])
	for i in range(1, keys.size()):
		var t1 := float(keys[i][0])
		if t <= t1:
			var t0 := float(keys[i - 1][0])
			var u := smoothstep(0.0, 1.0, (t - t0) / maxf(t1 - t0, 1e-4))
			return mix(_full(keys[i - 1][1]), _full(keys[i][1]), u)
	return _full(keys[-1][1])


## a → b por w (0..1), junta por junta; junta ausente = repouso (0°, drop 0).
static func mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {"drop": lerpf(float(a.get("drop", 0.0)), float(b.get("drop", 0.0)), w)}
	for j in JOINTS:
		out[j] = (a.get(j, Vector3.ZERO) as Vector3).lerp(b.get(j, Vector3.ZERO), w)
	return out


## Maior diferença de ângulo (graus) entre duas poses: mede "salto" de um quadro para o outro.
static func distance(a: Dictionary, b: Dictionary) -> float:
	var d := 0.0
	for j in JOINTS:
		var va: Vector3 = a.get(j, Vector3.ZERO)
		var vb: Vector3 = b.get(j, Vector3.ZERO)
		d = maxf(d, maxf(absf(va.x - vb.x), maxf(absf(va.y - vb.y), absf(va.z - vb.z))))
	return d


static func _full(p: Dictionary) -> Dictionary:
	if not p.has("_ready"):
		return p
	var out := READY.duplicate()
	out.merge(p, true)
	return out
