# SDD detalhado — Fase 1: Partida de verdade (1v1)

Complementa o [SDD geral](SDD.md) (seção 9.1) e o [ROADMAP](ROADMAP.md). Aqui está o design **no nível de implementação**: classes, assinaturas, sinais, arquivos, ordem dos PRs e testes.

| | |
|---|---|
| Versão | 1.0 — 2026-10-31 |
| Base | `main` @ 98d6898 (Fase 0) |
| Decisões já tomadas | 3 toques no 1v1 · melhor de 3 sets de 15, vantagem de 2 (DP-01, DP-02) |

---

## 1. Objetivo e escopo

**Meta:** o jogo deixa de ser um rally infinito e vira uma partida com começo, meio e fim, que dá vontade de pedir revanche.

**Dentro:**
1. Limite de toques explícito (`MAX_TOUCHES`) e plano de contato tipado (`ContactPlan`).
2. Partida em sets (regras, placar, set point / match point).
3. Estatísticas da partida.
4. Save local (progresso, recordes, opções).
5. Fluxo de telas: título, escolha do bot, partida, pausa, resultado.
6. Opções: sensibilidade da mira, modo canhoto, vibração.
7. Tutorial jogável na primeira vez.

**Fora (vai para outras fases):** tipos de saque e timing no saque (F2), 2v2 (F3), arte, som e fontes finais (F4). As telas da F1 usam o tema padrão do Godot e formas simples (ADR-03: tudo construído por código).

---

## 2. Requisitos

### 2.1 Funcionais

| ID | Requisito | Fatia |
|---|---|---|
| RF-1.01 | Cada lado tem no máximo `MAX_TOUCHES` (= 3) toques; o 4º não gera plano e a bola cai. | 1.1 |
| RF-1.02 | Set termina ao chegar a 15 com 2 de vantagem (sem teto: 16–14, 17–15...). | 1.2 |
| RF-1.03 | Partida termina quando um time vence 2 sets. | 1.2 |
| RF-1.04 | Saque é de quem fez o ponto (rally point). O 1º saque de cada set alterna: set 1 = você, set 2 = bot, set 3 = você. | 1.2 |
| RF-1.05 | HUD mostra pontos do set, sets vencidos, e o selo **SET POINT** / **MATCH POINT** para quem está a um ponto. | 1.2 |
| RF-1.06 | Fim de set mostra faixa "Fim do 1º set — 15 × 12" por 3 s antes do saque seguinte. | 1.2 |
| RF-1.07 | Ao fim da partida o jogo vai para a tela de resultado com placar de cada set e estatísticas. | 1.3 / 1.5 |
| RF-1.08 | Estatísticas por time: toques, perfeitos, bons, erros de timing, "longe", pontos por motivo, maior rally; % de perfeitos do humano. | 1.3 |
| RF-1.09 | Progresso salvo localmente e sobrevive a fechar o app (Android e Web). | 1.4 |
| RF-1.10 | Médio liberado após vencer o Fácil; Difícil após vencer o Médio. Níveis bloqueados aparecem com cadeado. | 1.4 / 1.5 |
| RF-1.11 | Telas: Título → Escolher bot → Partida → Resultado (Revanche / Trocar bot / Menu). | 1.5 |
| RF-1.12 | Pausa por botão no HUD, pelo voltar do Android e automaticamente quando o app perde o foco. Pausa oferece Continuar, Reiniciar, Opções, Sair para o menu. | 1.5 |
| RF-1.13 | Opções: sensibilidade da mira (50%–200%), modo canhoto, vibração liga/desliga. Valem na hora, inclusive com a partida pausada. | 1.6 |
| RF-1.14 | Tutorial em 3 passos (andar até o anel · soltar no tempo · mirar uma zona) roda automaticamente na primeira partida, pode ser pulado e pode ser revisto pelo título. | 1.7 |
| RF-1.15 | `-- --autoplay` e a cena `main.tscn` sozinha continuam funcionando (demo e testes), em rally infinito. | todas |

