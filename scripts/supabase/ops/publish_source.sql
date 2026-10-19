-- PUBLICAR uma fonte de vagas (alem do Jobicy) no app (can_redistribute = true). NAO E PARTE DA CRIACAO DA FONTE.
--
-- Estado inicial obrigatorio da linha: status = CONDITIONAL, can_redistribute = false. Junto com publish_jobicy.sql, este e o UNICO arquivo do repositorio
-- que liga can_redistribute (scripts/supabase/no_premature_publish.test.mjs falha se outro arquivo fizer isso).
--
-- O arquivo se recusa a rodar sozinho. Exige, na MESMA sessao e antes do script, a fonte e a frase de autorizacao:
--     set orbijob.publish_source = 'arbeitnow:EU-REVISEI-OS-REGISTROS-E-AUTORIZO';
-- (troque arbeitnow por remoteok, remotive, jobtech, twjobs, jobsconz, getonboard, teachingvacancies, nycjobs, karrierenrw, bpce, forem, mpsvcz, csp, sefmurcia, feinaactiva, ecyl, lanbide, calgary, sinees ou usajobs). So publica quando TODAS as condicoes valem:
--   1. a fonte existe, esta CONDITIONAL, ainda nao esta publicada e tem texto de atribuicao;
--   2. existe ao menos uma passada de descoberta (scope 'discover') com status 'ok', e NENHUMA passada failed, running ou partial;
--   3. ha vagas da fonte no banco e TODA original_url e https no dominio da propria fonte;
--   4. nenhuma vaga da fonte esta sem titulo ou sem empresa (excecao: fonte cuja atribuicao diz que nao nomeia o empregador).
-- Reversao imediata: update public.job_sources set can_redistribute = false where id = '<fonte>';
do $publish$
declare
  setting text := coalesce(current_setting('orbijob.publish_source', true), '');
  sid text := split_part(setting, ':', 1);
  src public.job_sources%rowtype;
  host_re text;
  ok_runs int; bad_runs int; total_jobs int; bad_urls int; bad_rows int;
begin
  if split_part(setting, ':', 2) <> 'EU-REVISEI-OS-REGISTROS-E-AUTORIZO' or sid = '' then
    raise exception 'publicacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';
  end if;
  host_re := case sid
    when 'arbeitnow' then '^https://(www\.)?arbeitnow\.(com|co\.uk|fr|ch|nl)(/|$)'
    when 'remoteok'  then '^https://([a-z0-9-]+\.)*remoteok\.com(/|$)'
    when 'remotive'  then '^https://([a-z0-9-]+\.)*remotive\.com(/|$)'
    when 'jobsconz'  then '^https://([a-z0-9-]+\.)*jobs\.co\.nz(/|$)'
    when 'twjobs'    then '^https://([a-z0-9-]+\.)*taiwanjobs\.gov\.tw(/|$)'
    when 'getonboard' then '^https://([a-z0-9-]+\.)*getonbrd\.com(/|$)'
    when 'teachingvacancies' then '^https://teaching-vacancies\.service\.gov\.uk(/|$)'
    when 'nycjobs' then '^https://cityjobs\.nyc\.gov(/|$)'
    when 'karrierenrw' then '^https://([a-z0-9-]+\.)*karriere\.nrw(/|$)'
    when 'bpce' then '^https://([a-z0-9-]+\.)*bpce\.fr(/|$)'
    when 'forem' then '^https://([a-z0-9-]+\.)*leforem\.be(/|$)'
    when 'mpsvcz' then '^https://up\.gov\.cz(/|$)'
    when 'csp' then '^https://choisirleservicepublic\.gouv\.fr(/|$)'
    when 'sefmurcia' then '^https://([a-z0-9-]+\.)*carm\.es(/|$)'
    when 'feinaactiva' then '^https://feinaactiva\.gencat\.cat(/|$)'
    when 'ecyl' then '^https://empleo\.jcyl\.es(/|$)'
    when 'lanbide' then '^https://([a-z0-9-]+\.)*lanbide\.eus(/|$)'
    when 'calgary' then '^https://([a-z0-9-]+\.)*calgary\.ca(/|$)'
    when 'sinees' then '^https://([a-z0-9-]+\.)*es\.gov\.br(/|$)'
    when 'usajobs' then '^https://([a-z0-9-]+\.)*usajobs\.gov(/|$)'
    when 'jobtech'   then '^https://([a-z0-9-]+\.)*arbetsformedlingen\.se(/|$)'
    else null end;
  if host_re is null then raise exception 'publicacao bloqueada: fonte % nao e publicavel por este arquivo', sid; end if;

  select * into src from public.job_sources where id = sid;
  if not found then raise exception 'publicacao bloqueada: a fonte % nao existe', sid; end if;
  if src.status <> 'CONDITIONAL' then raise exception 'publicacao bloqueada: status esperado CONDITIONAL, encontrado %', src.status; end if;
  if src.can_redistribute then raise exception 'publicacao bloqueada: a fonte ja esta publicada'; end if;
  if coalesce(btrim(src.attribution), '') = '' then raise exception 'publicacao bloqueada: a fonte nao tem atribuicao'; end if;

  select count(*) filter (where status = 'ok'), count(*) filter (where status <> 'ok')
    into ok_runs, bad_runs from public.sync_runs where source_id = sid and scope = 'discover';
  if ok_runs < 1 then raise exception 'publicacao bloqueada: nenhuma passada de descoberta concluida (ok)'; end if;
  if bad_runs > 0 then raise exception 'publicacao bloqueada: % passada(s) failed/running/partial; resolva antes', bad_runs; end if;

  select count(*) into total_jobs from public.jobs where source_id = sid;
  if total_jobs = 0 then raise exception 'publicacao bloqueada: nao ha vagas de % no catalogo', sid; end if;
  select count(*) into bad_urls from public.jobs where source_id = sid and original_url !~ host_re;
  if bad_urls > 0 then raise exception 'publicacao bloqueada: % vaga(s) com original_url fora do dominio da fonte', bad_urls; end if;
  -- an offer without an employer name is accepted only for a source whose attribution says so (public employment services that do not name the employer, or
  -- that leave out a person's name): the statement is part of the stored attribution, so it is visible to the user
  select count(*) into bad_rows from public.jobs where source_id = sid and (btrim(title) = '' or (btrim(company) = '' and src.attribution !~* '(not name the employer|show no employer name)'));
  if bad_rows > 0 then raise exception 'publicacao bloqueada: % vaga(s) sem titulo ou empresa', bad_rows; end if;

  update public.job_sources set can_redistribute = true where id = sid and can_redistribute = false;
end
$publish$;
