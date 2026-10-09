# OrbiJob — plano de aplicação das migrations no Supabase real

Projeto: `rpmlfxwebnlxnwadyvle` (https://supabase.com/dashboard/project/rpmlfxwebnlxnwadyvle). **Nenhuma alteração remota foi feita.** Este plano só deve ser executado após autorização **específica** do proprietário para aplicar as migrations.

## 0. Estado remoto (não verificado — bloqueio exato)
Tentativa em 2026-10-09 (somente leitura):
- Conector Supabase da conta: existe no registro, mas **não está instalado** (`installState: not_installed`) nem habilitado nesta sessão.
- Rede: `https://rpmlfxwebnlxnwadyvle.supabase.co/` e `https://api.supabase.com/` → `CONNECT tunnel failed, response 403` (host fora da allowlist de egress do ambiente).
- Credenciais: nenhuma disponível no ambiente (e nenhuma deve ser colada no chat).

Consequência: tabelas, migrations aplicadas, extensões, buckets e configurações de Auth **não foram consultados**. Não se assume banco vazio: o passo 1 abaixo comprova.

**Para destravar a leitura**, uma destas opções: (a) conectar o conector *Supabase* em claude.ai e habilitá-lo neste chat; (b) liberar `*.supabase.co` e `api.supabase.com` no egress do ambiente **e** fornecer um token somente-leitura por variável de ambiente do ambiente (não pelo chat); (c) o proprietário rodar a pré-checagem do passo 1 e colar apenas os resultados.

## 1. Migrations (ordem e conteúdo)
| # | Arquivo | O que faz | Destrutivo? |
|---|---|---|---|
| 1 | `20261008000000_init.sql` | `pg_trgm`; catálogo (`job_sources`, `jobs`, `job_clusters`, `sync_runs`); dados privados (perfis, experiências, formação, credenciais, currículos, favoritos, pesquisas, vistas, candidaturas, eventos, lembretes); RLS dono-único | não |
| 2 | `20261009000000_rls_hardening.sql` | políticas *restrictive* de pai, check do caminho do currículo, `revoke all` + `grant` mínimos a `anon`/`authenticated`, índices de FK | só `revoke` e `drop/create policy` de objetos do passo 1 |
| 3 | `20261010000000_app_integration.sql` | `pg_trgm` → schema `extensions`; `updated_at`; `user_preferences`; `saved_jobs` com snapshot (troca de PK numa tabela vazia); limites de tamanho; trigger de histórico (SECURITY INVOKER); bucket `resumes` privado + 4 policies em `storage.objects` | `drop constraint` da PK de `saved_jobs` e `drop policy` de 2 policies recriadas na mesma migration; seguro com tabelas vazias |
| 4 | `20261011000000_quotas.sql` | cotas por usuário via trigger (currículos 10, favoritos 1000, pesquisas 100, candidaturas 2000) | não |

Dependências: 2 usa objetos de 1; 3 usa `saved_jobs_visible_job`, `resumes` e a extensão de 1–2; 4 usa tabelas de 1. A ordem é a dos timestamps; a CLI aplica nessa ordem. Nenhuma migration usa `SECURITY DEFINER` nem cria trigger em `auth.users`; `anon` só recebe `SELECT` no catálogo.

## 2. O que já foi validado — e o que NÃO foi
**Validado em PostgreSQL 16 real, descartável, com um stub da plataforma** (`supabase/tests/run.sh`, job `supabase-sql` no CI):
- Cadeia das 4 migrations: sintaxe, dependências, ordem.
- `01_audit.sql`: RLS em todas as tabelas e em `storage.objects`; `anon` só lê o catálogo; `authenticated` não escreve catálogo nem lê `sync_runs`; nenhuma função `SECURITY DEFINER` nem executável pelas roles de API; nenhum trigger em `auth.users`; toda FK indexada; toda tabela privada com policy de dono; bucket `resumes` privado, 5 MiB, só PDF, 4 policies.
- `02_behaviour.sql`: A não lê/altera/apaga/vincula nada de B em 12 tabelas + `storage.objects`; anônimo sem acesso; caminho de currículo fora da própria pasta rejeitado; histórico de etapas gravado pelo trigger; limites de tamanho.
- `03_quotas.sql`: cada cota barra a inserção seguinte e libera ao remover.
- Mutação: 9 falhas deliberadas (policy permissiva, bucket público, grant a `anon`, `SECURITY DEFINER`, índice faltando, `using (true)`…) — todas detectadas.
- Teardown ida-e-volta: `rollback/rollback_all.sql` recusa sem confirmação, limpa tudo (`04_rollback_clean.sql`) e a cadeia reaplica.
- Descoberto pelos testes: uma policy que conta linhas da própria tabela falha com *infinite recursion detected in policy*; por isso as cotas são triggers.

**NÃO provado por esses testes (precisa do projeto real):**
- **Auth real**: e-mail/senha, confirmação, PKCE, refresh, limites de taxa, provedores. O `auth.uid()` do teste é um stub que lê um GUC.
- **Storage real**: o schema `storage` é um stub mínimo. Não foi exercitado: Storage API (upload, signed URL, remoção), `allowed_mime_types`/`file_size_limit` aplicados pela API, permissões do role `postgres` para criar policies em `storage.objects` e inserir em `storage.buckets`, dono dessas tabelas (`supabase_storage_admin`).
- **Extensão**: `alter extension pg_trgm set schema extensions` exige ser dono da extensão no projeto real.
- **Privilégios padrão**: o stub concede tudo a `anon`/`authenticated` por default privileges; no Supabase real os defaults vêm do `supabase_admin`. O `revoke all on all tables` dos passos 2 age sobre o que existe; o `alter default privileges` só vale para objetos criados pelo role que roda a migration (`postgres`). Conferir com a auditoria pós-aplicação.
- **Advisors** do painel e PostgREST (exposição do schema) não foram executados.

Por isso a pós-checagem (seção 3, passo 6–8) é obrigatória e não pode ser substituída pelos testes locais.

## 3. Execução remota (aguarda autorização específica)
Na máquina do proprietário (token pessoal; nunca no repositório ou no chat):
1. **Pré-checagem (SQL Editor, somente leitura)** — todos devem dar o resultado esperado, senão **parar**:
   - `select table_name from information_schema.tables where table_schema='public';` → vazio
   - `select * from supabase_migrations.schema_migrations;` → vazio (ou tabela inexistente)
   - `select extname, extnamespace::regnamespace from pg_extension;` → conferir se `pg_trgm` já existe e em qual schema
   - `select id, public from storage.buckets;` → sem `resumes`
   - `select policyname from pg_policies where schemaname='storage';` → sem `resumes_objects_*`
   - `select rolname from pg_roles where rolname in ('anon','authenticated','service_role');` → existem
   Registre os resultados (sem dados pessoais) em `docs/evidence/`.
2. `supabase login` · `supabase link --project-ref rpmlfxwebnlxnwadyvle`.
3. `supabase db dump -f backup-before-orbijob.sql` (fora do repositório). Em projeto vazio o dump é só o esquema da plataforma; o rollback real é o teardown da seção 5.
4. `supabase migration list` → remoto sem versões, local com as 4. `supabase db push --dry-run` → deve listar exatamente as 4, nesta ordem.
5. `supabase db push`. Cada migration é enviada como um lote; **não presuma atomicidade por arquivo** — se o comando falhar, rode `supabase migration list` e a pré-checagem para ver até onde foi, e decida entre corrigir adiante ou executar o teardown (seção 5).
6. **Auditoria no projeto real:** executar `supabase/tests/01_audit.sql` no SQL Editor (remova a linha `\set`; só lê o catálogo) → deve terminar sem erro. Rodar os **Advisors** (Security e Performance) e registrar os avisos.
7. **Isolamento com Auth e Storage reais** (staging ou contas descartáveis), pela API e não pelo SQL Editor: criar 2 usuários; com o token de A tentar ler/gravar linhas de B via PostgREST (`curl` com a chave publishable), tentar ler/baixar/enviar para a pasta de B no bucket `resumes`, tentar enviar um não-PDF e um arquivo > 5 MiB, confirmar que a signed URL expira, e que o 11º currículo é recusado. Não executar `02_behaviour.sql`/`03_quotas.sql` no projeto real (inserem dados).
8. Configurar Auth (seção 4) e entregar ao app `SUPABASE_URL` + chave **publishable**.

## 4. Configurações no painel (não são migrations)
- Auth → Providers: e-mail habilitado; **Confirm email = ON**; desabilitar provedores não usados.
- Auth → URL Configuration: Site URL e Redirect URLs (web e `com.lucksrei.orbijob://login-callback`).
- Auth → Password: mínimo 8+ (o app exige 8); proteção contra senhas vazadas se o plano permitir.
- Auth → Rate limits: manter os padrões ou reduzir; considerar CAPTCHA antes de abrir ao público.
- API: expor apenas o schema `public`; desligar GraphQL se não usado.
- Chaves: **publishable** → app; **secret** → somente Cloudflare Worker (`wrangler secret put`); nunca no Flutter, no repositório ou em logs; rotacionar se vazar.
- Projetos gratuitos pausam por inatividade e não têm PITR; para uso real, considerar plano pago.

## 5. Reversão
Não há migrations "down" na pasta de migrations (a CLI as aplicaria). Para uma instalação nova e **sem dados a preservar**: esvaziar o bucket `resumes` pela Storage API/painel e executar, na máquina do proprietário,
`PGOPTIONS="-c orbijob.confirm_rollback=yes" psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/rollback/rollback_all.sql`.
O script recusa rodar sem a confirmação ou com objetos no bucket, remove tabelas, funções, policies de storage, bucket e `pg_trgm`, restaura os default privileges da plataforma e apaga as 4 versões de `schema_migrations`, permitindo reaplicar. Foi testado em ida-e-volta (aplicar → desfazer → verificar limpo → reaplicar). **Com dados de usuários, não usar:** restaure um dump ou escreva uma migration corretiva.

## 6. Idempotência dos procedimentos
- Pré-checagem, auditoria e dry-run: somente leitura, repetíveis.
- `db push`: a CLI registra cada versão em `supabase_migrations.schema_migrations` e não reaplica; reexecutar é seguro.
- Seção de Storage da migration 3: reexecutável (`on conflict`, `drop policy if exists`). Os demais comandos DDL **não** são reexecutáveis; um erro no meio exige verificar o estado (passo 5) antes de tentar de novo.
- Teardown: protegido por confirmação; `if exists` em todos os `drop`.

## 7. Exclusão de conta e limpeza de currículos
- Hoje: apagar o usuário em `auth.users` remove as **linhas** (`on delete cascade`), mas os **arquivos** em `resumes/<user_id>/` permanecem (SQL não remove arquivos do Storage). Apagar um perfil no app já remove os arquivos antes (corrigido e testado); apagar um currículo também.
- Desenho para a exclusão de conta (a implementar no Worker, com service role, **fora do app**): `DELETE /account` autenticado pelo JWT do próprio usuário → lista `resumes/<user_id>/` e remove os objetos pela Storage API → `auth.admin.deleteUser(user_id)`. Só depois as linhas somem por cascata. Falha na remoção dos arquivos aborta antes de apagar a conta.
- **Varredura de órfãos** (Worker agendado, service role): remove objetos do bucket sem linha correspondente em `resumes` com mais de 1 h (cobre upload sem linha, por falha ou abuso, já que o número de arquivos não é limitado por SQL — ver `20261011000000_quotas.sql`).
- Ambos exigem o Worker com segredos e **não estão implementados nem implantados**.

## 8. Riscos
| Risco | Mitigação |
|---|---|
| Diferença entre stub e plataforma (privilégios, dono de `storage.*`, extensão) | passos 1, 6 e 7 no projeto real; parar na primeira divergência |
| Falha parcial no `db push` | não presumir atomicidade; checar estado; teardown se vazio |
| Arquivos órfãos / uploads sem linha | varredura agendada (não implementada); cota de linhas; limites do bucket |
| Projeto gratuito pausa / sem PITR | plano pago antes de dados reais |
| Chave secret em lugar errado | app recusa iniciar com ela; gitleaks no CI; rotação |
| `can_redistribute` indevido | manter `false` até licença aprovada |
