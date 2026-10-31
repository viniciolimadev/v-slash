# Roadmap — Fases 1 a 5

Ponto de partida: **Fase 0 pronta** — rally 1v1 contra bot, anel de timing, gesto segura → mira → solta,
assistência de mira, 3 níveis de bot, CI com testes headless, Web (Pages) e APK.

Regras para todas as fases:

- Cada fatia vira um PR pequeno, com teste headless em `tests/run_tests.gd` (e e2e quando mexer em toque/HUD).
- Números novos vão para `scripts/core/tuning.gd`.
- Mecânica nova também é usada pelo bot — senão o equilíbrio mente.
- Fim de fase = rodar de novo a simulação de equilíbrio (tabela do README) e testar no celular.

---

## Fase 1 — Partida de verdade (1v1)

**Meta:** sair do "rally infinito" e virar uma partida com começo, meio e fim, que dá vontade de pedir revanche.
Design detalhado: [SDD-fase-1.md](SDD-fase-1.md).

| # | Fatia | Detalhe |
|---|---|---|
| 1.1 | Limite de toques explícito | 1v1 mantém **3 toques do mesmo jogador** (receber → levantar → atacar). O "3" hoje fixo em `_make_plan` vira `Tuning.MAX_TOUCHES`, para o 2v2 reutilizar. |
| 1.2 | Placar de partida | Sets até 15, vantagem de 2, melhor de 3 (`SET_POINTS`, `SETS_TO_WIN`). Set point / match point no HUD. |
| 1.3 | Fluxo de telas | Título → escolher bot → partida → pausa → resultado (vitória/derrota, rally máximo, % perfeitos) → revanche / menu. |
| 1.4 | Progressão e save | `user://save.cfg`: recordes, níveis vencidos; Médio libera após vencer o Fácil, Difícil após o Médio. |
| 1.5 | Tutorial | 3 passos jogáveis na 1ª vez: andar até o anel → soltar no tempo → arrastar a mira. Pulável. |
| 1.6 | Opções | Sensibilidade da mira, modo canhoto (inverte metades da tela), vibração liga/desliga. |

**Pronto quando:** partida bot × bot termina sozinha no teste headless; uma partida humana contra o Fácil dura 4–7 min; e2e passa pelo fluxo título → resultado.

---

## Fase 2 — Profundidade (1v1)

**Meta:** dar escolhas ao jogador além de "acertar o tempo": arriscar ou jogar seguro, atacar ou defender na rede.
Design detalhado: [SDD-fase-2.md](SDD-fase-2.md).

| # | Fatia | Detalhe |
|---|---|---|
| 2.1 | Tipos de saque | **Por baixo** (seguro, lento) · **Viagem** (pulo, forte, janela de timing menor) · **Flutuante** (trajetória oscila: ponto de queda só fica certo perto do fim). Escolha antes de sacar. O preditor de `ball_sim.gd` precisa suportar o flutuante. |
| 2.2 | Bloqueio | Quando o adversário vai atacar e você está perto da rede, o botão vira BLOQUEAR. Resultado pelo timing: ponto · amortece (bola fica do seu lado, conta como toque) · toca e sai. Bot aprende a bloquear e a atacar desviando do bloqueio. |
| 2.3 | Ataque variado | **Largada** (bola curta por cima do bloqueio) além da cortada: mirar numa zona curta = largada (o botão mostra LARGAR). |
| 2.4 | Peixinho | Bola um pouco fora do `REACH`: o toque vira peixinho sozinho (o botão mostra PEIXINHO), alcança mais, mas você fica no chão um tempo. Qualidade sempre baixa. |
| 2.5 | Stamina (experimental) | Viagem, cortada forte e peixinho gastam; recupera entre pontos. Atrás de uma flag — entra só se o teste no celular mostrar que melhora a decisão sem frustrar. |

**Pronto quando:** cada mecânica tem teste headless e é usada pelo bot; simulação mostra que o Difícil usa bloqueio/flutuante e o equilíbrio fica perto da tabela atual.

---

## Fase 3 — 2v2

**Meta:** o jogo de dupla, com parceiro IA e a regra real (ninguém toca duas vezes seguidas).
Design detalhado: [SDD-fase-3.md](SDD-fase-3.md).

| # | Fatia | Detalhe |
|---|---|---|
| 3.1 | Dois jogadores por time | `game.gd` já escolhe o jogador mais perto (`_closest_player`); passa a respeitar "não toca duas vezes seguidas" e 3 toques por lado. Quadra maior (`COURT_HALF_W`/`COURT_DEPTH` por modo). |
| 3.2 | Troca de controle | Você controla quem o plano de contato escolheu do seu time; o outro vira IA. Indicador claro de "você agora". |
| 3.3 | IA de parceiro | Posição base, cobertura de defesa, quem levanta. Reaproveita `bot_brain.gd`. |
| 3.4 | Levantamentos | ALTA / PONTA / RÁPIDA / PIPE voltam a fazer sentido: o parceiro ataca onde você levantou (e vice-versa). |
| 3.5 | Câmera | Enquadra os 4 jogadores sem perder leitura da bola na tela vertical/horizontal. |

**Pronto quando:** partida 2v2 bot × bot completa no headless sem 2 toques seguidos do mesmo jogador; rally médio humano ≥ 1v1.

---

## Fase 4 — Arte e som

**Meta:** trocar as formas simples por algo bonito sem perder 60 fps em Android médio (renderer Compatibility).
Design detalhado: [SDD-fase-4.md](SDD-fase-4.md).

| # | Fatia | Detalhe |
|---|---|---|
| 4.1 | Personagens | Low-poly com rig simples; animações de manchete, toque, cortada, bloqueio, peixinho, saque, comemoração. |
| 4.2 | Quadra e cenário | Praia/ginásio, iluminação baked, torcida simples (billboards). |
| 4.3 | Efeitos | Rastro da bola na cortada, poeira/areia, "PERFEITO" com impacto, câmera treme leve no ataque. |
| 4.4 | Som | Toques (variam por qualidade), apito, torcida reagindo ao rally, música de menu. Haptics afinados. |
| 4.5 | UI final | Fonte, ícones, telas da Fase 1 com arte. |
| 4.6 | Performance | Orçamento por frame, teste num Android de entrada; medir no e2e (fps no log). |

**Pronto quando:** 60 fps estável no aparelho de teste e o APK release < 60 MB.

---

## Fase 5 — Lançamento

Design detalhado: [SDD-fase-5.md](SDD-fase-5.md).

Export release assinado, ícone e splash, Play Store (teste interno → aberto), página/itch.io da versão Web, telemetria opcional e anônima (duração de partida, rally médio, onde o jogador perde pontos) para afinar o equilíbrio.

---

## Decisões (2026-10-31)

1. **Toques no 1v1:** 3 toques do mesmo jogador (como na Fase 0).
2. **Partida:** melhor de 3 sets de 15, vantagem de 2.
3. **Stamina:** experimento atrás de flag na Fase 2; fica só se o teste no celular aprovar.
4. **Multiplayer** (local ou online): fora do plano; reavaliar depois da Fase 5.
