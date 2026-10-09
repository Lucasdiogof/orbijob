# OrbiJob — conectar um projeto Supabase real

Nada disso foi executado: **nenhum projeto Supabase foi criado e nenhuma migration rodou em ambiente remoto.** Este guia descreve o caminho seguro quando você criar o projeto.

## Auditoria (resumo)
Migrations: `supabase/migrations/20261008000000_init.sql` (esquema) e `20261009000000_rls_hardening.sql` (endurecimento). Testadas em PGlite por `worker/test/rls.test.ts` (16 testes).

| Item | Estado |
|---|---|
| RLS em todas as tabelas | sim; privadas = apenas dono (`user_id = auth.uid()`) |
| Vínculo entre usuários (filho → pai de outro usuário) | bloqueado por políticas *restrictive* em experiences, education, credentials, resumes, applications, reminders, application_events |
| Anônimo | sem privilégio algum nas tabelas privadas |
| Catálogo (`jobs`, `job_sources`, `job_clusters`) | leitura apenas; vagas só de fontes `can_redistribute` e `READY/CONDITIONAL` |
| `sync_runs` | nenhum acesso de cliente |
| Escrita de vagas | só o Worker com service role (nunca no app) |
| Currículo | bucket privado `resumes`, caminho `<user_id>/…` (check constraint + policy de storage no fim da migration) |
| Índices | todas as FKs usadas por policies/joins |
| Separação de papéis | `anon` (catálogo), `authenticated` (dados próprios), `service_role` (somente Worker) |
| Pendência | storage policies precisam rodar no Supabase (schema `storage` é da plataforma); testar em staging |

## Passo a passo
1. Crie o projeto em supabase.com (região próxima aos usuários). Anote **Project URL**, **anon key** (pública) e **service_role key** (secreta).
2. Instale a CLI e vincule: `supabase login && supabase link --project-ref <ref>`.
3. **Revise** as duas migrations, depois `supabase db push` (aplica em ordem). Execute o bloco comentado de storage no SQL editor.
4. Auth → Providers: habilite e-mail (confirmação obrigatória) e os provedores desejados; configure Redirect URLs (web/deep link `com.lucksrei.orbijob://`); defina política de senha e rate limits de Auth.
5. Cadastre `job_sources` pelo seed de `data/sources.catalog.json` com `can_redistribute=false` até a licença ser aprovada.
6. App Flutter (somente chaves públicas): `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`. **Nunca** coloque a service role no app (há teste que falha se `service_role` aparecer em `app/`).
7. Worker: `wrangler secret put SUPABASE_SERVICE_ROLE_KEY` (ver `docs/CLOUDFLARE_SETUP.md`).
8. Checklist em staging antes de produção: criar 2 usuários e confirmar que um não lê/escreve/anexa nada do outro (inclusive via Storage); conferir Advisors (security/performance) do painel; ativar backups/PITR.
