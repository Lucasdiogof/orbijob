-- LIGA a expiracao diaria das vagas de fontes sem endpoint de status (arbeitnow, remoteok, remotive). NAO e parte da migration: ela so cria a funcao.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_sources_maintenance = 'EU-AUTORIZO-A-EXPIRACAO-AUTOMATICA';
-- e que a migration 20261017000000 e a extensao pg_cron ja existam.
--
-- Agenda (UTC): todo dia 04:12, antes da retencao (04:37): fecha as vagas ABERTAS que o feed da fonte nao lista ha mais de 7 dias, mas so de fontes
-- cuja ultima passada de descoberta terminou 'ok' nas ultimas 36 h (sem leitura recente do feed, ausencia nao prova nada).
-- Desligar: scripts/supabase/ops/disable_sources_maintenance_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_sources_maintenance', true), '') <> 'EU-AUTORIZO-A-EXPIRACAO-AUTOMATICA' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regprocedure('ops.expire_unseen_jobs(text, interval, text[], integer)') is null then
    raise exception 'ativacao bloqueada: a migration 20261017000000 nao foi aplicada';
  end if;
  perform cron.schedule('sources-expire-unseen', '12 4 * * *', $cmd$select ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO')$cmd$);
end
$enable$;