### 2.2 Não funcionais

| ID | Requisito | Meta |
|---|---|---|
| RNF-1.01 | Duração de partida humana contra o Fácil | **6–9 min em média** (simulação "humano casual"). Era 4–7; medido 7,8 min (8 partidas; 2 sets ≈ 6–7 min, 3 sets ≈ 9–11 min) e o dono aceitou a duração (DP-05). |
| RNF-1.02 | Troca de tela | < 300 ms; sem recarregar o motor |
| RNF-1.03 | Save | nunca corrompe: grava em arquivo temporário e renomeia; arquivo ilegível = padrões, sem crash |
| RNF-1.04 | Botões de tela | alvo de toque ≥ 64 px de altura em 720 p |
| RNF-1.05 | Regressão | todos os testes da Fase 0 continuam passando sem afrouxar limites |

---

## 3. Visão da arquitetura da Fase 1

### 3.1 Árvore de nós (depois da Fase 1)

```
App (scenes/app.tscn, NOVO main_scene)      scripts/app/app.gd
├── ScreenLayer (CanvasLayer 10)
│   └── <tela atual>  TitleScreen | LevelSelectScreen | ResultScreen | OptionsScreen
└── Match (scenes/main.tscn, instanciada sob demanda)   scripts/main.gd
    ├── WorldEnvironment, DirectionalLight3D, Court, Camera3D
    ├── Player ×2, Ball, Game, Markers
    ├── CanvasLayer 1 → TouchControls
    ├── Hud (CanvasLayer 2)
    ├── PauseMenu (CanvasLayer 5, process_mode = ALWAYS)         NOVO
    └── TutorialDirector (só no tutorial)                        NOVO
```

**Por que um nó raiz `App` e não um autoload:** os testes rodam com `godot --headless --script`, que instancia `main.tscn` direto. Sem autoload, `main.gd` não depende de estado global: recebe tudo por um `MatchConfig` antes de entrar na árvore — exatamente como hoje recebe `autoplay`. `App` é só um roteador.

### 3.2 Novos arquivos

```
scenes/app.tscn                     raiz do app (só o nó com app.gd)
scripts/app/app.gd                  roteador de telas, dono do SaveData
scripts/app/match_config.gd         MatchConfig: parâmetros de uma partida
scripts/core/contact_plan.gd        ContactPlan: plano de contato tipado
scripts/core/match_rules.gd         MatchRules: pontos, sets, fim de partida
scripts/core/match_stats.gd         MatchStats: estatísticas por sinais
scripts/core/match_result.gd        MatchResult: o que a tela de resultado mostra
scripts/core/save_data.gd           SaveData: ConfigFile versionado
scripts/ui/screens/screen.gd        base comum das telas (layout, botões grandes)
scripts/ui/screens/title_screen.gd
scripts/ui/screens/level_select_screen.gd
scripts/ui/screens/result_screen.gd
scripts/ui/screens/options_screen.gd
scripts/ui/pause_menu.gd
scripts/tutorial/tutorial_director.gd
```

Arquivos alterados: `game.gd`, `bot_brain.gd`, `main.gd`, `markers.gd`, `hud.gd`, `touch_controls.gd`, `tuning.gd`, `project.godot` (`run/main_scene`), `tests/run_tests.gd`, `tests/e2e/mobile_smoke.js`, `README.md`.

### 3.3 Fluxo de dados

```
            ┌────────── SaveData (user://save.cfg) ──────────┐
            │                                                │ record_result()
            ▼                                                │
App ── MatchConfig ──▶ Match(main.gd) ──▶ Game ──sinais──▶ MatchStats
 ▲                         │               │ └─ rules: MatchRules
 │                         │               └──sinais──▶ Hud, main (vibração/popup)
 └── match_finished(MatchResult) / exit_requested ──┘
```

---

## 4. Design por fatia

