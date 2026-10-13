-- DESLIGA a passagem horaria dos alertas: remove o agendamento do pg_cron. Nao apaga nada (pesquisas, notificacoes e historico
-- ops.alert_runs ficam como estao). Pode ser executado a qualquer momento, quantas vezes quiser.
do $disable$
begin
  if to_regnamespace('cron') is null then
    raise notice 'pg_cron nao esta instalado: nada a desligar';
    return;
  end if;
  perform cron.unschedule(jobname) from cron.job where jobname = 'alerts-run';
end
$disable$;
