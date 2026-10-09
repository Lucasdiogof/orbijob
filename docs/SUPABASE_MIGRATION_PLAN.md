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
| 5 | `20261012000000_quota_upsert_fix.sql` | **corretiva** da 4: upsert de favorito já existente no teto passa (chave natural `job_key`) e inserts concorrentes não ultrapassam a cota (lock advisory por usuário/tabela). A 4 não foi reescrita, pois pode já ter sido aplicada | `create or replace function` e recriação de 1 trigger |
| 6 | `20261013000000_service_role_grants.sql` | **futura, ainda NÃO aplicada ao projeto real**: privilégios mínimos de tabela para o `service_role` (ver §13). Independente das demais | `revoke`/`grant` e `alter default privileges` (idempotente) |

Dependências: 2 usa objetos de 1; 3 usa `saved_jobs_visible_job`, `resumes` e a extensão de 1–2; 4 usa tabelas de 1. A ordem é a dos timestamps; a CLI aplica nessa ordem. Nenhuma migration usa `SECURITY DEFINER` nem cria trigger em `auth.users`; `anon` só recebe `SELECT` no catálogo.

## 2. O que já foi validado — e o que NÃO foi
**Validado em PostgreSQL 16 real, descartável, com um stub da plataforma** (`supabase/tests/run.sh`, job `supabase-sql` no CI):
- Cadeia das 5 migrations: sintaxe, dependências, ordem.
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

## 3. Execução remota (aguarda autorização específica) — fases A–E
Tudo é feito na máquina do proprietário (ou onde houver rede e CLI autenticada); segredos só em variável de ambiente local. Passo a passo de acesso e inspeção: **`docs/SUPABASE_OWNER_RUNBOOK.md`**. Scripts: `scripts/supabase/` (nunca rodam em CI; testados com binários falsos e modelos em memória, **não** contra o Supabase real).

**Fase A — Leitura** (`scripts/supabase/apply.sh read`, ou `inspect_readonly.sql` **e** `inspect_predeploy_details.sql` no SQL Editor; `backup` e `apply` exigem o veredito do `predeploy_check.mjs`)
1. Confirmar o projeto (`supabase/.temp/project-ref` e `DB_URL` devem conter `rpmlfxwebnlxnwadyvle`).
2. Inspeção somente leitura → `classify_state.mjs`: `EMPTY`, `CONSISTENT_PARTIAL`, `CONSISTENT_UP_TO_DATE` ou `DRIFT`.
3. `supabase migration list --linked` e Database → Migrations devem concordar com o histórico do JSON.
4. Objetos preexistentes (tabelas alheias, `resumes`, `pg_trgm`, triggers em `auth.users`, versões desconhecidas) aparecem como `DRIFT`/aviso: **parar e decidir**.

**Fase B — Segurança** (`apply.sh backup`)
1. Backup do schema (`supabase db dump --linked`, que exige Docker, ou `pg_dump --schema-only`); arquivo não vazio e `sha256` registrados. Abrir e conferir. Com dados de usuários, fazer também backup dos dados (painel/PITR em plano pago).
2. Comparação: `supabase db push --dry-run` precisa listar **exatamente** as migrations que a classificação diz estarem pendentes, e nenhuma já aplicada.
3. Recuperação de falha parcial: seção 5 (reversão) e seção 6 (idempotência). Em projeto vazio o caminho é o teardown; com dados, restaurar o backup ou migration corretiva.

**Fase C — Migração** (`ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle apply.sh apply`)
1. Exige: backup do passo B há ≤ 60 min, inspeção sem `DRIFT`, banco **idêntico** à inspeção (reinspeciona antes de escrever) e a variável de confirmação.
2. Um único `supabase db push` (a CLI aplica só as versões ausentes do histórico e registra cada uma; não repete as já aplicadas). Se falhar: **não repetir**; rodar `read` para ver até onde foi.
3. Reinspeciona e exige `CONSISTENT_UP_TO_DATE`; o "salvo-conduto" de backup é consumido (um backup autoriza uma aplicação).
4. A CLI não oferece verificar cada migration individualmente dentro de um mesmo `push`; a verificação é depois do lote. Para verificar uma a uma, aplicar em lotes movendo temporariamente os arquivos posteriores para fora de `supabase/migrations/` (opcional, mais lento).

