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
  constructor(
    supabaseUrl: string,
    private readonly serviceKey: string,
    private readonly fetchImpl: typeof fetch = fetch,
    private readonly timeoutMs = 20_000,
  ) {
    this.base = `${supabaseUrl.replace(/\/+$/, '')}/rest/v1`;
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
    for (let i = 0; i < rows.length; i += 100) {
      await this.call('jobs?on_conflict=source_id,external_id', {
        method: 'POST',
        body: rows.slice(i, i + 100),
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
