-- LIGA a passagem horaria dos lembretes de candidaturas (entrevista nas proximas 24 h, data de retorno de hoje). NAO e parte da migration:
-- ela so cria a funcao ops.reminders_run.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_reminders_cron = 'EU-AUTORIZO-OS-LEMBRETES-AUTOMATICOS';
-- e que a migration 20261025000000 e a extensao pg_cron ja existam.
--
-- Agenda (UTC): toda hora no minuto 50 (antes dos alertas, 53, e do push, 56). Cada data e lembrada uma vez. Desligar:
-- scripts/supabase/ops/disable_reminders_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_reminders_cron', true), '') <> 'EU-AUTORIZO-OS-LEMBRETES-AUTOMATICOS' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regprocedure('ops.reminders_run(timestamp with time zone)') is null then
    raise exception 'ativacao bloqueada: a migration 20261025000000 nao foi aplicada';
  end if;
  perform cron.schedule('reminders-run', '50 * * * *', $cmd$select ops.reminders_run()$cmd$);
end
$enable$;