**Fase D — Auditoria** (`apply.sh audit` + painel)
1. `supabase/tests/01_audit.sql` contra o projeto real (somente leitura): RLS, grants, funções, triggers, FKs indexadas, bucket e policies.
2. **Advisors** (Security e Performance): registrar avisos.
3. Conferir privilégios reais (`public_grants` e `default_privileges_public` do JSON `inspection-after.json`), Auth (confirmação de e-mail, redirects, limites) e Storage (bucket privado, 5 MiB, PDF).

**Fase E — Testes** (`node scripts/supabase/e2e_remote.mjs [--quotas]`)
Com 2 contas descartáveis e a chave **publishable**: Auth real; anônimo sem acesso; isolamento entre A e B (leitura, escrita, update/delete, inserção em nome do outro); upload de PDF na própria pasta; rejeição de não-PDF e de arquivo > 5 MiB; B sem acesso à pasta de A e bucket não público; signed URL válida e depois expirada; persistência após novo login; com `--quotas`, o 11º currículo é recusado. Limpa o que criou. Complementar manualmente: persistência de perfil e favoritos pelo app (`--dart-define` apontando ao projeto) depois de ligadas as telas.

## 4. Configurações no painel (não são migrations)
- Auth → Providers: e-mail habilitado; **Confirm email = ON**; desabilitar provedores não usados.
- Auth → URL Configuration: Site URL e Redirect URLs (web e `com.lucksrei.orbijob://login-callback`).
- Auth → Password: mínimo 8+ (o app exige 8); proteção contra senhas vazadas se o plano permitir.
- Auth → Rate limits: manter os padrões ou reduzir; considerar CAPTCHA antes de abrir ao público.
- API: expor apenas o schema `public`; desligar GraphQL se não usado.
- Chaves: **publishable** → app; **secret** → somente Cloudflare Worker (`wrangler secret put`); nunca no Flutter, no repositório ou em logs; rotacionar se vazar.
- Projetos gratuitos pausam por inatividade e não têm PITR; para uso real, considerar plano pago.

## 5. Reversão
Não há migrations "down" na pasta de migrations (a CLI as aplicaria). Para uma instalação nova e **sem dados a preservar**:
1. **Pela Storage API ou painel** (não por SQL): esvaziar e excluir o bucket `resumes`. A plataforma bloqueia `DELETE` direto em `storage.buckets`/`storage.objects` ("Direct deletion from storage tables is not allowed") e um delete por SQL deixaria os arquivos.
2. Executar, na máquina do proprietário: `PGOPTIONS="-c orbijob.confirm_rollback=yes" psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/rollback/rollback_all.sql`.
O script recusa rodar sem a confirmação ou enquanto o bucket existir; remove tabelas, funções, policies de storage e `pg_trgm`; restaura os default privileges da plataforma e apaga as 5 versões de `schema_migrations`, permitindo reaplicar. Foi testado em ida-e-volta localmente (aplicar → recusar com bucket → excluir bucket "pela API" → desfazer → verificar limpo → reaplicar), mas **nunca foi executado no Supabase real**. **Com dados de usuários, não usar:** restaure um dump ou escreva uma migration corretiva.

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

