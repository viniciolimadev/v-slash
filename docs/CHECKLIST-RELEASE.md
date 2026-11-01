# Checklist de release (por versão)

Feito à mão antes de promover uma versão da trilha interna para a seguinte. Marque cada linha no PR/issue da release.

## Automático (CI da tag `v*`)

- [ ] Testes headless `falhas: 0`, backend da telemetria e e2e verdes
- [ ] APK e AAB assinados (passo "Export signed APK + AAB": `apksigner verify`, `jarsigner -verify`, `versionName` = tag)
- [ ] APK ≤ 60 MB, Web ≤ 40 MB (gzip)
- [ ] GitHub Release criada com os dois arquivos
- [ ] AAB na trilha interna da Play (se `PLAY_SERVICE_ACCOUNT_JSON` existe) e HTML5 no itch.io (se `BUTLER_API_KEY` existe)

## Aparelhos (SDD-fase-5 4.6)

| Aparelho | Instala/abre | Partida 1v1 inteira | 2v2 | fps (`--fps` no PC / e2e na Web) | Som e vibração | Pausa ao trocar de app |
|---|---|---|---|---|---|---|
| Galaxy do dono | | | | | | |
| Android de entrada (2 GB RAM) | | | | | | |
| Tablet | | | | | | |
| Chrome Android (Web) | | | | | | |
| Safari iOS (Web) | | | | | | |

## Fluxos

- [ ] 1ª abertura: pergunta de estatísticas aparece; "Não enviar" não envia nada (sem pedidos de rede)
- [ ] Opções → Privacidade: ligar, desligar, "Apagar meus dados" (pedido `/v1/delete` chega ao Worker)
- [ ] Idioma: aparelho em inglês abre em inglês; troca manual em Opções vale na hora e fica salva
- [ ] Modo daltônico e texto 125%: anéis legíveis, nenhum texto cortado nas telas
- [ ] Sobre: versão certa e link da política abrindo
- [ ] Tutorial, revanche, troca de bot, fim de partida com resultado
- [ ] Relatório de pré-lançamento da Play sem falhas (RNF-5.02)

## Depois de publicar

- [ ] Política em `https://viniciolimadev.github.io/v-slash/privacidade/` igual ao que o código envia (`Telemetry.MATCH_FIELDS`)
- [ ] Data Safety da Play consistente com a política (docs/LANCAMENTO.md)
- [ ] Consulta `server/telemetry/balance.sql` rodando com dados reais
