-- LIGA a revalidacao automatica do Jobicy dentro do Supabase (pg_cron). NAO e parte da migration: ela so cria as funcoes.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_revalidation_cron = 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA';
-- e que a migration 20261015000000 e a extensao pg_cron ja existam.
--
-- Agenda (UTC), tudo no proprio banco, sem chave e sem segredo:
--   jobicy-revalidate-start     17 */6 * * *            00:17, 06:17, 12:17, 18:17: pega a lease e enfileira as consultas de status
--   jobicy-revalidate-collect   19,21,24,29,44 */6 * * *  +2, +4, +7, +12 e +27 min: le as respostas, aplica, fecha o registro do run
--   ops-cron-history-purge      7 3 * * *               apaga o historico do pg_cron com mais de 14 dias (o pg_cron guarda cada execucao)
-- Desligar: scripts/supabase/ops/disable_revalidation_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_revalidation_cron', true), '') <> 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regnamespace('net') is null then raise exception 'ativacao bloqueada: a extensao pg_net nao esta instalada'; end if;
  if to_regprocedure('ops.jobicy_revalidate_start()') is null or to_regprocedure('ops.jobicy_revalidate_collect()') is null then
    raise exception 'ativacao bloqueada: a migration 20261015000000 nao foi aplicada';
  end if;
  perform cron.schedule('jobicy-revalidate-start',   '17 */6 * * *',            'select ops.jobicy_revalidate_start()');
  perform cron.schedule('jobicy-revalidate-collect', '19,21,24,29,44 */6 * * *', 'select ops.jobicy_revalidate_collect()');
  perform cron.schedule('ops-cron-history-purge',    '7 3 * * *',               $purge$delete from cron.job_run_details where end_time < now() - interval '14 days'$purge$);
end
$enable$;
