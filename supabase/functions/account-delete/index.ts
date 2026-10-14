// Edge Function `account-delete`: permanent deletion of the signed-in person's own account and data (see core.ts for the order and the rules).
//
// Deployed WITH JWT verification. The service-role key never leaves this function (SUPABASE_SERVICE_ROLE_KEY is injected by the platform);
// it is used only to remove the caller's own storage folder and the caller's own Auth user. The password check uses a separate throw-away
// client with the publishable key and no stored session.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import { deleteAccount } from './core.ts';

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type, apikey, x-client-info',
  'access-control-allow-methods': 'POST, OPTIONS',
};
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...CORS } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) return reply(500, { error: 'not_configured' });

  let raw: unknown = null;
  try {
    raw = await req.json();
  } catch {
    raw = null;
  }
  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const out = await deleteAccount(
    {
      async userForToken(token) {
        const { data, error } = await admin.auth.getUser(token);
        return error || !data.user ? null : { id: data.user.id, email: data.user.email ?? null };
      },
      async passwordMatches(email, password, userId) {
        const probe = createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
        const { data, error } = await probe.auth.signInWithPassword({ email, password });
        return !error && data.user?.id === userId;
      },
      bucket: admin.storage.from('resumes') as never,
      deleteUser: (id) => admin.auth.admin.deleteUser(id, false) as never,
    },
    req.method,
    req.headers.get('authorization'),
    raw,
  );
  return reply(out.status, out.body);
});
