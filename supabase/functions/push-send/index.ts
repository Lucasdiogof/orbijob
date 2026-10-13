// Edge Function `push-send`: copies new in-app notifications to the person's devices through Firebase Cloud Messaging.
//
// Called every hour by pg_cron (scripts/supabase/ops/enable_push_cron.sql) with the shared secret PUSH_CRON_SECRET in `x-push-secret`; deployed
// without JWT verification because the scheduler has no user. Reads the database through the project's internal connection (SUPABASE_DB_URL),
// as the owner, and only through ops.push_claim / ops.push_forget_tokens (migration 20261024000000).
// Secrets: PUSH_CRON_SECRET (random, also in Vault) and FCM_SERVICE_ACCOUNT (the Firebase service-account JSON). Without the latter it answers
// `not_configured` and touches nothing.
import postgres from 'npm:postgres@3.4.5';
import { accessToken, parseServiceAccount, type PushRow, sameSecret, sendAll } from './core.ts';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'method' });
  if (!sameSecret(req.headers.get('x-push-secret'), Deno.env.get('PUSH_CRON_SECRET'))) return json(401, { error: 'unauthorised' });
  const sa = parseServiceAccount(Deno.env.get('FCM_SERVICE_ACCOUNT'));
  if (!sa) return json(200, { status: 'not_configured' });
  const dbUrl = Deno.env.get('SUPABASE_DB_URL');
  if (!dbUrl) return json(500, { error: 'no database url' });

  const sql = postgres(dbUrl, { max: 1, prepare: false });
  try {
    // Claim first: a row is marked even if Google is down, so a person never gets an hour-old burst later (the bell still has it).
    const rows = (await sql`select * from ops.push_claim(200)`) as unknown as PushRow[];
    if (rows.length === 0) return json(200, { status: 'ok', claimed: 0, sent: 0, failed: 0, forgotten: 0 });
    const token = await accessToken(sa, fetch, Math.floor(Date.now() / 1000));
    const s = await sendAll(fetch, token, sa.project_id, rows);
    if (s.forgotten.length) await sql`select ops.push_forget_tokens(${s.forgotten})`;
    return json(200, { status: 'ok', claimed: s.claimed, sent: s.sent, failed: s.failed, forgotten: s.forgotten.length });
  } catch (e) {
    return json(500, { error: e instanceof Error ? e.message.slice(0, 200) : 'error' });
  } finally {
    await sql.end({ timeout: 5 });
  }
});
