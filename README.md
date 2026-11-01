# Vôlei Mobile — Fase 4

Vôlei 1v1 contra bot: **bola cinemática + anel de timing + gesto segura → mira → solta**.
Partida em **melhor de 3 sets de 15** (vantagem de 2), com título, escolha do bot, tutorial, pausa, opções e resultado; progresso salvo no aparelho.
Fase 2: saque **por baixo / flutuante / viagem**, **bloqueio**, **largada**, **peixinho** e stamina (experimento, desligada).
Fase 3: modo **2v2** (quadra 8 × 8, parceiro IA): você controla sempre quem vai tocar na bola; ninguém toca duas vezes seguidas.
Fase 4: **praia** low-poly com jogadores animados (esqueleto, 14 clipes no tempo do toque), torcida, rastro/areia/tremor, sons e músicas, tema próprio com a fonte Fredoka.
Modelos, quadra e ícones são gerados por código; sons e músicas por `tools/gen_audio.py` ([docs/ARTE.md](docs/ARTE.md)). Godot **4.7**, renderizador Compatibility (Android/iOS/Web).

## Abrir e jogar

1. Godot 4.7 → **Importar** → escolha `project.godot`.
2. **F5** abre o título. Na 1ª partida o tutorial roda antes (dá para pular). Médio libera ao vencer o Fácil; Difícil ao vencer o Médio.
3. Só a partida, sem menus (rally infinito, troca de nível no topo): abra `scenes/main.tscn` e **F6**.

| Ação | Celular | PC |
|---|---|---|
| Andar | polegar esquerdo (o joystick nasce onde você encosta) | WASD / setas |
| Tocar na bola | segure na metade direita → arraste para mirar → **solte** | segure **Espaço** (mira padrão) ou clique-segure-arraste na direita |
| Modo | na escolha do bot: **1v1 · 2v2** (cada modo tem seus níveis e recordes) | mouse |
| Tipo de saque | antes do seu saque: **POR BAIXO · FLUTUANTE · VIAGEM** no topo direito (fica salvo) | mouse |
| Pausa | botão **II** ou voltar do Android (trocar de app também pausa) | mouse |

## O loop

| Na tela | Significa |
|---|---|
| Anel colorido no chão | onde ficar para o próximo toque (cor = ação) |
| Anel branco fechando | solte quando encostar no colorido = **PERFEITO** (fica verde) |
| Ponto branco | onde a bola cai se ninguém tocar (dá para deixar cair bola fora) |
| Sombra preta | posição da bola no chão (noção de altura) |
| Texto do botão | SACAR · RECEBER (1º) · LEVANTAR (2º) · ATACAR (3º, pulo automático) · BLOQUEAR · LARGAR · PEIXINHO |
| Levantamento | a mira gruda em **ALTA** (padrão), **PONTA**, **RÁPIDA**, **PIPE** |
| Saque flutuante/viagem | apertar **lança a bola**; o anel fecha embaixo de você: solte no anel. Bola lançada que cai = ponto do bot. Viagem: janela menor, mais forte, pode errar |
| Flutuante recebido | a bola balança de lado; o anel e o ponto de queda só ficam certos perto do contato (deslizam) |
| Anel roxo na rede | o bot vai atacar e você está perto da rede: **BLOQUEAR** pula; solte quando o anel fechar (pico na hora da cortada) |
| Faixa escura no chão | enquanto você mira o ataque com o bot na rede: onde o bloqueio dele pega. Mire fora dela |
| Mira nas zonas CURTA | **LARGAR**: bola curta (passa por cima do bloqueio se ele estiver na rede) |
| Anel laranja / PEIXINHO | no seu ritmo você não chega: o toque vira peixinho sozinho (alcança, mas sai fraco e você fica no chão) |

Timing ruim = bola menos precisa (e cortada mais fraca). Longe do anel = "LONGE", não toca.

O HUD mostra o placar do set, os sets, **SET POINT / MATCH POINT**, o rally e o recorde.
Opções (título ou pausa): sensibilidade da mira, volume de música e de efeitos, modo canhoto (joystick e botão trocam de lado), vibração.

## Ajustar o feel → `scripts/core/tuning.gd`

