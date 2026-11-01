# SDD detalhado — Fase 4: Arte e som

Complementa o [SDD geral](SDD.md) (seção 9.4) e o [ROADMAP](ROADMAP.md).

| | |
|---|---|
| Versão | 1.1 — 2026-11-01 (implementada; ver seções 9 e 10) |
| Base | Fase 3 concluída (versão 0.4.0) |
| Versão ao fim da fase | 0.5.0 |
| Muda invariante | ADR-03 ("tudo por código") é substituída pela ADR-09 abaixo |

---

## 1. Objetivo e escopo

**Meta:** trocar as formas simples por algo bonito e com som, **sem mudar a lógica** e sem perder 60 fps num Android de entrada.

**Dentro:**
1. Separação lógica × visual (`PlayerView`, `BallView`, `CourtView`).
2. Pipeline de assets (Blender → glTF → Godot), pastas, licenças.
3. Personagens low-poly com animações sincronizadas com o contato.
4. Cenário (praia) e iluminação.
5. Efeitos (rastro, partículas, impacto, câmera).
6. Som e música, volumes, vibração afinada.
7. UI final (tema, fonte, ícones) para telas e HUD.
8. Orçamento de desempenho medido no CI e no aparelho.

**Fora:** personalização de personagem, cenários extras (ginásio), dublagem/narração.

### ADR-09 — Assets e cenas a partir da Fase 4

- Lógica continua 100% em código e **não depende** de nenhum asset: `Player`, `Ball`, `Game`, `BallSim` não carregam arquivos.
- O visual vira cenas `.tscn` com assets em `assets/`, carregadas por nós "view" que só **observam** a lógica.
- Testes headless rodam com as views carregadas (garantem que nada quebra) e há um modo `--no-views` para simulações rápidas.

---

## 2. Requisitos

### 2.1 Funcionais

| ID | Requisito | Fatia |
|---|---|---|
| RF-4.01 | Personagens com animações: parado, corrida, deslocamento lateral, manchete, toque, cortada (com corrida e pulo), bloqueio, peixinho (deitar/levantar), saque por baixo / flutuante / viagem, comemoração, lamento. | 4.3 |
| RF-4.02 | O instante de contato da animação coincide com o contato da bola (erro ≤ 1 quadro a 60 fps). | 4.3 |
| RF-4.03 | Dois uniformes por time, cor do time preservada (leitura do jogo). Parceiro e controlado distinguíveis. | 4.3 |
| RF-4.04 | Cenário de praia: areia, rede com postes e antenas, linhas, mar/céu ao fundo, torcida simples. | 4.4 |
| RF-4.05 | Marcadores de jogo (anel, aproximação, ponto de queda, mira, sombra) continuam com o mesmo significado e legíveis sobre a areia. | 4.4 |
| RF-4.06 | Efeitos: rastro da cortada/viagem, areia no peixinho e na bola no chão, "PERFEITO" com impacto, leve tremor de câmera no ataque forte. | 4.5 |
| RF-4.07 | Som: toque (varia por ação e grau), rede, antena, apito, torcida reagindo ao tamanho do rally, música de menu e de partida. | 4.6 |
| RF-4.08 | Opções: volume de música e de efeitos (save v4). | 4.6 |
| RF-4.09 | Telas e HUD com tema próprio (fonte, cores, botões, ícones), mantendo os tamanhos de toque. | 4.7 |

### 2.2 Não funcionais

| ID | Requisito | Meta |
|---|---|---|
| RNF-4.01 | Quadros | 60 fps estáveis (p1 ≥ 50) no Android de teste de entrada e no Galaxy do dono |
| RNF-4.02 | Orçamento | ≤ 80 draw calls · ≤ 60 k triângulos visíveis · ≤ 5 k tris por personagem · texturas ≤ 1024² ETC2 |
| RNF-4.03 | Tamanho | APK release ≤ 60 MB; Web ≤ 40 MB (pck + wasm) |
| RNF-4.04 | Carregamento | título em ≤ 3 s no Android de teste; partida em ≤ 1,5 s |
| RNF-4.05 | Lógica intacta | simulações com e sem views dão os mesmos números (sementes fixas) |
| RNF-4.06 | Licenças | todo asset próprio ou CC0/CC-BY com crédito em `CREDITS.md` |

---

## 3. Arquitetura

### 3.1 Lógica × visual

