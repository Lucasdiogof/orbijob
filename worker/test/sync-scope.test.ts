import { describe, expect, it } from 'vitest';
import { runSync, toJobRow, type JobRow, type JobStore, type SyncRunRow } from '../src/sync';
import type { Connector, NormalizedJob } from '../src/types';

const job = (company: string, id: string): NormalizedJob => ({
  source: 'lever', externalId: id, company, title: `Role ${id}`, description: '', country: null, city: null, language: null,
  workMode: 'unspecified', contractType: null, salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
  publishedAt: null, lastCheckedAt: '2026-10-10T00:00:00.000Z', requirements: [], skills: [], originalUrl: `https://example.test/${id}`,
  applyUrl: null, status: 'open', geoRestrictions: [],
});

class Store implements JobStore {
  rows = new Map<string, JobRow>();
  runs: SyncRunRow[] = [];
  async upsertJobs(rows: JobRow[]) { for (const r of rows) this.rows.set(r.external_id, { ...r }); }
  async listOpenExternalIds() { return [...this.rows.values()].filter((r) => r.status === 'open').map((r) => r.external_id); }
  async markClosed(_s: string, ids: string[]) { for (const id of ids) this.rows.get(id)!.status = 'closed'; }
  async recordRun(r: SyncRunRow) { this.runs.push(r); }
}

/** A per-company board like Lever: one source id, many scopes, each scope's page is a FULL snapshot of that company only. */
const perCompanyBoard = (boards: Record<string, NormalizedJob[]>): Connector => ({
  id: 'lever',
  minIntervalMs: 0,
  async fetchPage(_cursor, scope) { return { jobs: boards[scope] ?? [], nextCursor: null, isFullSnapshot: true }; },
});

const opts = { sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 } };

describe('closing jobs after a full snapshot of ONE scope', () => {
  it('syncing company A never closes the open jobs of company B (same source id)', async () => {
    const store = new Store();
    const a = [job('A', 'a1'), job('A', 'a2')];
    const b = [job('B', 'b1'), job('B', 'b2')];
    const conn = perCompanyBoard({ A: a, B: b });
    await runSync({ connector: conn, store, scope: 'A', ...opts });
    await runSync({ connector: conn, store, scope: 'B', ...opts });
    expect([...store.rows.values()].every((r) => r.status === 'open')).toBe(true);
    // company A syncs again: B's jobs were not in A's snapshot, but they are not A's to close
    const s = await runSync({ connector: conn, store, scope: 'A', ...opts });
    expect(s.closed).toBe(0);
    expect(store.rows.get('b1')!.status).toBe('open');
    expect(store.rows.get('b2')!.status).toBe('open');
  });

  it('a job that really disappeared from a source whose single scope IS the whole source is closed when the caller says so', async () => {
    const store = new Store();
    const boards = { all: [job('X', 'x1'), job('X', 'x2')] };
    const conn = perCompanyBoard(boards);
    await runSync({ connector: conn, store, scope: 'all', snapshotCoversSource: true, ...opts });
    boards.all = [job('X', 'x1')];
    const s = await runSync({ connector: conn, store, scope: 'all', snapshotCoversSource: true, ...opts });
    expect(s.closed).toBe(1);
    expect(store.rows.get('x2')!.status).toBe('closed');
    expect(store.rows.get('x1')!.status).toBe('open');
  });

  it('toJobRow is untouched by this (sanity)', () => {
    expect(toJobRow(job('A', 'a1')).source_id).toBe('lever');
  });
});
