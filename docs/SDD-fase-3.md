# SDD detalhado — Fase 3: 2v2

Complementa o [SDD geral](SDD.md) (seção 9.3) e o [ROADMAP](ROADMAP.md). Design no nível de implementação.

| | |
|---|---|
| Versão | 1.0 — 2026-10-31 |
| Base | Fase 2 concluída (versão 0.3.0) |
| Versão ao fim da fase | 0.4.0 |
| Decisões que valem aqui | DP-01 (1v1 continua com 3 toques do mesmo jogador), DP-04 (sem multiplayer: o parceiro é IA) |

---

## 1. Objetivo e escopo

**Meta:** o jogo de dupla, com parceiro IA e a regra real (ninguém toca duas vezes seguidas), mantendo o gesto único: **você sempre controla quem vai tocar na bola**.

**Dentro:**
1. `CourtSpec` e `MatchConfig.mode` (refatoração: quadra por modo).
2. Times com N jogadores, ordem de saque, regra de toques seguidos.
3. Troca automática de controle.
4. IA de parceiro e dupla adversária (papéis e posições base).
5. Levantamento para o parceiro (alvos do 2v2).
6. Câmera e quadra do 2v2.
7. Telas: escolha de modo, save v3, resultado por modo, dica de primeira vez.
8. Equilíbrio e fechamento.

**Fora:** 2 humanos (local/online, DP-04), arte (Fase 4), troca de lado entre sets.

---

## 2. Requisitos

### 2.1 Funcionais

| ID | Requisito | Fatia |
|---|---|---|
| RF-3.01 | Escolha de modo **1v1 / 2v2** na tela de escolha do bot; cada modo tem seus níveis liberados e recordes. | 3.7 |
| RF-3.02 | 2v2 em quadra de 8 × 8 m por lado (vôlei de praia), rede 2,43 m. | 3.1, 3.6 |
| RF-3.03 | Até 3 toques por lado; **o mesmo jogador não toca duas vezes seguidas** (bloqueio é exceção, B3-2). | 3.2 |
| RF-3.04 | Ordem de saque: quando o time recupera o saque, saca o jogador que não sacou da última vez. | 3.2 |
| RF-3.05 | Você controla o jogador do seu time que o plano de contato escolheu; quando a bola está do outro lado, controla quem tocou por último (para bloquear/defender). Anel cheio no pé de quem você controla; anel fino no parceiro. | 3.3 |
| RF-3.06 | A troca de controle nunca acontece com o dedo segurando o botão de ação; o joystick continua valendo para o novo jogador (sem precisar soltar). | 3.3 |
| RF-3.07 | Parceiro IA se posiciona sozinho (recepção lado a lado, defesa com um na rede e um no fundo, levantador/atacante depois do 1º toque) e nunca "rouba" a bola do plano. | 3.4 |
| RF-3.08 | Levantamento no 2v2 mira o parceiro: alvo ALTA na frente do atacante; PONTA/MEIO/FUNDO relativos à posição dele. | 3.5 |
| RF-3.09 | Dupla adversária com os mesmos 3 níveis. | 3.4 |
| RF-3.10 | Dica na primeira partida 2v2: "O controle passa para quem vai tocar na bola". | 3.7 |

### 2.2 Não funcionais

| ID | Requisito | Meta |
|---|---|---|
| RNF-3.01 | 1v1 intacto | todos os testes das Fases 0–2 passam iguais |
| RNF-3.02 | Enquadramento | quadra inteira + 4 jogadores visíveis em 16:9 e 20:9 |
| RNF-3.03 | Rally | média humano roteirizado × Médio no 2v2 ≥ média do 1v1 |
| RNF-3.04 | Duração | partida 2v2 casual × Fácil em 6–9 min (como DP-05) |
| RNF-3.05 | Desempenho | 4 jogadores + IA sem queda de fps no Android de teste |

---

## 3. Arquitetura da fase

### 3.1 O que é "modo"

```gdscript
class_name MatchConfig            # existente, ganha:
enum Mode { ONE_V_ONE, TWO_V_TWO }
var mode := Mode.ONE_V_ONE
```

Tudo que depende do modo vem de dois objetos criados por `main.gd` a partir da config:

| Objeto | Conteúdo | Quem usa |
|---|---|---|
| `CourtSpec` | `half_w`, `depth`, `net_half_len`, `serve_back` (distância do sacador atrás da linha) | `Game`, `BallSim`, `Court`, `Player`, `BotBrain`, `Markers`, câmera |
| `MatchRules` (existente) | ganha `players_per_team`, `max_touches`, `same_player_twice: bool`, `block_counts: bool` | `Game` |

