class_name SaveData
extends RefCounted
## Progresso, recordes e opções em user://save.cfg (ConfigFile versionado).
## Arquivo ausente ou ilegível = valores padrão; nunca derruba o jogo.

const VERSION := 4                  # 2: tipo de saque (F2); 3: progresso por modo (F3); 4: volumes (F4)
const DEFAULT_PATH := "user://save.cfg"
const AIM_SENS_MIN := 0.5
const AIM_SENS_MAX := 2.0
const MODE_KEYS := ["1v1", "2v2"]   # sufixo das chaves por modo (índice = MatchConfig.Mode)


## Progresso e recordes de um modo.
class ModeRecord:
	extends RefCounted
	var unlocked_level := 0
	var best_rally := 0
	var wins: Array[int] = [0, 0, 0]
	var losses: Array[int] = [0, 0, 0]


var path: String
var records: Array[ModeRecord] = [ModeRecord.new(), ModeRecord.new()]
var tutorial_done := false
var hint_2v2_done := false          # dica "o controle passa para quem vai tocar" já mostrada
var aim_sens := 1.0                 # multiplicador de Tuning.AIM_SENS
var left_handed := false
var vibration := true
var serve_type := ServeType.Kind.UNDER   # último tipo de saque escolhido
var music_vol := 0.8                # 0..1 (barramento Music)
var sfx_vol := 1.0                  # 0..1 (barramento SFX)


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	# version > VERSION: lê o que entende; campos novos de versões futuras são ignorados
	for mode in MODE_KEYS.size():
		var r := records[mode]
		var suffix := "_" + str(MODE_KEYS[mode])
		# versões 1 e 2 não tinham modo: os valores sem sufixo são do 1v1
		var legacy := mode == MatchConfig.Mode.ONE_V_ONE
		r.unlocked_level = clampi(_int(cfg, "progress", _key(cfg, "progress", "unlocked_level", suffix, legacy), 0), 0, 2)
		r.best_rally = maxi(_int(cfg, "records", _key(cfg, "records", "best_rally", suffix, legacy), 0), 0)
		r.wins = _int_array(cfg, "records", _key(cfg, "records", "wins", suffix, legacy))
		r.losses = _int_array(cfg, "records", _key(cfg, "records", "losses", suffix, legacy))
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	hint_2v2_done = bool(cfg.get_value("progress", "hint_2v2_done", false))
	aim_sens = clampf(float(cfg.get_value("options", "aim_sens", 1.0)), AIM_SENS_MIN, AIM_SENS_MAX)
	left_handed = bool(cfg.get_value("options", "left_handed", false))
	vibration = bool(cfg.get_value("options", "vibration", true))
	# save versão 1 não tem o campo: fica o padrão
	serve_type = clampi(_int(cfg, "options", "serve_type", ServeType.Kind.UNDER), 0, ServeType.NAMES.size() - 1)
	# saves até a versão 3 não têm volume: ficam os padrões
	music_vol = _unit(cfg, "music_vol", 0.8)
	sfx_vol = _unit(cfg, "sfx_vol", 1.0)


## Grava num arquivo temporário e troca de nome: um desligamento no meio não corrompe o save.
func save_file() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for mode in MODE_KEYS.size():
		var r := records[mode]
		var suffix := "_" + str(MODE_KEYS[mode])
		cfg.set_value("progress", "unlocked_level" + suffix, r.unlocked_level)
		cfg.set_value("records", "best_rally" + suffix, r.best_rally)
		cfg.set_value("records", "wins" + suffix, r.wins)
		cfg.set_value("records", "losses" + suffix, r.losses)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "hint_2v2_done", hint_2v2_done)
	cfg.set_value("options", "aim_sens", aim_sens)
	cfg.set_value("options", "left_handed", left_handed)
	cfg.set_value("options", "vibration", vibration)
	cfg.set_value("options", "serve_type", serve_type)
	cfg.set_value("options", "music_vol", music_vol)
	cfg.set_value("options", "sfx_vol", sfx_vol)
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		return err
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		err = cfg.save(path)
	return err


func rec(mode: int) -> ModeRecord:
	return records[mode]


## Maior rally em qualquer modo (título).
func best_rally_any() -> int:
	var best := 0
	for r in records:
		best = maxi(best, r.best_rally)
	return best


## Registra uma partida terminada no modo dela (não grava sozinho). Preenche r.unlocked.
func record_result(r: MatchResult) -> void:
	var m := records[r.mode]
	m.best_rally = maxi(m.best_rally, r.stats.best_rally)
	if r.winner != 0:
		m.losses[r.level] += 1
		return
	m.wins[r.level] += 1
	var next := mini(r.level + 1, 2)
	if next > m.unlocked_level:
		m.unlocked_level = next
		r.unlocked = next


## Chave do modo (key + suffix); no 1v1, se ela não existe, a chave antiga sem sufixo (saves 1 e 2).
func _key(cfg: ConfigFile, sec: String, key: String, suffix: String, legacy: bool) -> String:
	if legacy and not cfg.has_section_key(sec, key + suffix):
		return key
	return key + suffix


func _int(cfg: ConfigFile, sec: String, key: String, default: int) -> int:
	var v: Variant = cfg.get_value(sec, key, default)
	return int(v) if (v is int or v is float) else default


func _unit(cfg: ConfigFile, key: String, default: float) -> float:
	var v: Variant = cfg.get_value("options", key, default)
	return clampf(float(v), 0.0, 1.0) if (v is int or v is float) else default


func _int_array(cfg: ConfigFile, sec: String, key: String) -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	var v: Variant = cfg.get_value(sec, key, [])
	if v is Array:
		for i in mini(v.size(), 3):
			if v[i] is int or v[i] is float:
				out[i] = maxi(int(v[i]), 0)
	return out
