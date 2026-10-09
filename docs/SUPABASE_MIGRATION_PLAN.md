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

**Fase A — Leitura** (`scripts/supabase/apply.sh read`, ou `inspect_readonly.sql` no SQL Editor)
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
