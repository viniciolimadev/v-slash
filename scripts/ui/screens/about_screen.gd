class_name AboutScreen
extends Screen
## Sobre (RF-5.09): versão, créditos (resumo do CREDITS.md) e política de privacidade.

signal closed


func _init() -> void:
	screen_name = "about"


func _build() -> void:
	add_title("VÔLEI MOBILE", 52)
	add_line(tr("Versão %s") % str(ProjectSettings.get_setting("application/config/version", "")), 26, Color.WHITE)
	add_line(tr("Jogo, modelos, sons e músicas: Vinicio Lima (feitos por código)"), 22)
	add_line(tr("Fonte Fredoka (SIL Open Font License) · Motor Godot Engine (MIT)"), 22)
	add_space(6.0)
	add_button(tr("POLÍTICA DE PRIVACIDADE"), "policy", func() -> void: OS.shell_open(Telemetry.PRIVACY_URL))
	add_button(tr("VOLTAR"), "back", func() -> void: closed.emit())
