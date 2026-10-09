# OrbiJob — conectar um projeto Supabase real

O projeto Supabase existe (`rpmlfxwebnlxnwadyvle`), mas **nenhuma migration foi aplicada nele**. O passo a passo ordenado (fases A–E) está em [SUPABASE_MIGRATION_PLAN.md](SUPABASE_MIGRATION_PLAN.md) e o roteiro de acesso/inspeção para o seu computador em [SUPABASE_OWNER_RUNBOOK.md](SUPABASE_OWNER_RUNBOOK.md); aguarde autorização expressa do proprietário antes de executar.

## Auditoria (resumo)
Migrations: `20261008000000_init.sql` (esquema), `20261009000000_rls_hardening.sql` (endurecimento), `20261010000000_app_integration.sql` (preferências, favoritos com snapshot, histórico de etapas, bucket privado) `20261011000000_quotas.sql` (cotas por usuário) e `20261012000000_quota_upsert_fix.sql` (corrige upsert no teto e concorrência da cota de favoritos). Testadas em PostgreSQL 16 real (`supabase/tests/run.sh`: auditoria de catálogo + testes entre usuários + 9 mutações) e em PGlite (`worker/test/rls.test.ts`).

| Item | Estado |
|---|---|
| RLS em todas as tabelas | sim; privadas = apenas dono (`user_id = auth.uid()`) |
| Vínculo entre usuários (filho → pai de outro usuário) | bloqueado por políticas *restrictive* em experiences, education, credentials, resumes, applications, reminders, application_events |
| Anônimo | sem privilégio algum nas tabelas privadas |
| Catálogo (`jobs`, `job_sources`, `job_clusters`) | leitura apenas; vagas só de fontes `can_redistribute` e `READY/CONDITIONAL` |
| `sync_runs` | nenhum acesso de cliente |
| Escrita de vagas | só o Worker com service role (nunca no app) |
| Currículo | bucket privado `resumes` (PDF, 5 MiB), caminho `<user_id>/…` (check constraint + 4 policies de storage na migration 3); app valida assinatura `%PDF-` e tamanho antes de enviar; leitura só por URL assinada de ≤ 5 min |
| Índices | todas as FKs usadas por policies/joins |
| Separação de papéis | `anon` (catálogo), `authenticated` (dados próprios), `service_role` (somente Worker) |
| Pendência | policies de storage só foram exercitadas contra um stub do schema `storage`; testar no projeto real (passo 7 do plano) |

## Passo a passo
1. Crie o projeto em supabase.com (região próxima aos usuários). Anote **Project URL**, **anon key** (pública) e **service_role key** (secreta).
2. Instale a CLI e vincule: `supabase login && supabase link --project-ref <ref>`.
3. **Revise** as duas migrations, depois `supabase db push` (aplica em ordem). Execute o bloco comentado de storage no SQL editor.
4. Auth → Providers: habilite e-mail (confirmação obrigatória) e os provedores desejados; configure Redirect URLs (web/deep link `com.lucksrei.orbijob://`); defina política de senha e rate limits de Auth.
5. Cadastre `job_sources` pelo seed de `data/sources.catalog.json` com `can_redistribute=false` até a licença ser aprovada.
6. App Flutter (somente valores públicos): copie `app/dart_defines.example.json` para `app/dart_defines.dev.json` (ignorado pelo git) e rode `flutter run --dart-define-from-file=dart_defines.dev.json`; equivalente: `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_…`. Sem esses valores o app roda sem contas. O app **recusa iniciar** com uma chave `sb_secret_…` ou JWT `service_role` e há testes que falham se `service_role` aparecer no código do app. Variáveis por ambiente: `.env.example`.
7. Worker: `wrangler secret put SUPABASE_SERVICE_ROLE_KEY` (ver `docs/CLOUDFLARE_SETUP.md`).
8. Checklist em staging antes de produção: criar 2 usuários e confirmar que um não lê/escreve/anexa nada do outro (inclusive via Storage); conferir Advisors (security/performance) do painel; ativar backups/PITR.

## Fase 4 — rodar o app contra o projeto real
Variáveis (`--dart-define` ou `--dart-define-from-file`; só valores públicos):
| Variável | Valor |
|---|---|
| `SUPABASE_URL` | Project URL (`https://<ref>.supabase.co`) |
| `SUPABASE_PUBLISHABLE_KEY` | chave `sb_publishable_…` (nunca `sb_secret_…`/service_role: o app recusa iniciar) |
| `AUTH_REDIRECT_URL` | para onde os e-mails de confirmação/recuperação voltam (ver abaixo) |

**Redirect URLs a cadastrar pelo proprietário** em Supabase → Authentication → URL Configuration (o assistente não altera Auth Settings):
| URL | Uso |
|---|---|
| `http://localhost:3000/**` | Web em desenvolvimento (`flutter run -d chrome --web-port=3000`, `AUTH_REDIRECT_URL=http://localhost:3000/`) |
| `com.lucksrei.orbijob://auth-callback` | Android e iOS (intent-filter e `CFBundleURLTypes` já no projeto; **não testados em aparelho**) |
| `https://<domínio-de-produção>/**` | **futura** — não existe hospedagem definida; não cadastrar nada inventado |

O **Site URL** hoje é `http://localhost:3000`: serve ao teste Web local, mas **não** para produção. Troque-o só quando existir a URL pública. Enquanto for localhost, **não considerar produção pronta**. Se a URL do esquema móvel não estiver na lista, o Supabase ignora o `redirectTo` e o e-mail cai no Site URL (no celular não abre o app).

Roteiro de teste com duas contas descartáveis: [FLUTTER_REMOTE_TEST.md](FLUTTER_REMOTE_TEST.md).

Sem essas variáveis o app abre normalmente, sem contas, e as telas dizem que a conta não está configurada.
