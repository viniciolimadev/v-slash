# Padrão de trabalho

Como o projeto é tocado, do planejamento ao merge. Vale para pessoas e agentes de IA (que também seguem o [AGENTS.md](../AGENTS.md)).

---

## 1. Documentos e quem manda em quê

| Documento | Responde | Atualizar quando |
|---|---|---|
| [ROADMAP.md](ROADMAP.md) | **o quê** e em que ordem (fases e fatias) | uma fatia termina, muda de escopo ou de ordem |
| [SDD.md](SDD.md) | **como** o sistema é e para onde vai (arquitetura, decisões) | muda arquitetura, invariante ou decisão (ADR/DP) |
| `SDD-fase-N.md` | **como** implementar a fase N (assinaturas, PRs, testes) | antes de começar a fase; ajustado se a implementação divergir |
| [README.md](../README.md) | como rodar, jogar e ajustar o feel | muda comando, controle, constante de `Tuning` ou equilíbrio |
| `AGENTS.md` | regras para agentes de IA | muda regra deste documento |

Precedência quando houver conflito: **decisão explícita do dono do projeto > SDD da fase > SDD geral > ROADMAP > README**. Conflito encontrado = corrigir o documento no mesmo PR.

---

## 2. Ciclo de uma fase

1. **Planejar:** fatias no ROADMAP com critério de pronto.
2. **Detalhar:** escrever `docs/SDD-fase-N.md` (requisitos com ID, design por fatia, ordem de PRs, testes, aceite). Decisões em aberto viram perguntas ao dono **antes** de codar.
3. **Implementar:** um PR por fatia, na ordem do SDD da fase.
4. **Fechar:** simulação de equilíbrio, tabela do README atualizada, teste no celular, critérios de aceite conferidos, fatias marcadas como feitas no ROADMAP.

---

## 3. Ciclo de uma fatia (um PR)

1. **Branch** a partir de `main` atualizado.
2. **Teste primeiro** quando der: escrever o caso em `tests/run_tests.gd` que falha sem a mudança.
3. **Implementar** o mínimo que faz o teste passar, seguindo o SDD da fase.
4. **Rodar** os testes headless localmente (comandos no README).
5. **Atualizar docs** afetados (seção 1).
6. **Abrir PR** com o modelo `.github/pull_request_template.md`.
7. **CI verde** + conferir os prints do e2e (artefato `e2e-screenshots`).
8. **Testar no celular** quando mexe em toque, HUD, telas ou feel (APK do artefato ou GitHub Pages).
9. **Merge** pelo dono do projeto (merge commit, como no histórico).

Tamanho: um PR revisável em ~15 minutos. Se passar disso, dividir em fatias menores (refatoração separada de comportamento novo).

---

## 4. Git

### 4.1 Branches

| Tipo | Nome | Exemplo |
|---|---|---|
| Fatia de fase | `f<fase>/<fatia>-<assunto>` | `f1/1.2-match-rules` |
| Correção | `fix/<assunto>` | `fix/joystick-dead-zone` |
| Documentação | `docs/<assunto>` | `docs/sdd-fase-2` |
| CI / ferramentas | `ci/<assunto>` | `ci/cache-playwright` |

Nunca commitar direto em `main`.

### 4.2 Commits

- Em **inglês**, assunto no formato `Área: resumo no imperativo`, até ~72 caracteres. Áreas usadas: `Game`, `Ball`, `Bot`, `Aim`, `HUD`, `UI`, `Controls`, `Match`, `Save`, `Tutorial`, `Test`, `CI`, `Docs`, `Tuning`.
- Corpo explica **por quê** e o efeito medido (ex.: "balls out 37 -> 0"), e qual teste cobre.
- Um commit = uma mudança coerente; refatoração sem mudança de comportamento em commit próprio.

```
Match: end a set at 15 with a 2-point lead

Game delegates scoring to MatchRules; endless mode (set_points = 0)
keeps main.tscn, --autoplay and the bot-vs-bot test unchanged.

Test: _test_match_rules (15-13, 15-14, 16-14, 1-1 -> third set).
```

### 4.3 Pull requests
Título igual ao commit principal. Corpo pelo modelo: o que muda, por quê, fatia/requisito (ex.: `F1 · 1.2 · RF-1.02`), como testar, prints/números, checklist de pronto.

---

## 5. Código