## 8. Incompatibilidades possíveis com o Supabase real (que os testes locais não detectam)
Auditoria das 5 migrations contra o comportamento documentado da plataforma. **Nenhum item foi verificado em projeto real.**
| # | Ponto | Por que o teste local não cobre | Como confirmar |
|---|---|---|---|
| 1 | `storage.protect_delete`: DELETE direto em tabelas de storage é bloqueado | o stub só imita o gatilho (a partir da documentação); já corrigiu o teardown | passo 7 + teardown em staging |
| 2 | Role `postgres` não é superusuário: precisa poder `insert` em `storage.buckets` e criar/dropar policies em `storage.objects` (dono: `supabase_storage_admin`) | stub roda como superusuário | falha explícita no `db push` (a migration 3 não degrada em silêncio) |
| 3 | `alter extension pg_trgm set schema extensions` exige ser dono da extensão e que `extensions` exista | idem | pré-checagem lista a extensão e seu schema; se já existir de outro dono, ajustar a migration antes |
| 4 | Default privileges: a plataforma concede por padrão (para objetos de `postgres`) `ALL` a `anon`/`authenticated`/`service_role` em tabelas **e funções**; a migration 2 revoga tabelas e as migrations 3–4 revogam as próprias funções | o stub só concede em tabelas | `01_audit.sql` remoto (verifica grants e execução de funções) |
| 5 | A CLI divide cada arquivo em instruções antes de enviar; blocos `do $$…$$` e funções com `$$` devem sobreviver ao divisor | `psql` envia o arquivo inteiro | `db push --dry-run` e, se falhar, mover o bloco para uma função/ajustar delimitadores |
| 6 | `REFERENCES auth.users(id)` exige o privilégio `REFERENCES` para `postgres` em `auth.users` (concedido na plataforma) | stub é superusuário | erro explícito no push |
| 7 | Versões do Postgres: testado em 16; o projeto pode estar em 15 ou 17 | só 16 | `select version()` na pré-checagem |
| 8 | ~~Gatilho de cota barrava upsert de favorito existente no teto e tinha corrida entre inserts concorrentes~~ — **corrigido na migration 5**; testes de regressão, de concorrência (duas sessões) e de caminho de atualização (banco que já tinha 1–4) | — | concorrência real só é provada em Postgres real; repetir o teste de quotas no passo 7 |
| 8b | Cota por trigger: o recontar só enxerga linhas já confirmadas em READ COMMITTED (padrão do PostgREST). Em transação `REPEATABLE READ`/`SERIALIZABLE` (não usada pelo app) o limite pode ser ultrapassado — medido: 999 + 2 inserts concorrentes = 1001. Lock é por usuário (não por tabela): com lock por tabela, transações do mesmo usuário em tabelas de cota em ordem oposta deram `deadlock detected` | medido em Postgres 16 local | aceito e documentado; teste de regressão de deadlock em `05_concurrency.sh` |
| 9 | A CLI divide cada arquivo em instruções; comentários `--` com apóstrofo (migrations 1–4 têm; a 5 não) podem confundir divisores ingênuos. `db push --dry-run` não faz parse | `psql` aceita; a CLI é a incógnita | se o `push` falhar com erro de sintaxe, colar o arquivo no SQL Editor e registrar com `supabase migration repair --status applied <versão>` |
| 10 | Auth real (PKCE, confirmação por e-mail, limites de taxa), Storage API (limites de MIME/tamanho, signed URL), Advisors e exposição do PostgREST | não existem no stub | passos 6–7 |

## 9. Riscos
| Risco | Mitigação |
|---|---|
| Diferença entre stub e plataforma (seção 8) | passos 1, 6 e 7 no projeto real; parar na primeira divergência |
| Falha parcial no `db push` | não presumir atomicidade; checar estado; teardown se vazio |
| Arquivos órfãos / uploads sem linha | varredura agendada (não implementada); cota de linhas; limites do bucket |
| Projeto gratuito pausa / sem PITR | plano pago antes de dados reais |
| Chave secret em lugar errado | app recusa iniciar com ela; gitleaks no CI; rotação |
| `can_redistribute` indevido | manter `false` até licença aprovada |

## 10. Revisão da integração Flutter (sem ligar telas a serviços remotos)
Inspecionada em 2026-10-09; nenhuma tela usa dados remotos (apenas entrar/conta no Perfil, que só aparece com configuração).
| Item | Estado |
|---|---|
| Inicialização | `initSupabase(AppConfig)` só roda com `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`; sem eles o app roda sem contas. Configuração inválida (http, chave secret/`service_role`) lança `StateError` no início |
| Chaves | só a *publishable*; teste varre `app/lib` por `service_role`; `e2e_remote.mjs` também recusa chaves privilegiadas |
| Sessão | Keystore/Keychain via `flutter_secure_storage` (mobile); web usa o armazenamento do navegador (limite da plataforma). PKCE |
| Erros | `mapAuthError` → `AuthFailureKind` tipado, mensagens PT/EN/ES, sem texto do servidor |
| Logout | `signOut()` com escopo local (limpa a sessão persistida); sessões em outros dispositivos continuam |
| Repositórios / DI | 7 repositórios Supabase registrados só com configuração; testados contra HTTP simulado (caminhos, filtros, ordem, `user_id`) |
| **Lacuna: callbacks de e-mail no mobile** | não há esquema de deep link (`com.lucksrei.orbijob://login-callback`) em `AndroidManifest.xml`/`Info.plist` nem `emailRedirectTo` em `signUp`/`resetPasswordForEmail`: o link de confirmação/redefinição abre a *Site URL* (web), não o app |
| **Lacuna: redefinição de senha** | o app envia o e-mail, mas não há tela para definir a nova senha ao voltar do link |
| Lacuna: exclusão de conta | ver seção 7 |
| Não verificado | PKCE e armazenamento seguro em aparelho real; comportamento do `onAuthStateChange` com token expirado offline |
Essas lacunas não bloqueiam aplicar as migrations; bloqueiam abrir o login ao público.

