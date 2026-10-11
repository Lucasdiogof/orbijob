-- LIGA a retencao semanal das vagas do Jobicy (pg_cron). NAO e parte da migration: ela so cria as funcoes.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_retention_cron = 'EU-AUTORIZO-A-RETENCAO-AUTOMATICA';
-- e que a migration 20261016000000 e a extensao pg_cron ja existam. Antes de ligar: backup (select ops.jobicy_retention_export(); salvo em arquivo, docs/JOBICY_RETENTION.md secao 6) e dry-run
-- (select * from ops.jobicy_retention_plan();). A PRIMEIRA execucao, se houver muito acumulado, deve ser manual com p_allow_large (a trava de 20 % recusaria).
--
-- Agenda (UTC): TODO DIA 04:37 (~100 vagas encerram por dia; semanal nao acompanharia), longe da revalidacao (00:17, 06:17...) e da descoberta (03:47, 09:47...). A funcao aplica a politica
-- (encerrada ha > 14 dias: compacta; ha > 90 dias e sem referencia: apaga) em lotes de 200 e recusa-se se mexeria em mais de 20 % das encerradas.
-- Desligar: scripts/supabase/ops/disable_retention_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_retention_cron', true), '') <> 'EU-AUTORIZO-A-RETENCAO-AUTOMATICA' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regprocedure('ops.jobicy_retention_apply(text, interval, interval, integer, boolean)') is null then
    raise exception 'ativacao bloqueada: a migration 20261016000000 nao foi aplicada';
  end if;
  perform cron.schedule('jobicy-retention', '37 4 * * *', $cmd$select ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO')$cmd$);
end
$enable$;