### 4.1 Fatia 1.1 — `ContactPlan` e `MAX_TOUCHES` (refatoração, sem mudar comportamento)

**`scripts/core/contact_plan.gd`**

```gdscript
class_name ContactPlan
extends RefCounted
## Quem toca a próxima bola, com qual ação, onde (anel) e quando (tempo ideal).

var team: int
var n: int              # 1º, 2º ou 3º toque do lado
var act: int            # Game.Act
var t: float            # tempo ideal (relógio de Game.time)
var pos: Vector3        # centro da bola no contato
var player: Player


func _init(p_team: int, p_n: int, p_act: int, p_t: float, p_pos: Vector3, p_player: Player) -> void:
	...
```

**Mudanças em `Game`:**
- `var plan: ContactPlan = null` (era `Dictionary`). Todo `plan.is_empty()` vira `plan == null`; `plan["pos"]` vira `plan.pos`.
- `_make_plan`: `if n > Tuning.MAX_TOUCHES: return`.
- Sem outra mudança de lógica.

**Chamadores a atualizar:** `bot_brain.gd` (`tick`), `markers.gd` (`refresh`), `tests/run_tests.gd` (`_test_scripted_human`, `_test_aim`).

**`Tuning`:** `const MAX_TOUCHES := 3  # toques por lado (o mesmo jogador no 1v1)`.

**Pronto quando:** testes da Fase 0 passam idênticos; nenhum `plan[` sobra no código (`grep`).

---

### 4.2 Fatia 1.2 — `MatchRules`, placar em sets

**`scripts/core/match_rules.gd`**

```gdscript
class_name MatchRules
extends RefCounted
## Pontos e sets. set_points = 0 → rally infinito (demo, testes, tutorial).

var set_points: int
var sets_to_win: int
var win_by: int
var points: Array[int] = [0, 0]      # do set atual
var sets: Array[int] = [0, 0]
var set_index := 0                   # 0, 1, 2
var history: Array[Vector2i] = []    # placar final de cada set (x = time 0)
var winner := -1                     # time vencedor da partida (-1 = em andamento)
var set_closed := false              # set acabou e o próximo ainda não começou (sem selo, sem ponto)


func _init(p_set_points := Tuning.SET_POINTS, p_sets_to_win := Tuning.SETS_TO_WIN,
		p_win_by := Tuning.WIN_BY) -> void: ...

## Registra um ponto. Retorna {"set_over": bool, "match_over": bool}.
func add_point(team: int) -> Dictionary: ...

func is_endless() -> bool: return set_points <= 0
func is_set_point(team: int) -> bool: ...    # mais um ponto fecha o set
func is_match_point(team: int) -> bool: ...  # is_set_point e sets[team] == sets_to_win - 1
func first_server(idx: int) -> int: return idx % 2   # set 1 você, set 2 bot, set 3 você
func start_next_set() -> void: ...           # zera points, set_index += 1
```

Regra de `add_point(team)`:
1. `points[team] += 1`.
2. Se não é infinito e `points[team] >= set_points` e `points[team] - points[1-team] >= win_by`: `sets[team] += 1`, `history.append(...)`, `set_over = true`.
3. Se `sets[team] == sets_to_win`: `winner = team`, `match_over = true`.

**Mudanças em `Game`:**

```gdscript
signal set_over(team: int, set_index: int, final: Vector2i)
signal match_over(team: int)

enum State { SERVE_WAIT, PLAY, POINT_PAUSE, MATCH_OVER }

var rules := MatchRules.new(0)        # infinito por padrão; main.gd troca pela config
```

- `score` deixa de existir; quem lia `game.score` passa a ler `game.rules.points` (HUD, testes).
- `_award(team, reason)`:
  1. Como hoje até `point_scored.emit(team, reason)`.
  2. `var r := rules.add_point(team)`.
  3. `match_over` → `state = MATCH_OVER`, `match_over.emit(team)`; não agenda saque.
  4. `set_over` → `set_over.emit(...)`, `_pause_t = Tuning.SET_PAUSE`, `_next_server = rules.first_server(rules.set_index + 1)`, marca `_set_break = true`.
  5. Senão `_pause_t = Tuning.POINT_PAUSE`, `_next_server = team`.
