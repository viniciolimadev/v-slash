# Lançamento — o que o dono do projeto precisa fazer

O código, o CI e o backend estão prontos ([SDD-fase-5](SDD-fase-5.md)). Os passos abaixo dependem de contas e
chaves que só o dono tem; nenhum deles está automatizado.

## 1. Chave de upload (uma vez)

```bash
keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload.keystore > upload.keystore.b64        # conteúdo vai para o segredo abaixo
```

Guarde `upload.keystore` e a senha fora do repositório (backup). Na Play, ative o **Play App Signing**: a Google guarda a chave do app; esta é só a de upload.

## 2. Segredos e variáveis do GitHub (Settings → Secrets and variables → Actions)

| Nome | Tipo | Valor |
|---|---|---|
| `ANDROID_KEYSTORE_B64` | segredo | conteúdo de `upload.keystore.b64` |
| `ANDROID_KEYSTORE_PASS` | segredo | senha da keystore |
| `ANDROID_KEY_ALIAS` | segredo | `upload` |
| `PLAY_SERVICE_ACCOUNT_JSON` | segredo (opcional) | JSON da conta de serviço com acesso de "Release manager" ao app |
| `BUTLER_API_KEY` | segredo (opcional) | chave da API do itch.io |
| `TELEMETRY_URL` | variável | URL do Worker (passo 4), sem barra no fim |
| `ITCH_TARGET` | variável (opcional) | `usuario/jogo` no itch.io (padrão `viniciolimadev/volei-mobile`) |
| `PLAY_RELEASE_STATUS` | variável (opcional) | `draft` até a 1ª revisão da Play; depois `completed` |

## 3. Play Console

1. Criar o app `com.viniciolimadev.voleimobile` (gratuito, sem anúncios — B5-1), classificação etária livre, público-alvo 13+ (B5-2).
2. Ficha da loja: textos e imagens de [LOJA.md](LOJA.md) e `assets/store/`.
3. **Data Safety**: coleta "Informações e desempenho do app → outras ações no app" e "diagnóstico" (erros), **opcional**, **não vinculada à identidade**, sem compartilhamento, com exclusão pelo usuário; criptografada em trânsito (HTTPS).
4. Política de privacidade: `https://viniciolimadev.github.io/v-slash/privacidade/`.
5. Primeira tag: `git tag v1.0.0 && git push origin v1.0.0` → AAB na trilha interna (rascunho).
6. Teste fechado com 12+ testadores por 14 dias (exigência para contas novas), depois produção (decisão do dono).

## 4. Telemetria (Cloudflare)

```bash
cd server/telemetry
npx wrangler d1 create volei-telemetry          # copie o database_id para wrangler.toml
npx wrangler d1 execute volei-telemetry --remote --file=schema.sql
npx wrangler deploy                             # a URL impressa vai para a variável TELEMETRY_URL
```

Relatório de equilíbrio: `npx wrangler d1 execute volei-telemetry --remote --file=balance.sql`.

## 5. itch.io

Criar o projeto (tipo HTML5, "This file will be played in the browser", 1280×720, botão de tela cheia) com o mesmo nome de `ITCH_TARGET`. Com `BUTLER_API_KEY` definido, cada tag publica a versão Web.
