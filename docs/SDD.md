# SDD — Vôlei Mobile (v-slash)

Documento de design de software. Descreve **como o jogo é hoje (Fase 0)** e **como a arquitetura evolui nas Fases 1–5** do [ROADMAP](ROADMAP.md).

| | |
|---|---|
| Versão | 1.0 — 2026-10-31 |
| Estado do código | Fase 0 concluída (`main` @ 98d6898) |
| Motor | Godot 4.7, GDScript, renderer GL Compatibility |
| Plataformas | Android (alvo principal), Web, PC (desenvolvimento) |

---

## 1. Introdução

### 1.1 Propósito
Servir de referência única para quem for mexer no código: o que cada parte faz, por que foi feita assim e onde cada mecânica nova deve entrar.

### 1.2 Escopo
Jogo de vôlei para celular, partida curta, controle por um gesto (**segura → mira → solta**) com leitura de timing por um anel no chão. Começa 1v1 contra bot; termina em 2v2 com arte, som e publicação na Play Store.

### 1.3 Glossário

| Termo | Significado |
|---|---|
| **Plano de contato** (`plan`) | Previsão de quem toca a próxima bola, com qual ação, onde (anel) e quando (tempo ideal). Coração do jogo. |
| **Anel** | Marcador colorido no chão = ponto onde o jogador deve estar. Cor = ação. |
| **Anel de aproximação** | Anel branco que fecha até o anel colorido; encostou = hora de soltar. |
| **Qualidade (q)** | 0–1, vem do erro de timing: PERFEITO = 1,0 · BOM = 0,7 · CEDO/TARDE = 0,35. |
| **Ímã** | Assistência que puxa a mira (ou o jogador) para um alvo próximo. |
| **Toque pendente** | Toque aceito, mas agendado para executar perto do tempo ideal (`_pending`). |
| **Whiff** | Tentativa que não toca na bola (CEDO, TARDE, LONGE, SEM BOLA). |
| **Time 0 / Time 1** | Humano (z > 0) / adversário (z < 0). Rede no plano z = 0. |

### 1.4 Referências
- [README.md](../README.md) — como rodar, controles, tabela de ajuste.
- [ROADMAP.md](ROADMAP.md) — fases, fatias e critérios de pronto.
- [scripts/core/tuning.gd](../scripts/core/tuning.gd) — todos os números.

---

## 2. Visão geral

### 2.1 Conceito de jogo
O jogador não aperta "na hora da bola": ele **se posiciona no anel e solta o dedo quando o anel branco fecha**. A mira define o destino; o timing define a precisão e a força. Tudo que é difícil em vôlei de verdade (ler a trajetória, chegar a tempo, escolher o alvo) vira algo legível na tela.

### 2.2 Pilares de design
1. **Legível em tela pequena** — sombra, ponto de queda, anel, mira e texto do botão sempre dizem o que fazer.
2. **Um gesto** — o mesmo segura-arrasta-solta serve para saque, recepção, levantamento e ataque.
3. **Justo** — o que o marcador mostra é exatamente o que a bola faz (preditor = física real).
4. **Ajustável** — todo número de feel está em `Tuning`; equilíbrio validado por simulação headless.

### 2.3 Restrições
- Renderer **GL Compatibility** (Android de entrada e Web sem threads).
- Sem assets externos até a Fase 4: toda geometria é gerada por código.
- Tela na horizontal (`orientation=4`, sensor landscape), base 1280×720, `stretch=canvas_items/expand`.
- APK só arm64-v8a.

---

## 3. Requisitos

### 3.1 Funcionais (estado atual — Fase 0)

