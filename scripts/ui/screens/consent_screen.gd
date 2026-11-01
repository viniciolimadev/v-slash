class_name ConsentScreen
extends Screen
## Primeira abertura (RF-5.03): pergunta se pode enviar estatísticas anônimas. Padrão = não
## (fechar o app sem escolher pergunta de novo). Dá para mudar depois em Opções → Privacidade.

signal chosen(allow: bool)


func _init() -> void:
	screen_name = "consent"


func _build() -> void:
	add_title(tr("Estatísticas anônimas"), 46)
	add_line(tr("Podemos enviar, ao fim de cada partida, números do jogo (duração, placar, rally,"), 24)
	add_line(tr("onde os pontos foram perdidos) para equilibrar os bots? Nada pessoal nem do aparelho."), 24)
	add_line(tr("Você pode desligar ou apagar tudo em Opções → Privacidade."), 22, Color(1.0, 0.92, 0.7))
	add_space(6.0)
	add_button(tr("NÃO ENVIAR"), "no", func() -> void: chosen.emit(false))
	add_button(tr("PODE ENVIAR"), "yes", func() -> void: chosen.emit(true))
