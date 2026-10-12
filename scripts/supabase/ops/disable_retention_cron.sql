-- DESLIGA a retencao semanal das vagas do Jobicy: remove o agendamento do pg_cron. Nao apaga nada: funcoes, historico
-- (ops.retention_runs, ops.job_tombstones) e vagas ficam como estao. Pode ser executado a qualquer momento, quantas vezes quiser.
do $disable$
begin
  if to_regnamespace('cron') is null then
    raise notice 'pg_cron nao esta instalado: nada a desligar';
    return;
  end if;
  perform cron.unschedule(jobname) from cron.job where jobname = 'jobicy-retention';
end
$disable$;