| ID | Requisito | Onde |
|---|---|---|
| RF-01 | Andar com joystick flutuante (metade esquerda) ou WASD/setas | `touch_controls.gd`, `player.gd` |
| RF-02 | Botão de ação contextual: SACAR · RECEBER · LEVANTAR · ATACAR · PASSAR | `game.gd` (`current_act`) |
| RF-03 | Segurar mostra/edita a mira; soltar executa o toque | `game.gd` (`human_*`) |
| RF-04 | Anel de timing com graus PERFEITO/BOM/CEDO/TARDE | `game.gd` (`_execute`), `markers.gd` |
| RF-05 | Pulo automático no ataque enquanto o botão está segurado | `game.gd` (`_auto_jumps`) |
| RF-06 | Física com rede (bate e volta), antena e chão; ponto por chão, fora, rede, antena | `ball_sim.gd`, `game.gd` |
| RF-07 | Bot com 3 níveis (Fácil/Médio/Difícil) usando o mesmo plano de contato | `bot_brain.gd` |
| RF-08 | Placar, rally atual, recorde, feedback de toque e de ponto | `hud.gd` |
| RF-09 | Vibração no toque (celular) | `main.gd` |
| RF-10 | Demo bot × bot (`-- --autoplay`) | `main.gd` |

### 3.2 Funcionais planejados
Detalhados por fase na seção 9 e no ROADMAP: partida em sets, telas, save, tutorial, opções (F1); tipos de saque, bloqueio, largada, peixinho, stamina (F2); 2v2 com parceiro IA (F3); arte, animação, som (F4); release assinado e telemetria (F5).

### 3.3 Não funcionais

| ID | Requisito | Meta | Como verificar |
|---|---|---|---|
| RNF-01 | Desempenho | 60 fps estável em Android médio (F4: Android de entrada) | log de fps no e2e + aparelho real |
| RNF-02 | Latência de entrada | toque processado no mesmo `_physics_process` | arquitetura (sinais síncronos) |
| RNF-03 | Determinismo da bola | preditor = bola real (erro < 1 mm) | teste "preditor = bola real" |
| RNF-04 | Robustez do rally | nunca > 8 s sem toque ou ponto | teste bot × bot |
| RNF-05 | Equilíbrio | jogador "bom" vence ~75% no Fácil, ~50% no Médio | simulação (tabela do README) |
| RNF-06 | Offline | jogo inteiro funciona sem rede | — |
| RNF-07 | Tamanho | APK release < 60 MB (F4) | CI |
| RNF-08 | Acessibilidade | modo canhoto, sensibilidade, vibração opcional (F1) | e2e |
| RNF-09 | Manutenção | todo número de feel em `Tuning`; CI verde a cada push | revisão + CI |

---

## 4. Arquitetura

### 4.1 Camadas

```
┌───────────────────────────────────────────────────────────────┐
│ main.gd  (composição: monta cena, liga sinais, lê entrada)    │
├───────────────┬───────────────────────┬───────────────────────┤
│ ui/           │ entities/             │ ai/                   │
│  TouchControls│  Player  (movimento,  │  BotBrain (lê o plano,│
│  Hud          │   pulo, animação)     │   decide, chama       │
│  Markers      │  Ball    (visual)     │   attempt_hit)        │
│               │  Court   (geometria)  │                       │
├───────────────┴───────────┬───────────┴───────────────────────┤
│ core/  (sem nós visuais)  │                                   │
│  Game     regras, plano de contato, toque, pontos             │
│  BallSim  física exata + preditor                             │
│  Tuning   constantes                                          │
└───────────────────────────────────────────────────────────────┘
```

**Regra de dependência:** `core` não conhece `ui` nem `ai`. `Game` só fala para fora por **sinais** (`point_scored`, `touch_made`, `whiffed`) e por consultas (`current_act`, `is_hot`, `human_aim_view`, `plan`, `land_point`). `ui` e `ai` leem `Game`; quem escreve nele é só `main.gd` (entrada humana) e `BotBrain` (`attempt_hit`).

> Exceção conhecida: `Game` referencia `Player` e `Ball` (nós de `entities/`) para posição e estado. Aceitável enquanto os dois forem finos; na Fase 3 avaliar extrair o estado de jogador para um objeto de dados.

### 4.2 Montagem
Desde a Fase 1 a cena principal é `scenes/app.tscn` (roteador de telas, ver [SDD-fase-1](SDD-fase-1.md)); ela abre `scenes/main.tscn` para cada partida. `scenes/main.tscn` tem só o nó raiz com `main.gd`. Em `_ready` ele cria, nesta ordem: mapa de teclas → mundo (ambiente, luz, `Court`, câmera fixa) → partida (`Player` ×2, `Ball`, `Game`, `BotBrain`, `Markers`) → UI (`TouchControls` no CanvasLayer 1, `Hud` no CanvasLayer 2) e conecta sinais.

