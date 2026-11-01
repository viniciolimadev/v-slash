class_name SaveData
extends RefCounted
## Progresso, recordes e opções em user://save.cfg (ConfigFile versionado).
## Arquivo ausente ou ilegível = valores padrão; nunca derruba o jogo.

const VERSION := 2                  # 2: tipo de saque nas opções (Fase 2)
const DEFAULT_PATH := "user://save.cfg"
const AIM_SENS_MIN := 0.5
const AIM_SENS_MAX := 2.0

var path: String
var unlocked_level := 0
var tutorial_done := false
var best_rally := 0
var wins: Array[int] = [0, 0, 0]
var losses: Array[int] = [0, 0, 0]
var aim_sens := 1.0                 # multiplicador de Tuning.AIM_SENS
var left_handed := false
var vibration := true
var serve_type := ServeType.Kind.UNDER   # último tipo de saque escolhido


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	# version > VERSION: lê o que entende; campos novos de versões futuras são ignorados
	unlocked_level = clampi(_int(cfg, "progress", "unlocked_level", 0), 0, 2)
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	best_rally = maxi(_int(cfg, "records", "best_rally", 0), 0)
	wins = _int_array(cfg, "records", "wins")
	losses = _int_array(cfg, "records", "losses")
	aim_sens = clampf(float(cfg.get_value("options", "aim_sens", 1.0)), AIM_SENS_MIN, AIM_SENS_MAX)
	left_handed = bool(cfg.get_value("options", "left_handed", false))
	vibration = bool(cfg.get_value("options", "vibration", true))
	# save versão 1 não tem o campo: fica o padrão
	serve_type = clampi(_int(cfg, "options", "serve_type", ServeType.Kind.UNDER), 0, ServeType.NAMES.size() - 1)


## Grava num arquivo temporário e troca de nome: um desligamento no meio não corrompe o save.
func save_file() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("records", "best_rally", best_rally)
	cfg.set_value("records", "wins", wins)
	cfg.set_value("records", "losses", losses)
	cfg.set_value("options", "aim_sens", aim_sens)
	cfg.set_value("options", "left_handed", left_handed)
	cfg.set_value("options", "vibration", vibration)
	cfg.set_value("options", "serve_type", serve_type)
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		return err
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		err = cfg.save(path)
	return err


## Registra uma partida terminada (não grava sozinho). Preenche r.unlocked.
func record_result(r: MatchResult) -> void:
	best_rally = maxi(best_rally, r.stats.best_rally)
	if r.winner != 0:
		losses[r.level] += 1
		return
	wins[r.level] += 1
	var next := mini(r.level + 1, 2)
	if next > unlocked_level:
		unlocked_level = next
		r.unlocked = next


func _int(cfg: ConfigFile, sec: String, key: String, default: int) -> int:
	var v: Variant = cfg.get_value(sec, key, default)
	return int(v) if (v is int or v is float) else default


func _int_array(cfg: ConfigFile, sec: String, key: String) -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	var v: Variant = cfg.get_value(sec, key, [])
	if v is Array:
		for i in mini(v.size(), 3):
			if v[i] is int or v[i] is float:
				out[i] = maxi(int(v[i]), 0)
	return out
