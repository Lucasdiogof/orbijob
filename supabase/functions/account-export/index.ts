// Edge Function `account-export`: the signed-in person's own data as one JSON document (see core.ts). Deployed WITH JWT verification and without
// any privileged key: every read runs as the caller, so row-level security decides what can be returned.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import { exportData } from './core.ts';

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type, apikey, x-client-info',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store', ...CORS } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const authorization = req.headers.get('authorization');
  if (!url || !anon) return reply(500, { error: 'not_configured' });
  const token = authorization?.replace(/^Bearer\s+/i, '') ?? '';
  const asCaller = createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const out = await exportData(
    {
      async userForToken(t) {
        const { data, error } = await asCaller.auth.getUser(t);
        if (error || !data.user) return null;
        return { id: data.user.id, email: data.user.email ?? null, created_at: data.user.created_at, last_sign_in_at: data.user.last_sign_in_at ?? null };
      },
      async page(table, columns, from, to) {
        const r = await asCaller.from(table).select(columns).range(from, to);
        return { data: (r.data as unknown as Record<string, unknown>[] | null) ?? null, error: r.error };
      },
      async signedUrl(path, seconds) {
        const r = await asCaller.storage.from('resumes').createSignedUrl(path, seconds);
        return r.data?.signedUrl ?? null;
      },
      now: () => new Date(),
    },
    req.method,
    authorization,
  );
  return reply(out.status, out.body);
});
