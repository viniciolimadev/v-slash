class_name Telemetry
extends RefCounted
## Estatísticas opcionais e anônimas (RF-5.03/5.04, SDD-fase-5 4.4). Só registra com consentimento
## (save.consent == 1); guarda até MAX_QUEUE eventos em disco e envia em lote quando há rede e
## URL configurada (ProjectSettings "volei/telemetry_url", injetada pelo CI na release).
## Nada de dado pessoal nem do aparelho: só o id aleatório local, a versão e a plataforma.

const VERSION := 1
const PRIVACY_URL := "https://viniciolimadev.github.io/v-slash/privacidade/"
const MAX_QUEUE := 50
const DEFAULT_QUEUE := "user://telemetry_queue.json"
## Campos exatos do evento match_end (o teste e a política de privacidade conferem esta lista).
const MATCH_FIELDS := ["v", "install_id", "app", "platform", "event", "mode", "level", "won", "sets", "duration_s",
		"rally_avg", "rally_best", "perfect_rate", "points_lost_by", "serve_types", "blocks", "dives", "options"]

var save: SaveData
var url := ""
var queue: Array = []
var queue_path := DEFAULT_QUEUE
var sending := 0                    # eventos no lote em voo (0 = nenhum envio pendente)
var sent_total := 0


func _init(p_save: SaveData, p_queue_path := DEFAULT_QUEUE) -> void:
	save = p_save
	queue_path = p_queue_path
	url = str(ProjectSettings.get_setting("volei/telemetry_url", "")).trim_suffix("/")
	_load_queue()


func enabled() -> bool:
	return save.consent == 1 and save.install_id != ""


## Liga/desliga o consentimento. Ligar cria o id aleatório; desligar descarta a fila.
func set_consent(on: bool) -> void:
	save.consent = 1 if on else 0
	if on and save.install_id == "":
		save.install_id = new_id()
	if not on:
		save.install_id = ""
		queue.clear()
		_save_queue()
	save.save_file()


## "Apagar meus dados": descarta a fila, pede ao servidor para apagar o id antigo e troca de id.
## Devolve o corpo do pedido de exclusão (vazio se não havia id).
func forget() -> Dictionary:
	var old := save.install_id
	queue.clear()
	_save_queue()
	save.install_id = new_id() if save.consent == 1 else ""
	save.save_file()
	return {"v": VERSION, "install_id": old} if old != "" else {}


func record(event: Dictionary) -> void:
	if not enabled():
		return
	queue.append(event)
	while queue.size() > MAX_QUEUE:
		queue.pop_front()           # sem rede por muito tempo: ficam os mais novos
	_save_queue()


## Base comum de todo evento.
func base(event_name: String) -> Dictionary:
	return {"v": VERSION, "install_id": save.install_id, "app": str(ProjectSettings.get_setting("application/config/version", "")),
			"platform": platform(), "event": event_name}


func session_start() -> Dictionary:
	var e := base("session_start")
	e["lang"] = TranslationServer.get_locale()
	return e


func tutorial_end(skipped: bool, fails_by_step: Array[int]) -> Dictionary:
	var e := base("tutorial_end")
	e["skipped"] = skipped
	var worst := -1
	for i in fails_by_step.size():
		if fails_by_step[i] > 0 and (worst < 0 or fails_by_step[i] > fails_by_step[worst]):
			worst = i
	e["worst_step"] = worst + 1         # 1..3; 0 = não errou
	return e


## Evento de fim de partida (time 0 = você). Exatamente os campos de MATCH_FIELDS.
func match_end(r: MatchResult) -> Dictionary:
	var st := r.stats
	var e := base("match_end")
	var sets: Array = []
	for s in r.sets:
		sets.append([s.x, s.y])
	e.merge({
		"mode": str(SaveData.MODE_KEYS[r.mode]), "level": r.level, "won": r.winner == 0, "sets": sets,
		"duration_s": roundi(st.duration()), "rally_avg": snappedf(st.rally_avg(), 0.1), "rally_best": st.best_rally,
		"perfect_rate": snappedf(st.perfect_rate(0), 0.01), "points_lost_by": st.points_by_reason[1].duplicate(),
		"serve_types": (st.serves[0] as Array).duplicate(), "blocks": st.blocks[0], "dives": st.dives[0],
		"options": {"left_handed": save.left_handed, "aim_sens": snappedf(save.aim_sens, 0.1)},
	})
	return e


## Manda a fila num POST (lote). false = nada a fazer (sem URL, fila vazia ou envio em andamento).
func flush(http: HTTPRequest) -> bool:
	if url == "" or queue.is_empty() or sending > 0 or not enabled():
		return false
	var batch := queue.duplicate()
	if http.request(url + "/v1/events", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
			JSON.stringify(batch)) != OK:
		return false
	sending = batch.size()
	return true


## Resposta do envio: 2xx tira o lote da fila; erro de rede ou do servidor tenta depois.
func on_sent(result: int, code: int) -> void:
	if sending > 0 and result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		queue = queue.slice(mini(sending, queue.size()))
		sent_total += sending
		_save_queue()
	sending = 0


static func platform() -> String:
	if OS.has_feature("web"):
		return "web"
	return OS.get_name().to_lower()


## UUID v4 aleatório (não deriva de nada do aparelho).
static func new_id() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


func _load_queue() -> void:
	if not FileAccess.file_exists(queue_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(queue_path))
	if data is Array:
		queue = (data as Array).slice(maxi((data as Array).size() - MAX_QUEUE, 0))


func _save_queue() -> void:
	var f := FileAccess.open(queue_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(queue))
