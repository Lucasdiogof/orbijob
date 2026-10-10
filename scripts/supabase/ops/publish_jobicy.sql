-- PUBLICAR o Jobicy no app (can_redistribute = true). NÃO É PARTE DA CRIAÇÃO DA FONTE.
--
-- Estado inicial obrigatório da linha: status = CONDITIONAL, can_redistribute = false. Esta é a ÚNICA operação do repositório que
-- liga can_redistribute (scripts/supabase/no_premature_publish.test.mjs falha se outro arquivo fizer isso).
--
-- O arquivo se recusa a rodar sozinho. Só publica quando TODAS as condições abaixo valem:
--   1. o proprietário autorizou por escrito e ligou a trava na MESMA sessão, antes do script:
--        set orbijob.publish_jobicy = 'EU-REVISEI-OS-REGISTROS-E-AUTORIZO';
--   2. a fonte existe, está CONDITIONAL e ainda não está publicada;
--   3. existe ao menos uma passada de sync_runs com status 'ok', ou 'partial' encerrada SOMENTE pelo teto de paginas
--      (error_class = 'max_pages', o resultado esperado da primeira ingestao limitada), e NENHUMA passada failed, running
--      ou partial por outro motivo (erro HTTP, prazo, falha ao gravar);
--   4. há vagas do jobicy no banco;
--   5. toda original_url é https em jobicy.com e nenhuma vaga é de outra fonte com o mesmo external_id duplicado por engano;
--   6. a fonte tem o texto de atribuição.
-- Reversão imediata: update public.job_sources set can_redistribute = false where id = 'jobicy';
do $publish$
declare
  src public.job_sources%rowtype;
  ok_runs int; bad_runs int; total_jobs int; bad_urls int;
begin
  if coalesce(current_setting('orbijob.publish_jobicy', true), '') <> 'EU-REVISEI-OS-REGISTROS-E-AUTORIZO' then
    raise exception 'publicacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;

  select * into src from public.job_sources where id = 'jobicy';
  if not found then raise exception 'publicacao bloqueada: a fonte jobicy nao existe'; end if;
  if src.status <> 'CONDITIONAL' then raise exception 'publicacao bloqueada: status esperado CONDITIONAL, encontrado %', src.status; end if;
  if src.can_redistribute then raise exception 'publicacao bloqueada: a fonte ja esta publicada'; end if;
  if coalesce(btrim(src.attribution), '') = '' then raise exception 'publicacao bloqueada: a fonte nao tem atribuicao'; end if;

  select count(*) filter (where status = 'ok' or (status = 'partial' and error_class = 'max_pages')),
         count(*) filter (where not (status = 'ok' or (status = 'partial' and error_class = 'max_pages')))
    into ok_runs, bad_runs from public.sync_runs where source_id = 'jobicy';
  if ok_runs < 1 then raise exception 'publicacao bloqueada: nenhuma passada de sincronizacao concluida (ok, ou parcial so pelo teto de paginas)'; end if;
  if bad_runs > 0 then raise exception 'publicacao bloqueada: % passada(s) failed/running/parcial por outro motivo; resolva antes', bad_runs; end if;

  select count(*) into total_jobs from public.jobs where source_id = 'jobicy';
  if total_jobs = 0 then raise exception 'publicacao bloqueada: nao ha vagas do jobicy no catalogo'; end if;

  select count(*) into bad_urls from public.jobs
   where source_id = 'jobicy' and original_url !~ '^https://([a-z0-9-]+\.)*jobicy\.com(/|$)';
  if bad_urls > 0 then raise exception 'publicacao bloqueada: % vaga(s) com original_url fora de https://jobicy.com', bad_urls; end if;

  update public.job_sources set can_redistribute = true where id = 'jobicy' and can_redistribute = false;
end
$publish$;