### 3.2 Arquivos

```
scripts/core/court_spec.gd        NOVO
scripts/core/team.gd              NOVO  jogadores do time, ordem de saque, quem está controlado
scripts/ai/partner_brain.gd       NOVO  posicionamento por papel (usado pelo parceiro e pela dupla do bot)
scripts/core/game.gd              last_player, escolha de quem toca, ordem de saque, court
scripts/core/ball_sim.gd          antena por CourtSpec
scripts/ai/bot_brain.gd           delega posicionamento sem bola ao PartnerBrain
scripts/main.gd                   monta 2 ou 4 jogadores, troca de controle, câmera por modo
scripts/entities/court.gd         geometria por CourtSpec
scripts/entities/player.gd        limites por CourtSpec; anel de "controlado" / "parceiro"
scripts/ui/markers.gd             anéis por jogador
scripts/ui/screens/level_select_screen.gd   alternador de modo
scripts/core/save_data.gd         versão 3: recordes e progresso por modo
```

---

## 4. Design por fatia

### 4.1 Fatia 3.0 — `CourtSpec` (refatoração, sem mudar comportamento)

```gdscript
class_name CourtSpec
extends RefCounted

var half_w: float
var depth: float
var net_half_len: float
var serve_back := 0.9

static func for_mode(mode: int) -> CourtSpec
	# ONE_V_ONE: 3,5 × 7 (valores atuais de Tuning) · TWO_V_TWO: 4,0 × 8,0

func is_inside(v: Vector3) -> bool
func keep_inside(v: Vector3, margin := 0.3) -> Vector3
```

- `Game.is_inside` e `Game.keep_inside` deixam de ser `static` e delegam para `game.court`.
- `BallSim` ganha `var court: CourtSpec` (copiado em `copy()`); antena usa `court.half_w`.
- `Court`, `Player._clamp_to_court`, `BotBrain._court_target/_clearly_out`, `clamp_aim`, posições de saque: trocam `Tuning.COURT_*` por `court.*`.
- `Tuning.COURT_HALF_W/DEPTH` viram `COURT_1V1 := Vector2(3.5, 7.0)` e `COURT_2V2 := Vector2(4.0, 8.0)`.
- `ATTACK_ZONES` e `SETTER_SPOT` passam a ser **frações** da quadra (multiplicadas por `half_w`/`depth`), para servirem aos dois modos com os mesmos valores no 1v1.

**Pronto quando:** `grep Tuning.COURT_HALF_W` só acha `court_spec.gd`; números das simulações iguais.

### 4.2 Fatia 3.1/3.2 — Times, quem toca, ordem de saque

**`scripts/core/team.gd`**

```gdscript
class_name Team
extends RefCounted

var index: int                    # 0 ou 1
var players: Array[Player] = []
var next_server := 0              # índice em players de quem saca quando o time recuperar o saque
var controlled: Player = null     # só no time do humano

func server_on_sideout() -> Player   # devolve o próximo sacador e alterna next_server
func other(p: Player) -> Player       # parceiro (null no 1v1)
```

**`Game`:**
- `var teams: Array[Team]` substitui o laço "primeiro jogador do time" em `_reset_for_serve`.
- `var last_player: Player = null` (zera a cada saque e quando a bola troca de lado... **não**: zera só no saque; a regra compara com quem tocou por último no mesmo lado).
- Saque: se `team` acabou de recuperar o saque (o ponto veio do outro time sacando), `server = teams[team].server_on_sideout()`; se o mesmo time pontuou sacando, o sacador repete.
- Posições no saque (2v2): sacador atrás da linha; parceiro em `(±1,5, depth·0,45)`; recepção adversária lado a lado em `(±2,0, depth·0,6)`.

**Quem toca (`_make_plan` → `_choose_player(team, at, t)`):**

| Situação | Regra |
|---|---|
| 1v1 | o único jogador (como hoje) |
| 2v2, 1º toque do lado | quem chega antes ao ponto (tempo = distância / velocidade, empate → quem está mais atrás) |
| 2v2, 2º/3º toque | **o jogador que não tocou por último** (`last_player`), exceto se `rules.block_counts` e o último toque foi bloqueio (B3-2) |
| ninguém elegível chega | o plano ainda aponta o elegível (o anel aparece; se não der, a bola cai) |

`n > rules.max_touches` continua sem plano.

### 4.3 Fatia 3.3 — Troca de controle

