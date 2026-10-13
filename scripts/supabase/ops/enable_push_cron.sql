-- LIGA o envio horario de push (Firebase Cloud Messaging) das notificacoes novas: o pg_cron chama a Edge Function push-send. NAO e parte da
-- migration 20261024000000: ela so cria a tabela de aparelhos e as funcoes ops.push_claim / ops.push_forget_tokens.
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script:
--     set orbijob.enable_push_cron = 'EU-AUTORIZO-O-PUSH-AUTOMATICO';
-- e que existam: a migration 20261024000000, as extensoes pg_cron e pg_net, e o segredo `push_cron_secret` no Vault (o MESMO valor do secret
-- PUSH_CRON_SECRET da funcao; ver docs/ORBIJOB_3_0.md, "Push").
--
-- Agenda (UTC): toda hora no minuto 56, logo depois dos alertas (minuto 53). Sem o secret FCM_SERVICE_ACCOUNT a funcao responde
-- `not_configured` e nao marca nada. Desligar: scripts/supabase/ops/disable_push_cron.sql
do $enable$
begin
  if coalesce(current_setting('orbijob.enable_push_cron', true), '') <> 'EU-AUTORIZO-O-PUSH-AUTOMATICO' then
    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;
  if to_regnamespace('net') is null then raise exception 'ativacao bloqueada: a extensao pg_net nao esta instalada'; end if;
  if to_regprocedure('ops.push_claim(integer)') is null then raise exception 'ativacao bloqueada: a migration 20261024000000 nao foi aplicada'; end if;
  if not exists (select 1 from vault.secrets where name = 'push_cron_secret') then
    raise exception 'ativacao bloqueada: falta o segredo push_cron_secret no Vault';
  end if;
  perform cron.schedule('push-send', '56 * * * *', $cmd$
    select net.http_post(
      url := 'https://rpmlfxwebnlxnwadyvle.supabase.co/functions/v1/push-send',
      headers := jsonb_build_object('content-type', 'application/json',
                                    'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_secret')),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000)
  $cmd$);
end
$enable$;
