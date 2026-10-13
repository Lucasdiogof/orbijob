-- LIGA a passagem horaria dos alertas de pesquisas salvas (pg_cron). NAO e parte da migration: ela so cria as funcoes.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_alerts_cron = 'EU-AUTORIZO-OS-ALERTAS-AUTOMATICOS';
-- e que a migration 20261023000000 e a extensao pg_cron ja existam.
--
-- Agenda (UTC): todo hora no minuto 53 (longe da revalidacao 00:17.., da descoberta 03:47.. e da retencao 04:37). A funcao so le o catalogo e
-- escreve em public.notifications (uma linha por usuario e vaga); nunca altera nem apaga vagas. Cada pesquisa so roda de novo conforme a sua
-- frequencia (instant = a cada hora, daily = 23 h, weekly = 6 d 23 h). Desligar: scripts/supabase/ops/disable_alerts_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_alerts_cron', true), '') <> 'EU-AUTORIZO-OS-ALERTAS-AUTOMATICOS' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regprocedure('ops.alerts_run(integer)') is null then
    raise exception 'ativacao bloqueada: a migration 20261023000000 nao foi aplicada';
  end if;
  perform cron.schedule('alerts-run', '53 * * * *', $cmd$select ops.alerts_run()$cmd$);
end
$enable$;
