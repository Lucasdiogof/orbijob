# OrbiJob Web (Cloudflare Workers + Static Assets)

Padrão: `Lucasdiogof/lucksrei-web-template`. Isto publica **somente a interface Flutter**. Nada aqui toca nos crawlers,
nos workflows de descoberta/revalidação, no Worker `orbijob-jobicy-sync` (não implantado) nem na busca de vagas.

- Arquivos em `app/`: `wrangler.jsonc` (Worker `orbijob-web`, só assets), `web/_headers`, `scripts/*.sh`.
- Worker proposto `orbijob-web` e domínio `orbijob.lucksrei.com`: **nada foi criado/publicado**. A rota está comentada em `wrangler.jsonc`.
- Build: `cd app && FLUTTER_WEB_FLAGS=--no-web-resources-cdn bash scripts/build-web.sh dart_defines.web.json`
  (mesma flag do CI: CanvasKit empacotado, sem CDN). Requer Flutter 3.47.7 (ver `orbijob-flutter-sdk-fl3477`; o Flutter padrão do PC não resolve o pubspec).
- Deploy manual: `bash scripts/deploy-web.sh dart_defines.web.json` (precisa de login do wrangler). Rollback: `npx wrangler rollback <id> --name orbijob-web`.
- Smoke: `bash scripts/smoke-test.sh <url> /vagas`.
- Sem workflow de deploy: o CI existente (`ci.yml`) só compila a web. Para automatizar, usar `templates/deploy-web.yml` do template
  e cadastrar secrets, depois de autorização. Custo: nenhum novo serviço.

## Autenticação
Recuperação por código (`resetPasswordForEmail(email)` sem `redirectTo` e `verifyOTP(recovery)` em `supabase_auth_repository.dart`), inalterada.
`AUTH_REDIRECT_URL` só afeta os links de **confirmação de cadastro**. Para a web em produção ele deve ser
`https://orbijob.lucksrei.com/` e essa URL precisa constar nas Redirect URLs do projeto Supabase do OrbiJob
(**não alterado**; decisão do dono). `dart_defines.web.json` hoje aponta para o ambiente local de desenvolvimento.
Pendência externa: confirmar SMTP custom no projeto (embutido = 2 e-mails/hora).

## Limitações web conhecidas
Tradução on-device (ML Kit), push (FCM nativo) e WebView interna são recursos de Android/iOS; na web o app já os degrada
(`kIsWeb`), mas a execução no navegador não foi validada aqui. Navegador abre vagas em nova aba.


## QA local no navegador (2026-10-17, build servido por wrangler dev em localhost)
Carregamento, tela inicial, ausência de erros de console, mobile (375x812) e desktop verificados. Sem chaves privilegiadas no bundle.
**Não testado por mim**: login/logout/persistência, recuperação por código, isolamento entre usuários (exigem conta de QA e caixa de e-mail de QA, que não tenho; digitar senhas fora de localhost também é vedado).
Deploy de teste em workers.dev: **bloqueado** (login do wrangler expirou e não há `CLOUDFLARE_API_TOKEN`). Workflow `deploy-web.yml` pronto, desativado até existir o token e a variável `AUTO_DEPLOY=true`.

Achado: na aba Explorar a consulta de contagem em \`jobs\` (join com \`job_sources\`) devolveu HTTP 500 várias vezes e 206 outras; a lista inicial carregou. Provável timeout no Postgres; não é específico da web e não foi alterado.

## Ambiente de teste (2026-10-17)
URL: https://orbijob-web.lucasdiogo1234.workers.dev (Worker `orbijob-web`, deploy manual com token Cloudflare; versão 44ad1d7f).
Validado nessa URL em navegador real: carrega, sem erro de console próprio (smoke público: raiz, manifest, scripts, rota profunda e headers OK), tela de entrada/inicial correta. Login, sessão, recuperação por código e isolamento **não testados**: exigem criar conta/digitar senha, o que fica com o dono.
