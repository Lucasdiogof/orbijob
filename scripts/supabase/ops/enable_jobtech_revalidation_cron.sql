-- LIGA a revalidacao automatica da Platsbanken (fonte jobtech) dentro do Supabase (pg_cron + pg_net). NAO e parte da migration: ela so cria as funcoes.
--
-- Por que existe: o agendador do GitHub descartou a maior parte das execucoes agendadas deste repositorio (auditoria de 12/10/2026). O Supabase Cron faz
-- parte do projeto, e gratuito e nao descarta execucoes. O Actions (sources-revalidate.yml) continua como contingencia, pela mesma lease.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_jobtech_revalidation = 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA';
-- e que a migration 20261020000000 e as extensoes pg_cron e pg_net ja existam.
--
-- Agenda (UTC): jobtech-revalidate-start 07 02,08,14,20 (pega a lease e enfileira ate 600 consultas /ad/{id}, a menos verificada primeiro);
-- jobtech-revalidate-collect nos minutos 10, 14, 20 e 35 das mesmas horas (le as respostas, aplica, fecha o registro). A descoberta da Platsbanken
-- (GitHub, 03/09/15/21 :31) fica uma hora depois: a lease e por fonte e por hora.
-- Desligar: scripts/supabase/ops/disable_jobtech_revalidation_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_jobtech_revalidation', true), '') <> 'EU-AUTORIZO-A-REVALIDACAO-AUTOMATICA' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regnamespace('net') is null then raise exception 'ativacao bloqueada: a extensao pg_net nao esta instalada'; end if;
  if to_regprocedure('ops.jobtech_revalidate_start()') is null or to_regprocedure('ops.jobtech_revalidate_collect()') is null then
    raise exception 'ativacao bloqueada: a migration 20261020000000 nao foi aplicada';
  end if;
  perform cron.schedule('jobtech-revalidate-start',   '7 2,8,14,20 * * *',         'select ops.jobtech_revalidate_start()');
  perform cron.schedule('jobtech-revalidate-collect', '10,14,20,35 2,8,14,20 * * *', 'select ops.jobtech_revalidate_collect()');
end
$enable$;
