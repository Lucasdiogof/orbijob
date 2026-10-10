# Primeira ingestão real (Jobicy): sequência controlada

**Nada deste documento foi executado.** Cada passo que altera algo fora do repositório (Supabase, Cloudflare) exige **autorização explícita e separada** do proprietário. Passos marcados **[LOCAL]** só mexem no código do repositório.

Estado de partida (2026-10-10, depois da Fase 5.5):

| Peça | Estado |
|---|---|
| Conector Jobicy, pipeline `runSync`, `SupabaseJobStore` (PR #50) | **mergeado** (`a0007a7`); testado, inclusive contra PostgREST real |
| Flutter lendo `public.jobs` (PR #51) | **mergeado** (`4da84f9`); testado, inclusive contra PostgREST real |
| Migration 6 (`service_role_grants`) | no repositório, **não aplicada** no Supabase |
| Linha `jobicy` em `job_sources` | **não existe** |
| **Ponto de entrada do Worker** (`scheduled`) e `wrangler.toml` | **feitos na Fase 5.5** (PR `feat/jobicy-worker-entrypoint`, ver [`JOBICY_WORKER.md`](JOBICY_WORKER.md)); testados em workerd local e no CI; **não publicados** |
| Segredos do Worker, Cron, deploy | nada configurado |
| Catálogo hospedado | vazio |

## Checklist de ativação (nada abaixo foi feito; cada item é uma autorização separada)

- [ ] **0. Plano Workers Paid** na conta Cloudflare (o gratuito não suporta o cron: 10 ms de CPU, 50 subrequests).
- [ ] **1. Backup e inspeção atualizada** do Supabase (`apply.sh read` e `apply.sh backup`).
- [ ] **2. Revisão da migration 6** pelo proprietário (`20261013000000_service_role_grants.sql`).
- [ ] **3. Autorização separada** para aplicá-la ("autorizo aplicar a migration 6 no projeto `rpmlfxwebnlxnwadyvle`") e aplicação (`apply.sh apply`).
- [ ] **4. Auditoria depois da aplicação** (`apply.sh audit` + consulta dos privilégios do `service_role`).
- [ ] **5. Criar a fonte `jobicy`** em `job_sources` (SQL do passo 6 abaixo) com `can_redistribute` decidido pelo proprietário.
- [ ] **6. Segredos no Cloudflare** com `wrangler secret put` (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`), digitados no terminal do proprietário.
- [ ] **7. Revisão dos direitos de uso e da atribuição:** reler o "Fair Use" do README do Jobicy no dia; conferir que o app mostra "Fonte: Jobicy" e o link para o anúncio original (já implementado); decidir se o volume previsto exige contato com a fonte.
- [ ] **8. Deploy do Worker** (`wrangler deploy` em `worker/`). O cron `0 */6 * * *` passa a existir aqui.
- [ ] **9. Primeira sincronização controlada** (cron temporário e `wrangler tail`; voltar ao cron definitivo).
- [ ] **10. Verificar as vagas reais no banco** (consultas do passo 10 abaixo).
- [ ] **11. Teste no Flutter com vagas reais** (Explorar → "Ver vagas recentes").
- [ ] **12. Favoritos e isolamento entre usuários** (salvar, F5, trocar de conta).

Interruptores de emergência, em ordem do mais leve ao mais drástico: `update public.job_sources set can_redistribute = false where id = 'jobicy'` (esconde tudo no app, reversível) → remover o cron e republicar (`crons = []`) → `wrangler delete` do Worker.

## Sequência

### 1. ~~Integrar o PR #50~~ · feito (merge `a0007a708ddab2f782ddff9a780ba505c1a1df12`)

### 2. ~~Integrar o PR #51~~ · feito (merge `4da84f91e37d3c104824edefaeacd33de5c0d265`)

### 3. ~~Ponto de entrada do Worker~~ · feito na Fase 5.5, aguardando merge do PR `feat/jobicy-worker-entrypoint`
`worker/src/index.ts` (`scheduled`, sem rota HTTP: `fetch` responde 404), `worker/wrangler.toml` (`0 */6 * * *`, sem `workers.dev`, sem segredos), lease entre instâncias, logs estruturados. Detalhes, limites da plataforma e testes em [`JOBICY_WORKER.md`](JOBICY_WORKER.md). Para o proprietário: integrar esse PR.

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

### 8. Configurar o agendamento · quem: proprietário aprova (o `wrangler.toml` já está pronto)
* A fonte permite **no máximo uma passada de sincronização por hora**; o README sugere que "algumas passadas por dia" bastam. Valor inicial recomendado: a cada 6 horas (`17 */6 * * *`).
* O cron só passa a existir no `wrangler deploy`. **Deploy exige autorização separada.**

### 9. Executar uma sincronização controlada · quem: proprietário autoriza; observar com `wrangler tail`
* Em produção um `scheduled` não pode ser chamado por HTTP (de propósito: não há endpoint administrativo). O endpoint `/cdn-cgi/handler/scheduled` do `wrangler dev` existe **só** no desenvolvimento local. Para a primeira execução real: ajustar temporariamente o cron para um minuto próximo, publicar, observar `wrangler tail`, e **voltar a `0 */6 * * *`** logo depois. O Worker impõe 60 min entre passadas, então um disparo repetido é pulado e registrado como `too_soon`.
* **Plano pago obrigatório** (Workers Paid, US$ 5/mês): no gratuito o cron tem 10 ms de CPU e 50 subrequests (limites oficiais, ver `JOBICY_WORKER.md`).
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