### 4.3 Laço de frame

```
_physics_process(dt)                     _process(dt)
  human.move_input ← controls.get_move()   markers.refresh()
  game.tick(dt):                           controls.action_label / action_hot
    time += dt                             hud.set_board(...)
    bots[].tick(dt)        (decidem)
    players[].step(dt)     (movem/pulam)
    _auto_jumps()
    ball.step(dt) → eventos → _on_ball_event
    _run_pending()         (executa toques agendados)
    pausa de ponto → _reset_for_serve
    _update_assists()      (ímã de posição)
```

Toda a lógica roda em `_physics_process` (passo fixo); `_process` só desenha. Entrada de toque chega por sinais de `TouchControls` → `main.gd` → `game.human_press/drag/release`.

### 4.4 Máquina de estados do rally

```
            attempt_hit (sacador)
SERVE_WAIT ───────────────────────▶ PLAY
    ▲                                 │ _award (chão, fora, antena)
    │   _pause_t = 1,8 s esgota       ▼
    └────────────────────────── POINT_PAUSE
```

Contador de toques: `last_team` + `touches`. Saque grava `touches = 3` para o sacador não tocar de novo antes de a bola cruzar. Ao trocar de lado, `n = 1`; no mesmo lado `n = touches + 1`; `n > 3` → sem plano, a bola cai.

### 4.5 Sistema de coordenadas
- Metros. Rede em z = 0, altura 2,43 m. Time 0 em z > 0, time 1 em z < 0.
- `side_of_team(t)` = +1/−1. Tudo que é espelhável é escrito para o time 0 e multiplicado por `s`.
- Câmera atrás do time 0: direita da tela = +x. Arrastar o dedo em tela (dx, dy) move a mira em (x, z) com `AIM_SENS` m/px.

---

## 5. Design detalhado (Fase 0)

### 5.1 `BallSim` — física e preditor
- Estado: `pos`, `vel`, `g` (gravidade do voo), `landed`, `net_hits`.
- **Parábola analítica** (`_move`): sem integração numérica, então qualquer `dt` dá o mesmo resultado.
- `advance(dt)` resolve em ordem cronológica os eventos dentro do passo: **cruzar a rede** (vira `NET` se abaixo da fita, `ANTENNA` se |x| fora da quadra, senão `CROSS`) e **chão** (`LAND`). Rede: bola volta para o lado de quem tocou com `NET_BOUNCE`.
- `predict()` copia o estado e avança em passos de 1/120 s até cair → `{points, times, land, landed}`.
- `find_descent(pred, h, side)` → primeiro instante em que a bola **desce** pela altura `h` no lado pedido (interpolado).
- Construtores de lançamento: `launch_velocity` (passa por p1 em t), `clear_net_velocity` (aumenta t 7% por iteração até passar a rede com folga — mirar curto vira largada).
- **Invariante:** a bola real e o preditor usam o mesmo código. Qualquer efeito novo (flutuante, F2) precisa ser determinístico e reproduzido em `predict()`.

### 5.2 `Game` — regras e plano de contato
**Plano** (`_make_plan`, chamado após cada toque e cada batida na rede):

| n (toque do lado) | Opções testadas em ordem (ação, altura de contato) |
|---|---|
| 1 | RECEBER @ 0,9 m |
| 2 | LEVANTAR @ 2,25 m → LEVANTAR @ 0,9 m |
| 3 | ATACAR @ 3,05 m → PASSAR @ 2,25 m → PASSAR @ 0,9 m |

A primeira altura que a bola atravessa descendo vira o plano `{team, n, act, t, pos, player}`. `player` = jogador mais próximo do time (`_closest_player`). `plan_id` incrementa a cada plano para invalidar toques pendentes antigos.