- Fim da pausa em `tick`: se `_set_break`, `rules.start_next_set()`; depois `_reset_for_serve(_next_server)`.
- `reset_match()`: `rules = MatchRules.new(rules.set_points, rules.sets_to_win, rules.win_by)`, `_reset_for_serve(rules.first_server(0))`.
- Em `MATCH_OVER`, `tick` continua andando jogadores e bola (quique visual), mas `attempt_hit` recusa e bots ficam parados.

**`Tuning`:**

```gdscript
# --- Partida ---
const SET_POINTS := 15
const SETS_TO_WIN := 2
const WIN_BY := 2
const POINT_PAUSE := 1.8           # s entre pontos (era fixo em _award)
const SET_PAUSE := 3.0             # s de faixa "Fim do set"
```

**HUD (`hud.gd`):**
- `set_board(rules: MatchRules, rally: int, best: int)`; placar `VOCÊ 12 × 9 BOT`, abaixo `Sets 1 – 0` (oculto em modo infinito).
- `set_badge(text: String, color: Color)` — selo fixo sob o placar: "SET POINT" (amarelo) / "MATCH POINT" (laranja), cor do time; vazio quando nenhum.
- `banner(text: String, secs: float)` — faixa grande central (fim de set).
- Botões do topo (PR 5): "Reiniciar" e "Bot: X" saem; entra um botão **II** (pausa) no canto esquerdo. Em modo infinito sem `App` (F5 em `main.tscn`), o botão de nível continua, para não perder o atalho de ajuste.

**Pronto quando:** testes de `MatchRules` (seção 6) passam; partida bot × bot com regras reais termina.

---

### 4.3 Fatia 1.3 — `MatchStats` e `MatchResult`

`MatchStats` não mexe em `Game`: só assina os sinais. Fica com `main.gd`.

```gdscript
class_name MatchStats
extends RefCounted

var touches: Array[int] = [0, 0]
var perfect: Array[int] = [0, 0]
var good: Array[int] = [0, 0]
var timing_errors: Array[int] = [0, 0]    # whiff CEDO/TARDE + toques com grau CEDO/TARDE
var far: Array[int] = [0, 0]              # whiff LONGE
var points_by_reason := [{}, {}]          # {"Bola no chão": 7, "Fora": 3, ...}
var best_rally := 0
var started_at := 0.0                     # Game.time no início
var ended_at := 0.0


func attach(game: Game) -> void           # conecta touch_made, whiffed, point_scored, match_over
func perfect_rate(team: int) -> float     # perfect / max(touches sem saque, 1)
func duration() -> float
```

Para saber o time no `whiffed`/`touch_made`, usa `player.team`. Saque não entra em `touches`.

```gdscript
class_name MatchResult
extends RefCounted

var winner: int
var level: int
var sets: Array[Vector2i]
var stats: MatchStats
var tutorial := false
```

---

### 4.4 Fatia 1.4 — `SaveData`

```gdscript
class_name SaveData
extends RefCounted

const VERSION := 1
const DEFAULT_PATH := "user://save.cfg"

var path: String
var unlocked_level := 0
var tutorial_done := false
var best_rally := 0
var wins: Array[int] = [0, 0, 0]
var losses: Array[int] = [0, 0, 0]
var aim_sens := 1.0                 # multiplicador, 0.5..2.0
var left_handed := false
var vibration := true


func _init(p_path := DEFAULT_PATH) -> void
func load_file() -> void            # ausente/ilegível → padrões; version antiga → _migrate()
func save_file() -> Error           # grava em path + ".tmp" e renomeia (DirAccess.rename_absolute)
func record_result(r: MatchResult) -> void
	# win: wins[level] += 1; unlocked_level = max(unlocked_level, mini(level + 1, 2))
	# derrota: losses[level] += 1
	# best_rally = max(...); não salva sozinho
```

