# Vôlei Mobile — Fase 2

Vôlei 1v1 contra bot: **bola cinemática + anel de timing + gesto segura → mira → solta**.
Partida em **melhor de 3 sets de 15** (vantagem de 2), com título, escolha do bot, tutorial, pausa, opções e resultado; progresso salvo no aparelho.
Fase 2: saque **por baixo / flutuante / viagem**, **bloqueio**, **largada**, **peixinho** e stamina (experimento, desligada).
Tudo é gerado por código (formas simples). Godot **4.7**, renderizador Compatibility (Android/iOS/Web).

## Abrir e jogar

1. Godot 4.7 → **Importar** → escolha `project.godot`.
2. **F5** abre o título. Na 1ª partida o tutorial roda antes (dá para pular). Médio libera ao vencer o Fácil; Difícil ao vencer o Médio.
3. Só a partida, sem menus (rally infinito, troca de nível no topo): abra `scenes/main.tscn` e **F6**.

| Ação | Celular | PC |
|---|---|---|
| Andar | polegar esquerdo (o joystick nasce onde você encosta) | WASD / setas |
| Tocar na bola | segure na metade direita → arraste para mirar → **solte** | segure **Espaço** (mira padrão) ou clique-segure-arraste na direita |
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
Opções (título ou pausa): sensibilidade da mira, modo canhoto (joystick e botão trocam de lado), vibração.

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

Equilíbrio dos valores atuais (`godot --headless --script res://tests/balance_sim.gd -- --matches=48`: 4 × 20 min por célula; "humano" roteirizado com reação e erro de timing, que não bloqueia; o "bom" ataca longe das mãos do bot quando ele está na rede):

| Você | Fácil | Médio | Difícil |
|---|---|---|---|
| bom (reação 0,25 s, erro 50 ms) | 74% dos pontos | 37% | 22% |
| casual (reação 0,4 s, erro 90 ms) | 50% | 26% | 14% |

Partida inteira, casual × Fácil: 48 sementes → vence **46%**, média **8,8 min**; no CI (`_test_match_duration`, 8 sementes) vence 2 de 8, média 8,4 min.

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
```

Teste no navegador emulando celular (título → escolha → tutorial → partida → pausa → menu, com prints):

```bash
mkdir -p export && touch export/.gdignore             # Godot ignora builds/prints
godot --headless --export-release "Web" export/web/index.html
npm i --prefix /tmp/pw playwright && /tmp/pw/node_modules/.bin/playwright install chromium
NODE_PATH=/tmp/pw/node_modules node tests/e2e/mobile_smoke.js export/web export/e2e  # prints em export/e2e
```

No CI os prints ficam em Actions → execução → Artifacts → `e2e-screenshots`.

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
  entities/            objetos 3D do jogo
  ui/                  HUD, controles, marcadores, pausa
  ui/screens/          título, escolha do bot, resultado, opções
  tutorial/            tutorial jogável
tests/run_tests.gd     testes headless
tests/balance_sim.gd   simulação de equilíbrio (tabela acima; fora do CI)
docs/                  roadmap, SDDs, padrão de trabalho
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
| `scripts/entities/ball.gd` | visual da bola |
| `scripts/entities/player.gd` | movimento, pulo automático, animação |
| `scripts/entities/court.gd` | quadra, rede, antenas |
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

2v2 → Fase 3 · arte e som → Fase 4. Plano completo em [docs/ROADMAP.md](docs/ROADMAP.md) e design em [docs/SDD.md](docs/SDD.md).
