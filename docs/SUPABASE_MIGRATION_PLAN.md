# OrbiJob — plano de aplicação das migrations no Supabase real

Projeto: `rpmlfxwebnlxnwadyvle` (https://supabase.com/dashboard/project/rpmlfxwebnlxnwadyvle). **Nenhuma alteração remota foi feita.** Este plano só deve ser executado após autorização expressa do proprietário.

## 0. Estado remoto (não verificado)
O ambiente de desenvolvimento não alcança `*.supabase.co` / `supabase.com` (egress bloqueado, HTTP 403 "Host not in allowlist") e não recebeu credenciais. Portanto o estado real do projeto **não foi inspecionado**. O plano abaixo assume projeto novo/vazio e começa com verificações que confirmam isso antes de qualquer escrita.

## 1. Migrations (ordem e conteúdo)
| # | Arquivo | O que faz | Destrutivo? |
|---|---|---|---|
| 1 | `20261008000000_init.sql` | extensão `pg_trgm`; catálogo (`job_sources`, `jobs`, `job_clusters`, `sync_runs`); dados privados (perfis, experiências, formação, credenciais, currículos, favoritos, pesquisas, vistas, candidaturas, eventos, lembretes); RLS dono-único | não (só `create`) |
| 2 | `20261009000000_rls_hardening.sql` | políticas *restrictive* de pai, check do caminho do currículo, `revoke all` + `grant` mínimos para `anon`/`authenticated`, índices de FK | só `revoke` e `drop/create policy` de objetos criados no passo 1 |
| 3 | `20261010000000_app_integration.sql` | `pg_trgm` → schema `extensions`; `updated_at` + triggers; `user_preferences`; `saved_jobs` com snapshot (troca de PK numa tabela vazia); limites de tamanho; trigger de histórico de etapas (SECURITY INVOKER); bucket privado `resumes` + 4 policies em `storage.objects` | `drop constraint` da PK de `saved_jobs` e `drop policy` de 2 policies recriadas na mesma migration; seguro com tabelas vazias |

Nenhuma migration usa `SECURITY DEFINER`, cria trigger em `auth.users` ou concede algo a `anon` além de `SELECT` no catálogo.

## 2. Validação já feita (antes de qualquer escrita remota)
- Cadeia completa aplicada em **PostgreSQL 16 real** descartável com stub da plataforma (`supabase/tests/run.sh`, também no CI como job `supabase-sql`): sintaxe, dependências e ordem.
- `01_audit.sql`: RLS em todas as tabelas e em `storage.objects`; `anon` só lê catálogo; `authenticated` não escreve catálogo nem lê `sync_runs`; nenhuma função `SECURITY DEFINER`/executável por API; nenhum trigger em `auth.users`; toda FK indexada; toda tabela privada com policy de dono; bucket `resumes` privado, 5 MiB, só PDF, 4 policies.
- `02_behaviour.sql`: usuário A não lê, altera, apaga nem vincula nada de B em **12 tabelas + storage**; anônimo sem acesso; caminho de currículo fora da própria pasta rejeitado; histórico de etapas gravado pelo trigger; limites de tamanho.
- Testes de mutação: 9 falhas deliberadas (policy permissiva, bucket público, grant a `anon`, `SECURITY DEFINER`, índice faltando, `using (true)`, etc.) — todas detectadas.
- Idempotência: a seção de storage é reexecutável (`on conflict`, `drop policy if exists`); o restante é de execução única, controlado pelo histórico `supabase_migrations.schema_migrations` (a CLI nunca reaplica uma versão já registrada).
- `worker/test/rls.test.ts` (PGlite) cobre as migrations 1–2 de forma independente.

## 3. Execução remota (aguarda autorização)
Na máquina do proprietário (token pessoal, nunca no repositório):
1. **Pré-checagem do projeto** (SQL Editor, somente leitura):
   - `select count(*) from information_schema.tables where table_schema='public';` → esperado `0`
   - `select * from supabase_migrations.schema_migrations;` → vazio/inexistente
   - `select id, public from storage.buckets;` → sem `resumes`
   Se algo existir, **parar** e reavaliar (conflito de nomes ou migrations anteriores).
2. `supabase login` · `supabase link --project-ref rpmlfxwebnlxnwadyvle`.
3. `supabase db dump -f backup-before-orbijob.sql` (guarde fora do repositório; o plano gratuito não tem PITR).
4. `supabase migration list` → remoto sem versões; local com as 3. `supabase db push --dry-run` → deve listar exatamente as 3, nesta ordem.
5. `supabase db push` (cada arquivo roda em transação; falha interrompe sem aplicar parcialmente aquela migration).
6. **Pós-checagem:** rodar `supabase/tests/01_audit.sql` no SQL Editor (remova a linha `\set`; é só leitura) → deve terminar sem erro. Rodar os **Advisors** (Security e Performance) do painel e registrar avisos.
7. **Teste de isolamento em staging** com 2 contas descartáveis: cada uma cria perfil/favorito/candidatura/currículo; confirmar que a outra não vê nada e que `curl` com a chave publishable e o token de A em linhas de B retorna vazio/403. Não executar `02_behaviour.sql` no projeto real (ele insere dados).
8. Configurar Auth (seção 4) e entregar ao app `SUPABASE_URL` + chave **publishable**.

## 4. Configurações no painel (não são migrations)
- Auth → Providers: e-mail habilitado; **Confirm email = ON**; desabilitar provedores não usados.
- Auth → URL Configuration: Site URL e Redirect URLs (web de produção e `com.lucksrei.orbijob://login-callback`).
- Auth → Password: mínimo 8+ (app exige 8); leaked-password protection se o plano permitir.
- Auth → Rate limits: manter os padrões ou reduzir; considerar CAPTCHA antes de abrir ao público.
- API: expor apenas o schema `public`; desligar GraphQL se não for usado.
- Chaves: **publishable** → app; **secret** → somente Cloudflare Worker (`wrangler secret put`); nunca em Flutter, no repositório ou em logs. Se uma secret vazar, rotacionar no painel.
- Projetos gratuitos pausam por inatividade; para uso real, considerar plano pago (backups/PITR).

## 5. Reversão
Não há migrations "down". Em staging: `supabase db reset --linked` (**apaga tudo**) e reaplicar. Em produção: restaurar o dump do passo 3 ou escrever migration corretiva (forward-fix). Dados de usuários só existirão depois da liberação do app, então o risco de perda na primeira aplicação é nulo.

## 6. Pendências conhecidas
- Exclusão de conta: linhas somem por `on delete cascade`, mas objetos do Storage ficam órfãos → rotina administrativa no Worker (service role) ou Edge Function; ainda não implementada.
- `jobs`/`job_sources` ficam vazias até existir fonte `READY`; `can_redistribute` deve ser `false` até a licença ser aprovada.
- As telas ainda não usam os repositórios Supabase (exceto login/conta); a ligação vem depois da validação remota.