Formato (`ConfigFile`):

```ini
[meta]
version=1
[progress]
unlocked_level=0
tutorial_done=false
[records]
best_rally=0
wins=[0, 0, 0]
losses=[0, 0, 0]
[options]
aim_sens=1.0
left_handed=false
vibration=true
```

Leitura sempre com `cfg.get_value(sec, key, padrão)` e validação de tipo/limite (`clampi`, `clampf`). Testes usam `SaveData.new("user://test_save.cfg")` e apagam o arquivo no fim.

---

### 4.5 Fatia 1.5 — `App`, `MatchConfig`, telas e pausa

**`MatchConfig`**

```gdscript
class_name MatchConfig
extends RefCounted

var bot_level := 0
var endless := true               # main.tscn sozinha / --autoplay / testes
var tutorial := false
var aim_sens := 1.0
var left_handed := false
var vibration := true


static func from_save(save: SaveData, level: int) -> MatchConfig  # endless = false
```

**`main.gd` (partida):**

```gdscript
signal match_finished(result: MatchResult)
signal exit_requested                       # "Sair para o menu"

var config: MatchConfig = null              # definido por App antes de add_child; null = padrão
var stats: MatchStats
var pause_menu: PauseMenu
```

- `_ready`: `if config == null: config = MatchConfig.new()`; aplica `game.set_bot_level(config.bot_level)`, `game.rules = MatchRules.new(0 if config.endless else Tuning.SET_POINTS)`, `game.aim_sens = config.aim_sens`, `controls.left_handed = config.left_handed`.
- Ouve `game.match_over` → espera 2,0 s (comemoração, quique da bola) → monta `MatchResult` → `match_finished.emit(r)`.
- Ouve `game.set_over` → `hud.banner("Fim do %dº set — %d × %d" ...)`.
- Vibração só se `config.vibration`.
- **Pausa:** `_notification(what)`: `NOTIFICATION_APPLICATION_FOCUS_OUT` e `NOTIFICATION_APPLICATION_PAUSED` → `pause()`; `NOTIFICATION_WM_GO_BACK_REQUEST` → alterna pausa. Botão II do HUD → `pause()`. `pause()` = `get_tree().paused = true` + `pause_menu.show()`; ao pausar, `game.human_release` não é chamado — `human_aiming` é cancelado (`game.cancel_aim()`), para não disparar um toque ao voltar.
- `project.godot`: `application/config/quit_on_go_back=false` (o voltar do Android pausa em vez de fechar).

**`Game` (ajuste para opções):** `var aim_sens := 1.0`; `human_drag` usa `Tuning.AIM_SENS * aim_sens`. `func cancel_aim()` zera `human_aiming` e `holding` do humano.

**`PauseMenu`** (CanvasLayer 5, `process_mode = PROCESS_MODE_ALWAYS`): fundo escuro 60%, botões **Continuar · Reiniciar · Opções · Sair para o menu**. Sinais `resume_pressed`, `restart_pressed`, `options_pressed`, `quit_pressed`. Opções abre `OptionsScreen` por cima, também `ALWAYS`.

**`App` (`scripts/app/app.gd`):**

```gdscript
extends Node

var save := SaveData.new()
var _screen: Control = null
var _match: Node = null
var _last_level := 0


func _ready() -> void:                 # save.load_file(); show_title()
func show_title() -> void
func show_level_select() -> void
func start_match(level: int) -> void   # tutorial primeiro se !save.tutorial_done
func start_tutorial(then_level: int) -> void
func show_result(r: MatchResult) -> void
func show_options(back: Callable) -> void
```