- `Game.human` deixa de ser fixo: `teams[0].controlled`. Quem lia `game.human` (Markers, main, testes) passa a ler `game.controlled()`.
- Regra (RF-3.05), avaliada em `Game._update_control()` a cada `tick`:
  1. Se o plano é do time 0 → `controlled = plan.player`.
  2. Se há `block_plan` do time 0 → `controlled = block_plan.player`.
  3. Senão mantém.
- **Trava:** se `human_aiming` (dedo no botão), não troca; aplica a troca quando soltar.
- `main.gd` copia `controls.get_move()` para `controlled` e zera o `move_input` do outro (que passa para o `BotBrain` dele).
- O jogador não controlado do time 0 recebe um `BotBrain` em **modo parceiro** (só posicionamento; nunca chama `attempt_hit`, porque o plano nunca é dele enquanto você o controla — invariante testada).
- Visual: anel cheio no controlado; anel fino na cor do time no parceiro; troca com "pulso" de 0,15 s no anel novo.

### 4.4 Fatia 3.4 — IA de posicionamento (`PartnerBrain`)

Usado pelo parceiro do humano **e** pelos dois jogadores do bot quando não são o `plan.player`.

| Fase do rally (vista do time) | Papel | Posição base (x relativo ao meio, z em fração da profundidade) |
|---|---|---|
| Recebendo saque | ambos `RECEIVE` | lado a lado: (−2,0 / +2,0, 0,6) |
| Nosso 1º toque feito | quem não tocou = `SETTER` | vai para o ponto de levantamento (perto da rede, x do passe) |
| | quem tocou = `ATTACKER` | recua para a "corrida" (x do levantamento ± 1, z 0,45) |
| Adversário com a bola, ataque previsto | `BLOCKER` (o mais perto da rede) e `DIGGER` | bloqueador na rede no x do atacante; defensor na diagonal, z 0,6 |
| Sem informação | `BASE` | (±1,8, 0,5) |

```gdscript
class_name PartnerBrain
extends RefCounted

func target_for(p: Player, game: Game) -> Vector3     # posição desejada agora
func role_of(p: Player, game: Game) -> int
```

`BotBrain` (do adversário e do parceiro) chama `PartnerBrain.target_for` quando não é `plan.player`; a parte de tocar continua como hoje. Nível do parceiro: `Tuning.PARTNER_LEVEL := 1` (velocidade e reação do Médio).

O bloqueio da Fase 2 vale no 2v2: o `BLOCKER` de cada time é quem pode receber `block_plan`.

### 4.5 Fatia 3.5 — Levantamento para o parceiro

`set_magnets(team)` no 2v2 usa o **atacante** (o jogador que vai fazer o 3º toque = quem não está levantando):

| Alvo | Posição |
|---|---|
| ALTA (padrão) | 1,0 m à frente do atacante, a 1,2 m da rede |
| PONTA | lateral do lado do atacante, 1,0 m da rede |
| MEIO | centro, 1,0 m da rede, levantamento rápido (`T_SET_QUICK`) |
| FUNDO | atrás do atacante, 3,0 m da rede (ataque de fundo) |

Depois do levantamento o controle passa para o atacante (o plano do 3º toque é dele) e o ímã de posição + pulo automático já existentes levam ao ponto.

### 4.6 Fatia 3.6 — Câmera e quadra

- `Court.new(spec)` desenha 8 × 8 no 2v2.
- Câmera por modo, fixa, com os mesmos testes de enquadramento (`_test_camera` roda para os dois modos): 2v2 começa em `(0, 16, 24)` olhando `(0, 0, 0,5)`, FOV 40°; ajustada até a quadra inteira + sacadores caberem em 16:9 e 20:9.
- Se o enquadramento fixo ficar pequeno demais no celular (teste manual), segunda opção já desenhada: seguir suavemente o centro entre bola e jogador controlado com limites (`CameraRig`), mantendo a quadra adversária visível.

### 4.7 Fatia 3.7 — Telas, save e dica

- `LevelSelectScreen`: alternador **1v1 | 2v2** no topo; cartões mostram V/D do modo escolhido; níveis do 2v2 liberam pela mesma regra (vença o Fácil do 2v2 → Médio do 2v2). 2v2 liberado desde o início.
- `SaveData` versão 3: `wins`, `losses`, `unlocked_level`, `best_rally` viram por modo (`[records] wins_1v1`, `wins_2v2`...). Migração: valores da versão 1/2 vão para `_1v1`.
- `MatchResult` ganha `mode`; `ResultScreen` mostra "2v2".
- Dica de primeira partida 2v2: faixa de 4 s no início ("O controle passa para quem vai tocar na bola"), `save.hint_2v2_done`.

