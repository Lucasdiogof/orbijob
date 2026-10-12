-- DESLIGA a revalidacao da Platsbanken dentro do Supabase: remove os dois agendamentos do pg_cron. Nao fecha nem reabre nada.
do $disable$
begin
  if to_regnamespace('cron') is null then
    raise notice 'pg_cron nao esta instalado: nada a desligar';
    return;
  end if;
  perform cron.unschedule(jobname) from cron.job where jobname in ('jobtech-revalidate-start', 'jobtech-revalidate-collect');
end
$disable$;
