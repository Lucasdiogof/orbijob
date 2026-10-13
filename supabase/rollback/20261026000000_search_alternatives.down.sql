-- Rollback of 20261026000000: restores ops.alert_matches of migration 16 (string alternatives, description always considered).
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
begin
  if v_term is not null then
    hit := j.search @@ websearch_to_tsquery('simple', v_term)
        or ops.title_has(j.title, v_term)
        or ops.title_has(j.city, v_term);
    if not hit then
      for k in select jsonb_array_elements_text(coalesce(m -> 'alts', '[]'::jsonb)) loop
        if ops.title_has(j.title, k) then hit := true; exit; end if;
      end loop;
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
drop function if exists ops.title_alt_matches(text, jsonb);
