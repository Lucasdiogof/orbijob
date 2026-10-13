-- DESLIGA a passagem horaria dos lembretes: remove o agendamento do pg_cron. Nao apaga nada (candidaturas e notificacoes ficam
--  como estao). Pode ser executado a qualquer momento, quantas vezes quiser.
do $disable$
begin
  if to_regnamespace('cron') is null then
    raise notice 'pg_cron nao esta instalado: nada a desligar';
    return;
  end if;
  perform cron.unschedule(jobname) from cron.job where jobname = 'reminders-run';
end
$disable$;