```
Player (lógica, Node3D)              Ball (lógica)            Court (lógica: só CourtSpec)
 └── PlayerView (cena)                └── BallView (cena)      CourtView (cena: praia)
      ├── modelo glTF + Skeleton3D         ├── malha + rastro
      ├── AnimationTree                    └── partículas de impacto
      └── marcadores do jogador (anéis)
```

- A lógica emite sinais/estados; a view lê. Contrato do `Player` para a view:

```gdscript
signal swung(kind: int, contact_t: float)   # NOVO: substitui o tween de braços; contact_t no relógio do Game
var vel: Vector3                            # corrida/lateral
func is_grounded() -> bool                  # pulo
var diving_t: float                         # peixinho (Fase 2)
var team: int
```

- `Player.swing()` deixa de animar braços diretamente; emite `swung`. Os tweens atuais viram a `PlayerView` "simples" (fallback e modo `--no-views`).
- `main.gd` escolhe a view: `PlayerViewSimple` (código, atual) ou `PlayerViewModel` (glTF). Uma constante `Tuning.USE_MODEL_VIEWS`.

### 3.2 Sincronizar animação com o contato (RF-4.02)

Cada animação de toque tem um marcador de **quadro de contato** (`contact_time` em segundos dentro do clipe, lido de um metadado do clipe ou de uma tabela em `scripts/view/anim_table.gd`).

Quando o plano do jogador é criado (e quando muda), a view agenda: `começo = plan.t − contact_time / speed_scale`. Se já passou, entra no meio do clipe (`seek`). Para a cortada, o pulo da lógica (`start_jump` em `t − JUMP_TIME_UP`) dita o "subir"; o clipe é escolhido para que o pico do salto coincida.

O `swung(kind, contact_t)` confirma/corrige no momento do toque (se o toque foi cedo/tarde, a view faz um blend curto para não "teleportar").

### 3.3 Pastas e pipeline

```
assets/
  models/players/   player_base.glb (malha + esqueleto), uniformes como materiais
  models/court/     beach_court.glb, net.glb, props.glb
  anims/            player_anims.glb (biblioteca de animações, mesmo esqueleto)
  textures/         *.png (fonte), importadas como ETC2/ASTC
  audio/sfx/        *.ogg (mono, 44,1 kHz)
  audio/music/      *.ogg (estéreo, streaming)
  fonts/            fonte OFL
  ui/               ícones (SVG → textura), tema
scenes/views/       player_view.tscn, ball_view.tscn, court_view.tscn
scripts/view/       código das views, anim_table.gd, sfx.gd, camera_fx.gd
CREDITS.md
```

- **Blender** (fonte em `art/*.blend`, fora do pck via `.gdignore`; versionado com Git LFS) → exporta glTF com `+Y up`, escala 1 = 1 m, esqueleto único para todos os clipes.
- Import do Godot: `.import` com compressão ETC2/ASTC (já ligada no projeto), LOD automático desligado para personagens (low-poly já).
- Checklist de export no `docs/ARTE.md` (criado nesta fase).

### 3.4 Som

- `scripts/view/sfx.gd` (`Sfx`, nó filho de `MatchScene`, não autoload) assina os sinais de `Game`: `touch_made` (som por ação × grau), `whiffed`, eventos da bola (rede/antena/chão via novo sinal `Game.ball_event(kind, pos)`), `point_scored` (apito + torcida), `set_over`, `match_over`.
- Torcida: camada contínua com volume que sobe com `rally_touches`; "ohh" em bola salva por peixinho; aplauso no ponto.
- Música: `MusicPlayer` no `App` (menu) e na partida (faixa mais calma, abaixa no ponto).
- Barramentos: `Master`, `Music`, `SFX` (`default_bus_layout.tres`). Volumes no save v4 (`[options] music_vol`, `sfx_vol`, 0–1).
- Posição 3D leve: `AudioStreamPlayer3D` só para o toque (dá noção de lado); o resto 2D.
- Vibração: tabela por evento (perfeito 45 ms, bom 20 ms, bloqueio 60 ms, ponto seu 2×30 ms), respeitando a opção.

### 3.5 UI

- Um `Theme` (`assets/ui/theme.tres`) aplicado na raiz do `App` e da partida: fonte, tamanhos, `StyleBoxFlat` para botões (normal/pressionado/desativado), cores dos times.
- `Screen` (base) ganha fundo ilustrado e animação de entrada (0,2 s).
- HUD: placar em "plaquinha", selos com ícone, botão de ação com ícone por ação (manchete, toque, cortada, bloqueio...) **mantendo o texto** (aprendizado).
- Todos os alvos de toque continuam ≥ 64 px em 720p; e2e continua achando os botões pelo `E2eHooks`.

