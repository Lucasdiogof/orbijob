# HANDOFF — OrbiJob (atualizado 2026-10-09, Fase 3 — Supabase preparado)

## Fase 3 (branch `feat/phase3-supabase`, PR próprio, sem merge)
- Projeto Supabase **já criado pelo proprietário**: `rpmlfxwebnlxnwadyvle`. **Nada foi aplicado nele** (e o ambiente de desenvolvimento nem o alcança: egress bloqueado). Estado remoto = não verificado.
- Entregue: migration `20261010000000_app_integration.sql`; testes SQL em PostgreSQL 16 real (`supabase/tests/`, job `supabase-sql` no CI); `AppConfig` (só valores públicos, recusa secret/service_role), sessão no keystore, `AuthCubit` + tela de login/conta no Perfil, repositórios Supabase (perfil, experiência, formação, currículos, favoritos, candidaturas + histórico, preferências, pesquisas salvas) testados contra backend HTTP simulado; `.env.example` e `app/dart_defines.example.json`.
- **Plano de execução remota:** `docs/SUPABASE_MIGRATION_PLAN.md` — aguarda autorização expressa. Telas ainda não usam os repositórios (exceto conta).
- A Fase 3 depende das migrations do PR #39 (Fase 2): o PR da Fase 3 tem base `feat/phase2-stabilization`.

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
