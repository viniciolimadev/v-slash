class_name PrivacyScreen
extends Screen
## Opções → Privacidade (RF-5.05): o que é enviado, liga/desliga e "apagar meus dados".

signal toggled(allow: bool)
signal forget_pressed
signal closed

var save: SaveData


func _init() -> void:
	screen_name = "privacy"


func _build() -> void:
	add_title(tr("PRIVACIDADE"), 46)
	add_line(tr("Enviado ao fim da partida: versão, plataforma, modo, nível, placar, duração,"), 22)
	add_line(tr("rally, % de perfeitos, motivos dos pontos, saques, bloqueios, peixinhos e 2 opções."), 22)
	add_line(tr("Com um id aleatório deste aparelho, que muda quando você apaga os dados."), 22, Color(1.0, 0.92, 0.7))
	var send := add_button("", "send", func() -> void: pass)
	send.toggle_mode = true
	send.button_pressed = save.consent == 1
	var label_for := func(v: bool) -> void:
		send.text = "%s: %s" % [tr("Enviar estatísticas"), tr("LIGADO") if v else tr("DESLIGADO")]
	label_for.call(send.button_pressed)
	send.toggled.connect(func(v: bool) -> void:
		label_for.call(v)
		toggled.emit(v))
	add_button(tr("APAGAR MEUS DADOS"), "forget", func() -> void: forget_pressed.emit())
	add_button(tr("POLÍTICA DE PRIVACIDADE"), "policy", func() -> void: OS.shell_open(Telemetry.PRIVACY_URL))
	add_button(tr("VOLTAR"), "back", func() -> void: closed.emit())
