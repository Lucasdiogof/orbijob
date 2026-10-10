# Arquitetura efetivamente implantada e recuperação

Este documento descreve **o que está rodando hoje** (verificado em 2026-10-10), não o que está planejado. O planejado fica em `docs/ARCHITECTURE.md` e `docs/ROADMAP.md`.

## O que existe em produção
| Peça | Estado |
|---|---|
| Supabase `rpmlfxwebnlxnwadyvle` (PostgreSQL 17.11, plano gratuito) | 8 migrations aplicadas (`supabase migration list`), RLS ligado, `pg_cron` 1.6.4 e `pg_net` 0.20.4 instalados |
| Catálogo | fonte `jobicy` (`CONDITIONAL`, `can_redistribute = true`), **299 vagas** de 133 empresas, todas abertas na última verificação |
| Revalidação (principal) | **Supabase Cron** → `ops.jobicy_revalidate_start()` às 00:17, 06:17, 12:17, 18:17 UTC e `ops.jobicy_revalidate_collect()` em +2, +4, +7, +12, +27 min; limpeza do histórico do cron às 03:07 |
| Revalidação (contingência) | GitHub Actions `Jobicy revalidate` (`17 */6`, mais manual), mesma lease; usa a chave `sb_secret_` do environment `jobicy-revalidation` |
| Monitor | GitHub Actions `Jobicy watchdog` (`43 5,17`): lê o catálogo público e abre/fecha uma issue de alerta |
| Cloudflare Worker | **não implantado** (cinco cron triggers gratuitos ocupados; sem plano pago). O código existe e é reaproveitado pelo GitHub Actions |
| App Flutter | lê o catálogo com a chave publicável (RLS); não escreve vagas |
| Importação de vagas novas | **desligada**. Só existiu a primeira ingestão controlada (299 vagas). A descoberta incremental é uma proposta separada (PR próprio), ainda não ativa |

## Fluxo da revalidação
```
pg_cron (00:17 ...) ──> ops.jobicy_revalidate_start()
   lease: sync_runs.id determinístico por (fonte, hora)  → 1 passada por hora, compartilhada com o Actions
   pg_net: 1 GET /status?ids=... por 100 vagas abertas (até 1000 por passada)
pg_cron (+2/+4/+7/+12/+27 min) ──> ops.jobicy_revalidate_collect()
   lê net._http_response; fecha SÓ o que o Jobicy responde "closed"; carimba last_checked_at do "active";
   "unknown", sem resposta, erro HTTP, timeout e JSON ilegível não mudam nada; grava o resultado em sync_runs
```
O app só mostra vagas com `last_checked_at` de até 72 h: sem revalidação elas saem da lista (nunca aparecem como abertas sem garantia).

## Evidências (produção, 2026-10-10)
* Prova manual (20:28 UTC): 3 respostas HTTP 200, 299 confirmadas, 0 fechadas, linha `ok/revalidate` em `sync_runs`.
* Prova disparada pelo Supabase Cron com jobs temporários (já removidos): `start` 21:31:00 e `collect` 21:34:00 UTC, ambos `succeeded` em `cron.job_run_details`, 3 lotes `applied`.
* Concorrência entre mecanismos: a execução agendada do GitHub das 21:46 UTC terminou `skipped (too_soon)` por causa da passada das 21:31 (`docs/GITHUB_SCHEDULE_DIAGNOSTIC.md`).
* A primeira execução **da agenda definitiva** (00:17 UTC de 11/10) usa as mesmas funções e o mesmo mecanismo; confira com as consultas abaixo.