---

## 4. Design por fatia

| Fatia | Entregas | Pronto quando |
|---|---|---|
| 4.1 Views | `Player.swung`, `PlayerViewSimple` (atual movido), `BallView`, `CourtView` (atual), `--no-views`; `Game.ball_event` | simulações idênticas com e sem views |
| 4.2 Pipeline | `assets/`, `art/` com LFS, `.gdignore`, `docs/ARTE.md`, `CREDITS.md`, personagem placeholder com esqueleto e 1 clipe | glb importa no CI; APK continua < 60 MB |
| 4.3 Personagens | modelo final, 2 uniformes, 14 clipes (RF-4.01), `AnimationTree` (locomoção em BlendSpace2D + one-shots de toque), `anim_table.gd` | teste de sincronia ≤ 1 quadro; revisão no celular |
| 4.4 Cenário | areia, rede/postes/antenas, mar e céu (fundo pintado), torcida em billboards, luz direcional sem sombras dinâmicas + luz assada nas texturas; marcadores revisados para contraste | prints de e2e legíveis; orçamento ok |
| 4.5 Efeitos | `CPUParticles3D` (areia), rastro (`MeshInstance3D` de fita atualizada por código), `camera_fx.gd` (tremor 0,12 s, amplitude por força), impacto do PERFEITO (escala + brilho no anel) | sem queda de fps |
| 4.6 Som | ~25 SFX, 2 músicas, `Sfx`, barramentos, volumes no save v4, vibração por tabela | teste de "todo evento toca um som" |
| 4.7 UI | tema, fonte, ícones, HUD e telas restilizados | e2e e prints ok, alvos ≥ 64 px |
| 4.8 Desempenho | `--fps` (overlay), e2e registra fps médio/p1 na Web, checagem de tamanho do APK no CI, teste no Android de entrada | RNF-4.01–4.04 medidos e registrados |

---

## 5. Ordem dos PRs

1. 4.1 Views (refatoração) · 2. 4.2 Pipeline + placeholder · 3. 4.3 Personagens (pode ir em 2–3 PRs: modelo, locomoção, toques) · 4. 4.4 Cenário · 5. 4.5 Efeitos · 6. 4.6 Som · 7. 4.7 UI · 8. 4.8 Desempenho + README + 0.5.0.

---

## 6. Testes

| Grupo | Casos |
|---|---|
| `_test_views_do_not_change_logic` | bot × bot e humano roteirizado com sementes fixas: números iguais com `PlayerViewModel` e com `--no-views` |
| `_test_anim_sync` | para cada ação, o começo agendado + `contact_time` = `plan.t` (± 1/60 s); toque cedo/tarde gera blend, não salto |
| `_test_sfx_events` | cada sinal de `Game` produz um pedido de som (Sfx com saída falsa contando chamadas) |
| `_test_save` | v3 → v4 mantém tudo e cria volumes padrão |
| `_test_theme_targets` | todos os `Button` das telas têm altura ≥ 64 px em 720p |
| CI | tamanho do APK ≤ 60 MB e da Web ≤ 40 MB; falha se passar |
| e2e | fps médio e p1 impressos; prints de todas as telas para revisão visual |

---

## 7. Critérios de aceite

1. RNF-4.01 a 4.04 medidos no Android de entrada e no Galaxy, registrados no README.
2. Lógica intacta (RNF-4.05).
3. Pessoas que não conhecem o jogo reconhecem as ações pela animação + texto do botão.
4. `CREDITS.md` completo (RNF-4.06).

---

## 8. Riscos

| Risco | Mitigação |
|---|---|
| Animação "atrasada" em relação à bola | agendamento pelo `plan.t` (3.2) e teste de sincronia |
| Fps cair no Android de entrada | orçamento fixo, sem sombras dinâmicas, CPUParticles, medição no CI desde a 4.1 |
| Repositório pesado com `.blend` | Git LFS para `art/`; só `.glb`/texturas finais no pck |
| Marcadores perderem contraste na areia | revisão de cores (anel com contorno escuro), prints do e2e |
| Produção de arte demorar | placeholder com esqueleto na 4.2 permite integrar tudo antes da arte final |

---

