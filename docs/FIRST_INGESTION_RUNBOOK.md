# Primeira ingestão real (Jobicy): sequência controlada

**Nada deste documento foi executado.** Cada passo que altera algo fora do repositório (Supabase, Cloudflare) exige **autorização explícita e separada** do proprietário. Passos marcados **[LOCAL]** só mexem no código do repositório.

Estado de partida (2026-10-10):

| Peça | Estado |
|---|---|
| Conector Jobicy, pipeline `runSync`, `SupabaseJobStore` (PR #50) | pronto e testado; CI verde |
| Flutter lendo `public.jobs` (PR #51) | pronto e testado; CI verde, inclusive contra PostgREST real |
| Migration 6 (`service_role_grants`) | no repositório, **não aplicada** no Supabase |
| Linha `jobicy` em `job_sources` | **não existe** |
| **Ponto de entrada do Worker** (`scheduled`) e `wrangler.toml` | **não existem**: `worker/` é uma biblioteca, não um Worker publicável |
| Segredos do Worker, Cron, deploy | nada configurado |
| Catálogo hospedado | vazio |

## Sequência

### 1. Integrar o PR #50 · quem: proprietário (botão Merge)
Pré-condição: todos os checks verdes. Conferir o CI da `main` depois do merge.

### 2. Integrar o PR #51 · quem: proprietário
Depois do #50. O #51 não depende de código do #50 (lê só as tabelas), mas só faz sentido com o catálogo preenchido. Conferir o CI da `main`.

### 3. **[LOCAL] Escrever o ponto de entrada do Worker** · quem: assistente, em PR próprio, após autorização
Lacuna encontrada na auditoria: sem isso não há o que publicar. Escopo mínimo:
* `worker/src/index.ts` com `export default { scheduled }`, **sem rota HTTP pública** (`fetch` responde 404). Lê `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` do ambiente, monta `jobicyConnector(fetch)` + `SupabaseJobStore` e chama `runSync` com `scope: ''`. Registra só contagens (o `runSync` já registra em `sync_runs`).
* `worker/wrangler.toml` com nome, data de compatibilidade e `[triggers] crons`; **sem** segredos.
* Testes com `wrangler dev --test-scheduled` e uma fonte Jobicy simulada. **Sem deploy.**

### 4. Revisar e autorizar a migration 6 · quem: proprietário
Arquivo: `supabase/migrations/20261013000000_service_role_grants.sql`. O que ela faz (idempotente: revoga e concede):
* `service_role` passa a ter só: `job_sources` (select, insert, update), `jobs` e `job_clusters` (select, insert, update, delete), `sync_runs` (select, insert, update) e `resumes` (select). Nada em dados de usuário, nada de TRUNCATE/REFERENCES/TRIGGER.
* Evidência: `supabase/tests/08_service_role.sql` (CI `supabase-sql` 16 e 17) e `worker/test/live/postgrest.contract.test.ts` (CI `worker-postgrest`: o `service_role` real **não** lê `saved_jobs`/`professional_profiles` e não apaga `job_sources`).
* Resposta esperada do proprietário: "autorizo aplicar a migration 6 no projeto `rpmlfxwebnlxnwadyvle`".

### 5. Aplicar a migration 6 com pré-check e backup · quem: proprietário, no computador dele
Usa as travas já existentes (`scripts/supabase/apply.sh`), que só aplicam as migrations **pendentes**:
1. `scripts/supabase/apply.sh read`: inspeção somente leitura. Esperado: estado `CONSISTENT_PARTIAL` com **apenas** `20261013000000_service_role_grants` pendente. Qualquer `DRIFT`: parar.
2. `scripts/supabase/apply.sh backup`: backup do schema com `sha256` registrado. **Atenção:** o plano gratuito do Supabase não tem recuperação pontual (PITR) e pausa por inatividade. Hoje o banco só tem contas de teste e nenhum catálogo, então o risco é baixo, mas é por isso que o backup do schema importa.
3. `ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle scripts/supabase/apply.sh apply`.
4. `scripts/supabase/apply.sh audit`, e conferir os privilégios (somente leitura, no SQL Editor):
   ```sql
   select table_name, string_agg(privilege_type, ', ' order by privilege_type) as privileges
   from information_schema.role_table_grants
   where grantee = 'service_role' and table_schema = 'public'
   group by table_name order by table_name;
   ```
   Esperado: `job_clusters` (DELETE, INSERT, SELECT, UPDATE), `job_sources` (INSERT, SELECT, UPDATE), `jobs` (DELETE, INSERT, SELECT, UPDATE), `resumes` (SELECT), `sync_runs` (INSERT, SELECT, UPDATE). Nenhuma outra tabela.
* **Desfazer, se necessário:** só o `service_role` é afetado, e ele ainda não é usado por nada. O estado anterior era "sem privilégio de tabela": `revoke all on all tables in schema public from service_role;`.

### 6. Criar a fonte Jobicy no banco · quem: proprietário, no SQL Editor (ou o assistente, se autorizado)
A decisão `can_redistribute = true` é do proprietário e se apoia no texto de uso justo do README do Jobicy (ver `JOBICY_INGESTION.md`: não é um contrato; volume fora do normal exige falar com a fonte).
```sql
insert into public.job_sources (id, status, attribution, can_redistribute)
values ('jobicy', 'CONDITIONAL', 'Remote jobs via Jobicy (https://jobicy.com)', true)
on conflict (id) do update set attribution = excluded.attribution;
```
Verificar: `select id, status, can_redistribute from public.job_sources;` deve mostrar só `jobicy`.
**Interruptor de emergência (reversível, imediato):** `update public.job_sources set can_redistribute = false where id = 'jobicy';` esconde todas as vagas do Jobicy do app, sem apagar nada.

### 7. Configurar o segredo no Worker · quem: proprietário
* Em Supabase → Project Settings → API Keys, usar a chave **secreta** (`sb_secret_…`), nunca a publishable. Ela vai **só no Worker**, **nunca** no Flutter, no repositório, em log ou no chat.
* `wrangler secret put SUPABASE_SERVICE_ROLE_KEY` e `wrangler secret put SUPABASE_URL` (comando interativo, o valor é digitado no terminal do proprietário).
* O `SupabaseJobStore` envia chaves `sb_secret_…` **somente** no cabeçalho `apikey`, como a documentação do Supabase manda, e só aceita URL `https`.

### 8. Configurar o agendamento · quem: proprietário aprova, assistente prepara o `wrangler.toml`
* A fonte permite **no máximo uma passada de sincronização por hora**; o README sugere que "algumas passadas por dia" bastam. Valor inicial recomendado: a cada 6 horas (`17 */6 * * *`).
* O cron só passa a existir no `wrangler deploy`. **Deploy exige autorização separada.**

### 9. Executar uma sincronização controlada · quem: proprietário autoriza; observar com `wrangler tail`
* Em produção um `scheduled` não pode ser chamado por HTTP (de propósito). Para a primeira execução: ajustar temporariamente o cron para um minuto próximo, publicar, observar `wrangler tail`, e **voltar ao valor definitivo** logo depois.
* Critério de parada: qualquer 401/403 nos logs, `sync_runs.status = 'failed'`, ou dados claramente errados.

### 10. Conferir os registros reais · somente leitura
```sql
select status, fetched, upserted, duplicates, closed, http_errors, error_class, started_at
from public.sync_runs order by started_at desc limit 3;

select status, count(*) from public.jobs where source_id = 'jobicy' group by status;

select external_id, title, company, work_mode, country, geo_restrictions, salary_min, salary_currency, salary_period, published_at, original_url
from public.jobs where source_id = 'jobicy' order by published_at desc nulls last limit 10;
```
Conferir: `sync_runs` com `ok`; links em `jobicy.com`; salários só quando há moeda e período; nenhum HTML na descrição; nenhuma vaga de outra fonte.

### 11. Validar no Flutter · quem: proprietário, com conta de teste
1. Abrir o app (`scripts\windows\run_orbijob_web.ps1`) → Explorar → **Ver vagas recentes**. Deve aparecer a lista com **"Fonte: Jobicy"**.
2. Abrir uma vaga: descrição, elegibilidade, botão **Abrir anúncio original** (deve abrir a página do Jobicy).
3. Salvar nos favoritos → F5 → aba Favoritos (a vaga continua).
4. Sair e entrar com outra conta: os favoritos da primeira **não** aparecem.
5. Filtros: modalidade, publicação, só com salário, país.

## O que pode dar errado e como se percebe

| Sintoma | Provável causa | Ação |
|---|---|---|
| `permission denied` / 401 / 403 no Worker | migration 6 não aplicada, ou chave errada | parar; conferir o passo 5.4 e o segredo |
| `sync_runs.status = 'failed'`, `error_class = 'http_429'` | limite da fonte | espaçar o cron |
| Explorar mostra "Nenhuma fonte integrada" | linha `jobicy` ausente ou `can_redistribute = false` | passo 6 |
| Explorar mostra "Nenhuma vaga" | catálogo vazio (ingestão ainda não rodou) | passos 9–10 |
| Vagas fechadas aparecendo | status não consultado | conferir `closed` em `sync_runs` e o endpoint de status |

## Compromissos com a fonte (Jobicy)
Atribuição visível ("Fonte: Jobicy") e link para a página canônica; nunca apresentar as vagas como nossas; uma passada por hora no máximo; descrições reduzidas a texto simples; para grande volume ou uso diferente do normal, contatar o Jobicy.
