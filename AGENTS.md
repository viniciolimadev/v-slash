# AGENTS.md

Guia para agentes de IA que trabalham neste repositório. Leia inteiro antes de mudar qualquer coisa.
O padrão completo (para pessoas e agentes) está em [docs/PADRAO-DE-TRABALHO.md](docs/PADRAO-DE-TRABALHO.md); aqui está o essencial e o que é específico de agente.

## O projeto em 30 segundos

Jogo de vôlei para celular em **Godot 4.7 / GDScript**, renderer Compatibility (Android, Web). 1v1 contra bot hoje (Fase 0); evolui por fases até 2v2 com arte e lançamento. O jogador se posiciona num **anel no chão** e **segura → mira → solta** quando o anel branco fecha. Tudo é gerado por código.

| Leia | Para |
|---|---|
| [README.md](README.md) | rodar, controles, tabela de ajuste do feel |
| [docs/ROADMAP.md](docs/ROADMAP.md) | fases e fatias (o quê) |
| [docs/SDD.md](docs/SDD.md) | arquitetura, invariantes, ADRs, decisões de produto (como) |
| `docs/SDD-fase-N.md` | design de implementação da fase atual — **a fonte da verdade para a tarefa** |

Fase atual: **Fase 3 implementada** ([docs/SDD-fase-3.md](docs/SDD-fase-3.md); falta o teste no celular); a **Fase 4** segue [docs/SDD-fase-4.md](docs/SDD-fase-4.md).

## Mapa do código

```
scripts/main.gd            monta a partida, liga sinais, entrada humana
scripts/core/ball_sim.gd   física exata da bola + preditor (mesmo código)
scripts/core/game.gd       regras, plano de contato, toque, pontos
scripts/core/tuning.gd     TODOS os números de feel
scripts/ai/bot_brain.gd    bot (lê o mesmo plano, chama attempt_hit)
scripts/ai/partner_brain.gd  2v2: posição sem bola por papel
scripts/core/court_spec.gd medidas da quadra por modo (1v1 / 2v2)
scripts/core/team.gd       jogadores do time e ordem de saque
scripts/entities/          Player, Ball (visual), Court
scripts/ui/                TouchControls, Hud, Markers
tests/run_tests.gd         testes headless
tests/e2e/mobile_smoke.js  e2e no navegador com toque emulado
```

## Comandos

```bash
godot --headless --import                              # 1ª vez / depois de criar class_name
godot --headless --script res://tests/run_tests.gd     # precisa terminar com "falhas: 0" e sem "SCRIPT ERROR"
godot -- --autoplay                                    # demo bot x bot
```

Se o binário `godot` não existir no ambiente, diga isso no relatório final: **não afirme que os testes passam sem tê-los rodado.** O CI (`.github/workflows/build.yml`) roda testes, e2e, Web e APK em todo PR.

## Regras invioláveis

1. **Preditor = bola real.** Efeito na bola vai em `BallSim`, determinístico; nunca uma física paralela só para o visual ou só para a previsão.
2. **Número de feel só em `Tuning`**, com comentário de unidade, e linha na tabela do README se for algo que alguém vai querer ajustar.
3. **`core/` não importa `ui/` nem `ai/`.** `Game` comunica por sinais e consultas.
4. **Bot usa `attempt_hit` como o humano.** Sem atalho de regra para a IA. Mecânica nova → bot usa.
5. **`scenes/main.tscn` roda sozinha** (testes, `--autoplay`) — sem autoload, sem depender da `App`.
6. **Tudo por código** até a Fase 4: sem assets externos, sem nós em `.tscn` além da raiz.
7. **Não afrouxe testes existentes** para passar. Se um limite estiver errado, pare e explique.
8. Quebrar qualquer item acima exige ADR no `docs/SDD.md` **e** aprovação do dono do projeto.

## Como trabalhar numa tarefa

1. Identifique a fatia no SDD da fase (ex.: `F1 · 1.2`). Se a tarefa não está lá, pergunte se deve entrar no SDD antes.
2. Leia os arquivos que vai mudar **e** os que chamam o que você vai mudar (`grep` pelo nome).
3. Escreva o teste em `tests/run_tests.gd` primeiro, no padrão `_check(cond, "regra em português")`.
4. Implemente o mínimo, no estilo do código vizinho.
5. Rode os testes. Compare os números impressos pelas simulações antes/depois.
6. Atualize README / SDD / ROADMAP se afetados.
7. Commit e PR **somente se o usuário pedir**; nunca em `main` — crie branch `f<fase>/<fatia>-<assunto>`.

Uma fatia por vez. Não adiante fatias seguintes "já que está mexendo".

## Estilo

- Identificadores em **inglês**; comentários, docs, UI e mensagens de teste em **português**.
- GDScript com tabs, tipagem estática (`:=`, `-> Tipo`, `Array[T]`), `class_name` + comentário `##` em classes, `_privado`.
- Estrutura nova de domínio = classe `RefCounted` tipada, não `Dictionary`.
- Comentário diz o porquê; mesma densidade do código ao redor.
- Ao criar `class_name` novo, rode `--import` antes dos testes. Arquivos `.gd.uid` são versionados: commite junto.
- Não edite `.godot/`, `export/` nem `export_presets.cfg` sem motivo da tarefa.

## Commits e PRs

- Commit em inglês: `Área: resumo no imperativo` (`Game`, `Ball`, `Bot`, `Aim`, `HUD`, `UI`, `Controls`, `Match`, `Save`, `Tutorial`, `Test`, `CI`, `Docs`, `Tuning`). Corpo: por quê, efeito medido, teste que cobre.
- PR pelo modelo `.github/pull_request_template.md`, citando fatia e requisitos (`F1 · 1.2 · RF-1.02`).
- Refatoração sem mudança de comportamento em commit/PR separado.

## Quando parar e perguntar

- Regra de jogo, escopo, formato de partida, o que o jogador vê → **decisão de produto, pergunte**.
- O SDD da fase não cobre o caso, ou o código real contradiz o SDD.
- A solução exige quebrar uma regra inviolável.
- Teste existente falha por motivo que você não entende.

Detalhes razoáveis que você decidir sozinho: liste em "Decisões assumidas" do SDD da fase e no relatório final.

## Relatório final

Diga o que mudou (arquivos), por quê, o que foi testado e o resultado real (com os números das simulações), o que **não** foi feito ou verificado, e o próximo passo.