**Toque** (`attempt_hit` → `_pending` → `_execute`):
1. Rejeita se em cooldown, fora de estado, sem plano para este jogador.
2. `err = time − t_ideal`. Fora de `[−WINDOW_EARLY, +WINDOW_LATE]` → whiff CEDO/TARDE.
3. Agenda para `max(agora, t_ideal − EARLY_SNAP)` — soltar cedo dentro da janela não adianta a bola, só piora a qualidade.
4. Ao executar: distância > `REACH` → LONGE. Senão calcula `q`, aplica ímã (`snap_aim`), dispersão `_scatter` (raio ∝ 1−q), força o lado certo (`_keep_side`), e para o humano com q ≥ 0,7 mantém dentro (`keep_inside`).
5. Velocidade por tipo: RECEBER (sobe a H_SET em ~T_RECEIVE), LEVANTAR (a H_ATTACK em T_SET_HIGH ou T_SET_QUICK), ATACAR (velocidade horizontal entre ATTACK_SPEED_MIN/MAX por `power`, gravidade SPIKE), PASSAR (bola por cima da rede em T_FREEBALL). Mandar a bola para o outro lado no 1º/2º toque vira PASSAR.
6. Atualiza contadores, emite `touch_made`, refaz o plano.

**Saque** (`_serve`): q fixo 0,85 na Fase 0, mira com ímã de zona, sai de 1,05 m acima do sacador.

**Pontos** (`_on_ball_event`): `LAND` dentro → ponto para quem não é dono do lado; fora → ponto contra quem tocou por último; `ANTENNA` → contra quem tocou. `_award` registra recorde de rally, passa o saque para quem pontuou (rally point) e entra em `POINT_PAUSE`.

**Assistências do humano** (todas em `Game`, testadas em `_test_aim_assist`):

| Assistência | Mecanismo | Constante |
|---|---|---|
| Mira sempre na quadra | `clamp_aim` com margem; saque/ataque nunca do seu lado | `AIM_MARGIN` |
| Mira persistente | `human_aim` só muda quando você arrasta | — |
| Ímã de zona (saque/ataque) | gruda em `ATTACK_ZONES` dentro do raio | `AIM_MAGNET_RADIUS` |
| Ímã do levantador (recepção) | gruda em `SETTER_SPOT` | `RECEIVE_MAGNET_RADIUS` |
| Ímã de levantamento (todos) | ALTA / PONTA / RÁPIDA / PIPE | `SET_MAGNET_RADIUS` |
| Bola boa fica dentro | q ≥ limiar → `keep_inside` | `ASSIST_KEEP_IN_Q` |
| Ímã de posição | solta o joystick perto do anel → anda até ele | `MAGNET_RADIUS`, `MAGNET_SPEED` |
| Correção no ar | pulo puxa em direção à bola | `JUMP_DRIFT` |

### 5.3 `BotBrain` — IA
- Lê o **mesmo** `game.plan`. Ao ver um `plan_id` novo decide uma vez: atraso de reação (`BOT_REACTION`, só quando a bola vem do adversário), erro de timing gaussiano (`BOT_TIMING_SIGMA`, limitado a [−0,3; +0,13]) e se deixa cair bola que vai claramente para fora (`BOT_READS_OUT`).
- Anda até `plan.pos` com `_go_to` (rampa de velocidade nos últimos 0,6 m); sem bola volta para casa (z = 4,2 do seu lado).
- Mira: recepção → levantador ± ruído; levantamento → `default_aim`; ataque/saque → `_court_target` (6 candidatos aleatórios; Fácil escolhe perto de você, Médio aleatório, Difícil longe de você).
- Força limitada por `BOT_POWER` (timing continua definindo a precisão).
- Usa `attempt_hit` como o humano: **não tem atalho de regra**.

### 5.4 `Player`
Movimento com aceleração (`ACCEL`) até `speed`; preso à própria meia-quadra (até 2,5 m fora nas laterais e 3 m no fundo); sacador preso atrás da linha. Pulo parabólico de `JUMP_TIME_UP × 2` com correção no ar. `lunge` (passo rápido no toque) disfarça o alcance generoso. `swing(kind)` anima os braços com tween. Geometria: cápsula + "nariz" + braços; anel no pé do humano.

