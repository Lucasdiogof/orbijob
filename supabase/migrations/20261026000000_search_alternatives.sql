-- Search alternatives with several required parts, and profession searches judged on the title (OrbiJob 5.0).
--
-- The app now expands a search into the other names of the PROFESSION while keeping the words that qualify it ("engenheiro civil" -> civil
-- engineer / Bauingenieur, never every engineer; "desenvolvedor flutter" -> [flutter, developer] / [flutter, entwickler]). An alternative in
-- match.alts is therefore either a string (inside the title, as before) or an array of 1-6 parts that must ALL be inside the title. A search that
-- has alternatives is a profession search: it is judged on the title (and city); a description that merely mentions the word no longer triggers an
-- alert. A search without alternatives keeps the full-text match on title, company and description. Saved searches stored before keep working
-- (string alternatives). Same signature. Rollback: supabase/rollback/20261026000000_search_alternatives.down.sql (restores migration 16).
create or replace function ops.title_alt_matches(p_title text, p_alt jsonb) returns boolean
language sql immutable set search_path = pg_catalog as $$
  select case jsonb_typeof(p_alt)
    when 'string' then ops.title_has(p_title, p_alt #>> '{}')
    when 'array' then jsonb_array_length(p_alt) between 1 and 6
                      and not exists (select 1 from jsonb_array_elements(p_alt) x where jsonb_typeof(x) <> 'string' or not ops.title_has(p_title, x #>> '{}'))
    else false end
$$;
revoke all on function ops.title_alt_matches(text, jsonb) from public, anon, authenticated, service_role;

create or replace function ops.alert_matches(j public.jobs, q jsonb) returns boolean
language plpgsql stable set search_path = pg_catalog as $$
declare
  m jsonb := coalesce(q -> 'match', '{}'::jsonb);
  v_term text := nullif(btrim(coalesce(m ->> 'term', '')), '');
  v_country text := nullif(upper(btrim(coalesce(m ->> 'country', ''))), '');
  v_cc text[];
  v_modes text[];
  v_days int;
  g jsonb;
  k text;
  hit boolean;
  e jsonb;
begin
  if v_term is not null then
    hit := ops.title_has(j.title, v_term) or ops.title_has(j.city, v_term);
    if not hit then
      -- an alternative is a string (inside the title) or an array of parts that must ALL be inside the title (migration 20261026000000)
      for e in select x from jsonb_array_elements(case when jsonb_typeof(m -> 'alts') = 'array' then m -> 'alts' else '[]'::jsonb end) x loop
        if ops.title_alt_matches(j.title, e) then hit := true; exit; end if;
      end loop;
    end if;
    -- a profession search (it has other names) is about the TITLE; free words may also match the description
    if not hit and coalesce(jsonb_array_length(case when jsonb_typeof(m -> 'alts') = 'array' then m -> 'alts' end), 0) = 0 then
      hit := j.search @@ websearch_to_tsquery('simple', v_term);
    end if;
    if not coalesce(hit, false) then return false; end if;
  end if;

  if v_country is not null then
    if not coalesce(j.country::text = v_country
                    or coalesce(j.geo_restrictions, '{}') @> array[v_country]
                    or (j.work_mode = 'remote' and coalesce(j.geo_restrictions, '{}') @> array['Anywhere']), false) then
      return false;
    end if;
  elsif jsonb_typeof(m -> 'cc') = 'array' and jsonb_array_length(m -> 'cc') > 0 then
    select array_agg(upper(x)) into v_cc from jsonb_array_elements_text(m -> 'cc') x;
    if not coalesce(j.country::text = any (v_cc)
                    or coalesce(j.geo_restrictions, '{}') && (v_cc || coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(m -> 'regions', '[]'::jsonb)) x), '{}')), false) then
      return false;
    end if;
  end if;

  if jsonb_typeof(m -> 'modes') = 'array' and jsonb_array_length(m -> 'modes') > 0 then
    select array_agg(x) into v_modes from jsonb_array_elements_text(m -> 'modes') x;
    if not coalesce(j.work_mode = any (v_modes), false) then return false; end if;
  end if;

  if jsonb_typeof(m -> 'title_groups') = 'array' then
    for g in select jsonb_array_elements(m -> 'title_groups') loop
      hit := false;
      for k in select jsonb_array_elements_text(g) loop
        if ops.title_has(j.title, k) then hit := true; exit; end if;
      end loop;
      if not hit then return false; end if;
    end loop;
  end if;

  if jsonb_typeof(m -> 'days') = 'number' then
    v_days := (m ->> 'days')::int;
    if v_days > 0 and not coalesce(j.published_at >= now() - make_interval(days => v_days), false) then return false; end if;
  end if;

  if m ->> 'salary' = 'true' then
    if not ((j.salary_min is not null or j.salary_max is not null) and j.salary_currency is not null and j.salary_period is not null) then
      return false;
    end if;
  end if;
  return true;
end $$;

revoke all on function ops.alert_matches(public.jobs, jsonb) from public, anon, authenticated, service_role;