## 11. Classificação dos testes (o que cada um prova)
| Teste | Natureza | O que prova | O que NÃO prova |
|---|---|---|---|
| `flutter analyze`/`test` (182), build web | **local** | código do app, repositórios contra `SupabaseClient` com HTTP simulado | comportamento do Supabase hospedado |
| Worker `tsc` + 58 testes (inclui RLS em PGlite) | **local** | conectores, retry/timeout, RLS das migrations 1–2 em Postgres embutido | idem |
| `supabase/tests/run.sh` em PostgreSQL **16 e 17** reais (+ **stub** de Auth/Storage com aproximação de `rls_auto_enable`/`ensure_rls`): auditoria de catálogo, isolamento entre usuários em 12 tabelas + `storage.objects`, cotas, concorrência (2 sessões), deadlock, caminho de atualização 1–4 → 5, teardown ida-e-volta, inspeção real sobre a cadeia | **local, motor real, plataforma simulada** | SQL, RLS, triggers, locks, grants e ordem das 5 migrations em PostgreSQL 16 | Auth real, Storage API, dono/privilégios do role `postgres` do Supabase, divisor de instruções da CLI, versões 15/17 |
| `classify_state.test.mjs` (21), `predeploy_check.test.mjs` (28), `predeploy_sql_lint.test.mjs` (5), `e2e_remote.test.mjs` (8) | **simulado** (catálogos gerados do stub; modelo em memória da API) | lógica do classificador e do script e2e; cada falha injetada é detectada | que a API real responda como o modelo |
| `apply.test.sh` (30) | **simulado** (binários falsos) | travas do `apply.sh`: nenhum `db push` sem as condições; uma única execução; gate gasto após falha | comportamento da CLI/rede reais; atomicidade do `db push` (**não verificada**) |
| gitleaks | local | sem segredos no histórico e na árvore | — |
| Fase E (`e2e_remote.mjs` contra o projeto) | **real — NÃO executada** | (futuro) Auth, RLS via API, Storage, signed URL, cotas | — |

## 12. Primeira inspeção real do projeto (2026-10-09T03:02:11Z) e auditoria pré-migração
Fonte: relato do proprietário sobre o resultado de `scripts/supabase/inspect_readonly.sql` no SQL Editor (o JSON bruto não foi compartilhado; `scripts/supabase/fixtures/owner-reported-2026-10-09.json` é uma **reconstrução** a partir desse relato, usada só para testar o classificador).

### 12.1 Fatos informados
PostgreSQL **17.11**, banco `postgres`, consulta como `postgres`. Schemas: auth, extensions, graphql, graphql_public, pgbouncer, public, realtime, storage, vault. `public`: 0 tabelas, 0 policies, 0 triggers, nenhum grant. Storage: 0 buckets, 0 policies. Triggers de usuário em `auth.users`: 0. `migration_versions: null`. Extensões instaladas: pg_stat_statements, pgcrypto, plpgsql, supabase_vault, uuid-ossp (**`pg_trgm` não instalada**). Existe `public.rls_auto_enable` (SECURITY DEFINER, executável por `anon` e `authenticated`). Há default privileges para `postgres` e `supabase_admin`.