### 5.5 `Ball`
Visual da bola. Modos `HELD` (segue o sacador), `FLYING` (posição = `sim.pos`), `DEAD` (quiques só visuais depois do ponto). Rotação visual proporcional à velocidade.

### 5.6 UI
- **`TouchControls`** (Control em tela cheia, `MOUSE_FILTER_IGNORE`, lê `_input`): metade esquerda = joystick flutuante (nasce onde encosta, raio 95 px, zona morta 0,12); metade direita = botão de ação (press/drag/release); faixa superior de 80 px reservada aos botões do HUD; multitoque por índice; Espaço/J no PC. Usa `get_viewport_rect()` porque o Control direto num CanvasLayer pode ficar 0×0.
- **`Hud`**: placar, rally/recorde, popup de grau (some com tween), mensagem de ponto, botões Reiniciar e nível do bot.
- **`Markers`** (3D no chão): sombra (escala com altura), ponto de queda, anel colorido por ação, anel de aproximação (fecha em `RING_LEAD` s), retículo da mira com nome do ímã, pontos e rótulos das zonas.

### 5.7 `Tuning`
Classe só de constantes, agrupada por tema (quadra, bola, alturas, tempos, janela de timing, dispersão, jogador, mira, bot). Arrays de bot indexados por nível. **Toda constante nova entra aqui com comentário de unidade.**

---

## 6. Dados e estado

### 6.1 Estado em memória (Game)

| Campo | Tipo | Ciclo de vida |
|---|---|---|
| `state` | `State` | máquina do rally |
| `score[2]`, `best_rally` | int | partida (`reset_match`) |
| `server_team`, `server` | int, Player | ponto |
| `last_team`, `touches`, `rally_touches` | int | rally |
| `plan`, `plan_id` | Dictionary, int | toque |
| `land_point`, `land_in` | Vector3, bool | toque |
| `human_aim`, `human_aiming` | Vector3, bool | sessão |
| `_pending` | Array[Dictionary] | até executar ou o plano mudar |

> `plan` é um `Dictionary` sem tipo. Na Fase 1 vale virar uma classe `ContactPlan` (RefCounted) para pegar erro de chave em tempo de análise — o 2v2 vai acrescentar campos.

### 6.2 Persistência (a partir da Fase 1)
Arquivo `user://save.cfg` (`ConfigFile`), versionado:

```ini
[meta]
version=1
[progress]
unlocked_level=0          ; 0 Fácil, 1 Médio, 2 Difícil
tutorial_done=false
[records]
best_rally=0
wins=[0, 0, 0]            ; por nível
[options]
aim_sens=1.0              ; multiplicador de AIM_SENS
left_handed=false
vibration=true
```

Leitura tolerante (chave ausente = padrão); migração por `version`. Na Web `user://` vai para IndexedDB — sem mudança de código.

---

## 7. Interface e experiência

### 7.1 Controles
| Ação | Celular | PC |
|---|---|---|
| Andar | polegar esquerdo, joystick flutuante | WASD / setas |
| Mirar e tocar | segurar metade direita, arrastar, soltar | Espaço/J; mouse imita toque |

Modo canhoto (F1) inverte as metades. Sensibilidade multiplica `AIM_SENS`.

### 7.2 Códigos visuais
Cor do anel = ação; anel branco fechando = timing; botão acende verde quando `|time − t_ideal| ≤ GOOD`; popup verde = PERFEITO, amarelo = BOM, vermelho = erro.

### 7.3 Fluxo de telas (Fase 1)

```
Título ─▶ Escolher bot ─▶ [Tutorial na 1ª vez] ─▶ Partida ─▶ Resultado
  ▲            ▲                                   │  ▲          │
  │            └──────────── Revanche ◀────────────┼──┼──────────┘
  └────────────────────── Menu ◀── Pausa ◀─────────┘  │
                                       └── Continuar ─┘
```

---

## 8. Câmera e renderização
Câmera fixa em (0, 14, 21) olhando (0, 0, 0,5), FOV 38°, enquadrando as duas quadras e o sacador nos aspectos testados (`_test_camera`). Iluminação: uma direcional + ambiente por cor; fundo em cor sólida; MSAA 2×. Materiais `StandardMaterial3D` sem textura. Fase 3 ajusta a câmera para 4 jogadores; Fase 4 troca materiais e luz (baked).

