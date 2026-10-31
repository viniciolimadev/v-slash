# SDD detalhado — Fase 5: Lançamento

Complementa o [SDD geral](SDD.md) (seção 9.5) e o [ROADMAP](ROADMAP.md).

| | |
|---|---|
| Versão | 1.0 — 2026-10-31 |
| Base | Fase 4 concluída (versão 0.5.0) |
| Versão ao fim da fase | **1.0.0** |
| Decisões que valem aqui | DP-04 (sem multiplayer) |

---

## 1. Objetivo e escopo

**Meta:** o jogo publicado na Play Store (e na Web), com builds assinadas e reproduzíveis, privacidade em ordem e dados suficientes para afinar o equilíbrio depois do lançamento.

**Dentro:**
1. Build release assinada (AAB) e versionamento automático no CI.
2. Trilhas da Play: teste interno → fechado → aberto → produção.
3. Página da loja (textos, ícone, capturas, vídeo curto) e versão Web pública (GitHub Pages + itch.io).
4. Telemetria **opcional e anônima** com consentimento, e backend mínimo.
5. Privacidade (LGPD/Play Data Safety), política publicada.
6. Robustez: relatório de erros, tela de "algo deu errado", teste em vários aparelhos.
7. Idiomas: português + inglês.
8. Acessibilidade e ajustes finais (tamanhos de texto, modo daltônico para os anéis).

**Fora:** monetização (anúncios/compras), contas de usuário, multiplayer (DP-04), iOS (avaliar depois).

---

## 2. Requisitos

### 2.1 Funcionais

| ID | Requisito | Fatia |
|---|---|---|
| RF-5.01 | CI gera **AAB release assinado** em tags `v*`, com `version/code` = número da execução e `version/name` = tag. | 5.1 |
| RF-5.02 | Publicação automática da tag na trilha **interna** da Play; promoção entre trilhas manual pelo dono. | 5.2 |
| RF-5.03 | Na primeira abertura: pergunta de consentimento para estatísticas anônimas (padrão **não**), alterável em Opções. | 5.4 |
| RF-5.04 | Com consentimento: ao fim de cada partida envia um evento anônimo (seção 4.4); sem rede, guarda até 50 eventos e envia depois. | 5.4 |
| RF-5.05 | Opções → "Privacidade": ver o que é enviado, desligar e pedir para apagar (apaga o ID local e envia pedido de exclusão). | 5.5 |
| RF-5.06 | Erros de script em produção geram um relatório anônimo (com consentimento) e o jogo volta ao título com uma mensagem, sem travar. | 5.6 |
| RF-5.07 | Jogo inteiro em **português e inglês**, seguindo o idioma do aparelho, com troca em Opções. | 5.7 |
| RF-5.08 | Modo daltônico (cores dos anéis e times com formas/contornos extras) e texto maior (110%/125%) em Opções. | 5.8 |
| RF-5.09 | Tela "Sobre": versão, créditos (`CREDITS.md`), link da política de privacidade. | 5.5 |

### 2.2 Não funcionais

| ID | Requisito | Meta |
|---|---|---|
| RNF-5.01 | Estabilidade | ≥ 99,5% sessões sem crash no teste fechado (Android vitals) |
| RNF-5.02 | Compatibilidade | Android 8+ (API 26), arm64; relatório de pré-lançamento da Play sem falhas |
| RNF-5.03 | Privacidade | nenhum dado pessoal; nenhum identificador do aparelho; ID aleatório local reiniciável |
| RNF-5.04 | Reprodutibilidade | qualquer versão publicada pode ser reconstruída a partir da tag |
| RNF-5.05 | Custo | backend de telemetria dentro do plano gratuito do provedor no volume esperado |

---

## 3. Arquitetura

### 3.1 Build e publicação

```
tag v1.0.0 ─▶ CI (build.yml, job release)
              ├─ testes + e2e (como hoje)
              ├─ export Android release (AAB) com keystore dos segredos
              ├─ export Web → Pages + upload itch.io (butler)
              ├─ anexa AAB/APK ao GitHub Release
              └─ envia AAB para a trilha interna da Play (API de publicação)
```

| Segredo do GitHub | Uso |
|---|---|
| `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASS`, `ANDROID_KEY_ALIAS` | assinatura (upload key; Play App Signing ativado) |
| `PLAY_SERVICE_ACCOUNT_JSON` | publicação na trilha interna |
| `BUTLER_API_KEY` | itch.io |
| `TELEMETRY_URL` | injetado no build (não é segredo, mas fica fora do código) |

