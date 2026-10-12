-- DESLIGA a expiracao diaria das vagas de fontes sem endpoint de status: remove o agendamento do pg_cron. Nao fecha nem reabre nada.
do $disable$
begin
  if to_regnamespace('cron') is null then
    raise notice 'pg_cron nao esta instalado: nada a desligar';
    return;
  end if;
  perform cron.unschedule(jobname) from cron.job where jobname = 'sources-expire-unseen';
end
$disable$;