---

## 9. Evolução por fase

Cada item indica **onde** o código muda. Princípio fixo: regra nova entra em `core/`, é usada pelo bot e coberta por teste headless.

### 9.1 Fase 1 — Partida de verdade

Detalhamento completo (assinaturas, telas, testes, ordem dos PRs): [SDD-fase-1.md](SDD-fase-1.md). Onde os dois divergirem, vale o detalhado.

| Mudança | Design |
|---|---|
| Limite de toques | 1v1 mantém 3 toques do mesmo jogador. `Tuning.MAX_TOUCHES := 3` substitui o `3` fixo em `_make_plan` (`n > MAX_TOUCHES` → sem plano); o 2v2 reaproveita. |
| Contrato `ContactPlan` | Classe tipada com `team, n, act, t, pos, player`; `Game.plan` passa a ser `ContactPlan` ou `null`. |
| Placar em sets | Novo `core/match_rules.gd` (RefCounted): `SET_POINTS`, `SETS_TO_WIN`, vantagem de 2; `add_point(team) -> {set_over, match_over}`. `Game._award` delega. Novo sinal `Game.set_over(team)` e `Game.match_over(team)`. |
| Fluxo de telas | `scripts/app.gd` (autoload) troca entre cenas `title.tscn`, `level_select.tscn`, `main.tscn`, `result.tscn`. `main.gd` recebe o nível e o modo por `App`, não por botão do HUD. Pausa = `get_tree().paused` + `Game.process_mode` pausável. |
| Save | `scripts/core/save_data.gd` (autoload) — formato em 6.2. |
| Tutorial | Cena com `Game` em modo roteirizado: bola lançada por script, passo só avança quando o objetivo é cumprido (estar no anel / grau ≥ BOM / arrastar a mira). |
| Opções | Lidas de `SaveData`; `TouchControls.left_handed` inverte `x < meio`. |
| Estatísticas da partida | `Game` acumula por time: toques, perfeitos, erros, pontos por motivo → tela de resultado. |

### 9.2 Fase 2 — Profundidade

Detalhamento completo: [SDD-fase-2.md](SDD-fase-2.md). Onde os dois divergirem, vale o detalhado.

| Mudança | Design |
|---|---|
| Tipos de saque | `enum ServeType { UNDER, JUMP, FLOAT }`. Saque passa a ter timing (anel no lançamento da bola). JUMP: janela menor, velocidade maior. FLOAT: `BallSim` ganha um termo lateral **determinístico** `x += A·sin(ω·t + φ)` com φ sorteado no lançamento e guardado no estado — `predict()` reproduz exatamente; o *marcador* é que mostra o ponto de queda com incerteza até os últimos ~0,4 s. |
| Bloqueio | Nova ação `Act.BLOCK`. Quando o plano do adversário é ATACAR e você está a < 1,2 m da rede, o botão vira BLOQUEAR e você pula por timing próprio. Em `BallSim`, colisão da bola com um "painel de bloqueio" (retângulo no plano z ≈ ±0,3 m, ativo durante o pulo). Resultado por q: ponto (devolve para baixo), amortece (bola sobe do seu lado, conta como 1º toque), desvia para fora. |
| Largada | No ataque: arraste curto (< limiar em px) → velocidade baixa e alvo curto; longo → cortada. Reaproveita `clear_net_velocity`. |
| Peixinho | Gesto de deslizar rápido na metade direita fora do alcance: `REACH` estendido por um instante, `Player` entra em estado `DIVING` (sem mover por `DIVE_RECOVER` s); q máximo limitado. |
| Stamina | `Player.stamina` 0–1, gasta em JUMP/cortada forte/peixinho, recupera entre pontos. Atrás de `Tuning.STAMINA_ENABLED`. |
| Bot | `BotBrain` ganha decisão de tipo de saque, bloqueio por nível e ataque desviando do bloqueio. |

### 9.3 Fase 3 — 2v2