`export_presets.cfg` ganha o preset **Android Release** (`gradle_build/use_gradle_build=true` para gerar AAB, `target_sdk` atual exigido pela Play, `min_sdk=26`).

### 3.2 Telemetria

```
Jogo ──HTTPS POST /v1/events (JSON, lote)──▶ Worker (Cloudflare) ──▶ D1 (SQLite)
                                                │
                                                └─ /v1/delete {install_id}
```

- **Cliente:** `scripts/core/telemetry.gd` (`Telemetry`, RefCounted, dono: `App`), usa `HTTPRequest` num nó do App. Fila em `user://telemetry_queue.json` (máx. 50). Envia ao abrir o título e ao fim de cada partida; ignora erros de rede (tenta depois).
- **Backend:** um Worker com duas rotas e uma tabela D1. Sem IP gravado (o Worker não salva cabeçalhos). Código em `server/telemetry/` (fora do pck via `.gdignore`), com seu próprio teste.
- Alternativa equivalente se o dono preferir outro provedor: qualquer endpoint HTTPS que aceite o mesmo JSON.

### 3.3 Idiomas

- Textos de UI e de jogo em `assets/i18n/strings.csv` (`keys,pt_BR,en`) importado como `Translation`.
- Código usa `tr("KEY")`; labels de ação (`ACT_LABELS`) e motivos de ponto viram chaves (`ACT_SERVE`, `REASON_OUT`...). Os **motivos** continuam em português nos sinais/testes como chave estável e são traduzidos só na tela.
- Teste: nenhuma chave sem tradução; nenhum texto literal em `ui/` fora de `tr()` (lint simples por grep no CI).

### 3.4 Erros em produção

- `App` conecta um tratador: em build release, o log do Godot é lido no próximo início (`user://logs/godot.log`); se houver `SCRIPT ERROR`, gera um evento `error` (mensagem + arquivo:linha, sem dados do jogador) — com consentimento.
- Falha durante a partida (`push_error` detectado pelo `MatchScene` via verificação de estado inválido) → volta ao título com "Algo deu errado, sua partida não foi salva".

---

## 4. Design por fatia

### 4.1 Fatia 5.1 — Release assinado e versões
- Preset Android Release; job `release` no `build.yml` disparado por `push: tags: ['v*']`.
- `version/code` = `github.run_number + 100`; `version/name` = tag sem `v`. Script `tools/set_version.sh` edita o preset no CI (não versionado alterado).
- Keystore só nos segredos; `debug.keystore` continua gerada no job de debug.

### 4.2 Fatia 5.2 — Play Console
- Criação do app (pelo dono), Play App Signing, ficha de conteúdo (classificação etária: livre), público-alvo 13+ (evita regras de público infantil; decisão B5-2), Data Safety preenchido conforme 4.4.
- Ação de upload (`r0adkll/upload-google-play` ou API direta) para a trilha interna.
- Teste fechado com 12+ testadores por 14 dias (exigência atual da Play para contas novas) antes de produção.

### 4.3 Fatia 5.3 — Loja e Web
- Ícone 512², imagem de destaque 1024×500, 6 capturas (geradas por um roteiro e2e "modo vitrine" com poses fixas), vídeo de 30 s (gravação do `--autoplay` com `--write-movie`).
- Textos pt-BR e en (curto ≤ 80, completo ≤ 4000).
- Web: Pages já existe; itch.io com `butler push export/web viniciolimadev/volei-mobile:html5`.

### 4.4 Fatia 5.4 — Telemetria

**Evento `match_end`:**

```json
{
  "v": 1, "install_id": "uuid-aleatório-local", "app": "1.0.0", "platform": "android",
  "event": "match_end", "mode": "1v1", "level": 1, "won": true,
  "sets": [[15, 12], [13, 15], [15, 9]], "duration_s": 512,
  "rally_avg": 5.1, "rally_best": 14, "perfect_rate": 0.42,
  "points_lost_by": {"Bola no chão": 9, "Fora": 4, "Rede": 2},
  "serve_types": [12, 6, 3], "blocks": 4, "dives": 2,
  "options": {"left_handed": false, "aim_sens": 1.2}
}
```

Também `session_start` (versão, idioma, modelo de aparelho **não**), `tutorial_end` (pulou?, passo em que mais errou). `install_id` gerado na primeira vez que o consentimento é dado; apagar = novo ID.

**Consentimento:** `ConsentScreen` na primeira abertura (depois do título carregar), dois botões ("Pode enviar" / "Não enviar"), texto curto + link. Save v5: `[privacy] consent=-1|0|1`, `install_id`.