## 9. Decisões assumidas (mude se discordar)

| # | Assumido | Alternativa |
|---|---|---|
| B4-1 | Cenário único de **praia** (combina com o 2v2) | ginásio, ou os dois |
| B4-2 | Arte própria low-poly feita no Blender + CC0 para complementos | comprar pacote de assets |
| B4-3 | Luz "assada" nas texturas + 1 direcional sem sombra dinâmica (Compatibility) | LightmapGI |
| B4-4 | Som e música CC0/CC-BY ou próprios | compor trilha |
| B4-5 | Ícones no botão de ação **além** do texto (não no lugar) | só ícone |
| B4-6 | **Arte gerada por código** e **áudio sintetizado** (`tools/gen_audio.py`): o ambiente não tem Blender nem Git LFS, e assim nada binário grande entra no repositório. Personagem = malhas low-poly presas a um `Skeleton3D` de 11 ossos (uma malha só, 1 chamada de desenho); quadra/props agrupados por `MeshKit` | Blender → glTF como no esboço (uma `PlayerView` nova com o mesmo contrato encaixa sem mexer na lógica) |
| B4-7 | Clipes como **tabelas de pose** (`AnimTable`, 14 clipes, `contact` por clipe) e locomoção misturada na própria view (parado/corrida/lateral pela velocidade), sem `AnimationTree` | `AnimationTree` com BlendSpace2D |
| B4-8 | Views são **classes** em `scripts/view/` (sem `scenes/views/*.tscn`); `main.gd` escolhe pela constante `Tuning.USE_MODEL_VIEWS` | cenas `.tscn` por view |
| B4-9 | Tema montado em código (`UiTheme`) e **mesclado no tema padrão** do Godot: `CanvasLayer` não herda o tema do pai, então não há `theme.tres` | `assets/ui/theme.tres` em `gui/theme/custom` |
| B4-10 | Limite da Web medido **em gzip** (o que o navegador baixa; o Pages serve comprimido). O `index.wasm` do Godot 4.7 sozinho tem 39,5 MB sem compressão | sem compressão (exigiria compilar o motor sem módulos) |
| B4-11 | Tremor de câmera por `h_offset`/`v_offset`: o enquadramento testado (`_test_camera`) não muda | mexer no transform |
| B4-12 | Opções em duas colunas (volumes à esquerda, chaves à direita) para caber em 720p | uma coluna com rolagem |
| B4-13 | Torcida: quads virados para a câmera fixa (`MultiMesh` por cor de camisa, 6 chamadas), pula no ponto e se agita com rally ≥ 5 | billboards por pessoa |
| B4-14 | Mar e camisas da torcida **fora do azul do seu time**: o e2e acha o jogador pela cor da camisa | trocar a detecção do e2e |

---

## 10. Resultado (fim da fase)

Implementada em 2026-11-01 (versão 0.5.0).

| Medida | Meta | Resultado |
|---|---|---|
| Lógica intacta (RNF-4.05) | mesmos números com e sem views | `_test_views_do_not_change_logic`: 5 min bot × bot 1v1 e 2v2 idênticos; simulações com semente (duração casual × Fácil, 1v1 e 2v2) iguais às da Fase 3 |
| Sincronia (RF-4.02) | contato ± 1 quadro | erro 0 s em manchete, toque, cortada, flutuante e viagem; toque cedo corrige com mistura (8° no quadro contra 45° sem mistura) |
| Orçamento (RNF-4.02) | ≤ 80 chamadas, ≤ 60 k tris, ≤ 5 k por personagem | 2v2: 24 chamadas, 9,5 k tris, 660 tris por personagem, 92 pessoas na torcida |
| Eventos com som (RF-4.07) | todos | 13 sinais do `Game` pedem um som existente; 28 SFX + 2 músicas = 1,2 MB |
| Alvos de toque (RF-4.09) | ≥ 64 px em 720p | 26 botões/controles nas telas, pausa e HUD |
| Tamanho (RNF-4.03) | APK ≤ 60 MB, Web ≤ 40 MB | medido e conferido no CI a cada execução (passo "Web size budget" e export do APK) |

**Em aberto (precisa do aparelho):** RNF-4.01 (60 fps / p1 ≥ 50 no Android de entrada e no Galaxy — o contador `-- --fps` e o e2e já medem), RNF-4.04 (tempo de carregamento) e os critérios 3 (ações reconhecíveis por quem não conhece o jogo) e 1 (registro no README).