### 12.2 Classificação formal: `EMPTY` (com exceções e bloqueios)
`node scripts/supabase/classify_state.mjs <arquivo>` →
- `state: EMPTY`, `pending`: as 5 migrations.
- **Por que `migration_versions: null` não é tomada como prova isolada:** o coletor devolve `null` quando `supabase_migrations.schema_migrations` não existe. Isso por si só não diz que nada foi aplicado (migrations poderiam ter sido aplicadas por SQL sem registro). O estado `EMPTY` decorre da **combinação**: schema `supabase_migrations` ausente **e** 0 tabelas/policies/triggers/buckets/policies de storage/objetos de qualquer das 5 migrations. Se existissem objetos do OrbiJob com histórico `null`, o classificador devolve `DRIFT` (há teste).
- **Exceção registrada:** `public.rls_auto_enable` (função de plataforma conhecida por nome). O classificador **não** a ignora: lista-a em `exception:` e emite `BLOCKER-FOR-APPLY` enquanto não houver o detalhe (`returns`, vínculo a event trigger, definição). Qualquer *outra* função desconhecida em `public` é `DRIFT`.
- O formato real do SQL Editor (array com `inspection` como string JSON) é aceito (teste dedicado).

### 12.3 `public.rls_auto_enable` — o que se sabe e o que não se sabe
**Medido localmente (PostgreSQL 16 e 17, função de teste que imita o comportamento descrito):** se uma função `RETURNS event_trigger` for `SECURITY DEFINER` e tiver `EXECUTE` para `anon`/`authenticated`, chamá-la como `select public.rls_auto_enable()` falha ("só pode ser chamada como event trigger"); revogar o `EXECUTE` **não** impede o event trigger de disparar (o privilégio é verificado na criação do event trigger). Logo, o `EXECUTE` aberto não permite que um usuário comum execute a lógica administrativa.
**Hipótese a confirmar (não provada):** é a função do recurso "automatically enable RLS" da plataforma, ligada a um event trigger (`ensure_rls`) em `CREATE TABLE`, que executa `alter table … enable row level security` em tabelas novas de `public`. **Não assumo que seja segura nem maliciosa**: proprietário, linguagem, assinatura, `search_path`, corpo, vínculo a event trigger, origem (extensão ou não) e comentário só saem de `inspect_predeploy_details.sql`. `predeploy_check.mjs` só aceita a função automaticamente se: retorna `event_trigger`; está ligada a ≥1 event trigger; tem `search_path` fixo; e **todo** SQL dinâmico do corpo é `alter table … enable row level security` (sem drop/grant/insert/create/etc.). Caso contrário o item fica `UNKNOWN` e **bloqueia**; o corpo é impresso para leitura humana e o proprietário pode aceitá-lo explicitamente (`ORBIJOB_PREDEPLOY_ACK=function-rls_auto_enable`).
**Impacto nas migrations:** nenhum conflito (RLS é habilitada duas vezes; idempotente). **Impacto na nossa auditoria:** `01_audit.sql` falharia à toa no projeto real ("SECURITY DEFINER em public"); corrigido para tolerar *somente* funções que retornam `event_trigger` **e** estão ligadas a um event trigger (listadas como `AUDIT-NOTE`), mantendo falha para qualquer outra função SECURITY DEFINER ou executável pelas roles de API. Nada foi removido, substituído ou revogado no projeto.

### 12.4 `pg_trgm`
Não instalada. Migration 1 executa `create extension if not exists pg_trgm;` **sem** `with schema`: a extensão vai para o primeiro schema do `search_path` do role em que ele tenha CREATE (esperado `public`; o `search_path` efetivo e o schema escolhido saem do detalhe pré-deploy). Migration 3 executa `alter extension pg_trgm set schema extensions;` (e `create schema if not exists extensions`). Exige: ser **dono** da extensão (será `postgres`, que a cria) e ter **CREATE no schema `extensions`**. A extensão é *trusted* e relocável; a propriedade não é problema, o privilégio no schema `extensions` **é a incógnita** — se faltar, o erro acontece no início da migration 3, depois de 1 e 2 aplicadas (estado parcial recuperável por teardown, pois o projeto está vazio). O item `extensions-schema` do verificador bloqueia antes disso. Nenhuma migration "espera que ela já exista". Local: PostgreSQL 16 e 17 reais passam, o que **não** prova o privilégio no projeto hospedado.