- Trocar de tela = liberar a anterior (`queue_free`) e instanciar a nova; a partida é liberada ao sair dela. `get_tree().paused = false` em toda troca.
- `start_match`: `var m := load("res://scenes/main.tscn").instantiate()`, `m.config = MatchConfig.from_save(save, level)`, conecta `match_finished` e `exit_requested`, `add_child(m)`.
- `match_finished(r)`: `save.record_result(r)`, `save.save_file()`, `show_result(r)`.

**Telas** (todas `extends Screen`, construídas por código, ancoradas em tela cheia, botões ≥ 64 px):

| Tela | Conteúdo | Ações |
|---|---|---|
| `TitleScreen` | nome do jogo, recorde de rally | **Jogar** → escolher bot · **Tutorial** · **Opções** |
| `LevelSelectScreen` | 3 cartões Fácil/Médio/Difícil com vitórias/derrotas; bloqueados com cadeado e "Vença o X para liberar" | cartão liberado → `start_match(level)` · **Voltar** |
| `ResultScreen` | "VOCÊ VENCEU!" / "O BOT VENCEU", placar dos sets, duração, maior rally, % perfeitos, pontos por motivo, "Médio liberado!" se for o caso | **Revanche** (mesmo nível) · **Trocar bot** · **Menu** |
| `OptionsScreen` | slider de sensibilidade 50–200% (passo 10), alternador canhoto, alternador vibração | **Voltar** (salva) |

**`TouchControls`:** `var left_handed := false`. A decisão "joystick ou botão" passa a usar `_is_move_side(x)` = `x < meio` (ou `>` se canhoto); `_joy_home` e `_button_center` espelham. Faixa `TOP_BAR` continua reservada.

---

### 4.6 Fatia 1.6 — Opções ao vivo
`OptionsScreen` recebe o `SaveData` e um `Callable` de retorno. Ao mudar qualquer valor: atualiza o save e, se houver partida aberta, chama `match.apply_options(save)` → atualiza `game.aim_sens`, `controls.left_handed` (+ `queue_redraw`) e `config.vibration`. Salva no **Voltar**.

---

### 4.7 Fatia 1.7 — Tutorial

Roda numa partida com `config.tutorial = true`, `endless = true`, **sem bot do time 1** (`bots` vazio; o adversário fica parado no fundo).

**Novo em `Game`:**

```gdscript
## Lança uma bola "de treino" do lado do time 1 para o time 0, como se o
## adversário tivesse atacado: state = PLAY, last_team = 1, touches = 1, sem saque.
func feed_ball(to: Vector3, flight_time: float) -> void
```

`feed_ball` libera o sacador (`serving = false`, `server = null`), lança de `(0, 2.6, -3)` com `clear_net_velocity` e chama `_make_plan`. Pontos no tutorial não importam (modo infinito); o diretor ouve `point_scored` e alimenta de novo.

**`TutorialDirector`** (nó filho da partida):

```gdscript
signal finished(skipped: bool)

enum Step { MOVE, TIMING, AIM, DONE }
```

| Passo | Texto | Como roda | Conclui quando |
|---|---|---|---|
| MOVE | "Ande até o anel colorido" | `feed_ball` lento (2,2 s) para 2,5 m do jogador | humano a ≤ 0,5 m de `plan.pos` antes de `plan.t` (não precisa tocar) |
| TIMING | "Segure o botão e solte quando o anel branco encostar no colorido" | `feed_ball` normal (`T_RECEIVE`) perto do jogador | um toque com grau PERFEITO ou BOM |
| AIM | "Arraste a mira até FUNDO ESQ e solte para sacar" | `_reset_for_serve(0)`; zona-alvo destacada | saque com `snap_aim(...).name == "FUNDO ESQ"` |
| DONE | "Pronto! Agora é contra o bot." | 2 s | → `finished(false)` |