### 5.1 Idioma
- **Identificadores em inglês** (`ContactPlan`, `add_point`).
- **Comentários, docs, textos da UI e mensagens de teste em português.**
- Texto de UI em MAIÚSCULAS para ações do botão (`SACAR`, `ATACAR`), como já está.

### 5.2 GDScript
- Godot 4.7, tabs (`.editorconfig`), LF.
- **Tipagem estática sempre:** `var x := 1.0`, `func f(a: int) -> Vector3`, `Array[Player]`.
- Toda classe reutilizável tem `class_name` e um comentário `##` de 1–2 linhas dizendo o que ela é.
- Funções públicas com `##` quando o nome não basta; privadas com prefixo `_`.
- Blocos grandes separados por `# ---------------------------------------------------------------- assunto`.
- Comentário explica o **porquê** (regra, assistência, armadilha do Godot), não repete o código. Densidade como a do código existente.
- Sem `Dictionary` como estrutura de domínio nova: usar classe `RefCounted` tipada.
- Sem `get_node("caminho")` frágil: a cena é montada por código e as referências ficam em variáveis.

### 5.3 Regras de arquitetura (invariantes)
1. **Preditor = bola real.** Qualquer efeito na bola vai em `BallSim` e é determinístico; `predict()` usa o mesmo código.
2. **Número de feel só em `Tuning`**, com comentário de unidade. Nada de número mágico no meio da lógica (exceção: geometria visual de forma simples).
3. **`core/` não depende de `ui/` nem `ai/`.** `Game` fala para fora por sinais e consultas.
4. **O bot usa a mesma API do humano** (`attempt_hit`). Mecânica nova é usada pelo bot no mesmo PR (ou no seguinte, explicitamente).
5. **`main.tscn` roda sozinha** (F5, `--autoplay`, testes) sem autoload e sem a `App`.
6. **Tudo construído por código** até a Fase 4 (sem assets externos, sem `.tscn` com nós além da raiz).
7. **Assistências só para o humano** ficam marcadas como tal e configuráveis em `Tuning`.

Quebrar um invariante exige registrar a decisão no SDD (nova ADR) no mesmo PR.

---

## 6. Testes

- Todo comportamento novo tem `_check` em `tests/run_tests.gd`, com descrição em português que diz a regra ("15–14 não fecha o set").
- **Não afrouxar limite de teste existente** para fazer passar. Se o limite estava errado, explicar no PR.
- Aleatoriedade em teste: semente fixa (`rng.seed = ...`).
- Simulações imprimem os números (placar, médias, duração) para comparar antes/depois no PR.
- Mudou toque, HUD ou telas: ajustar `tests/e2e/mobile_smoke.js`.
- CI falha com `SCRIPT ERROR` ou `falhas: N > 0`; ninguém faz merge com CI vermelho.

---

## 7. Feel e equilíbrio

- Ajuste de feel = mudar `Tuning` + linha correspondente na tabela "Ajustar o feel" do README.
- Mudou algo que afeta pontos (velocidade, janela, bot, assistência): rodar de novo a simulação e colocar a tabela antes/depois no PR.
- Feel só é aprovado no celular, não no PC.

---

## 8. Definição de pronto

Uma fatia está pronta quando:

- [ ] Faz o que o SDD da fase descreve (ou o SDD foi atualizado para o que foi feito).
- [ ] Testes novos cobrem a regra; todos os testes e o e2e passam no CI.
- [ ] Nenhum invariante da seção 5.3 foi quebrado sem ADR.
- [ ] README/SDD/ROADMAP atualizados se afetados.
- [ ] Testada no celular quando mexe em toque, UI ou feel.
- [ ] PR pequeno, com por quê, números e como testar.

---

## 9. Decisões

- **Produto** (regra de jogo, escopo, formato): só o dono decide. Registrar no SDD como `DP-NN` com data.
- **Arquitetura**: proposta no PR ou no SDD da fase; registrada como `ADR-NN` no SDD.
- **Assumidas** (detalhes razoáveis sem resposta ainda): listar na seção "Decisões assumidas" do SDD da fase, para o dono confirmar.

---

## 10. Versões

- `version/name` do preset Android: Fase 0 = `0.1.x`; cada fase concluída sobe o minor (fim da Fase 1 → `0.2.0`); lançamento (Fase 5) = `1.0.0`. `version/code` sobe a cada build distribuída.
- `config/description` do `project.godot` acompanha a fase atual.