| Se… | Mexa em |
|---|---|
| difícil acertar o tempo | `WINDOW_EARLY`, `WINDOW_LATE`, `PERFECT` |
| não chega na bola | `REACH`, `MOVE_SPEED` |
| cortada impossível de defender | `ATTACK_SPEED_MAX`, `SPIKE_GRAVITY` |
| mira sensível demais | `AIM_SENS` |
| mira gruda demais / de menos | `AIM_MAGNET_RADIUS`, `RECEIVE_MAGNET_RADIUS`, `ATTACK_ZONES` |
| bola boa ainda sai / nunca sai | `AIM_MARGIN`, `ASSIST_KEEP_IN_Q` |
| jogo lento/rápido | `GRAVITY`, `T_RECEIVE`, `T_SET_HIGH` |
| bot forte/fraco | `BOT_SPEED`, `BOT_REACTION`, `BOT_POWER` |
| partida longa/curta | `SET_POINTS`, `SETS_TO_WIN`, `WIN_BY`, `POINT_PAUSE` |
| saque fácil/difícil | `SERVE_TIME`, `SERVE_WINDOW`, `SERVE_SCATTER`, `SERVE_Q_UNDER` |
| flutuante balança demais / leitura cedo ou tarde | `FLOAT_AMP`, `FLOAT_FREQ`, `FLOAT_REVEAL`, `FLOAT_SLIDE` |
| bloqueio fácil/difícil | `BLOCK_ZONE`, `BLOCK_HALF_W`, `BLOCK_REACH`, `BLOCK_T_DOWN` |
| largada | `DINK_DIST`, `T_DINK`, `DINK_APEX_MARGIN`, `SCATTER_DINK` |
| peixinho | `DIVE_REACH`, `DIVE_Q_MAX`, `DIVE_RECOVER` |
| stamina (experimento) | `STAMINA_ENABLED` e os `STAMINA_*` / `TIRED_*` |
| bot saca/bloqueia/larga mais ou menos | `BOT_SERVE_MIX`, `BOT_BLOCK_CHANCE`, `BOT_BLOCK_SIGMA`, `BOT_DINK_CHANCE` |
| tamanho da quadra (1v1 / 2v2) | `COURT_1V1`, `COURT_2V2`, `NET_OVERHANG` |
| 2v2: parceiro e dupla do bot | `PARTNER_LEVEL`, `BOT_SPEED_2V2` |
| visual simples (sem modelos nem praia) | `USE_MODEL_VIEWS` |
| tremor de câmera na cortada | `SHAKE_TIME`, `SHAKE_AMP` |
| vibração por evento | `VIBRATE_PERFECT`, `VIBRATE_GOOD`, `VIBRATE_BLOCK`, `VIBRATE_POINT` |

Equilíbrio dos valores atuais (`godot --headless --script res://tests/balance_sim.gd -- --matches=48`: 4 × 20 min por célula; "humano" roteirizado com reação e erro de timing, que não bloqueia; o "bom" ataca longe das mãos do bot quando ele está na rede):

| Você | Fácil | Médio | Difícil |
|---|---|---|---|
| bom (reação 0,25 s, erro 50 ms) | 74% dos pontos | 37% | 22% |
| casual (reação 0,4 s, erro 90 ms) | 50% | 26% | 14% |

Partida inteira, casual × Fácil: 48 sementes → vence **46%**, média **8,8 min**; no CI (`_test_match_duration`, 8 sementes) vence 2 de 8, média 8,4 min.

2v2 (testes do CI, 8 sementes): casual × Fácil vence 4 de 8, média **8,3 min**; rally médio do humano bom × Médio: 10,3 toques no 2v2 contra 6,5 no 1v1.

## Testar no celular sem instalar nada (CI)

Todo push no `main` roda o workflow `.github/workflows/build.yml`:

| Saída | Onde |
|---|---|
| Testes headless | aba **Actions** (falha se houver `SCRIPT ERROR`) |
| Versão Web | **GitHub Pages**: `https://viniciolimadev.github.io/v-slash/` — abrir no navegador do celular |
| APK de debug (arm64) | Actions → execução → **Artifacts** → `volei-mobile-apk` → instalar no Android |

Uma vez só: Settings → Pages → Source = **GitHub Actions**.

## Rodar no Galaxy (Android)

1. Editor → **Gerenciar modelos de exportação** → baixar.
2. Configurações do Editor → Exportar → Android: caminho do **JDK 17** e do **Android SDK**.
3. Projeto → Exportar → **Adicionar Android** → em Permissões marque **Vibrate**.
4. Celular com **depuração USB** ligada → ícone do Android no topo do editor (deploy em 1 clique).

## Testes sem tela

```bash
godot --headless --import                              # 1ª vez: registra as classes
godot --headless --script res://tests/run_tests.gd     # física, sets, save, telas, tutorial, simulações
godot -- --autoplay                                    # demo bot x bot
godot -- --autoplay --fps                              # com contador de fps (médio e p1)
godot -- --autoplay --no-views                         # só a lógica: sem modelos, praia, efeitos nem som
python3 tools/gen_audio.py                             # regenera assets/audio (precisa de ffmpeg com libvorbis)
```

Teste no navegador emulando celular (título → opções → escolha → tutorial → partida → fps → pausa → menu → 2v2, com prints):

