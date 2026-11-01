# SDD detalhado — Fase 2: Profundidade (1v1)

Complementa o [SDD geral](SDD.md) (seção 9.2) e o [ROADMAP](ROADMAP.md). Design no nível de implementação: estados, física, assinaturas, números iniciais, ordem dos PRs e testes.

| | |
|---|---|
| Versão | 1.1 — 2026-10-31 (implementada; ver seção 9) |
| Base | Fase 1 concluída (PR #11, versão 0.2.0) |
| Versão ao fim da fase | 0.3.0 |
| Decisões que valem aqui | DP-01 (3 toques no 1v1), DP-03 (stamina atrás de flag) |

---

## 1. Objetivo e escopo

**Meta:** dar escolhas além de "acertar o tempo": arriscar ou jogar seguro no saque, atacar ou defender na rede, ir ou não ir numa bola longe.

**Dentro:**
1. Refatoração: tirar de `Game` o cálculo do lançamento (`HitResolver`).
2. Saque com timing e três tipos: **por baixo**, **flutuante**, **viagem**.
3. Física do flutuante (oscilação lateral determinística) e leitura atrasada do ponto de queda.
4. Bloqueio na rede.
5. Largada explícita (zonas curtas).
6. Peixinho automático para bola fora do alcance.
7. Stamina (desligada por padrão).
8. Bot usando tudo + reequilíbrio.

**Fora:** 2v2 (Fase 3), arte/animações de verdade (Fase 4), dicas contextuais além do texto no botão (Fase 4).

**Princípios que não mudam:** um gesto só (segura → mira → solta); preditor = bola real; tudo em `Tuning`; bot usa `attempt_hit`.

---

## 2. Requisitos

### 2.1 Funcionais

| ID | Requisito | Fatia |
|---|---|---|
| RF-2.01 | Antes de sacar, o jogador escolhe o tipo: POR BAIXO · FLUTUANTE · VIAGEM (seletor no topo direito; lembra a última escolha na partida e no save). | 2.1 |
| RF-2.02 | POR BAIXO: sem lançamento, solta e saca (como hoje), bola lenta e alta, quase nunca erra. | 2.1 |
| RF-2.03 | FLUTUANTE e VIAGEM: apertar **lança a bola para cima**; aparece o anel de timing no sacador; soltar no anel = saque com qualidade pelo timing (mesmos graus PERFEITO/BOM/CEDO/TARDE). | 2.1 |
| RF-2.04 | Se a bola lançada cair sem ser batida, é **falta de saque** (ponto do adversário, motivo "Saque perdido"). | 2.1 |
| RF-2.05 | VIAGEM: bola rápida e com mais efeito; janela de timing menor; erro de timing espalha mais (pode sair ou ir na rede). | 2.1 |
| RF-2.06 | FLUTUANTE: a bola oscila de lado durante o voo; o anel e o ponto de queda de quem recebe só mostram a posição certa nos últimos `FLOAT_REVEAL` s. | 2.2 |
| RF-2.07 | Quando o adversário vai atacar e você está a ≤ `BLOCK_ZONE` m da rede, o botão vira **BLOQUEAR**; soltar faz pular, e o bloqueio vale enquanto as mãos estão acima da rede. | 2.3 |
| RF-2.08 | Resultado do bloqueio pelo timing: PERFEITO = bola volta para baixo no lado do atacante; BOM = amortece (sobe devagar do seu lado); ruim = desvia (tende a sair). Toque de bloqueio **não conta** como um dos 3 toques. | 2.3 |
| RF-2.09 | Atacar com a mira numa zona curta (CURTA ESQ/DIR) faz uma **largada**: bola lenta e alta que passa por cima do bloqueio. O botão mostra LARGAR. | 2.4 |
| RF-2.10 | Se no instante do toque a bola está entre `REACH` e `DIVE_REACH`, o toque vira **peixinho** (automático): alcança, mas com qualidade limitada e o jogador fica no chão por `DIVE_RECOVER` s. O botão mostra PEIXINHO quando for o caso. | 2.5 |
| RF-2.11 | Com `STAMINA_ENABLED`, viagem, cortada forte, bloqueio e peixinho gastam stamina; abaixo de 30% o jogador fica mais lento e pula menos; recupera entre pontos. Barra fina sobre o jogador. | 2.6 |
| RF-2.12 | O bot usa tipos de saque, bloqueio, largada e peixinho conforme o nível. | 2.7 |

### 2.2 Não funcionais

| ID | Requisito | Meta |
|---|---|---|
| RNF-2.01 | Preditor = bola real com flutuante e bloqueio | erro < 1 mm no teste de física |
| RNF-2.02 | Equilíbrio | humano "bom" × Médio continua perto de 50% dos pontos; casual × Fácil vence 35–60% das partidas |
| RNF-2.03 | Duração | partida casual × Fácil continua em 6–9 min (DP-05) |
| RNF-2.04 | Regressão | todos os testes das Fases 0–1 passam sem afrouxar limites |

---

## 3. Arquitetura da fase

### 3.1 Estados do rally (novos em negrito)

```
SERVE_WAIT ──(POR BAIXO: soltar)───────────────────────▶ PLAY
    │
    └──(FLUT./VIAGEM: apertar)──▶ **SERVE_TOSS** ──(soltar no tempo)──▶ PLAY
                                       │
                                       └──(bola cai)──▶ POINT_PAUSE ("Saque perdido")
```

### 3.2 Arquivos

```
scripts/core/hit_resolver.gd     NOVO  calcula alvo + velocidade de cada toque (sai de Game._execute)
scripts/core/serve_type.gd       NOVO  enum + parâmetros dos tipos de saque
scripts/core/block.gd            NOVO  janela de bloqueio (painel) usada pelo BallSim
scripts/core/ball_sim.gd         flutuante (wobble) + colisão com bloqueio + evento BLOCK
scripts/core/game.gd             SERVE_TOSS, BLOCK, DINK, peixinho, stamina
scripts/core/contact_plan.gd     campo `display_pos` (posição que a tela mostra)
scripts/entities/player.gd       DIVING, stamina, pulo de bloqueio
scripts/ai/bot_brain.gd          escolhas novas por nível
scripts/ui/hud.gd                seletor de saque
scripts/ui/markers.gd            anel no sacador, anel de bloqueio, aviso de peixinho, barra de stamina
scripts/core/save_data.gd        `serve_type` nas opções (versão 2 do save)
```

### 3.3 `Game.Act` depois da fase

```gdscript
enum Act { NONE, SERVE, RECEIVE, SET_BALL, ATTACK, FREEBALL, BLOCK, DINK, DIVE }
const ACT_LABELS := ["", "SACAR", "RECEBER", "LEVANTAR", "ATACAR", "PASSAR", "BLOQUEAR", "LARGAR", "PEIXINHO"]
```

`DINK` e `DIVE` não são planejados por `_make_plan`: são **variações** decididas na hora (`current_act` mostra, `_execute` aplica). `BLOCK` vem de um plano próprio (seção 4.4).

---

## 4. Design por fatia

### 4.1 Fatia 2.0 — `HitResolver` (refatoração, sem mudar comportamento)

`Game._execute` hoje faz duas coisas: regras (contadores, sinais, plano) e cálculo do lançamento (ímã, dispersão, lado, velocidade). A fase 2 dobra o cálculo; ele sai para uma classe sem estado próprio.

```gdscript
class_name HitResolver
extends RefCounted
## Dado quem toca, a ação, a mira e a qualidade, devolve para onde e como a bola sai.

var rng: RandomNumberGenerator      # o mesmo do Game (testes com semente continuam iguais)


## {"from": Vector3, "vel": Vector3, "grav": float, "kind": int, "target": Vector3}
func resolve(game: Game, p: Player, act: int, aim: Vector3, q: float, cap: float) -> Dictionary
func scatter(target: Vector3, kind: int, q: float) -> Vector3       # = Game._scatter de hoje
```

`Game._execute` fica com: alcance → qualidade → `resolver.resolve(...)` → `ball.launch` → contadores → sinal → plano. Mesma ordem de chamadas ao `rng`, para os números das simulações não mudarem.

**Pronto quando:** testes e números das simulações iguais aos da `main` (com sementes fixas).

---

### 4.2 Fatia 2.1 — Tipos de saque e saque com timing

**`scripts/core/serve_type.gd`**

```gdscript
class_name ServeType
extends RefCounted

enum Kind { UNDER, FLOAT, JUMP }
const NAMES := ["POR BAIXO", "FLUTUANTE", "VIAGEM"]
```

**`Tuning` (valores iniciais):**

```gdscript
# --- Saque (Fase 2) ---
const SERVE_TOSS_H := [0.0, 1.2, 2.6]        # m acima da mão; 0 = sem lançamento
const SERVE_CONTACT_H := [1.05, 2.45, 3.0]   # altura do contato (centro da bola)
const SERVE_TIME := [1.8, 1.45, 1.05]        # s de voo até o alvo
const SERVE_GRAV := [11.0, 11.0, 16.0]       # viagem com "topspin" (= SPIKE_GRAVITY)
const SERVE_WINDOW := [1.0, 1.0, 0.7]        # multiplica WINDOW_EARLY/LATE, PERFECT e GOOD
const SERVE_SCATTER := [0.4, 0.8, 1.6]       # m de dispersão com q = 0
const SERVE_Q_UNDER := 0.9                   # por baixo não tem timing: qualidade fixa
```

**Fluxo (`Game`):**

| Momento | O que acontece |
|---|---|
| `SERVE_WAIT`, sacador aperta (`human_press` / bot) com tipo FLOAT/JUMP | `_toss(p)`: `ball.launch(mão, (0, v_toss, 0))` com `v_toss` para subir `SERVE_TOSS_H`; `state = SERVE_TOSS`; cria `plan = ContactPlan(team, 0, Act.SERVE, t_contato, pos_contato, p)` com `t_contato` = quando a bola desce por `SERVE_CONTACT_H` (`find_descent`). No JUMP o sacador dá um passo à frente e pula sozinho como no ataque (`start_jump` em `t_contato − JUMP_TIME_UP`). |
| Soltar | `attempt_hit` usa a janela do plano (× `SERVE_WINDOW[tipo]`), agenda como os outros toques; `_execute` com `act == SERVE` chama `_serve(p, aim, q)`. |
| Bola do lançamento toca o chão em `SERVE_TOSS` | `_award(1 − team, "Saque perdido")`. |
| POR BAIXO | sem `SERVE_TOSS`: soltar chama `_serve(p, aim, SERVE_Q_UNDER)` direto, como hoje. |

`_serve(p, aim, q)` passa a receber `q`; dispersão `SERVE_SCATTER[tipo] * (1 − q)`; voo `SERVE_TIME[tipo]` com `SERVE_GRAV[tipo]` via `clear_net_velocity`. A assistência "toque BOM fica dentro" continua valendo para o humano em FLOAT e UNDER; **não vale para VIAGEM** (é o risco do saque forte).

**Escolha do tipo:**
- `Game.serve_type: Array[int] = [UNDER, UNDER]` (por time). Humano troca pelo seletor; bot decide em `BotBrain`.
- HUD (`Hud.Mode.MATCH`, só em `SERVE_WAIT` quando você saca): 3 botões pequenos na faixa do topo à direita (dentro de `TOP_BAR`, então não acionam o botão de ação). Sinal `serve_type_chosen(kind)`.
- `SaveData` versão 2: `[options] serve_type=0`. `load_file` de um save versão 1 usa o padrão.

**Marcadores:** com plano `SERVE`, o anel aparece no chão **embaixo do sacador** e o anel branco fecha até `t_contato` — mesma leitura de todo o resto do jogo.

---

### 4.3 Fatia 2.2 — Flutuante: oscilação determinística + leitura atrasada

**Física (`BallSim`):**

```gdscript
var age := 0.0                # s desde o lançamento
var wobble_amp := 0.0         # m (0 = bola normal)
var wobble_freq := 0.0        # rad/s
var wobble_phase := 0.0
```

`_move(t)` soma em x o termo exato `A·(sin(ω(age+t)+φ) − sin(ω·age+φ))` e avança `age`. z e y não mudam, então `t_cross` e `t_floor` continuam analíticos; o x na rede (rede/antena) já sai certo porque é calculado por `_move`. `copy()` copia os campos novos. **O preditor continua usando o mesmo código.**

`Tuning`: `FLOAT_AMP := Vector2(0.35, 0.7)` (sorteada pela qualidade: melhor saque = mais oscilação), `FLOAT_FREQ := 4.5`, `FLOAT_REVEAL := 0.45`.

Para o alvo continuar sendo o alvo: o saque compensa a oscilação no lançamento (subtrai o deslocamento total que a oscilação vai causar até o pouso), de modo que **a bola cai no ponto mirado**; o que oscila é o caminho.

**Leitura atrasada (`ContactPlan.display_pos`):**
- `_make_plan` calcula `pos` exato (como sempre) e também `display_pos` = mesma conta numa cópia com `wobble_amp = 0` (a trajetória "sem efeito").
- `Markers` desenha o anel e o ponto de queda em `display_pos` até `t − FLOAT_REVEAL`; depois desliza para `pos` em 0,15 s.
- O **bot** também só "enxerga" `pos` depois de `t − FLOAT_REVEAL` (`BotBrain` anda para `display_pos` antes disso). Mesma informação para os dois lados.
- O ímã de posição (`magnet_point`) usa `display_pos` antes da revelação.

---

### 4.4 Fatia 2.3 — Bloqueio

**Plano de bloqueio.** Além do `plan` normal, `Game` mantém `block_plan: ContactPlan` para o time que defende quando o plano do adversário é `ATTACK`:

| Campo | Valor |
|---|---|
| `player` | jogador do time defensor mais perto da rede, se a ≤ `BLOCK_ZONE` (1,2 m) |
| `pos` | ponto na rede: x do ataque previsto (antes do ataque: x do `plan.pos` do atacante; depois: x onde a cortada cruza z = 0) |
| `t` | instante em que a bola cruza a rede (antes do ataque: estimativa `plan.t + dist/ATTACK_SPEED_MAX`; depois: exato pelo preditor) |
| `act` | `Act.BLOCK` |

`current_act(p)` devolve `BLOCK` se `block_plan.player == p` e não há plano normal para `p`.

**Gesto:** soltar com `BLOCKAR` faz o jogador pular (`start_jump` no ponto da rede); o **pico** do pulo é o instante de referência do timing: `err = t_cruzamento − t_pico`. A mira não é usada.

**`scripts/core/block.gd`**

```gdscript
class_name Block
extends RefCounted
## Mãos do bloqueador: um retângulo vertical no plano z = side·BLOCK_DEPTH, ativo enquanto
## as mãos passam da fita da rede. Conhecido assim que o pulo começa (determinístico).

var side: float               # lado do bloqueador (+1/−1)
var x_center: float
var half_w := Tuning.BLOCK_HALF_W
var t_start: float            # relógio do Game: começo do pulo
var team: int
var player: Player

func top_at(t: float) -> float          # altura das mãos no instante t (curva do pulo)
func active_at(t: float) -> bool         # mãos acima de NET_HEIGHT
```

**Física (`BallSim`):** `var blocks: Array[Block]`, passados pelo `Game` ao lançar e ao começar um pulo de bloqueio. `advance` ganha um terceiro tempo candidato, `t_block` (cruzar o plano z = ±`BLOCK_DEPTH` do lado do bloqueador dentro de `half_w` e abaixo de `top_at`). Ao bater: evento `Ev.BLOCK` com `{pos, block}`, a bola **para no ponto de contato** (velocidade zerada) e quem decide a saída é o `Game` — igual à rede, o preditor sabe do bloqueio desde que o pulo começou.

**Saída (`Game._on_block`):**

| Grau (erro do pico) | Saída | Contadores |
|---|---|---|
| PERFEITO (≤ `PERFECT`) | bola para baixo no lado do atacante, 1,5–3 m da rede | `last_team = bloqueador`, `touches = 0` → ponto provável |
| BOM (≤ `GOOD`) | bola sobe devagar do lado do bloqueador (amortece) | `last_team = bloqueador`, `touches = 0` (bloqueio não conta) |
| ruim | desvia para fora da quadra, em direção à lateral mais próxima | `last_team = bloqueador` → se sair, ponto do atacante |

`Tuning`: `BLOCK_ZONE := 1.2`, `BLOCK_DEPTH := 0.25`, `BLOCK_HALF_W := 0.45`, `BLOCK_REACH := 0.55` (mãos acima da fita no pico), `BLOCK_RECOVER := 0.35`.

**Atacar contra o bloqueio:** sem regra nova — mirar longe do bloqueador (linha × diagonal) já passa. `Markers` mostra, enquanto você mira o ataque, a "sombra" do bloqueio adversário (faixa no chão do outro lado atrás das mãos).

---

### 4.5 Fatia 2.4 — Largada

- No 3º toque com plano `ATTACK`, se a mira (depois do ímã) cai numa zona com `"dink": true` (CURTA ESQ, CURTA DIR) ou a menos de `DINK_DIST` (2,5 m) da rede, a ação vira `DINK`.
- `current_act` devolve `DINK` enquanto você segura com a mira ali → o botão mostra **LARGAR** antes de soltar.
- `HitResolver`: `DINK` sai do ponto de ataque com ápice ≥ `NET_HEIGHT + BLOCK_REACH + 0.3` e voo `T_DINK` (0,9 s), gravidade normal, dispersão `SCATTER_DINK` (0,6 m).
- Bloqueio contra largada: o painel só pega se o ápice não passou — com o ápice acima do alcance, passa.

`ATTACK_ZONES` passa a ter um terceiro campo: `["CURTA ESQ", Vector2(-2.2, 1.8), true]`.

---

### 4.6 Fatia 2.5 — Peixinho

- `_execute`: se a distância até a bola for `> REACH` e `≤ DIVE_REACH` (2,6 m), em vez de `LONGE` vira `DIVE`: `q = minf(q, DIVE_Q_MAX)` (0,5), o jogador entra em `DIVING` (deita, sem andar) por `DIVE_RECOVER` (0,9 s) e o toque segue a ação do plano (recepção/levantamento/passe) com essa qualidade.
- `current_act` devolve `DIVE` quando o plano é seu e, **no ritmo atual**, você não chega a `REACH` até `plan.t` mas chega a `DIVE_REACH` (estimativa: distância − velocidade × tempo restante). O botão mostra **PEIXINHO** e o anel fica laranja tracejado.
- Ataque não tem peixinho (no ar não dá).
- `Player`: `var diving_t := 0.0`; `step` ignora `move_input` enquanto `diving_t > 0`; animação: corpo deita (rotação 80° na direção do mergulho) e levanta.

---

### 4.7 Fatia 2.6 — Stamina (experimento)

`Tuning.STAMINA_ENABLED := false`. Com a flag desligada, nada muda (testes garantem).

| | Valor |
|---|---|
| Custo | VIAGEM 0,15 · ataque `0,08 × power` · bloqueio 0,05 · peixinho 0,2 |
| Recuperação | 0,04/s em jogo · +0,25 a cada ponto |
| Cansado (< 0,3) | `speed × 0,85`, `JUMP_HEIGHT × 0,8`, `ATTACK_SPEED_MAX` reduzido em 10% |
| Sem stamina para a ação | executa como "cansado" (não bloqueia o gesto) |

`Player.stamina: float`; `Game` desconta em `_execute`/`_serve`/pulo de bloqueio. `Markers`: barra fina sobre o jogador (só com a flag). Avaliação: testar no celular com e sem; fica ligada só se melhorar as decisões sem frustrar (DP-03).

---

### 4.8 Fatia 2.7 — Bot e equilíbrio

| Nível | Saque | Bloqueio | Ataque | Peixinho |
|---|---|---|---|---|
| Fácil | só POR BAIXO | nunca | cortada no meio, sem largada | não |
| Médio | 70% POR BAIXO, 30% FLUTUANTE | 40% das vezes que dá, σ de timing 0,1 s | 15% largada | sim |
| Difícil | 30% / 40% FLUTUANTE / 30% VIAGEM | 75%, σ 0,06 s | mira longe do bloqueio; 25% largada quando você bloqueia | sim |

`Tuning`: `BOT_SERVE_MIX`, `BOT_BLOCK_CHANCE`, `BOT_BLOCK_SIGMA`, `BOT_DINK_CHANCE` (arrays por nível). Bot sacando FLOAT/JUMP também lança a bola e solta com o erro de timing do nível (pode errar o saque).

Depois da fatia: rodar a simulação de equilíbrio (tabela do README em % de pontos e de partidas) e a de duração.

---

## 5. Ordem dos PRs

| PR | Conteúdo | Risco |
|---|---|---|
| 1 | 2.0 `HitResolver` (sem mudança de comportamento) | baixo |
| 2 | 2.1 tipos de saque + `SERVE_TOSS` + seletor + save v2 | médio |
| 3 | 2.2 flutuante (`BallSim` wobble) + `display_pos` | **alto** (invariante do preditor) |
| 4 | 2.3 bloqueio (`Block`, evento `BLOCK`, plano de bloqueio) | **alto** |
| 5 | 2.4 largada | baixo |
| 6 | 2.5 peixinho | médio |
| 7 | 2.6 stamina (flag desligada) | baixo |
| 8 | 2.7 bot + equilíbrio + README + versão 0.3.0 | médio |

---

## 6. Testes

| Grupo | Casos |
|---|---|
| `_test_hit_resolver` | mesma semente → mesmo alvo/velocidade que o código antigo (tabela de casos fixos) |
| `_test_serve_types` | POR BAIXO saca sem `SERVE_TOSS`; FLOAT/JUMP entram em `SERVE_TOSS` com plano `SERVE`; soltar no `t` = PERFEITO; deixar cair = ponto "Saque perdido"; JUMP tem janela menor (soltar a 0,12 s é BOM no FLOAT e CEDO/TARDE no JUMP); tipo salvo e recarregado |
| `_test_float_physics` | preditor = real com wobble (erro < 1 mm); bola cai no ponto mirado; `display_pos` ≠ `pos` antes de `FLOAT_REVEAL` e = depois; antena com x oscilando é detectada |
| `_test_block` | bloqueador fora da zona não ganha `BLOCK`; pulo começa → preditor já mostra o evento `BLOCK`; graus por erro do pico (3 casos); bloqueio não conta toque (`touches == 0` depois); ataque mirado longe do painel passa |
| `_test_dink` | mira em CURTA vira `DINK` e o botão diz LARGAR; largada passa por cima de um bloqueio perfeito |
| `_test_dive` | bola a 2,0 m no contato vira `DIVE` com q ≤ 0,5; jogador não anda por `DIVE_RECOVER`; a 3,0 m continua LONGE; ataque nunca vira peixinho |
| `_test_stamina` | flag desligada: números das simulações iguais; ligada: custo, recuperação e efeito de "cansado" |
| `_test_bot_vs_bot` (existente) | continua passando; imprime uso de cada mecânica por nível (saques por tipo, bloqueios, largadas, peixinhos) |
| `_test_match_duration` (existente) | continua em 6–9 min |
| e2e | seletor de saque aparece no seu saque e não aciona o botão de ação; trocar para FLUTUANTE e sacar |

---

## 7. Critérios de aceite

1. Todos os testes (Fases 0–2) e o e2e passam no CI.
2. Preditor = real com flutuante e bloqueio (teste de física).
3. Bot × bot imprime uso de todas as mecânicas no Médio e no Difícil.
4. Equilíbrio e duração dentro de RNF-2.02 e RNF-2.03; tabela do README atualizada.
5. No celular: escolher saque, sacar flutuante/viagem, bloquear uma cortada, fazer uma largada e um peixinho sem precisar de explicação além do texto do botão.
6. Stamina testada no celular com e sem; decisão registrada (DP).

---

## 8. Riscos

| Risco | Mitigação |
|---|---|
| Flutuante quebrar "preditor = real" | oscilação analítica em `_move`; teste de igualdade obrigatório; PR isolado |
| Bloqueio criar casos de borda na física (bola presa, dois eventos no mesmo passo) | evento `BLOCK` para a bola e o `Game` relança; `advance` resolve eventos em ordem de tempo (como rede/chão); teste "nunca trava" do bot × bot |
| Leitura atrasada parecer bug | o anel desliza (não pula) na revelação; texto do ponto de queda some até revelar |
| Saque com timing deixar a partida mais longa | `SERVE_WAIT` do humano não muda; medir com `_test_match_duration` |
| Botão mudando de texto demais (LARGAR/PEIXINHO) | só muda enquanto o efeito é certo; teste no celular |

---

## 9. Decisões assumidas (mude se discordar)

| # | Assumido | Alternativa |
|---|---|---|
| B-1 | Bola lançada que cai = falta de saque | pode relançar uma vez |
| B-2 | Largada pela **zona curta da mira**, não por gesto de arrastar curto (o ROADMAP falava em arrastar curto; a mira é persistente, então "não arrastar" viraria largada sem querer) | gesto separado |
| B-3 | Peixinho **automático** quando a bola está entre `REACH` e `DIVE_REACH` (mantém um gesto só; o ROADMAP falava em deslizar) | gesto de deslizar |
| B-4 | Bloqueio não conta como toque (regra de quadra); no 2v2 da Fase 3 revisitar (na praia conta) | contar como toque |
| B-5 | Tipo de saque lembrado no save | volta para POR BAIXO a cada partida |
| B-6 | Assistência "bola boa fica dentro" não vale para VIAGEM | vale para todos |
| B-7 | `HitResolver.resolve` devolve `HitResolver.Shot` (classe tipada), não `Dictionary` (regra de estilo: estrutura de domínio nova é `RefCounted`). O cálculo do saque também foi para o resolver (`serve`) | `Dictionary` como no esboço da seção 4.1 |
| B-8 | POR BAIXO voa **1,45 s** (o saque da Fase 1), não 1,8 s: com 1,8 s a partida casual × Fácil foi para 8,9–9,2 min (RNF-2.03). FLUTUANTE 1,3 s, VIAGEM 1,05 s | 1,8 s e aceitar partida mais longa |
| B-9 | A bola é lançada da mão a `SERVE_HAND_H` = 1,5 m: com a mão a 1,05 m o flutuante subiria só até 2,25 m e nunca desceria pelo contato (2,45 m) | contato mais baixo |
| B-10 | A nota do saque com timing vai no sinal novo `served(player, kind, grade)`; `touch_made` continua com "SAQUE" (as estatísticas não contam saque como toque) | nota no `touch_made` |
| B-11 | Viagem sem "passo à frente": só o pulo automático (o sacador fica preso atrás da linha) | animar o passo na Fase 4 |
| B-12 | Fora do App (F6) o seletor de saque fica à esquerda do botão do nível do bot | só na partida do App |
| B-13 | O flutuante sorteia a fase da oscilação; se o balanço levaria a bola para fora da antena ao cruzar a rede, a fase é invertida (o erro do flutuante é de leitura, não de sorte) | deixar sair pela antena |
| B-14 | O ponto de queda revela `FLOAT_REVEAL` s antes do **pouso**; o anel, antes do **contato** | os dois pelo contato |
| B-15 | O plano das mãos fica **do lado do atacante** (z = −side·`BLOCK_DEPTH`: as mãos passam a fita), não do lado do bloqueador: senão o bloqueio PERFEITO, para voltar ao lado do atacante, bateria na rede | plano do lado do bloqueador e relançar a bola do outro lado |
| B-16 | Erro do bloqueio = pico − contato: pular cedo dá **CEDO** (como soltar cedo nos outros toques) | contato − pico, como o esboço |
| B-17 | Depois que a cortada sai, o botão de quem defende é RECEBER (o plano normal tem prioridade): o bloqueio é decidido antes do ataque, como na quadra | bloquear também depois da cortada |
| B-18 | O pulo de bloqueio é no lugar (mãos em x fixo, sem a deriva do pulo de ataque); depois dele o jogador não toca por `2·JUMP_TIME_UP + BLOCK_RECOVER` | deriva até o x previsto |
| B-19 | Bloqueio ruim desvia por cima da rede (sem bater nela) para fora pela lateral mais perto: ponto do atacante | desvio aleatório que às vezes fica dentro |
| B-20 | A largada é garantida pela **altura ao cruzar as mãos e a rede** (≥ `NET_HEIGHT + BLOCK_REACH + DINK_APEX_MARGIN`), não pelo ápice: com ápice alto mas antes da rede a bola já descia e batia no bloqueio | ápice, como o esboço |
| B-21 | O peixinho vale para quem tem `Player.can_dive` (humano sempre; bot a partir do Médio): sem atalho de regra, é um atributo do jogador como a velocidade | parâmetro no `attempt_hit` |
| B-22 | Ímãs e limites da mira usam a ação do plano durante o PEIXINHO (`Game.aim_act`): a recepção de peixinho continua grudando no levantador | ímãs próprios do peixinho |
| B-23 | A flag é a constante `Tuning.STAMINA_ENABLED`, copiada para `Game.stamina_on` (os testes ligam com `set_stamina(true)`); a recuperação em jogo só corre com a bola em jogo (`PLAY`) | flag só em `Tuning` |
| B-24 | Sem bloqueador na rede, a largada só passa a rede (rápida e curta); com bloqueador, sobe acima do alcance do bloqueio. Com a largada sempre alta, a bola lenta era fácil para o bot e a partida casual × Fácil passava de 9 min | sempre alta |
| B-25 | Peixinho mais limitado que o esboço: `DIVE_REACH` 2,1 m (era 2,6) e `DIVE_Q_MAX` 0,35 (era 0,5, "qualidade sempre baixa" do ROADMAP). Com 2,6/0,5 a partida casual × Fácil ia a 9,9 min (48 sementes) | valores do esboço e meta de duração maior |
| B-26 | Bot: cortada sempre além de `DINK_DIST` + 0,3 m (senão a mira curta viraria largada sem querer); o Difícil larga 25% quando você está no bloqueio e 10% quando não está | cortada curta continua possível |

---

## 10. Resultado (fim da fase)

Simulação `tests/balance_sim.gd` (humano roteirizado: não bloqueia; o "bom" ataca longe das mãos do bot quando ele está na rede). Pontos: 4 × 20 min por célula. Partidas: casual × Fácil, 48 sementes.

| | Fácil | Médio | Difícil |
|---|---|---|---|
| bom (Fase 1 → Fase 2) | 72% → 74% | 47% → **37%** | 16% → 22% |
| casual (Fase 1 → Fase 2) | 50% → 50% | 34% → 26% | 13% → 14% |

| Casual × Fácil, partidas inteiras | Fase 1 | Fase 2 |
|---|---|---|
| Vitórias | 52% | **46%** (RNF-2.02: 35–60% ✔) |
| Duração média | 8,3 min (7,6 s/ponto) | **8,8 min** (8,3 s/ponto) (RNF-2.03: 6–9 ✔, com pouca folga) |

**Em aberto:**
- RNF-2.02 "bom × Médio perto de 50%": ficou em ~37–42% (ruído de ±4 pontos entre rodadas). O Médio ficou mais forte com flutuante, bloqueio, largada e peixinho; mexer em `BOT_POWER`/`BOT_TIMING_SIGMA`/`BOT_SPEED` do Médio não moveu o número além do ruído. Decidir no celular: aceitar, ou tirar o peixinho do Médio (chegou a 41–43% na simulação).
- Duração: o teste do CI (8 sementes) dá 8,4 min; com 48 sementes, 8,8 min. Peixinho e largada alongam o rally (+0,7 s por ponto).
- Critérios 5 e 6 (teste no celular, decisão da stamina) dependem do dono do projeto.
