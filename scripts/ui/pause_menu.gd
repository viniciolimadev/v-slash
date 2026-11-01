class_name PauseMenu
extends CanvasLayer
## Menu de pausa por cima da partida. Roda com a árvore pausada (PROCESS_MODE_ALWAYS).

signal resume_pressed
signal restart_pressed
signal options_pressed
signal quit_pressed

var screen: Screen


func _init() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## in_app = aberta pelo App (há save e menu): mostra Opções e Sair.
func open(in_app: bool) -> void:
	if screen != null:
		screen.queue_free()
	screen = _PauseScreen.new()
	screen.menu = self
	screen.in_app = in_app
	add_child(screen)
	visible = true


func close() -> void:
	visible = false
	if screen != null:
		screen.queue_free()
		screen = null


class _PauseScreen extends Screen:
	var menu: PauseMenu
	var in_app := true

	func _init() -> void:
		screen_name = "pause"
		dim = true

	func _build() -> void:
		add_title("PAUSA", 52)
		add_space(8.0)
		add_button("CONTINUAR", "resume", func() -> void: menu.resume_pressed.emit())
		add_button("REINICIAR", "restart", func() -> void: menu.restart_pressed.emit())
		if in_app:
			add_button("OPÇÕES", "options", func() -> void: menu.options_pressed.emit())
			add_button("SAIR PARA O MENU", "quit", func() -> void: menu.quit_pressed.emit())
