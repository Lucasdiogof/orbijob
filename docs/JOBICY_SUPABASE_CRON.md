# Revalidação automática do Jobicy dentro do Supabase (pg_cron + pg_net)

## Por que isto existe
O agendamento do GitHub Actions **nunca disparou neste repositório** (zero execuções `schedule` em qualquer workflow, mesmo com o workflow de
diagnóstico a cada 15 minutos; execuções manuais funcionam e revalidam de verdade, provado no banco). Não há causa objetiva conhecida
(`docs/GITHUB_SCHEDULE_DIAGNOSTIC.md`), e o Cloudflare Cron está fora (os 5 triggers gratuitos da conta estão ocupados). A revalidação agora roda
**dentro do próprio banco**: sem GitHub, sem Cloudflare, sem token, sem chave.

## Disponibilidade e custo (verificado no projeto real, 2026-10-10)
* PostgreSQL 17.11. O projeto oferece **pg_cron 1.6.4** e **pg_net 0.20.4** (`pg_available_extensions`); hoje nenhuma das duas está instalada.
* Documentação do Supabase: pg_cron recomenda no máximo 8 jobs simultâneos e até 10 min por job (aqui: 3 jobs, de segundos); pg_net guarda as respostas por
  6 horas e aguenta ~200 requisições/s (aqui: 3 requisições a cada 6 h). **Custo: US$ 0**, sem Edge Function, sem serviço externo.
* **Não verificável daqui:** o plano da organização (a CLI não o informa). Os recursos acima existem no projeto; se a instalação das extensões for recusada,
  a migration falha inteira (nada é gravado) e o motivo aparece na hora.
* Atenção conhecida do plano gratuito do Supabase: projetos **inativos por uma semana são pausados**. Um job do pg_cron não é uma garantia de atividade; o uso
  normal do app (leitura pública) é.

## Decisão de projeto: SQL, não Edge Function
Uma Edge Function reaproveitaria o código TypeScript, mas precisaria de uma **chave** como secret da função (e a que a plataforma injeta por padrão é a
`service_role` legada que foi exposta em 10/10). A consulta de status do Jobicy é pública e as gravações são feitas pelo dono do banco (o papel que o
pg_cron usa). Logo **nenhuma credencial existe nesta solução**. O preço é reimplementar em SQL a regra de decisão, que é pequena. Para não divergir do Worker:
* a **lease** usa o mesmo id determinístico (`ops.slot_run_id` = `slotRunId` do TypeScript; teste de paridade) e as mesmas regras (`running` < 20 min, `too_soon`
  em 60 min, `stale_lock`, `lost_race`): uma execução manual ou do GitHub Actions na mesma hora faz esta recuar, e vice-versa;
* as **decisões** são as de `closeStale` em modo `revalidate` (`worker/src/sync.ts`), com os mesmos casos nos testes: `closed` fecha, `active` renova
  `last_checked_at`, `unknown`/sem resposta/erro HTTP/timeout/resposta ilegível **não mudam nada**.

## Como funciona
Duas fases, porque o pg_net só envia a requisição quando a transação confirma e responde de forma assíncrona:

| Quando (UTC) | Função | O que faz |
|---|---|---|
| 00:17, 06:17, 12:17, 18:17 | `ops.jobicy_revalidate_start()` | pega a lease; lê as vagas **abertas já gravadas** do `jobicy` (verificação mais antiga primeiro, só ids no formato do Jobicy, até 1000 por passada); enfileira uma consulta de status por 100 ids |
| +2, +4, +7, +12, +27 min | `ops.jobicy_revalidate_collect()` | lê as respostas em `net._http_response`; aplica por lote; fecha o registro do run em `sync_runs`; espera enquanto faltar resposta (até 30 min, depois é timeout) |
| 03:07 | limpeza | apaga o histórico do pg_cron com mais de 14 dias |

Garantias (cada uma tem teste: `worker/test/supabase-cron-revalidation.test.ts`, 29 testes em PostgreSQL real via PGlite, e `supabase/tests/10_revalidation_cron.sql`, que o CI roda em PostgreSQL 16 e 17):
* **só vagas existentes**: nenhum `INSERT` em `jobs`, nenhum `DELETE`; só `status` (e só para `closed` confirmado) e `last_checked_at` mudam, e só de vagas ainda `open`;
* **nunca fecha por engano**: HTTP ≠ 200, timeout, JSON ilegível, `success` falso, ausência do vetor `jobs`, `unknown` ou id não respondido não fecham nada;
  ids que não foram perguntados são ignorados; vagas de outra fonte nunca são tocadas;
