# Arte e som — pipeline

Como os assets do jogo são feitos, onde ficam e quanto podem pesar. Vale a partir da Fase 4 (ADR-09).

## 1. Regra principal

A lógica (`Player`, `Ball`, `Game`, `BallSim`) **não carrega nenhum arquivo**. Todo o visual e o som ficam em
"views" que só observam a lógica (`scripts/view/`) e podem ser desligados (`-- --no-views`).

## 2. De onde vem cada coisa

| O quê | Como é feito | Onde |
|---|---|---|
| Personagens | malhas low-poly montadas por código + "rig" de juntas (`Node3D`) e clipes de pose em tabela | `scripts/view/player_view_model.gd`, `scripts/view/anim_table.gd` |
| Quadra e praia | malhas por código, cor "assada" nos vértices (sem luz dinâmica extra) | `scripts/view/court_view.gd` |
| Torcida | silhuetas desenhadas numa `Image` em tempo de carga, em billboards | `scripts/view/court_view.gd` |
| Efeitos | `CPUParticles3D`, fita do rastro (`ImmediateMesh`), tremor de câmera | `scripts/view/fx.gd`, `scripts/view/camera_fx.gd` |
| Sons e músicas | sintetizados por `tools/gen_audio.py` (Python puro) → `.wav` → `ffmpeg` → `.ogg` | `assets/audio/sfx/`, `assets/audio/music/` |
| Fonte | Fredoka (OFL) | `assets/fonts/` |
| Ícones | desenhados com `draw_*` (vetor) | `scripts/ui/icons.gd` |

Não há Blender nem Git LFS no fluxo atual: nada binário grande entra no repositório. Se um dia houver modelo
glTF, ele entra como mais uma `PlayerView` (mesmo contrato: `bind(player, game)`, sinais `swung`/`ring_changed`,
tabela de `contact_time` por clipe) e o `.blend` fonte fica em `art/` com `.gdignore` e LFS.

## 3. Regenerar o áudio

```bash
python3 tools/gen_audio.py          # escreve assets/audio/**/*.ogg (precisa de ffmpeg com libvorbis)
godot --headless --import
```

O gerador é determinístico (sementes fixas): rodar de novo produz os mesmos sons.
SFX: mono, 44,1 kHz, Vorbis q4. Música: estéreo, 44,1 kHz, Vorbis q3, em loop.

## 4. Orçamento (RNF-4.02 / 4.03)

| Item | Limite |
|---|---|
| Draw calls | ≤ 80 |
| Triângulos visíveis | ≤ 60 k (≤ 5 k por personagem) |
| Texturas | ≤ 1024², ETC2/ASTC |
| APK release | ≤ 60 MB |
| Web (pck + wasm) | ≤ 40 MB |

O teste headless `_test_render_budget` soma triângulos e malhas da cena da partida; o CI mede o tamanho do APK e da Web.

## 5. Checklist ao trocar um asset

1. A lógica continua sem `load()` de asset (grep em `scripts/core`, `scripts/entities`).
2. Testes headless passam com e sem views.
3. Orçamento acima respeitado (teste + CI).
4. Licença própria, CC0 ou CC-BY, com linha no `CREDITS.md`.
