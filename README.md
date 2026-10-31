# Vôlei Mobile — Fase 0

Protótipo 1v1 contra bot: **bola cinemática + anel de timing + gesto segura → mira → solta**.
Tudo é gerado por código (formas simples). Godot **4.7**, renderizador Compatibility (Android/iOS/Web).

## Abrir e jogar

1. Godot 4.7 → **Importar** → escolha `project.godot`.
2. **F5** roda no PC. O bot começa no **Fácil** (botão no canto superior direito troca).

| Ação | Celular | PC |
|---|---|---|
| Andar | polegar esquerdo (o joystick nasce onde você encosta) | WASD / setas |
| Tocar na bola | segure na metade direita → arraste para mirar → **solte** | segure **Espaço** (mira padrão) ou clique-segure-arraste na direita |
| Reiniciar / nível do bot | botões do topo | mouse |

## O loop

| Na tela | Significa |
|---|---|
| Anel colorido no chão | onde ficar para o próximo toque (cor = ação) |
| Anel branco fechando | solte quando encostar no colorido = **PERFEITO** (fica verde) |
| Ponto branco | onde a bola cai se ninguém tocar (dá para deixar cair bola fora) |
| Sombra preta | posição da bola no chão (noção de altura) |
| Texto do botão | SACAR · RECEBER (1º) · LEVANTAR (2º) · ATACAR (3º, pulo automático) |
| Levantamento | a mira gruda em **ALTA** (padrão), **PONTA**, **RÁPIDA**, **PIPE** |

Timing ruim = bola menos precisa (e cortada mais fraca). Longe do anel = "LONGE", não toca.

**Meta da Fase 0:** rally de **5+ toques** e vontade de jogar mais uma. O HUD mostra Rally e Recorde.

## Ajustar o feel → `scripts/core/tuning.gd`

| Se… | Mexa em |
|---|---|
| difícil acertar o tempo | `WINDOW_EARLY`, `WINDOW_LATE`, `PERFECT` |
| não chega na bola | `REACH`, `MOVE_SPEED` |
| cortada impossível de defender | `ATTACK_SPEED_MAX`, `SPIKE_GRAVITY` |
| mira sensível demais | `AIM_SENS` |
| jogo lento/rápido | `GRAVITY`, `T_RECEIVE`, `T_SET_HIGH` |
| bot forte/fraco | `BOT_SPEED`, `BOT_REACTION`, `BOT_POWER` |

Equilíbrio dos valores atuais (simulação de 20 min por linha, "humano" com reação e erro de timing):

| Você | Fácil | Médio | Difícil |
|---|---|---|---|
| bom (reação 0,25 s, erro 50 ms) | 77% dos pontos | 52% | 20% |
| casual (reação 0,4 s, erro 90 ms) | 54% | 33% | 13% |

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
godot --headless --script res://tests/run_tests.gd     # física, câmera, bot x bot, humano roteirizado
godot -- --autoplay                                    # demo bot x bot
```

Teste no navegador emulando celular (toque no analógico e no botão, com prints):

```bash
mkdir -p export && touch export/.gdignore             # Godot ignora builds/prints
godot --headless --export-release "Web" export/web/index.html
npm i --prefix /tmp/pw playwright && /tmp/pw/node_modules/.bin/playwright install chromium
NODE_PATH=/tmp/pw/node_modules node tests/e2e/mobile_smoke.js export/web export/e2e  # prints em export/e2e
```

No CI os prints ficam em Actions → execução → Artifacts → `e2e-screenshots`.

## Estrutura

```
project.godot          config do Godot (cena principal: scenes/main.tscn)
scenes/main.tscn       cena raiz
scripts/
  main.gd              monta a cena e liga tudo
  core/                regras e física (sem nós visuais)
  ai/                  bot
  entities/            objetos 3D do jogo
  ui/                  HUD, controles e marcadores
tests/run_tests.gd     testes headless
```

| Arquivo | Faz |
|---|---|
| `scripts/core/ball_sim.gd` | física exata da bola (parábola, rede, chão) + preditor |
| `scripts/core/game.gd` | regras, plano de contato (quem/onde/quando), toque, pontos |
| `scripts/core/tuning.gd` | todos os números |
| `scripts/ai/bot_brain.gd` | IA (usa o mesmo preditor) |
| `scripts/entities/ball.gd` | visual da bola |
| `scripts/entities/player.gd` | movimento, pulo automático, animação |
| `scripts/entities/court.gd` | quadra, rede, antenas |
| `scripts/ui/markers.gd` | sombra, ponto de queda, anel, mira |
| `scripts/ui/touch_controls.gd` | joystick flutuante + botão de ação |
| `scripts/ui/hud.gd` | placar, rally, feedback |

## Fora da Fase 0 (de propósito)

Bloqueio, peixinho, stamina e tipos de saque → Fase 2 · regra de dois toques e 2v2 → Fases 1 e 3 · arte e som → Fase 4.