### 4.8 Fatia 3.8 — Equilíbrio e fechamento

Simulações novas: bot × bot 2v2 (Médio × Médio) e humano roteirizado com troca de controle × Fácil/Médio. Ajustes esperados: `MOVE_SPEED` do 2v2 (quadra maior), `REACH`, `BOT_*` por modo se preciso (`Tuning` pode ter arrays por modo). README com tabela por modo; versão 0.4.0.

---

## 5. Ordem dos PRs

| PR | Conteúdo | Risco |
|---|---|---|
| 1 | 3.0 `CourtSpec` + zonas em frações (sem mudança no 1v1) | médio (toca muitos arquivos) |
| 2 | 3.1/3.2 `Team`, 4 jogadores, quem toca, ordem de saque (2v2 bot × bot, sem humano) | **alto** |
| 3 | 3.3 troca de controle | **alto** (sensação) |
| 4 | 3.4 `PartnerBrain` | médio |
| 5 | 3.5 levantamento para o parceiro | baixo |
| 6 | 3.6 câmera/quadra | médio |
| 7 | 3.7 telas, save v3, dica | baixo |
| 8 | 3.8 equilíbrio, README, 0.4.0 | médio |

---

## 6. Testes

| Grupo | Casos |
|---|---|
| `_test_court_spec` | `is_inside`/`keep_inside` nos dois modos; 1v1 com os mesmos números de antes |
| `_test_two_touch_rule` | 2v2: depois do toque de A, o plano do 2º toque é de B; 3º toque volta para A; nunca A→A (bot × bot 20 min sem nenhuma ocorrência) |
| `_test_serve_order` | sideout alterna o sacador; pontuar sacando mantém |
| `_test_control_switch` | plano do time 0 → controle no `plan.player`; com o dedo segurando não troca; troca ao soltar; parceiro nunca chama `attempt_hit` |
| `_test_partner_positions` | recepção lado a lado; depois do 1º toque o não-tocador vai para o levantamento; defesa com um na rede |
| `_test_sets_2v2` | ALTA fica na frente do atacante; depois do levantamento o controle é do atacante |
| `_test_camera` | roda nos dois modos (16:9 e 20:9) |
| `_test_bot_vs_bot_2v2` | pontos saem, nunca trava, média de toques ≥ 3, todas as posições/papéis usados |
| `_test_match_duration_2v2` | casual × Fácil 6–9 min |
| `_test_save` | migração v1/v2 → v3 mantém o 1v1 |
| e2e | escolher 2v2, pular dica, partida carrega com 4 jogadores (pixels azuis em 2 lugares) |

---

## 7. Critérios de aceite

1. Testes das Fases 0–3 e e2e verdes.
2. Nenhum toque seguido do mesmo jogador no 2v2 (simulação longa).
3. Enquadramento ok nos dois modos.
4. No celular: a troca de controle é entendida sem explicar (além da dica) e o parceiro não atrapalha.
5. Equilíbrio e duração do 2v2 dentro de RNF-3.03/3.04.

---

## 8. Riscos

| Risco | Mitigação |
|---|---|
| Troca de controle confusa | trava com dedo no botão, pulso visual, dica inicial, teste com pessoas antes da Fase 4 |
| Parceiro fora de posição e "culpa" do jogador | papéis simples e testados; parceiro no nível Médio |
| Refatoração da quadra quebrar o 1v1 | PR 1 sem mudança de comportamento, números comparados |
| Quadra maior + câmera fixa = tudo pequeno no celular | `CameraRig` já desenhado como plano B |
| Game crescer de novo | `Team` e `PartnerBrain` concentram o que é de dupla |

---

## 9. Decisões assumidas (mude se discordar)

| # | Assumido | Alternativa |
|---|---|---|
| B3-1 | Quadra 8 × 8 por lado (praia) | 9 × 9 (quadra) |
| B3-2 | No 2v2 o bloqueio **conta** como toque e o bloqueador pode tocar de novo em seguida (regra de praia); no 1v1 continua não contando (B-4) | regra de quadra nos dois |
| B3-3 | Controle automático em quem vai tocar | controle fixo num jogador (parceiro IA toca as bolas dele) — poderia virar opção |
| B3-4 | 2v2 liberado desde o início, com progressão própria de níveis | liberar só depois de vencer o 1v1 Médio |
| B3-5 | Sem troca de lado entre sets | trocar a cada 7 pontos como na praia |
