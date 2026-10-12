-- LIGA a revalidacao automatica do Jobs.co.nz (Nova Zelandia) dentro do Supabase (pg_cron + pg_net). NAO e parte da migration: ela so cria as funcoes.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_jobsconz_revalidation = 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA';
-- e que a migration 20261022000000 e as extensoes pg_cron e pg_net ja existam.
--
-- Agenda (UTC): jobsconz-revalidate-start 37 01,04,07,10,13,16,19,22 (pega a lease e enfileira ate 100 consultas /api/v1/jobs/{id}, a menos verificada primeiro;
-- 100 por vez porque o limite sem chave e 120 requisicoes por minuto por IP); jobsconz-revalidate-collect aos minutos 41, 45 e 52 das mesmas horas.
-- A descoberta (GitHub, 03/09/15/21 :05) fica sempre a mais de uma hora de distancia: a lease e por fonte e por hora.
-- Desligar: scripts/supabase/ops/disable_jobsconz_revalidation_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_jobsconz_revalidation', true), '') <> 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regnamespace('net') is null then raise exception 'ativacao bloqueada: a extensao pg_net nao esta instalada'; end if;
  if to_regprocedure('ops.jobsconz_revalidate_start()') is null or to_regprocedure('ops.jobsconz_revalidate_collect()') is null then
    raise exception 'ativacao bloqueada: a migration 20261022000000 nao foi aplicada';
  end if;
  perform cron.schedule('jobsconz-revalidate-start',   '37 1,4,7,10,13,16,19,22 * * *',    'select ops.jobsconz_revalidate_start()');
  perform cron.schedule('jobsconz-revalidate-collect', '41,45,52 1,4,7,10,13,16,19,22 * * *', 'select ops.jobsconz_revalidate_collect()');
end
$enable$;
