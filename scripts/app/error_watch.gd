class_name ErrorWatch
extends Logger
## Pega erros de script em produção (RF-5.06): o App instala com OS.add_logger e, a cada quadro,
## lê o que chegou. O Godot pode chamar _log_error de outra thread: só guarda, com trava.

const MAX_PER_SESSION := 5          # relatórios por sessão (um erro em loop não vira enxurrada)

var _mutex := Mutex.new()
var _pending: Array[Dictionary] = []
var _seen := 0


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	# só erros do nosso código (os do motor/driver não derrubam a partida)
	if error_type != ERROR_TYPE_SCRIPT or not file.begins_with("res://scripts"):
		return
	_mutex.lock()
	if _seen < MAX_PER_SESSION:
		_seen += 1
		_pending.append({"message": (rationale if rationale != "" else code).left(300),
				"where": "%s:%d (%s)" % [file.trim_prefix("res://"), line, function]})
	_mutex.unlock()


## Erros novos desde a última chamada.
func take() -> Array[Dictionary]:
	_mutex.lock()
	var out := _pending
	_pending = []
	_mutex.unlock()
	return out
