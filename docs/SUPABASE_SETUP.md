# OrbiJob — conectar um projeto Supabase real

O projeto Supabase existe (`rpmlfxwebnlxnwadyvle`), mas **nenhuma migration foi aplicada nele**. O passo a passo ordenado, com pré e pós-checagens, está em [SUPABASE_MIGRATION_PLAN.md](SUPABASE_MIGRATION_PLAN.md); aguarde autorização expressa do proprietário antes de executar.

## Auditoria (resumo)
Migrations: `20261008000000_init.sql` (esquema), `20261009000000_rls_hardening.sql` (endurecimento), `20261010000000_app_integration.sql` (preferências, favoritos com snapshot, histórico de etapas, bucket privado) e `20261011000000_quotas.sql` (cotas por usuário). Testadas em PostgreSQL 16 real (`supabase/tests/run.sh`: auditoria de catálogo + testes entre usuários + 9 mutações) e em PGlite (`worker/test/rls.test.ts`).

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
