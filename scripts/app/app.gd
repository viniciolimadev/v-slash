extends Node
## Raiz do app: troca entre as telas e a partida, e é o dono do save.
## Não é autoload de propósito: main.tscn continua rodando sozinha (testes, --autoplay).

const MATCH_SCENE := "res://scenes/main.tscn"

var save := SaveData.new()          # os testes trocam o caminho antes de adicionar o App
var screen: Control = null          # tela atual (null durante a partida)
var match_node: MatchScene = null

var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	save.load_file()
	if "--autoplay" in OS.get_cmdline_user_args():
		_open_match(MatchConfig.new())  # demo bot x bot direto, sem menus
		return
	show_title()


func show_title() -> void:
	var s := TitleScreen.new()
	s.save = save
	s.play_pressed.connect(show_level_select)
	s.tutorial_pressed.connect(func() -> void: start_tutorial(-1))
	s.options_pressed.connect(func() -> void: show_options(show_title))
	_show(s)


func show_level_select() -> void:
	var s := LevelSelectScreen.new()
	s.save = save
	s.level_chosen.connect(start_match)
	s.back_pressed.connect(show_title)
	_show(s)


func show_options(back: Callable) -> void:
	var s := OptionsScreen.new()
	s.save = save
	s.closed.connect(back)
	_show(s)


func show_result(r: MatchResult) -> void:
	var s := ResultScreen.new()
	s.result = r
	s.rematch_pressed.connect(func() -> void: start_match(r.level, r.mode))
	s.change_level_pressed.connect(show_level_select)
	s.menu_pressed.connect(show_title)
	_show(s)


## Abre uma partida. Na primeira vez, passa antes pelo tutorial.
func start_match(level: int, mode: int = MatchConfig.Mode.ONE_V_ONE) -> void:
	if not save.tutorial_done:
		start_tutorial(level, mode)
		return
	var m := _open_match(MatchConfig.from_save(save, level, mode))
	m.match_finished.connect(_on_match_finished)


## then_level = nível a jogar depois do tutorial (no modo then_mode); -1 = volta ao título.
func start_tutorial(then_level: int, then_mode: int = MatchConfig.Mode.ONE_V_ONE) -> void:
	var cfg := MatchConfig.from_save(save, 0)
	cfg.endless = true
	cfg.tutorial = true
	var m := _open_match(cfg)
	m.tutorial_finished.connect(func(_skipped: bool) -> void:
		save.tutorial_done = true
		save.save_file()
		if then_level >= 0:
			start_match(then_level, then_mode)
		else:
			show_title())


func _open_match(cfg: MatchConfig) -> MatchScene:
	_clear()
	var m: MatchScene = load(MATCH_SCENE).instantiate()
	m.config = cfg
	m.save = save
	m.exit_requested.connect(show_title)
	match_node = m
	add_child(m)
	E2eHooks.set_screen("tutorial" if cfg.tutorial else "match")
	return m


func _on_match_finished(r: MatchResult) -> void:
	save.record_result(r)
	save.save_file()
	show_result(r)


func _show(s: Control) -> void:
	_clear()
	screen = s
	_layer.add_child(s)


## Fecha a tela ou a partida atual (e despausa: sair pela pausa deixaria a árvore parada).
func _clear() -> void:
	get_tree().paused = false
	if screen != null:
		screen.queue_free()
		screen = null
	if match_node != null:
		match_node.queue_free()
		match_node = null
