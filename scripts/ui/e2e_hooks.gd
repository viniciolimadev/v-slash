class_name E2eHooks
extends RefCounted
## Só na versão Web: publica em window.__vs a tela atual e onde ficam os botões
## (em pixels CSS da página), para o teste e2e tocar neles sem adivinhar coordenadas.


static func enabled() -> bool:
	return OS.has_feature("web")


static func set_screen(screen_name: String) -> void:
	if enabled():
		JavaScriptBridge.eval("(window.__vs = window.__vs || {}).screen = '%s';" % screen_name, true)


## Registra o centro de um controle com a chave `key` (ex.: "title/play").
## Espera o layout do quadro atual antes de medir.
static func publish(key: String, ctrl: Control) -> void:
	if not enabled() or ctrl == null:
		return
	await ctrl.get_tree().process_frame
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	var c := ctrl.get_viewport().get_final_transform() * ctrl.get_global_rect().get_center()
	JavaScriptBridge.eval(
			"(window.__vs = window.__vs || {})['%s'] = {x: %f / devicePixelRatio, y: %f / devicePixelRatio};"
			% [key, c.x, c.y], true)