### 12.5 Storage
Bucket privado `resumes` é criado por `insert into storage.buckets … on conflict do update` (migration 3) e 4 policies em `storage.objects`. Exigem, no projeto real: `INSERT`/`UPDATE` em `storage.buckets`; ser dono (ou membro do dono, `supabase_storage_admin`) de `storage.objects` para `create policy`; colunas `file_size_limit` e `allowed_mime_types`; `storage.foldername(text)`. Todos são verificados por `inspect_predeploy_details.sql` + `predeploy_check.mjs`. **Se `postgres` não puder criar policies em `storage.objects`**, a migration 3 falha; contingência: criar bucket e policies pelo painel/Storage API e dividir a migration (a decidir com a evidência). Upload de PDF, limite de 5 MiB, isolamento e signed URLs só serão provados pela Fase E (`e2e_remote.mjs`) no projeto real.

### 12.6 Default privileges e exposição
Relatado: defaults amplos para `postgres` e `supabase_admin`. As migrations rodam como `postgres`: (a) tabelas novas nascem com `ALL` para `anon/authenticated/service_role`; a migration 2 faz `revoke all on all tables … from anon, authenticated` e concede só o necessário; entre as migrations 1 e 2 as tabelas já têm RLS ligada (própria e pelo `ensure_rls`) e `anon` só tem a policy de leitura do catálogo (sem dados); (b) funções novas nascem executáveis por PUBLIC/anon/authenticated; **cada** função do OrbiJob faz `revoke all … from public, anon, authenticated` logo após criada (auditado); (c) não há sequences (ids `uuid`); (d) `alter default privileges … revoke` da migration 2 só vale para objetos futuros de `postgres`; o OrbiJob não cria objetos como `supabase_admin`. O detalhe decodificado (`default_privileges_public`) vai no JSON de pré-deploy.

### 12.7 Quotas (PostgreSQL 16 e 17 locais)
Lock advisory por usuário (sem deadlock entre tabelas, testado), upsert no teto (existente passa, novo é recusado), concorrência de 2 sessões (total 1000), sem recursão de RLS (triggers `SECURITY INVOKER`), `READ COMMITTED` garantido; `REPEATABLE READ` pode exceder (999 + 2 = 1001, medido; o app não usa).

### 12.8 Matriz PostgreSQL
A suíte SQL passa em **PostgreSQL 16.15 e 17.10** (binários reais; 17.10 via pacote `@embedded-postgres`, o projeto roda 17.11) e o CI roda a matriz 16/17. Isto **não** reproduz privilégios, roles, extensões, Storage, Auth nem event triggers da plataforma: usamos um stub (incluindo uma aproximação de `rls_auto_enable`/`ensure_rls`).

### 12.9 Decisão técnica: **BLOCKED** (para aplicar)
Motivos críticos ainda sem evidência: (1) privilégio de `postgres` em `extensions` (migration 3), (2) privilégios/propriedade em `storage.buckets`/`storage.objects` (migration 3), (3) `REFERENCES` em `auth.users` (migrations 1 e 3), (4) definição e vínculo reais de `rls_auto_enable`, (5) event triggers adicionais desconhecidos. **Destrava:** executar **uma única** consulta de leitura, `scripts/supabase/inspect_predeploy_details.sql`, e passar o JSON por `predeploy_check.mjs`. Veredito `PRECHECK_OK` é condição necessária, não suficiente (ainda há backup, dry-run, confirmação específica e Fase D/E).

