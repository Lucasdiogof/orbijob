import { HttpError, parseRetryAfter } from '../http';
import { RunConflict, type RunLedger, type RunPatch, type RunRef } from '../lease';
import type { JobRow, JobStore, SyncRunRow } from '../sync';

/**
 * JobStore over Supabase PostgREST with the SERVICE ROLE key. Server-side only (Cloudflare Worker): the key must never
 * reach the Flutter app, a log line or an error message.
 *
 * Needs, on the hosted project (none of it is applied by this code):
 *   - migration 20261013000000_service_role_grants.sql (service_role has no table privilege without it)
 *   - a `job_sources` row for the source (jobs.source_id is a foreign key)
 */
export class SupabaseJobStore implements JobStore, RunLedger {
  private readonly base: string;

  /**
   * @throws if [supabaseUrl] is not https (http is accepted only for localhost, used by tests): the service key is sent in
   * every request, so a mistyped or hostile URL must never receive it in clear text.
   */
  constructor(
    supabaseUrl: string,
    private readonly serviceKey: string,
    // an arrow, not `fetch` itself: in Workers a platform function called as a method of another object throws "Illegal invocation"
    private readonly fetchImpl: typeof fetch = (input, init) => fetch(input, init),
    private readonly timeoutMs = 20_000,
  ) {
    let u: URL;
    try { u = new URL(supabaseUrl); } catch { throw new Error('SupabaseJobStore: invalid URL'); }
    const local = ['localhost', '127.0.0.1', '[::1]'].includes(u.hostname);
    if (!(u.protocol === 'https:' || (u.protocol === 'http:' && local)) || u.username || u.password) {
      throw new Error('SupabaseJobStore: the URL must be https without credentials (http only for localhost)');
    }
    this.base = `${u.origin}/rest/v1`;
  }

  private async call(path: string, init: { method: string; body?: unknown; prefer?: string }): Promise<Response> {
    const res = await this.fetchImpl(`${this.base}/${path}`, {
      method: init.method,
      headers: {
        apikey: this.serviceKey,
        // New-style keys (sb_secret_...) are not JWTs and Supabase says to send them ONLY in `apikey`: in Authorization they
        // fail JWT verification. A classic service_role JWT (and a direct PostgREST) needs the Bearer header.
        ...(isJwt(this.serviceKey) ? { Authorization: `Bearer ${this.serviceKey}` } : {}),
        'Content-Type': 'application/json',
        Accept: 'application/json',
        ...(init.prefer ? { Prefer: init.prefer } : {}),
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    // Only the status leaves this class: the response body can echo row content.
    if (!res.ok) throw new HttpError(res.status, parseRetryAfter(res.headers.get('retry-after')));
    return res;
  }

  async upsertJobs(rows: JobRow[]): Promise<void> {
    for (const chunk of chunkRows(rows)) {
      await this.call('jobs?on_conflict=source_id,external_id', {
        method: 'POST',
        body: chunk,
        prefer: 'resolution=merge-duplicates,return=minimal',
      });
    }
  }

  async listOpenExternalIds(sourceId: string): Promise<string[]> {
    const ids: string[] = [];
    const pageSize = 1000;
    for (let offset = 0; ; offset += pageSize) {
      const res = await this.call(
        `jobs?select=external_id&source_id=eq.${encodeURIComponent(sourceId)}&status=eq.open&order=external_id&limit=${pageSize}&offset=${offset}`,
        { method: 'GET' },
      );
      const page = (await res.json()) as { external_id: string }[];
      ids.push(...page.map((r) => r.external_id));
      if (page.length < pageSize) return ids;
    }
  }

  async markClosed(sourceId: string, externalIds: string[]): Promise<void> {
    for (let i = 0; i < externalIds.length; i += 100) {
      const list = externalIds.slice(i, i + 100).map((id) => encodeURIComponent(`"${id.replace(/"/g, '')}"`)).join(',');
      await this.call(`jobs?source_id=eq.${encodeURIComponent(sourceId)}&external_id=in.(${list})`, {
        method: 'PATCH',
        body: { status: 'closed', last_checked_at: new Date().toISOString() },
        prefer: 'return=minimal',
      });
    }
  }

  async recordRun(run: SyncRunRow): Promise<void> {
    await this.call('sync_runs', { method: 'POST', body: run, prefer: 'return=minimal' });
  }

  // ───────── RunLedger: the run record doubles as the lease (see lease.ts) ─────────

  async runningRuns(sourceId: string): Promise<RunRef[]> {
    const res = await this.call(
      `sync_runs?select=id,status,started_at,error_class&source_id=eq.${encodeURIComponent(sourceId)}&status=eq.running&order=started_at.asc&limit=50`,
      { method: 'GET' },
    );
    return (await res.json()) as RunRef[];
  }

  async finishedSince(sourceId: string, sinceIso: string, untilIso: string): Promise<RunRef[]> {
    const res = await this.call(
      `sync_runs?select=id,status,started_at,error_class&source_id=eq.${encodeURIComponent(sourceId)}&status=neq.running&started_at=gte.${encodeURIComponent(sinceIso)}&started_at=lte.${encodeURIComponent(untilIso)}&order=started_at.desc&limit=50`,
      { method: 'GET' },
    );
    return (await res.json()) as RunRef[];
  }

  async beginRun(row: { id?: string; source_id: string; scope: string; started_at: string }): Promise<string> {
    if (row.id !== undefined && !UUID.test(row.id)) throw new Error('SupabaseJobStore: invalid run id');
    // Plain INSERT (no merge-duplicates): with an explicit id that already exists PostgreSQL refuses it (unique violation,
    // HTTP 409 through PostgREST). That refusal is the mutual exclusion between Worker instances.
    const res = await this.call('sync_runs?select=id', {
      method: 'POST',
      body: { ...row, status: 'running' },
      prefer: 'return=representation',
    }).catch((e) => { throw e instanceof HttpError && e.status === 409 ? new RunConflict() : e; });
    const id = ((await res.json()) as { id?: unknown }[])[0]?.id;
    if (typeof id !== 'string' || !UUID.test(id)) throw new Error('SupabaseJobStore: the run id was not returned');
    return id;
  }

  async finishRun(id: string, patch: RunPatch): Promise<void> {
    if (!UUID.test(id)) throw new Error('SupabaseJobStore: invalid run id');
    await this.call(`sync_runs?id=eq.${id}`, { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** True for a three-part JWT (the legacy service_role key); false for `sb_secret_...` keys. */
export function isJwt(key: string): boolean {
  return /^eyJ[\w-]+\.[\w-]+\.[\w-]+$/.test(key);
}

/** At most [maxRows] rows and about [maxChars] characters of JSON per request: a hundred long descriptions must not make one huge body. */
export function chunkRows(rows: JobRow[], maxRows = 100, maxChars = 400_000): JobRow[][] {
  const out: JobRow[][] = [];
  let cur: JobRow[] = [];
  let size = 0;
  for (const r of rows) {
    const n = JSON.stringify(r).length;
    if (cur.length && (cur.length >= maxRows || size + n > maxChars)) { out.push(cur); cur = []; size = 0; }
    cur.push(r);
    size += n;
  }
  if (cur.length) out.push(cur);
  return out;
}