* **falha parcial**: cada lote vale por si; um lote com erro não desfaz os outros (o run fica `partial` com `error_class`);
* **concorrência**: lease (uma passada por hora, compartilhada com o Worker/Actions), trava consultiva na coleta, e a coleta só mexe em runs que ela mesma iniciou;
* **falha ao enfileirar**: a transação inteira desfaz (sem lease presa, sem registro);
* **fonte, `can_redistribute` e dados de usuário**: intocados; favoritos e candidaturas continuam ligados à vaga quando ela fecha (testado);
* **acesso**: o schema `ops` é fechado a `anon`, `authenticated` e `service_role` (testado); não é exposto pela API; sem chave, sem segredo.
* **logs**: `sync_runs` (mesmas colunas do Worker) e `ops.revalidation_batches` (por consulta: status HTTP, fechadas, confirmadas, sem confirmação), só contagens.

Limites conhecidos: 1000 vagas por passada (hoje 299; com o catálogo maior, a verificação mais antiga vai primeiro e o alerta de validade avisa); o pg_net guarda
respostas em tabela não registrada (perdida num crash do banco: o run vira timeout e a próxima passada refaz); a coleta tem 5 tentativas por ciclo.

## Ativação (executada com autorização do proprietário em 2026-10-10)
Estado: migration aplicada; prova manual (20:28 UTC) e prova disparada pelo Supabase Cron (21:31 start / 21:34 collect, jobs temporários já removidos) concluídas; agenda definitiva ativa (3 jobs). Arquitetura e recuperação: `docs/DEPLOYED_ARCHITECTURE.md`. Os passos abaixo ficam como procedimento de reativação.

1. Merge do PR (a migration só cria funções; **não agenda nada**).
2. Aplicar a migration `20261015000000_supabase_cron_revalidation.sql` (`supabase db push`; instala `pg_net` e `pg_cron` onde faltarem).
3. **Prova real, uma vez, sem agendar:** `select ops.jobicy_revalidate_start();` → esperar ~10 s → `select ops.jobicy_revalidate_collect();`. Conferir: 299 vagas,
   `last_checked_at` renovado, `sync_runs` com uma linha `ok/revalidate`, `ops.revalidation_batches` com 3 consultas `applied`.
4. Ligar o agendamento: `set orbijob.enable_revalidation_cron = 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA';` + `scripts/supabase/ops/enable_revalidation_cron.sql`
   (recusa-se a rodar sem a frase, sem pg_cron/pg_net ou sem a migration).
5. Conferir `select jobname, schedule, active from cron.job;` e, depois da primeira passada, `select * from cron.job_run_details order by start_time desc limit 5;`.

Consultas de acompanhamento (somente leitura):
```sql
select status, scope, closed, http_errors, error_class, started_at, finished_at from sync_runs order by started_at desc limit 5;
select run_id, batch, outcome, http_status, closed, confirmed, unknown from ops.revalidation_batches order by requested_at desc limit 10;
select jobname, schedule, active from cron.job;
select min(last_checked_at), max(last_checked_at), count(*) from jobs where status = 'open';
```

## Desativar e desfazer (nada apaga vagas)
* **Desligar:** `scripts/supabase/ops/disable_revalidation_cron.sql` (remove os 3 agendamentos; idempotente).
* **Desfazer a migration:** `supabase/rollback/20261015000000_supabase_cron_revalidation.down.sql` (remove o schema `ops` e os agendamentos; não mexe em vagas, nem em
  linhas de `sync_runs`, nem nas extensões). `rollback_all.sql` também limpa.
* **Emergência no catálogo:** `update public.job_sources set can_redistribute = false where id = 'jobicy';`.

## Monitoramento
* O **monitor do GitHub** (`jobicy-watchdog`) continua olhando o catálogo público: alerta a 48 h/60 h de verificação mais antiga. Isso vale para qualquer mecanismo de
  revalidação. O próprio monitor depende do agendador do GitHub, então não é a única linha de defesa.
* A **validade de 72 h do app** é o freio final: sem revalidação, as vagas saem da lista (nunca aparecem como abertas sem garantia).
* O GitHub Actions manual (`Run workflow → revalidate`) continua como plano B e usa a mesma lease.