- Cada passo repete até concluir; após 3 falhas mostra uma dica extra ("Solte um pouco antes", "Arraste para a esquerda").
- Botão **Pular** (canto superior direito) → `finished(true)`.
- Em `finished`: `App` marca `save.tutorial_done = true`, salva e chama `start_match(then_level)` (ou volta ao título se veio de lá).
- Overlay de texto: `Label` grande com contorno, no topo central, embaixo do placar (o placar fica oculto no tutorial).
- Destaque da zona-alvo: `Markers.highlight_zone(name: String)` pinta o ponto da zona e mostra o rótulo mesmo fora do levantamento.

---

## 5. Ordem de implementação (PRs)

| PR | Conteúdo | Depende de | Risco |
|---|---|---|---|
| 1 | 1.1 `ContactPlan` + `MAX_TOUCHES` | — | baixo (refatoração com testes) |
| 2 | 1.2 `MatchRules` + estados/sinais no `Game` + HUD (placar, selos, faixa). A partida fica infinita até o PR 5 ligar as regras pela `MatchConfig` | 1 | médio |
| 3 | 1.3 `MatchStats` + `MatchResult` | 2 | baixo |
| 4 | 1.4 `SaveData` | 3 | baixo |
| 5 | 1.5 `App`, `MatchConfig`, telas, pausa, `main_scene` → `app.tscn`, e2e do fluxo | 2–4 | **alto** (muda a entrada do app) |
| 6 | 1.6 Opções + canhoto | 5 | baixo |
| 7 | 1.7 Tutorial | 5 | médio |
| 8 | Fechamento: simulação de equilíbrio e duração, README, prints no celular | 1–7 | — |

Cada PR: CI verde, prints do e2e conferidos, testado no celular pelo APK/Pages antes do merge.

---

## 6. Testes

Novos grupos em `tests/run_tests.gd` (mesmo padrão `_check`). Nenhum teste da Fase 0 muda de limite.

| Grupo | Casos |
|---|---|
| `_test_contact_plan` | 4º toque do mesmo lado não gera plano (forçando `touches = MAX_TOUCHES`); `plan` é `ContactPlan` ou `null` |
| `_test_match_rules` | 15–13 fecha set; 15–14 não fecha; 16–14 fecha; 2 sets fecham a partida; 1–1 vai ao 3º; `first_server` = 0, 1, 0; set point / match point corretos em 14–13, 14–14, 1 set a 0; modo infinito nunca fecha |
| `_test_match_flow` | bot × bot (Médio × Médio) com regras reais: emite `set_over` ≥ 2 vezes e `match_over` 1 vez; `state == MATCH_OVER` depois; nenhum `attempt_hit` aceito após o fim; duração impressa |
| `_test_match_duration` | humano roteirizado "casual" (reação 0,4 s, erro 90 ms) × Fácil, 8 sementes fixas (bot incluso): imprime cada partida e a média; checa 6–9 min (RNF-1.01) |
| `_test_stats` | contagens batem com os sinais emitidos num rally roteirizado; saque não conta como toque |
| `_test_save` | ida e volta de todos os campos; arquivo ausente → padrões; arquivo lixo → padrões sem erro; valores fora do limite são cortados; vitória no Fácil libera Médio; vitória no Difícil mantém 2 |
| `_test_pause` | `cancel_aim` ao pausar: soltar depois não gera toque; `get_tree().paused` congela `Game.time` |
| `_test_left_handed` | com `left_handed`, toque na direita move o joystick e na esquerda aperta o botão |
| `_test_tutorial` | humano roteirizado completa MOVE → TIMING → AIM e recebe `finished(false)`; **Pular** emite `finished(true)` |
| `_test_app_flow` | instancia `app.tscn` com `SaveData` de teste: título → seleção → partida (endless off) → força `match_over` → tela de resultado existe; save gravou a vitória |

