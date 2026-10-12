-- LIGA a expiracao diaria das vagas da Platsbanken (jobtech) e do Jobs.co.nz (jobsconz) que a busca deles nao lista ha mais de 7 dias. Complementa
-- enable_sources_maintenance_cron.sql (que cobre arbeitnow, remoteok e remotive com o padrao da funcao); a funcao ops.expire_unseen_jobs ja aceita
-- qualquer fonte sem endpoint de status, entao nao ha migration. Fonte sem passada de descoberta 'ok' nas ultimas 36 h nao e julgada.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_jobtech_expiry = 'EU-AUTORIZO-A-EXPIRACAO-AUTOMATICA';
-- Agenda (UTC): todo dia 04:22 (depois da expiracao das outras fontes, 04:12, e antes da retencao, 04:37).
-- Desligar: scripts/supabase/ops/disable_jobtech_expiry_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_jobtech_expiry', true), '') <> 'EU-AUTORIZO-A-EXPIRACAO-AUTOMATICA' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regprocedure('ops.expire_unseen_jobs(text, interval, text[], integer)') is null then
    raise exception 'ativacao bloqueada: a migration 20261017000000 nao foi aplicada';
  end if;
  perform cron.schedule('jobtech-expire-unseen', '22 4 * * *', $cmd$select ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO', interval '7 days', array['jobtech', 'jobsconz'])$cmd$);
end
$enable$;