### 12.10 Defeito achado no projeto real: `inspect_predeploy_details.sql` (corrigido)
**Sintoma (PostgreSQL 17.11 hospedado):** `ERROR: 3F000: schema "$user" does not exist`.
**Causa raiz:** o campo `pg_trgm.create_without_schema_would_use` quebrava o `search_path` em *texto* e chamava `has_schema_privilege(current_user, s, 'CREATE')` com esse texto. O filtro `s <> '$user'` não protege: o PostgreSQL não garante a ordem de avaliação das condições do `WHERE`, então a função pode receber `"$user"` (ou qualquer entrada que não seja um schema). Havia ainda um segundo defeito: sem `ORDER BY`, o `limit 1` devolvia um schema arbitrário (com `extensions, public` o SQL antigo respondia `public`).
**Reprodução local:** com PostgreSQL 16.15 e 17.10 o SQL antigo **não** falhou com `"$user"` (o plano local por acaso avaliou o filtro antes; nem forçando os parâmetros do planner consegui reproduzir a ordem do ambiente hospedado). Reproduz de forma determinística a mesma classe de erro com uma entrada inexistente, `set search_path = nonexistent, public` → `ERROR: schema "nonexistent" does not exist`, e o mecanismo puro (`has_schema_privilege(current_user, '$user', 'CREATE')` → 3F000). O arquivo original completo foi guardado em `scripts/supabase/fixtures/old_inspect_predeploy_details.sql` só como fixture de regressão. **Não afirmo que a correção foi testada no Supabase hospedado:** só o proprietário pode confirmar rodando a versão nova.
**Correção:** o `search_path` é resolvido pelo servidor com `current_schemas(false)` (expande `"$user"`, descarta schemas inexistentes ou sem USAGE, mantém a ordem) com `WITH ORDINALITY`, ligado a `pg_namespace`; as funções de privilégio recebem sempre `n.oid`, nunca texto. Novos campos: `search_path_schemas` (posição, nome, dono, USAGE/CREATE do usuário atual), `pg_trgm.create_without_schema_would_use` (o **primeiro** schema, que é o que `CREATE EXTENSION` sem `SCHEMA` usa), `..._can_create` e `first_creatable_schema_in_path`. O verificador reprova (`FAIL`) se o primeiro schema do caminho não permitir CREATE — o PostgreSQL não "cai" para o próximo — e trata documentos no formato antigo como `UNKNOWN`.
**Revisão do restante do arquivo:** nomes de roles viraram OIDs resolvidos por `pg_roles` (NULL se o role não existir, sem erro); `'auth.users'::regclass` e `'storage'::regnamespace` (constantes dobradas em tempo de planejamento, que um `CASE` não protege) viraram `to_regclass`/lookup em `pg_namespace`; colunas de `storage.buckets` vêm de `pg_attribute` (não dependem de privilégio de coluna); erros reais de permissão **não** são mascarados (testado). `inspect_readonly.sql` recebeu a mesma troca do `::regclass`.
**Testes:** `supabase/tests/07_predeploy_search_path.sh` (PostgreSQL 16 e 17; roda dentro da suíte SQL e do CI) cobre `"$user"`, ordem, schemas inexistentes, nomes entre aspas/espaço/vírgula/aspas internas, schema sem CREATE, caminho sem schemas, erro de permissão real e compatibilidade com `predeploy_check.mjs`; `predeploy_sql_lint.test.mjs` impede, por análise estática, texto como objeto de `has_*_privilege`, role literal e casts `::regclass` de objetos que podem não existir (falha no arquivo antigo, passa no novo).

### 12.11 Segundo erro no SQL Editor: `42601: syntax error at end of input`
Depois da correção do `search_path`, o proprietário recebeu `42601: syntax error at end of input` (`LINE 0:`). O arquivo completo é válido (rodou em PostgreSQL 16 e 17 por `psql`), então a causa está no caminho de transporte até o banco — texto incompleto enviado pelo editor (seleção parcial, colagem cortada ou divisão do script em vários comandos); **não foi reproduzido localmente e a causa exata não está confirmada**. Mitigação: `scripts/supabase/build_paste_variants.mjs` gera `inspect_*.paste.sql`: a mesma consulta como **um único comando**, sem comentários, linhas em branco nem `begin`/`rollback`, com um único `;` final. Testes garantem que o arquivo está atualizado, que tem uma só instrução e que devolve o mesmo documento que o arquivo completo (PostgreSQL 16 e 17).

### 12.12 Segunda inspeção real (detalhes pré-deploy, 2026-10-09)

A consulta única rodou sem erro no SQL Editor (PostgreSQL 17.11, conectado como `postgres`). Resultado de `predeploy_check`: 20 PASS e 1 FAIL.

- `public.rls_auto_enable`: lida a definição real. Função de event trigger, ligada a `ensure_rls`, `SECURITY DEFINER` com `search_path=pg_catalog`, só executa `alter table if exists … enable row level security` em `public`. O EXECUTE para anon/authenticated não permite chamá-la (event triggers não são chamáveis). Aceita; compatível com as migrations, que já habilitam RLS.
- pg_trgm entra em `public` (primeiro schema criável do caminho) e a migration 3 move para `extensions`, onde `postgres` tem CREATE. OK.
- **Pendência única**: `postgres` não é dono nem membro de `supabase_storage_admin` (dono de `storage.objects`), então `CREATE POLICY` em `storage.objects` (migration 3) não está provado. `postgres` é membro de `supabase_privileged_role` (supautils), que na plataforma costuma permitir isso, mas não há evidência. O verificador continua FAIL de propósito. Evidência somente leitura: `scripts/supabase/inspect_storage_policy_evidence.paste.sql`.
- Decisão: **BLOCKED** até essa evidência (ou autorização específica para um teste transacional com ROLLBACK).

