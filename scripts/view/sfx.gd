class_name Sfx
extends Node
## Sons da partida (RF-4.07): assina os sinais do Game e pede um som para cada evento
## (o bloqueio soa pelo touch_made, não pelo ball_event, para não tocar duas vezes).
## Nó filho da MatchScene (não é autoload). `sink` troca a saída (testes contam os pedidos).
## Também toca a torcida contínua (sobe com o rally) e a música da partida (abaixa no ponto).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const GRADE_DB := {"perfect": 0.0, "good": -2.0, "bad": -5.0}
const VOICES := 8                   # sons ao mesmo tempo

var game: Game
var human_team := 0
var sink := Callable()              # (nome: String, volume_db: float) -> void; vazio = toca de verdade
var requests: Array[String] = []    # tudo que foi pedido (diagnóstico e testes)

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _touch3d: AudioStreamPlayer3D
var _crowd: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_db := -4.0


func bind(g: Game, p_human_team: int, with_music := true) -> void:
	game = g
	human_team = p_human_team
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_voices.append(p)
	# toque com posição (dá noção de lado da quadra); o resto é 2D
	_touch3d = AudioStreamPlayer3D.new()
	_touch3d.bus = &"SFX"
	_touch3d.unit_size = 12.0
	add_child(_touch3d)
	_crowd = _loop_player("crowd_loop", SFX_DIR, &"SFX", -30.0)
	if with_music:
		_music = _loop_player("match", MUSIC_DIR, &"Music", _music_db)
	g.touch_made.connect(_on_touch)
	g.whiffed.connect(func(_p: Player, _why: String) -> void: play("whiff", -6.0))
	g.ball_event.connect(_on_ball_event)
	g.action_used.connect(func(_p: Player, act: int) -> void:
		if act == Game.Act.DIVE:
			play("dive")
			play("ohh", -8.0))
	g.point_scored.connect(_on_point)
	g.set_over.connect(func(_t: int, _i: int, _f: Vector2i) -> void: play("whistle_long", -6.0))
	g.match_over.connect(func(team: int) -> void: play("match_win" if team == human_team else "match_lose"))


func _process(_delta: float) -> void:
	if _crowd == null or game == null:
		return
	# a torcida "acorda" com o rally: de quase nada a cheia em ~12 toques
	var k := clampf(game.rally_touches / 12.0, 0.0, 1.0) if game.state == Game.State.PLAY else 0.0
	_crowd.volume_db = lerpf(_crowd.volume_db, lerpf(-30.0, -10.0, k), 0.05)


## Pede o som `sound_name` (arquivo em assets/audio/sfx). at = posição 3D (só o toque usa).
func play(sound_name: String, volume_db := 0.0, at: Variant = null) -> void:
	requests.append(sound_name)
	if sink.is_valid():
		sink.call(sound_name, volume_db)
		return
	var s := stream(sound_name)
	if s == null:
		return
	if at is Vector3:
		_touch3d.stream = s
		_touch3d.volume_db = volume_db + 4.0
		_touch3d.global_position = at
		_touch3d.play()
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = s
	p.volume_db = volume_db
	p.play()


func stream(sound_name: String) -> AudioStream:
	if not _streams.has(sound_name):
		var path := SFX_DIR + sound_name + ".ogg"
		_streams[sound_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound_name]


## Nome do som do toque: ação × grau (manchete, toque e cortada variam com o timing).
static func touch_sound(kind: int, quality: float) -> String:
	var grade := "perfect" if quality >= 1.0 else ("good" if quality >= 0.7 else "bad")
	match kind:
		Game.Act.RECEIVE, Game.Act.FREEBALL:
			return "bump_" + grade
		Game.Act.SET_BALL:
			return "set_" + grade
		Game.Act.ATTACK:
			return "spike_" + grade
		Game.Act.DINK:
			return "dink"
		Game.Act.BLOCK:
			return "block"
		Game.Act.SERVE:
			return "serve"
	return "bump_" + grade


func _on_touch(p: Player, _grade: String, q: float) -> void:
	var snd := touch_sound(game.last_kind, q)
	play(snd, float(GRADE_DB.get(snd.get_slice("_", 1), 0.0)), game.ball.position)
	if q >= 1.0 and p.team == human_team and game.last_kind != Game.Act.SERVE:
		play("perfect", -9.0)


func _on_ball_event(kind: int, _pos: Vector3) -> void:
	match kind:
		BallSim.Ev.NET:
			play("net", -2.0)
		BallSim.Ev.ANTENNA:
			play("antenna", -3.0)
		BallSim.Ev.LAND:
			play("land")


func _on_point(team: int, _reason: String) -> void:
	play("whistle", -7.0)
	# rally longo = aplauso cheio; ponto seu = torcida comemora
	var long := game.rally_touches >= 6
	if team == human_team:
		play("cheer" if long else "applause", -4.0 if long else -8.0)
	elif long:
		play("applause", -10.0)
	if _music != null:
		var tw := create_tween()
		tw.tween_property(_music, "volume_db", _music_db - 8.0, 0.15)
		tw.tween_interval(1.2)
		tw.tween_property(_music, "volume_db", _music_db, 0.6)


func _loop_player(stream_name: String, dir: String, bus: StringName, db: float) -> AudioStreamPlayer:
	var path := dir + stream_name + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStreamOggVorbis = load(path)
	s.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = db
	p.autoplay = true
	add_child(p)
	return p


## Volumes das opções (0..1) nos barramentos Music e SFX (0 = mudo).
static func apply_volumes(music: float, sfx: float) -> void:
	for pair in [["Music", music], ["SFX", sfx]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx < 0:
			continue
		var v := float(pair[1])
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))