**Uso dos dados:** consulta SQL no D1 que gera a tabela de equilíbrio real (vitórias por nível, duração, onde se perde ponto) — alimenta ajustes em `Tuning` nas versões 1.0.x.

### 4.5 Fatia 5.5 — Privacidade e "Sobre"
- Política de privacidade em `docs/privacidade.md` publicada no Pages (`/privacidade`), pt e en.
- Opções → Privacidade (RF-5.05) e tela Sobre (RF-5.09).

### 4.6 Fatia 5.6 — Robustez
- Relatório de erro (3.4); "algo deu errado" (RF-5.06).
- Matriz de aparelhos: Galaxy do dono, 1 Android de entrada (2 GB RAM), 1 tablet, Chrome Android e Safari iOS na Web; checklist manual por versão em `docs/CHECKLIST-RELEASE.md`.
- Relatório de pré-lançamento da Play sem erros (RNF-5.02).

### 4.7 Fatia 5.7 — Idiomas
- Extração de todos os textos para `strings.csv`; `tr()` em telas, HUD, botão de ação, tutorial, resultado.
- Seleção automática pelo `OS.get_locale_language()`; opção manual (save v5 `[options] lang`).

### 4.8 Fatia 5.8 — Acessibilidade e polimento
- Modo daltônico: anéis com padrão (cheio/tracejado/pontilhado por ação) além da cor; times com contorno e número na camisa.
- Texto 110%/125% (escala do `Theme`).
- Revisão final de tutorial com dados do teste fechado.

---

## 5. Ordem dos PRs

| PR | Conteúdo |
|---|---|
| 1 | 5.1 preset release + job de tag (publica só no GitHub Release) |
| 2 | 5.7 idiomas (mexe em muitos textos; antes da loja) |
| 3 | 5.4 telemetria cliente + consentimento + save v5 |
| 4 | `server/telemetry` (Worker + D1) + testes do backend |
| 5 | 5.5 privacidade e Sobre |
| 6 | 5.6 robustez + checklist |
| 7 | 5.8 acessibilidade |
| 8 | 5.2/5.3 upload para a Play + itch.io + material da loja |
| — | teste fechado (14 dias) → ajustes 1.0.x → produção (decisão do dono) |

---

## 6. Testes

| Grupo | Casos |
|---|---|
| `_test_telemetry` | sem consentimento nada é enfileirado; com consentimento o evento `match_end` tem exatamente os campos da 4.4 (nenhum extra); fila limita 50; apagar gera novo `install_id` |
| `_test_save` | migração v4 → v5 (consentimento −1 = perguntar) |
| `_test_i18n` | toda chave tem pt e en; nenhuma tela mostra chave crua; motivos de ponto traduzidos |
| `_test_colorblind` | modo daltônico muda o padrão dos anéis por ação |
| backend | POST válido grava; campos extras são descartados; DELETE apaga por `install_id`; sem IP na tabela |
| CI release | tag gera AAB assinado (verifica com `apksigner`/`bundletool`) e versão correta |
| e2e | fluxo com consentimento "Não enviar"; troca de idioma para inglês e título em inglês |

---

## 7. Critérios de aceite

1. Versão 1.0.0 em produção na Play (após teste fechado) e na Web (Pages + itch.io).
2. Data Safety e política de privacidade consistentes com o que o código envia (teste de campos).
3. RNF-5.01 e 5.02 atendidos no teste fechado.
4. Primeiro relatório de equilíbrio real a partir da telemetria.

---

## 8. Riscos

| Risco | Mitigação |
|---|---|
| Exigências da Play mudarem (target SDK, teste fechado) | checar a documentação no início da fase; `target_sdk` no preset revisado a cada release |
| Telemetria vista como invasiva | opt-in, padrão "não", campos mínimos e públicos na política |
| Perder a keystore | Play App Signing (a Google guarda a chave de app); upload key com backup do dono |
| Tradução quebrar layout | e2e em inglês com prints; textos longos testados |

---

## 9. Decisões assumidas (mude se discordar)

| # | Assumido | Alternativa |
|---|---|---|
| B5-1 | Gratuito, sem anúncios nem compras no 1.0 | anúncios recompensados / versão paga |
| B5-2 | Público 13+ | incluir crianças (regras extras da Play) |
| B5-3 | Telemetria em Cloudflare Worker + D1 | Firebase Analytics (mais completo, menos privado) |
| B5-4 | Português + inglês no lançamento | só português |
| B5-5 | Android primeiro; iOS só depois de avaliar o 1.0 | iOS junto |
