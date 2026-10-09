-- THE DEFECTIVE ORIGINAL (kept only as a regression fixture; never run it against a real project).
-- It passes a TEXT value derived from search_path to has_schema_privilege() and relies on the order in which WHERE
-- conditions are evaluated. On the hosted Supabase project (PostgreSQL 17.11) it failed with:
--   ERROR: 3F000: schema "$user" does not exist
-- Locally it fails the same way for any search_path entry that is not an existing schema, e.g. `nonexistent`.
select s from (
  select trim(both '"' from unnest(string_to_array(replace(current_setting('search_path'), ' ', ''), ','))) as s) q
where s <> '$user' and exists (select 1 from pg_namespace where nspname = s) and has_schema_privilege(current_user, s, 'CREATE')
limit 1;
