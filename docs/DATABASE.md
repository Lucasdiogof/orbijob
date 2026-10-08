# Banco de dados (Supabase / PostgreSQL)

Migração proposta: `supabase/migrations/20261008000000_init.sql` — **não executada em nenhum projeto Supabase.** Validada localmente em PGlite (Postgres WASM) com stubs de `auth`/roles (`worker/test/rls.test.ts`, 7 testes).

## Modelo
- **Público:** `job_sources`, `jobs`, `job_clusters`. Leitura por clientes apenas de fontes com `can_redistribute` e status READY/CONDITIONAL. Escrita só pelo Worker (service role). `sync_runs`: sem política → inacessível a clientes.
- **Privado (RLS dono-único via `auth.uid()`):** `professional_profiles`, `experiences`, `education`, `credentials`, `resumes`, `saved_jobs`, `saved_searches`, `viewed_jobs`, `applications`, `application_events`, `reminders`. Políticas *restritivas* impedem anexar filhos ao perfil/candidatura de terceiros.
- **Currículos:** bucket privado `resumes`, caminho `<user_id>/<uuid>.pdf`, política por pasta (SQL comentado na migração; só roda no Supabase). Acesso por URL assinada de curta duração.

## Índices de busca
GIN `tsvector` (config `simple`, multilíngue), GIN trigram em `title`, B-tree `(country, published_at)`, `(isco08, country)`, `fingerprint`, `canonical_url`. Revisar config de idioma/unaccent e `EXPLAIN` com volume real.

## Deduplicação
Chave `(source_id, external_id)` única; `canonical_url` e `fingerprint` indexados para formar clusters. Vagas de fontes diferentes permanecem como linhas distintas ligadas por `cluster_id` (preserva atribuição por fonte).

## Backup/recuperação
Ver ARCHITECTURE; verificar limites do plano gratuito; `pg_dump` periódico criptografado das tabelas privadas; teste de restauração trimestral (a definir).

## Limitações conhecidas
RLS testada em PGlite, **não** no Supabase real (grants/roles padrão da plataforma foram emulados). Repetir testes em projeto de staging. Exclusão de conta (LGPD/GDPR) via `on delete cascade` de `auth.users`; arquivos do Storage precisam de rotina própria.
