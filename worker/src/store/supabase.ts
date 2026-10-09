import { HttpError, parseRetryAfter } from '../http';
import type { JobRow, JobStore, SyncRunRow } from '../sync';

/**
 * JobStore over Supabase PostgREST with the SERVICE ROLE key. Server-side only (Cloudflare Worker): the key must never
 * reach the Flutter app, a log line or an error message.
 *
 * Needs, on the hosted project (none of it is applied by this code):
 *   - migration 20261013000000_service_role_grants.sql (service_role has no table privilege without it)
 *   - a `job_sources` row for the source (jobs.source_id is a foreign key)
 */
export class SupabaseJobStore implements JobStore {
  private readonly base: string;

  /**
   * @throws if [supabaseUrl] is not https (http is accepted only for localhost, used by tests): the service key is sent in
   * every request, so a mistyped or hostile URL must never receive it in clear text.
   */
  constructor(
    supabaseUrl: string,
    private readonly serviceKey: string,
    private readonly fetchImpl: typeof fetch = fetch,
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
        Authorization: `Bearer ${this.serviceKey}`,
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