```bash
mkdir -p export && touch export/.gdignore             # Godot ignora builds/prints
godot --headless --export-release "Web" export/web/index.html
npm i --prefix /tmp/pw playwright && /tmp/pw/node_modules/.bin/playwright install chromium
NODE_PATH=/tmp/pw/node_modules node tests/e2e/mobile_smoke.js export/web export/e2e  # prints em export/e2e
```

No CI os prints ficam em Actions → execução → Artifacts → `e2e-screenshots`. O CI também falha se o APK passar de 60 MB ou a Web (wasm + pck, gzip) passar de 40 MB.

## Estrutura

```
project.godot          config do Godot (cena principal: scenes/app.tscn)
scenes/app.tscn        raiz do app: telas + partida
scenes/main.tscn       uma partida (roda sozinha: testes, --autoplay, F6)
scripts/
  main.gd              monta a partida e liga tudo (MatchScene)
  app/                 roteador de telas (App) e MatchConfig
  core/                regras, física, sets, estatísticas, save (sem nós visuais)
  ai/                  bot
  entities/            jogador e bola (lógica) e a quadra simples
  view/                visual e som (ADR-09): modelos, animações, praia, efeitos, sons
  ui/                  HUD, controles, marcadores, pausa, tema, ícones, fps
  ui/screens/          título, escolha do bot, resultado, opções
  tutorial/            tutorial jogável
tests/run_tests.gd     testes headless
tests/balance_sim.gd   simulação de equilíbrio (tabela acima; fora do CI)
assets/                fonte (OFL) e áudio gerado; créditos em CREDITS.md
tools/gen_audio.py     sintetizador dos sons e músicas
docs/                  roadmap, SDDs, padrão de trabalho, pipeline de arte
```

| Arquivo | Faz |
|---|---|
| `scripts/core/ball_sim.gd` | física exata da bola (parábola, flutuante, bloqueio, rede, chão) + preditor |
| `scripts/core/game.gd` | regras, plano de contato (quem/onde/quando), toque, saque, bloqueio, pontos |
| `scripts/core/hit_resolver.gd` | para onde e como a bola sai de cada toque (saque, largada, bloqueio) |
| `scripts/core/serve_type.gd` | tipos de saque |
| `scripts/core/block.gd` | mãos do bloqueio (usadas pela física) |
| `scripts/core/tuning.gd` | todos os números |
| `scripts/ai/bot_brain.gd` | IA (usa o mesmo preditor) |
| `scripts/ai/partner_brain.gd` | 2v2: posição sem bola por papel (recepção, levantador, ataque, defesa) |
| `scripts/core/team.gd` | jogadores do time e ordem de saque |
| `scripts/core/court_spec.gd` | medidas da quadra por modo |
| `scripts/entities/ball.gd` | bola em jogo (modo, quiques depois do ponto) |
| `scripts/entities/player.gd` | movimento, pulo automático, peixinho; avisa a view por sinais |
| `scripts/entities/court.gd` | quadra simples (com `USE_MODEL_VIEWS = false`) |
| `scripts/view/player_view_model.gd` | jogador low-poly (esqueleto + malha única), clipes agendados pelo plano |
| `scripts/view/anim_table.gd` | os 14 clipes (poses por junta, instante de contato) |
| `scripts/view/court_view.gd` | praia: areia, linhas, rede, mar, coqueiros, torcida |
| `scripts/view/fx.gd`, `camera_fx.gd` | rastro, areia, brilho do PERFEITO, tremor de câmera |
| `scripts/view/sfx.gd` | sons por evento do jogo, torcida, música da partida, volumes |
| `scripts/ui/ui_theme.gd`, `icons.gd` | tema (fonte, botões, painéis) e ícones das ações |
| `scripts/ui/markers.gd` | sombra, ponto de queda, anel, mira |
| `scripts/ui/touch_controls.gd` | joystick flutuante + botão de ação |
| `scripts/ui/hud.gd` | placar, sets, selos, faixas, feedback, botão de pausa |
| `scripts/core/match_rules.gd` | pontos e sets (15, vantagem de 2, melhor de 3) |
| `scripts/core/match_stats.gd` | estatísticas da partida (pelos sinais do Game) |
| `scripts/core/save_data.gd` | progresso, recordes e opções em `user://save.cfg` |
| `scripts/app/app.gd` | título → escolha → tutorial → partida → resultado |
| `scripts/tutorial/tutorial_director.gd` | os 3 passos do tutorial |
| `scripts/ui/e2e_hooks.gd` | só na Web: posições dos botões para o e2e |

## Próximas fases

Lançamento → Fase 5. Plano completo em [docs/ROADMAP.md](docs/ROADMAP.md) e design em [docs/SDD.md](docs/SDD.md).
