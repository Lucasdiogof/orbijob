import { createHmac } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { env } from 'node:process';
import { beforeAll, describe, expect, it } from 'vitest';
import { acquireLease, type RunLedger } from '../../src/lease';
import { SupabaseJobStore } from '../../src/store/supabase';

/**
 * MEASURES the mutual exclusion between concurrent Workers on a REAL PostgREST (CI job `worker-postgrest`).
 *
 *  - "legacy": the first design, kept here only to be measured: read, insert a row with a random id, read again (twice, with a
 *    pause), the oldest row by (started_at, id) wins. It is optimistic: every step is a separate request on its own connection.
 *  - "atomic": the current acquireLease: the id of the run is derived from (source, hour) and sync_runs.id is a PRIMARY KEY, so
 *    PostgreSQL itself lets exactly one insert succeed.
 *
 * The atomic result is asserted: exactly one winner in EVERY round. The legacy result is only reported (a notice annotation with
 * the histogram), because it is evidence about the old design, not a requirement. Two throw-away sources keep it away from jobicy.
 */
const URL_ = env.POSTGREST_URL;
const SECRET = env.POSTGREST_JWT_SECRET;
const ROUNDS = 20;
const CONTENDERS = 10;

const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');
const sign = (role: string) => {
  const h = b64({ alg: 'HS256', typ: 'JWT' });
  const p = b64({ role, exp: Math.floor(Date.now() / 1000) + 3600 });
  return `${h}.${p}.${createHmac('sha256', SECRET ?? '').update(`${h}.${p}`).digest('base64url')}`;
};
const direct: typeof fetch = (input, init) => fetch(String(input).replace('/rest/v1/', '/'), init);

/** The first design, verbatim in behaviour (see git history of src/lease.ts), minus the unrelated cleanup of stale rows. */
async function legacyAcquire(ledger: RunLedger, o: { sourceId: string; now: Date; settleMs: number }): Promise<'acquired' | 'skipped'> {
  const now = o.now.getTime();
  const t = (iso: string) => Date.parse(iso);
  const live = (await ledger.runningRuns(o.sourceId)).filter((r) => now - t(r.started_at) < 20 * 60_000);
  if (live.length) return 'skipped';
  const recent = await ledger.finishedSince(o.sourceId, new Date(now - 60 * 60_000 + 1).toISOString(), '9999-12-31T00:00:00.000Z'); // the first design had no upper bound
  if (recent.length) return 'skipped';
  const id = await ledger.beginRun({ source_id: o.sourceId, scope: '', started_at: o.now.toISOString() }); // random id: nothing can refuse it
  const before = (a: { id: string; started_at: string }, b: { id: string; started_at: string }) => t(a.started_at) < t(b.started_at) || (t(a.started_at) === t(b.started_at) && a.id < b.id);
  const stillFirst = async () => {
    const after = (await ledger.runningRuns(o.sourceId)).filter((r) => now - t(r.started_at) < 20 * 60_000);
    const mine = after.find((r) => r.id === id);
    return !!mine && !after.some((r) => r.id !== id && before(r, mine));
  };
  const ok = (await stillFirst()) && (await new Promise((r) => setTimeout(r, o.settleMs)), await stillFirst());
  if (!ok) { await ledger.finishRun(id, { status: 'failed', error_class: 'lost_lease' }); return 'skipped'; }
  await ledger.finishRun(id, { status: 'ok' }); // finished at once so later rounds start clean
  return 'acquired';
}

describe.skipIf(!URL_ || !SECRET)('mutual exclusion between concurrent runs, measured on a real PostgREST', () => {
  const svc = sign('service_role');
  const store = new SupabaseJobStore(URL_ ?? 'http://localhost:3000', svc, direct);
  const SRC = { atomic: 'stress-atomic', legacy: 'stress-legacy' } as const;
  const report: Record<string, Record<string, unknown>> = { atomic: {}, legacy: {} };

  beforeAll(async () => {
    // the two throw-away sources are created by the OWNER (CI seeds them as postgres): service_role cannot create sources
    for (const id of Object.values(SRC)) {
      const r = await fetch(`${URL_}/job_sources?select=id&id=eq.${id}`, { headers: { Authorization: `Bearer ${svc}` } });
      expect(await r.json(), `source ${id} must be seeded by the owner before the tests`).toEqual([{ id }]);
    }
  });

  /** variant "tie": every contender has the same clock reading; "skew": each one reads its clock 0-40 ms apart, like real instances. */
  const variants = [{ name: 'tie', skew: 0 }, { name: 'skew', skew: 40 }];

  for (const v of variants) {
    it(`ATOMIC claim (${v.name} clock): ${ROUNDS} rounds x ${CONTENDERS} contenders, EXACTLY one winner in every round`, async () => {
      const hist: Record<number, number> = {};
      for (let round = 0; round < ROUNDS; round++) {
        const base = Date.UTC(2028, v.name === 'tie' ? 0 : 6, 1, round * 2); // a distinct hour per round, 2 hours apart
        const res = await Promise.all(Array.from({ length: CONTENDERS }, async (_, i) => {
          const now = new Date(base + (v.skew ? Math.floor((i * 37) % v.skew) : 0));
          const r = await acquireLease(store, { sourceId: SRC.atomic, scope: '', now });
          if (r.kind === 'acquired') await store.finishRun(r.id, { status: 'ok' });
          return r;
        }));
        const winners = res.filter((r) => r.kind === 'acquired').length;
        hist[winners] = (hist[winners] ?? 0) + 1;
        expect(winners, `round ${round}`).toBe(1);
      }
      report.atomic![v.name] = { rounds: ROUNDS, contenders: CONTENDERS, winnersPerRound: hist };
    }, 120_000);

    it(`LEGACY optimistic lease (${v.name} clock): measured, reported, not asserted`, async () => {
      const hist: Record<number, number> = {};
      for (let round = 0; round < ROUNDS; round++) {
        const base = Date.UTC(2027, v.name === 'tie' ? 0 : 6, 1, round * 2);
        const res = await Promise.all(Array.from({ length: CONTENDERS }, (_, i) => {
          const now = new Date(base + (v.skew ? Math.floor((i * 37) % v.skew) : 0));
          return legacyAcquire(store, { sourceId: SRC.legacy, now, settleMs: 100 });
        }));
        const winners = res.filter((r) => r === 'acquired').length;
        hist[winners] = (hist[winners] ?? 0) + 1;
      }
      report.legacy![v.name] = { rounds: ROUNDS, contenders: CONTENDERS, winnersPerRound: hist };
      expect(Object.keys(hist).length).toBeGreaterThan(0);
    }, 180_000);
  }

  it('writes the measurement for the CI annotations', () => {
    writeFileSync('lease-stress.json', JSON.stringify(report, null, 2));
    expect(Object.keys(report.atomic!)).toEqual(['tie', 'skew']);
  });
});
