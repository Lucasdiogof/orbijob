-- DESLIGA a revalidacao automatica do Jobicy no Supabase: remove os agendamentos do pg_cron. Nao apaga nada: as funcoes, o historico
-- (sync_runs, ops.revalidation_batches) e as vagas continuam como estao. Pode ser executado a qualquer momento, quantas vezes quiser.
do $disable$
begin
  if to_regnamespace('cron') is null then
    raise notice 'pg_cron nao esta instalado: nada a desligar';
    return;
  end if;
  perform cron.unschedule(jobname) from cron.job where jobname in ('jobicy-revalidate-start', 'jobicy-revalidate-collect', 'ops-cron-history-purge');
end
$disable$;