## Auditoria (concorrência, falhas, histórico)
| Tema | Como está | Observação |
|---|---|---|
| Concorrência | `sync_runs.id` é chave primária e derivada de (fonte, hora): só um `INSERT` vence; `running` < 20 min bloqueia; `too_soon` em 60 min; coleta com trava consultiva | vale entre Supabase Cron, GitHub Actions e Worker (mesma regra, teste de paridade SQL × TypeScript) |
| Falha parcial | cada lote vale por si; lote com erro não desfaz os outros; o run fica `partial` com `error_class` | nunca fecha por falha, timeout ou `unknown` |
| Resposta incompleta | a coleta espera até 30 min pelas respostas; depois conta como timeout | o pg_net guarda respostas em tabela não registrada (perdidas se o banco reiniciar: a próxima passada refaz) |
| Retenção | `cron.job_run_details` apagado após 14 dias (job 03:07); `net._http_response` expira em 6 h (pg_net); `ops.revalidation_batches` (3 linhas por passada, ~12/dia) e `sync_runs` (~4/dia) crescem de forma desprezível | sem rotina de limpeza para essas duas tabelas (custo de armazenamento irrelevante) |
| Limite por passada | 1000 vagas (a verificação mais antiga vai primeiro) | hoje 299 |
| Plano gratuito | projetos inativos por uma semana são pausados | o uso normal do app (leituras) evita; veja a recuperação |

### Redundância: o que manter
* **Supabase Cron + GitHub Actions:** redundância **intencional**. Compartilham a lease, então rodar os dois não duplica chamadas ao Jobicy (provado em 21:46). Se o Cron falhar (projeto pausado, extensão), o Actions segura as 72 h; se o GitHub atrasar ou for desativado, o Cron segura. **Nenhum foi desativado.**
* **Monitor (`jobicy-watchdog`):** independente dos dois; alerta se a verificação mais antiga passar de 48 h.
* **Diagnóstico `diagnostics-schedule.yml`:** removido (não explicava nada e gerava ~96 execuções/dia).

## Acompanhamento (somente leitura, via `supabase db query --linked`)
```sql
select j.jobname, d.status, d.start_time from cron.job_run_details d join cron.job j using (jobid) order by d.start_time desc limit 8;
select scope, status, closed, http_errors, error_class, started_at, finished_at from sync_runs order by started_at desc limit 6;
select run_id, batch, outcome, http_status, closed, confirmed, unknown from ops.revalidation_batches order by requested_at desc limit 10;
select jobname, schedule, active from cron.job;
select min(last_checked_at), max(last_checked_at), count(*) from jobs where status = 'open';
```

## Procedimentos de recuperação
| Situação | O que fazer |
|---|---|
| Vagas sumindo do app (`last_checked_at` > 72 h) | rodar uma passada agora: `select ops.jobicy_revalidate_start();` e, ~10 s depois, `select ops.jobicy_revalidate_collect();`. Se responder `skipped:too_soon`, já houve passada na última hora. Alternativa: Actions → *Jobicy revalidate* → *Run workflow* → `revalidate` |
| `cron.job` vazio ou inativo | `scripts/supabase/ops/enable_revalidation_cron.sql` com `set orbijob.enable_revalidation_cron = 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA';` |
| Projeto pausado (plano gratuito) | restaurar pelo painel do Supabase (*Restore project*); os `cron.job` voltam com o banco. Depois, rodar uma passada manual como na primeira linha |
| `sync_runs` com `running` preso | some sozinho: após 20 min a lease o fecha como `failed/stale_lock`. Não apague linhas à mão |
| Passada `partial`/`failed` | ver `error_class` em `sync_runs` e `outcome` em `ops.revalidation_batches`. Nada foi fechado por causa do erro; a próxima passada refaz |
| Chave `sb_secret_` do Actions recusada | gerar outra no painel, atualizar o secret `ORBIJOB_SYNC_WORKER_KEY` do environment; o Supabase Cron não usa chave |
| Desligar tudo | `scripts/supabase/ops/disable_revalidation_cron.sql` (remove os 3 agendamentos; não apaga vagas) |
| Desfazer a migration 8 | `supabase/rollback/20261015000000_supabase_cron_revalidation.down.sql` |
| Emergência no catálogo | `update public.job_sources set can_redistribute = false where id = 'jobicy';` (esconde tudo do app; não apaga) |
| Restaurar dados | backups manuais em `C:\Users\lucas\orbijob-backups\` (só locais); não conte com backups gerenciados no plano gratuito (confira no painel); a fonte de verdade das vagas é o Jobicy, e as 299 podem ser reconstruídas, mas favoritos e candidaturas não |