### 12.13 Evidência de `CREATE POLICY` em `storage.objects` (2026-10-09)

Consulta somente leitura devolveu: `postgres` é membro de `supabase_privileged_role`; `supautils.privileged_role = supabase_privileged_role`; `supautils.policy_grants` concede a `postgres` as tabelas `storage.objects` (e `storage.buckets`, `auth.users` etc.); `postgres` tem todos os privilégios com grant option em `storage.objects`; `pg_trgm` consta em `supautils.privileged_extensions`; ainda não há policies em `storage`. Isso é evidência de configuração da plataforma, não de execução: o `CREATE POLICY` em si só será provado na aplicação real (Fase D) e no e2e (Fase E).

`predeploy_check.mjs --evidence=<arquivo>` (ou `ORBIJOB_STORAGE_EVIDENCE` no `apply.sh`) aceita `storage-policies` quando há essa evidência. Com ela, o resultado sobre a inspeção real é **PRECHECK_OK**. Isso continua sendo condição necessária, não suficiente: faltam backup, dry-run e autorização específica. Contingência se o `CREATE POLICY` falhar na migration 3: a migration roda em transação e é revertida inteira; policies/bucket seriam criados pelo painel e a migration dividida.


## 13. `service_role`: o que ele realmente tem no projeto real (2026-10-09) e a migration 6

**Achado (inspeção real após as migrations 1–5):** `service_role` só tem `REFERENCES`, `TRIGGER` e `TRUNCATE` nas 16 tabelas de `public` (default `{service_role=Dxtm/postgres}` para objetos criados por `postgres`). `BYPASSRLS` ignora as policies, mas **não é privilégio de tabela**: uma chamada do Worker com a chave de serviço receberia `permission denied`. Nenhuma migration anterior menciona o papel, e o stub local concedia `ALL` por padrão, por isso os testes não viram o problema. O stub agora reproduz os defaults reais (`truncate, references, trigger`; o `maintain` do PostgreSQL 17 só existe no real) e `02_behaviour.sql` deixou de assumir que `service_role` lê `applications`.

**Migration 6 (`20261013000000_service_role_grants.sql`, não aplicada, PR separado):** revoga tudo de `service_role` em `public`, zera o default para tabelas futuras e concede só o necessário:

| Operação do backend | Privilégio |
|---|---|
| Ingestão e sincronização de fontes | `job_sources` select/insert/update; `jobs` select/insert/update; `sync_runs` select/insert/update |
| Manutenção do catálogo (dedupe, remoção de vagas velhas) | `jobs` e `job_clusters` também delete |
| Varredura de currículos órfãos | `resumes` select (os arquivos saem pela Storage API) |
| Exclusão de conta | **nenhum privilégio de tabela**: `auth.admin.deleteUser` cascateia pelas FKs e os arquivos saem pela Storage API |

Não concede: `ALL`, escrita em tabelas de usuário, delete em `job_sources`/`sync_runs`, `EXECUTE` em funções, `TRUNCATE`/`REFERENCES`/`TRIGGER`. O app Flutter nunca usa esse papel. Testes: `08_service_role.sql` (matriz exata de privilégios em todas as tabelas, sem `EXECUTE`, tabela futura nasce sem privilégio, operações que funcionam e que falham, em PostgreSQL 16 e 17); três mutantes (sem a migration, `grant all`, sem delete em `job_clusters`) são detectados. O classificador passou a reconhecer a migration 6 pela assinatura do grant e a tratar o projeto real como `CONSISTENT_PARTIAL` com ela pendente. O `rollback_all.sql` restaura os defaults reais da plataforma, não `ALL`. **A aplicação depende de autorização expressa; o procedimento é o mesmo (`db push --dry-run`, depois `db push`).**