**e2e (`mobile_smoke.js`)** passa a abrir o título:
1. Print do título; toca **Jogar**.
2. Print da seleção; Médio e Difícil aparecem bloqueados; toca **Fácil**.
3. Tutorial aparece (save novo); toca **Pular**.
4. Na partida, os testes de analógico e saque atuais (sem mudança).
5. Toca **II** → print da pausa → **Sair para o menu** → print do título.

Os toques do e2e acertam botões por coordenada proporcional à tela; as telas expõem posições fixas (ancoragem) para isso não ser frágil.

---

## 7. Critérios de aceite da Fase 1

1. Todos os testes (Fase 0 + Fase 1) e o e2e passam no CI.
2. Partida bot × bot completa termina sozinha no headless.
3. Simulação "humano casual × Fácil" dá partidas de 6–9 min em média; tabela de equilíbrio do README atualizada (agora em **% de partidas vencidas**, além de % de pontos).
4. No celular (Galaxy): fluxo título → tutorial → partida → resultado → revanche sem travar; voltar do Android pausa; trocar de app pausa; fechar e abrir mantém o progresso.
5. Na Web (Pages): progresso persiste ao recarregar a página.

---

## 8. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Trocar `main_scene` quebra o CI/e2e | PR 5 isolado; `main.tscn` continua funcionando sozinha (RF-1.15) |
| `get_tree().paused` pausar a UI de pausa | `PauseMenu` e `OptionsScreen` com `PROCESS_MODE_ALWAYS`; teste `_test_pause` |
| Partida longa demais com sets de 15 | medir em `_test_match_duration` antes do PR 8; ajuste por `POINT_PAUSE` ou tempos de voo, não pelo formato (decidido) |
| `user://` na Web sem persistência (aba anônima) | jogo segue com padrões; nenhuma tela depende do save existir |
| `ContactPlan` quebrar algo sutil no bot | PR 1 sem mudança de comportamento; mesmos números impressos no bot × bot antes/depois |
| Tutorial frustrante | 3 passos curtos, dica após 3 falhas, Pular sempre visível |

---

## 9. Decisões assumidas neste documento (mude se discordar)

### 9.1 Ajustes feitos na implementação

| Onde | O que mudou em relação ao design acima |
|---|---|
| `main.gd` | ganhou `class_name MatchScene` (o App acessa sinais e campos com tipo). |
| `main.gd` | `save` (definido pelo App) habilita **Opções** e **Sair** na pausa; sem App a pausa só tem Continuar e Reiniciar. Opções abrem dentro da partida, numa camada que roda pausada. |
| `App` | `-- --autoplay` abre a partida bot × bot direto (a cena principal agora é `app.tscn`). |
| `E2eHooks` (novo) | só na Web: publica em `window.__vs` a tela atual e o centro de cada botão; o e2e toca pelos nomes (`title/play`, `level/0`, `tutorial/skip`, `hud/pause`, `pause/quit`). |
| `Hud` | `set_mode(STANDALONE / MATCH / TUTORIAL)` decide quais botões e textos aparecem. |
| Pausa por foco | `FOCUS_OUT` só pausa em aparelho de toque (no PC atrapalharia o desenvolvimento e o e2e); `APPLICATION_PAUSED` e o voltar do Android sempre. |
| Tutorial | o diretor é chamado por `main._physics_process` (`tick`), não tem `_physics_process` próprio, para os testes headless o dirigirem. |

### 9.2 Decisões

| # | Assumido | Alternativa |
|---|---|---|
| A-1 | 1º saque alterna por set (você, bot, você) | sorteio a cada set |
| A-2 | Médio libera ao vencer o Fácil uma vez; Difícil ao vencer o Médio | tudo liberado desde o início |
| A-3 | Tutorial obrigatório na 1ª partida, com Pular | só pelo menu |
| A-4 | Raiz `App` como roteador (sem autoload) | autoload `App` |
| A-5 | Telas com tema padrão do Godot até a Fase 4 | tema simples próprio já na F1 |
| A-6 | Sem troca de lado entre sets (câmera fixa atrás de você) | trocar lado visualmente |