Detalhamento completo: [SDD-fase-3.md](SDD-fase-3.md). Onde os dois divergirem, vale o detalhado.

| Mudança | Design |
|---|---|
| Regra real | `Game` guarda `last_player`; plano exclui `last_player` do time que acabou de tocar (ninguém toca duas vezes seguidas). `MAX_TOUCHES = 3` no modo 2v2. |
| Modo | `MatchConfig { mode: ONE_V_ONE / TWO_V_TWO, court_half_w, court_depth, max_touches }` substitui as constantes de quadra usadas direto. `Court`, `is_inside`, `clamp_aim` e `keep_inside` passam a ler a config. |
| Controle | O humano controla quem o plano escolheu no time 0; ao mudar, `main.gd` transfere `move_input` e o anel do pé. O outro do time recebe um `BotBrain` em modo parceiro. |
| IA de parceiro | `BotBrain` ganha papel (`DEFENSE`, `SETTER`, `ATTACKER`) e posições base por fase do rally; chamada "minha" resolvida pelo plano (um só dono por bola). |
| Levantamentos | ALTA/PONTA/RÁPIDA/PIPE já existem em `set_magnets`; o atacante passa a ser o parceiro, que corre para o ponto do levantamento. |
| Câmera | Enquadramento dinâmico suave (bounding box de jogadores + bola) com limites, mantendo o teste de enquadramento. |

### 9.4 Fase 4 — Arte e som

Detalhamento completo: [SDD-fase-4.md](SDD-fase-4.md). Onde os dois divergirem, vale o detalhado.

| Mudança | Design |
|---|---|
| Separação lógica × visual | `Player` mantém a lógica; o visual vira uma cena filha `PlayerView` (modelo glTF + `AnimationTree`) que reage a `swing(kind)`, pulo e corrida. Mesma ideia para `Ball` e `Court`. Testes headless continuam sem depender de assets. |
| Pipeline de assets | Modelos low-poly (Blender → glTF) em `assets/models/`, texturas ETC2/ASTC, áudio OGG em `assets/audio/`. Orçamento: ≤ 5 k tris por jogador, 1 material por personagem, luz baked na quadra. |
| Áudio | Autoload `Sfx` assinando os sinais de `Game` (toque por grau, apito, rede, torcida pelo tamanho do rally). Barramentos Master/Música/Efeitos, volumes no save. |
| Efeitos | Rastro na cortada, partículas no chão (GPUParticles compatíveis com GLES3), leve tremor de câmera no ataque. |
| Medição | e2e registra fps médio e p1; CI falha se o APK passar do limite. |

### 9.5 Fase 5 — Lançamento

Detalhamento completo: [SDD-fase-5.md](SDD-fase-5.md). Onde os dois divergirem, vale o detalhado.
Preset Android release com keystore em segredo do GitHub (`GODOT_ANDROID_KEYSTORE_RELEASE_*`), AAB para a Play Store, `version/code` incrementado pelo CI. Telemetria opcional e anônima (consentimento na 1ª abertura) com eventos de fim de partida: modo, nível, duração, rally médio, motivos de ponto. Página de privacidade.

---

## 10. Testes e qualidade

### 10.1 Pirâmide

| Nível | Arquivo | O que cobre |
|---|---|---|
| Unidade / física | `tests/run_tests.gd` → `_test_physics` | alvo exato, cruzar rede, tempo de voo, batida na rede, preditor = real, antena, `clear_net_velocity`, `find_descent` |
| Sistema (simulação) | `_test_bot_vs_bot` | 20 min simulados: pontos saem, nunca trava > 8 s, média ≥ 3 toques |
| Sistema (humano roteirizado) | `_test_scripted_human` | soltar no anel fechado = PERFEITO ≥ 80%, pontos saem |
| UI | `_test_touch_controls`, `_test_hud_layout`, `_test_camera` | joystick/botão/multitoque, HUD em tela cheia, enquadramento por aspecto |
| Mira | `_test_aim`, `_test_aim_assist` | persistência, limites, ímãs |
| Ponta a ponta | `tests/e2e/mobile_smoke.js` | build Web real em Chromium com toque emulado (915×412), confere movimento pelos pixels, salva prints |

