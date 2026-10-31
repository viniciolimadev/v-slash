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

## Ajustar o feel → `scripts/tuning.gd`

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

## Arquivos

| Arquivo | Faz |
|---|---|
| `scripts/ball_sim.gd` | física exata da bola (parábola, rede, chão) + preditor |
| `scripts/game.gd` | regras, plano de contato (quem/onde/quando), toque, pontos |
| `scripts/bot_brain.gd` | IA (usa o mesmo preditor) |
| `scripts/player.gd` | movimento, pulo automático, animação |
| `scripts/markers.gd` | sombra, ponto de queda, anel, mira |
| `scripts/touch_controls.gd` | joystick flutuante + botão de ação |
| `scripts/hud.gd` | placar, rally, feedback |
| `scripts/court.gd` | quadra, rede, antenas |
| `scripts/tuning.gd` | todos os números |

## Fora da Fase 0 (de propósito)

Bloqueio, peixinho, stamina e tipos de saque → Fase 2 · regra de dois toques e 2v2 → Fases 1 e 3 · arte e som → Fase 4.
