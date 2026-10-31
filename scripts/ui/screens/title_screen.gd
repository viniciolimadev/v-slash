class_name TitleScreen
extends Screen
## Tela inicial: jogar, tutorial, opções.

signal play_pressed
signal tutorial_pressed
signal options_pressed

var save: SaveData


func _init() -> void:
	screen_name = "title"


func _build() -> void:
	add_title("VÔLEI MOBILE", 64)
	if save != null and save.best_rally > 0:
		add_line("Recorde de rally: %d toques" % save.best_rally)
	add_space(18.0)
	add_button("JOGAR", "play", func() -> void: play_pressed.emit())
	add_button("TUTORIAL", "tutorial", func() -> void: tutorial_pressed.emit())
	add_button("OPÇÕES", "options", func() -> void: options_pressed.emit())
