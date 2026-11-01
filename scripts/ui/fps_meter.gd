class_name FpsMeter
extends CanvasLayer
## Mede os quadros da partida (RNF-4.01): fps médio e p1 (o fps do 1% de quadros mais lentos).
## Com  -- --fps  mostra um contador no canto; na Web publica em window.__vs.fps para o e2e.

const WINDOW := 600                 # quadros guardados (~10 s a 60 fps)

var show := false
var avg := 0.0
var p1 := 0.0

var _times := PackedFloat32Array()     # anel de WINDOW quadros
var _next := 0
var _label: Label
var _acc := 0.0


func _ready() -> void:
	layer = 20
	show = "--fps" in OS.get_cmdline_user_args()
	_label = Label.new()
	_label.position = Vector2(12.0, 84.0)
	_label.add_theme_font_size_override("font_size", 18)
	_label.visible = show
	add_child(_label)


func _process(delta: float) -> void:
	add_frame(delta)
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	measure()
	_label.text = "%d fps · p1 %d" % [roundi(avg), roundi(p1)]
	if E2eHooks.enabled():
		JavaScriptBridge.eval("(window.__vs = window.__vs || {}).fps = {avg: %.1f, p1: %.1f, frames: %d};"
				% [avg, p1, _times.size()], true)


## Registra um quadro de `dt` s (barato: as contas ficam para measure(), uma vez por segundo).
func add_frame(dt: float) -> void:
	if _times.size() < WINDOW:
		_times.append(dt)
	else:
		_times[_next] = dt
	_next = (_next + 1) % WINDOW


## Recalcula fps médio e p1 dos quadros guardados.
func measure() -> void:
	if _times.is_empty():
		return
	var total := 0.0
	for t in _times:
		total += t
	avg = _times.size() / maxf(total, 1e-6)
	var sorted := _times.duplicate()
	sorted.sort()
	var slow := sorted[clampi(int(sorted.size() * 0.99), 0, sorted.size() - 1)]     # quadro no limite do 1% mais lento
	p1 = 1.0 / maxf(slow, 1e-6)