### 10.2 Regras
- Toda mecânica nova: teste headless + participação do bot no `_test_bot_vs_bot`.
- Fim de fase: rodar a simulação de equilíbrio e atualizar a tabela do README.
- Testes que dependem de sorte usam semente fixa (`rng.seed`), como no teste de mira determinístico.
- CI falha com qualquer `SCRIPT ERROR` ou `falhas: N > 0`.

---

## 11. Build, CI e entrega

`.github/workflows/build.yml`, a cada push/PR:

1. Baixa e cacheia Godot 4.7 + templates (Web sem threads, Android).
2. `--import`; roda `run_tests.gd` (falha em erro de script ou falha de teste).
3. Exporta Web → roda e2e Playwright → publica prints como artefato.
4. Exporta APK debug arm64 (keystore gerada no job) → artefato `volei-mobile-apk`.
5. Em `main`: publica a Web no GitHub Pages.

`export/` tem `.gdignore` (o Godot não importa builds/prints); Playwright é instalado fora do projeto para não entrar no APK. Presets em `export_presets.cfg` excluem `tests/*`.

---

## 12. Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Saque flutuante quebrar "preditor = real" | alto | efeito determinístico com fase guardada; teste de igualdade continua obrigatório |
| `Game` virar classe gigante (567 linhas hoje) | médio | extrair `MatchRules` (F1), `ContactPlanner` e `HitResolver` (F2) |
| 2v2 com troca de controle confusa | alto | indicador forte, troca só quando o plano muda, teste com jogadores reais antes da F4 |
| Performance com arte na F4 | alto | orçamento por asset, medir fps no CI desde a F1 |
| Assistências demais tirarem o mérito | médio | todas em `Tuning`; níveis de bot equilibrados por simulação |
| Gestos novos (largada, peixinho) conflitarem com mirar | médio | limiares em px no `Tuning`, e2e com gestos reais |

---

## 13. Decisões de arquitetura

| # | Decisão | Motivo |
|---|---|---|
| ADR-01 | Bola **cinemática** (parábola analítica), não física do motor | previsão exata, mesmo resultado em qualquer fps, anel confiável |
| ADR-02 | Um **preditor único** para marcador, plano e bot | o que a tela mostra é o que acontece; bot sem trapaça |
| ADR-03 | Cena montada **por código** | protótipo rápido, diffs legíveis, nada de .tscn conflitando; revisitar na F4 para arte |
| ADR-04 | **Todas as constantes em `Tuning`** | ajuste de feel sem caçar números |
| ADR-05 | Toque por **janela + agendamento** (`_pending`) | soltar cedo não antecipa a bola; timing só muda qualidade |
| ADR-06 | Bot usa a **mesma API** do humano (`attempt_hit`) | regra nova vale para os dois automaticamente |
| ADR-07 | Renderer **Compatibility** | roda em Android de entrada e na Web |
| ADR-08 | **CI gera Web + APK** a cada push | testar no celular sem instalar o editor |
| ADR-09 | A partir da Fase 4, **visual em cenas e assets** (`assets/`, `scenes/views/`); a lógica continua só em código e não carrega arquivos | arte de verdade sem perder testes headless; substitui a ADR-03 ([SDD-fase-4](SDD-fase-4.md)) |

### 13.1 Decisões de produto (2026-10-31)

| # | Decisão |
|---|---|
| DP-01 | 1v1 com **3 toques do mesmo jogador** (receber → levantar → atacar). |
| DP-02 | Partida em **melhor de 3 sets de 15**, vantagem de 2 (`SET_POINTS = 15`, `SETS_TO_WIN = 2`). |
| DP-03 | **Stamina** entra na Fase 2 atrás de `STAMINA_ENABLED`; só fica ligada se o teste no celular aprovar. |
| DP-04 | **Multiplayer** (local e online) fora do escopo; reavaliar depois da Fase 5. |
| DP-05 | Partida de **~8 min** contra o Fácil é aceita: meta de duração revista de 4–7 para **6–9 min** em média, sem mudar formato nem pausas. |
