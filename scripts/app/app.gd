extends Node
## Raiz do app: troca entre as telas e a partida, e é o dono do save.
## Não é autoload de propósito: main.tscn continua rodando sozinha (testes, --autoplay).

const MATCH_SCENE := "res://scenes/main.tscn"

var save := SaveData.new()          # os testes trocam o caminho antes de adicionar o App
var screen: Control = null          # tela atual (null durante a partida)
var match_node: MatchScene = null

var music: AudioStreamPlayer        # música do menu (a partida tem a sua, no Sfx)
var telemetry: Telemetry            # estatísticas opcionais (só com consentimento)
var http: HTTPRequest               # envio dos eventos
var http_delete: HTTPRequest        # pedido de exclusão (separado: pode coincidir com um envio)

var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	save.load_file()
	Sfx.apply_volumes(save.music_vol, save.sfx_vol)
	Lang.apply(save.lang)
	_setup_audio()
	_setup_telemetry()
	if "--autoplay" in OS.get_cmdline_user_args():
		_open_match(MatchConfig.new())  # demo bot x bot direto, sem menus
		return
	if save.consent < 0:
		show_consent()
	else:
		telemetry.record(telemetry.session_start())
		show_title()


func show_title() -> void:
	var s := TitleScreen.new()
	s.save = save
	s.play_pressed.connect(show_level_select)
	s.tutorial_pressed.connect(func() -> void: start_tutorial(-1))
	s.options_pressed.connect(func() -> void: show_options(show_title))
	s.about_pressed.connect(show_about)
	_show(s)
	telemetry.flush(http)


## Primeira abertura: pode enviar estatísticas anônimas? (padrão: não)
func show_consent() -> void:
	var s := ConsentScreen.new()
	s.chosen.connect(func(allow: bool) -> void:
		telemetry.set_consent(allow)
		telemetry.record(telemetry.session_start())
		show_title())
	_show(s)


func show_about() -> void:
	var s := AboutScreen.new()
	s.closed.connect(show_title)
	_show(s)


func show_privacy(back: Callable) -> void:
	var s := PrivacyScreen.new()
	s.save = save
	s.toggled.connect(func(allow: bool) -> void: telemetry.set_consent(allow))
	s.forget_pressed.connect(forget_data)
	s.closed.connect(back)
	_show(s)


## Apagar meus dados (RF-5.05): fila descartada, pedido de exclusão do id antigo, id novo.
func forget_data() -> void:
	var body := telemetry.forget()
	if telemetry.url != "" and not body.is_empty():
		http_delete.request(telemetry.url + "/v1/delete", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
				JSON.stringify(body))


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
	# trocar o idioma remonta a tela para os textos mudarem na hora
	s.lang_changed.connect(func() -> void: show_options(back))
	s.privacy_pressed.connect(func() -> void: show_privacy(func() -> void: show_options(back)))
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
	m.tutorial_finished.connect(func(skipped: bool) -> void:
		telemetry.record(telemetry.tutorial_end(skipped, m.tutorial.fails_by_step))
		save.tutorial_done = true
		save.save_file()
		if then_level >= 0:
			start_match(then_level, then_mode)
		else:
			show_title())


func _open_match(cfg: MatchConfig) -> MatchScene:
	_clear()
	music.stop()
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
	telemetry.record(telemetry.match_end(r))
	telemetry.flush(http)
	show_result(r)


func _show(s: Control) -> void:
	_clear()
	if not music.playing:
		music.play()
	screen = s
	_layer.add_child(s)


func _setup_telemetry() -> void:
	var queue := Telemetry.DEFAULT_QUEUE if save.path == SaveData.DEFAULT_PATH else save.path + ".queue.json"
	telemetry = Telemetry.new(save, queue)
	http = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		telemetry.on_sent(result, code))
	http_delete = HTTPRequest.new()
	http_delete.timeout = 10.0
	add_child(http_delete)


## Música do menu e o clique dos botões (as telas tocam pelo grupo "ui_click").
func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music.bus = &"Music"
	music.volume_db = -6.0
	var path := "res://assets/audio/music/menu.ogg"
	if ResourceLoader.exists(path):
		var s: AudioStreamOggVorbis = load(path)
		s.loop = true
		music.stream = s
	add_child(music)
	var click := AudioStreamPlayer.new()
	click.bus = &"SFX"
	click.volume_db = -8.0
	click.process_mode = Node.PROCESS_MODE_ALWAYS     # também no menu de pausa
	if ResourceLoader.exists("res://assets/audio/sfx/ui_click.ogg"):
		click.stream = load("res://assets/audio/sfx/ui_click.ogg")
	click.add_to_group("ui_click")
	add_child(click)


## Fecha a tela ou a partida atual (e despausa: sair pela pausa deixaria a árvore parada).
func _clear() -> void:
	get_tree().paused = false
	if screen != null:
		screen.queue_free()
		screen = null
	if match_node != null:
		match_node.queue_free()
		match_node = null
