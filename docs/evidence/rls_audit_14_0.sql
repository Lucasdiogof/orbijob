-- OrbiJob 14.0 read-only RLS audit: every table of the public/ops schemas with RLS on or off, and what the anonymous role can do on it.
select n.nspname as schema, c.relname as tbl, c.relrowsecurity as rls_on,
  has_table_privilege('anon', c.oid, 'select') as anon_select,
  has_table_privilege('anon', c.oid, 'insert') as anon_insert,
  has_table_privilege('anon', c.oid, 'update') as anon_update,
  has_table_privilege('anon', c.oid, 'delete') as anon_delete,
  (select count(*) from pg_policy p where p.polrelid = c.oid and (p.polroles = '{0}' or exists (select 1 from pg_roles r where r.oid = any (p.polroles) and r.rolname = 'anon'))) as policies_for_anon
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind in ('r', 'p') and n.nspname in ('public', 'ops')
order by 1, 2;
