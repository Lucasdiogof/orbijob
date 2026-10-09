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

## Fase 3.3 (2026-10-09)
- PR #42 (docs) integrado: `28a281fd88537f399ef35cc37f4b58971575ad97`; CI da `main` verde.
- Cota de favoritos: upsert de favorito existente no teto e inserts concorrentes — corrigido pela migration **corretiva** `20261012000000_quota_upsert_fix.sql` (a 4 não foi reescrita), PR #43 (não integrado).
- Ferramentas de implantação (PR de tooling, não integrado): `scripts/supabase/` — `inspect_readonly.sql` (inspeção somente leitura), `classify_state.mjs` (EMPTY / CONSISTENT / DRIFT), `apply.sh` (fases A–D com travas), `e2e_remote.mjs` (fase E com 2 contas), todos testados só com modelos/binários falsos. Roteiro do proprietário: `docs/SUPABASE_OWNER_RUNBOOK.md`.
- Acesso ao Supabase: continua bloqueado no ambiente do assistente (sem conector, sem CLI, sem credenciais, egress 403). Não se repetiu a sondagem.
- Flutter: revisão em `docs/SUPABASE_MIGRATION_PLAN.md` seção 10 (lacunas: deep link/redirect dos e-mails e tela de nova senha).

## Próxima ação necessária do proprietário
1. Destravar o acesso de leitura (acima) **ou** rodar a pré-checagem manualmente.
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
