# HANDOFF — OrbiJob (atualizado 2026-10-09, Fase 3 — Supabase preparado)

## Integração dos PRs (2026-10-09)
| PR | Conteúdo | Merge commit |
|---|---|---|
| #38 | identidade C | `3f5dc6185bc8f5da592ddb415b9a2404c5ab4e40` |
| #39 | Fase 2 (conteúdo original das vagas, RLS hardening, Worker HTTP) | `eaae3ea3228905cb25e766392d85bfda2c9e354d` |
| #40 | Fase 3 (migration de integração, testes SQL, auth e repositórios Flutter) | `dce2599f68e7941940f40763c7f4f53a15718815` |
| #41 | cotas, teardown testado, remoção de arquivos ao apagar perfil, plano revisado | `4ba5023faee3dde6d88cb1f7acaa22b0f0bdfd70` |
CI da `main` verde após cada merge (#38, #39, #40 e #41; no #41: app, supabase-sql, worker, catalog, android-resources e secrets). Histórico preservado (merge commits), sem force push.

## Supabase (projeto `rpmlfxwebnlxnwadyvle`) — estado conhecido
- **Nada foi aplicado e nada foi lido do projeto.** Acesso de leitura tentado em 2026-10-09 (duas vezes):
  - conector Supabase: existe no registro, **não instalado** na conta nem habilitado na sessão;
  - rede: `*.supabase.co` e `api.supabase.com` → `CONNECT tunnel failed, response 403` (host fora da allowlist do ambiente);
  - CLI `supabase`: não instalada; sem token no ambiente (nenhuma variável `SUPABASE_*`).
  Não se assume banco vazio.
- **Para destravar (feito por você, nas configurações do ambiente — nunca colando segredos no chat):** (1) Editar o ambiente de nuvem → Network access → liberar `rpmlfxwebnlxnwadyvle.supabase.co` e `api.supabase.com` (Allowed domains); (2) criar um **token de acesso pessoal somente leitura** em supabase.com/dashboard/account/tokens e guardá-lo em *Network secrets/API credentials* (ou variável de ambiente `SUPABASE_ACCESS_TOKEN`) do ambiente; (3) alternativa sem rede: instalar o conector *Supabase* em claude.ai e habilitá-lo neste chat; (4) alternativa manual: rodar a pré-checagem do plano (seção 3, passo 1) no SQL Editor e colar só os resultados.
- Migrations pendentes (5): `20261008000000_init`, `20261009000000_rls_hardening`, `20261010000000_app_integration`, `20261011000000_quotas`, `20261012000000_quota_upsert_fix` (corretiva da cota de favoritos). Plano exato, riscos e reversão: `docs/SUPABASE_MIGRATION_PLAN.md`. Teardown (não executado): `supabase/rollback/rollback_all.sql`, exige excluir o bucket pela Storage API antes.
- Testes SQL rodam em PostgreSQL 16 real com **stub** de Auth/Storage: não substituem validação real. Incompatibilidades possíveis estão listadas na seção 8 do plano.
- Pendentes de implementar: exclusão de conta e varredura de órfãos no Worker; ligar telas aos repositórios.

## Correção do `inspect_predeploy_details.sql` (2026-10-09)
O proprietário rodou a consulta no Supabase hospedado (PostgreSQL 17.11) e ela falhou com `ERROR: 3F000: schema "$user" does not exist` (causa raiz e correção em `docs/SUPABASE_MIGRATION_PLAN.md` §12.10). Versão corrigida no PR #45; **precisa ser executada de novo** pelo proprietário. A correção só foi testada localmente (PostgreSQL 16 e 17); nada foi verificado no Supabase hospedado até o novo resultado chegar. Decisão técnica continua **BLOCKED**.

## Fase 3.6 (2026-10-09) — primeira inspeção REAL do Supabase
- **Estado real informado pelo proprietário** (SQL Editor, 2026-10-09T03:02:11Z): PostgreSQL 17.11; `public` sem tabelas/policies/triggers; sem buckets; sem triggers em `auth.users`; sem histórico (`migration_versions: null`); `pg_trgm` não instalada; função `public.rls_auto_enable` (SECURITY DEFINER, executável por anon/authenticated) e default privileges para `postgres`/`supabase_admin`.
- **Classificação formal: `EMPTY`** (justificada: schema `supabase_migrations` ausente **e** nenhum objeto do OrbiJob), com a exceção `rls_auto_enable` e um `BLOCKER-FOR-APPLY` até haver detalhe. As 5 migrations estão pendentes. Análise completa: `docs/SUPABASE_MIGRATION_PLAN.md` seção 12.
- **Decisão técnica: BLOCKED para aplicar** — faltam evidências de privilégio de `postgres` em `extensions`, `storage.*` e `auth.users`, e a definição real de `rls_auto_enable`. **Próxima consulta (única, somente leitura):** `scripts/supabase/inspect_predeploy_details.sql` → `node scripts\supabase\predeploy_check.mjs predeploy.json`.
- Corrigido: `01_audit.sql` falharia no projeto real por causa de `rls_auto_enable`; agora tolera só event-trigger functions ligadas a um event trigger (testado, com mutantes). Classificador devolve `exceptions`/`blockers`/`evidence`; novo `predeploy_check.mjs`; `apply.sh` exige o veredito de pré-deploy em `backup` e de novo antes do `db push`.
- Suíte SQL agora em PostgreSQL **16 e 17** (CI em matriz). Nada foi aplicado, criado ou alterado no projeto remoto.

## Fase 3.4 (2026-10-09) — estado anterior
- PR #42 (docs): `28a281fd88537f399ef35cc37f4b58971575ad97`. PR #43 (cota de favoritos): `3142ab8e63418c1c725707664683edef857fb536`. PR #44 (ferramentas de implantação): integrado nesta rodada; o SHA do merge está em `git log --first-parent main` (merge commit "Merge pull request #44"). CI da `main` verde após os merges anteriores.
- **Cota de favoritos corrigida** pela migration corretiva `20261012000000_quota_upsert_fix.sql` (a 4 não foi reescrita): upsert de favorito existente no teto passa; inserts concorrentes não ultrapassam (lock advisory **por usuário**; um lock por tabela gerava `deadlock detected` entre duas tabelas de cota — medido). Limite conhecido: só vale em `READ COMMITTED` (padrão do PostgREST); em `REPEATABLE READ` medimos 999 + 2 inserts = 1001.
- **Ferramentas** (`scripts/supabase/`): `inspect_readonly.sql`, `classify_state.mjs` (aceita as formas de exportação do SQL Editor), `apply.sh` (travas: projeto certo, CLI autenticada, backup válido com marcador final, atestado de backup de DADOS se o projeto não estiver vazio, banco inalterado entre backup e aplicação, confirmação explícita, trava gasta **antes** do `db push`), `e2e_remote.mjs`. Roteiro para Windows 10/11 em `docs/SUPABASE_OWNER_RUNBOOK.md` (SQL Editor primeiro; WSL 2 para as fases em Bash).
- **Supabase `rpmlfxwebnlxnwadyvle`: classificação UNKNOWN.** Sem conector, sem CLI autenticada, sem credenciais e egress bloqueado no ambiente do assistente (sondado de novo nesta rodada, mesmo resultado). Nada lido, nada aplicado.
- **Migrations pendentes (5, presumidas):** `20261008000000_init`, `20261009000000_rls_hardening`, `20261010000000_app_integration`, `20261011000000_quotas`, `20261012000000_quota_upsert_fix`.
- Testes: ver "Classificação dos testes" no plano (seção 11): o que é local, simulado ou real. **Nenhum teste contra Auth/Storage reais foi executado.**
- Lacunas do app antes de abrir o login ao público: deep link/`emailRedirectTo` dos e-mails e tela de nova senha (plano, seção 10); exclusão de conta e varredura de órfãos no Worker.

## Próxima ação necessária do proprietário
1. Rodar no SQL Editor a **segunda consulta** `scripts/supabase/inspect_predeploy_details.sql` (passo a passo para Windows em `docs/SUPABASE_OWNER_RUNBOOK.md`, seção "Segunda consulta") e enviar o `predeploy.json` (sem segredos) ao assistente.
2. Com o estado remoto conhecido, autorizar **especificamente** a aplicação das 5 migrations (ou executar os passos 2–8 do plano).

# Estado da Fase 2

## Estado
- Repositório: https://github.com/Lucasdiogof/orbijob (**público**). **PR #38 (identidade C) integrado na `main`** com merge commit `3f5dc6185bc8f5da592ddb415b9a2404c5ab4e40` (histórico preservado, sem force push). CI da `main` nesse commit: **verde** (catalog, worker, app, android-resources, secrets; run 37862754804).
- **Identidade oficial: C — Minimal Tech**, presente na `main` (tokens gerados de `docs/design/identity/c-minimal/tokens.json`, fontes, logotipo, ícones, splash, temas, componentes, responsividade).
- Trabalho da Fase 2 está na branch `feat/phase2-stabilization` (PR próprio, **sem merge automático**): conteúdo original das vagas com selo de idioma, cartão compacto, Início com pesquisas recentes/países de interesse, migration de endurecimento RLS (proposta), Worker com `getJson`/timeout/`Retry-After`, `scripts/probe-sources.mjs`, `web_checks.mjs`, guias `SUPABASE_SETUP.md`, `CLOUDFLARE_SETUP.md`, `SOURCES_VALIDATION.md`.

## Verificado na Fase 2
`dart format`, `flutter analyze` (limpo), **144 testes Flutter**, **58 testes do Worker** (RLS em PGlite com 16 casos, HTTP/retry), `tsc`, `flutter build web --release`, checagens web (`docs/evidence/web-checks-2026-10-09.json`: manifest, 4 ícones com dimensões corretas incl. maskable, theme-color claro/escuro, favicons, sem erros de console nem rolagem horizontal em 3 tamanhos × claro/escuro).

## Plataformas — o que NÃO foi validado
1. **Android:** `flutter build apk --debug` / `appbundle` **impossíveis aqui** (sem Android SDK; `dl.google.com` bloqueado). Só validação estática (`aapt2`, testes de assets). Nome, `applicationId com.lucksrei.orbijob`, ícone adaptativo/monocromático e splash validados estaticamente; **falta** build, instalação e teste em aparelho/emulador (fazer no CI com `setup-android` ou localmente).
2. **iOS:** sem macOS/Xcode — **não compilado**. Pendências no Mac: abrir `Runner.xcworkspace`, conferir `LaunchScreen.storyboard` e a cor `LaunchBackground`, `flutter build ios --no-codesign`, ícones, assinatura/Team ID, ícones iOS 18 escuro/tingido (não incluídos).
3. Splash fria/quente em aparelho, leitores de tela reais, daltonismo, testes com usuários.

## Pendências técnicas
- Fontes de vagas: **nenhuma `READY`**. Sonda de 2026-10-09: ambiente bloqueia os hosts (`EGRESS_BLOCKED`) e faltam chaves (USAJOBS, Adzuna, France Travail). Primeira recomendada: **Adzuna** (cobre qualquer profissão em vários países); depois USAJOBS. Ver `docs/SOURCES_VALIDATION.md`.
- Supabase: nada criado/executado. Seguir `docs/SUPABASE_SETUP.md` (revisar migrations → `db push`; policies de storage no SQL editor; testar isolamento em staging).
- Cloudflare: Worker é biblioteca sem entrada/`wrangler.toml`; rate limit precisa de Durable Object. Ver `docs/CLOUDFLARE_SETUP.md`.
- Persistir tema, favoritos e pesquisas recentes; busca de marca (INPI/USPTO/EUIPO/WIPO); proteção de branch; licença do repositório; autoria dos commits antigos mostra "Claude" (histórico público, não reescrito).

## Próxima etapa recomendada
Revisar/mergear o PR da Fase 2; criar contas/chaves (Adzuna, USAJOBS) e rodar `scripts/probe-sources.mjs` com rede liberada; ler os termos; implementar o 1º conector real com teste de contrato; só depois criar o projeto Supabase (staging) e o Worker.
