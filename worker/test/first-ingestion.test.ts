import { describe, expect, it } from 'vitest';
// @ts-expect-error plain .mjs module without type declarations
import { EXPECTED_ATTRIBUTION, evaluatePreflight, evaluateVerification } from '../scripts/first-ingestion-checks.mjs';

const source = { id: 'jobicy', status: 'CONDITIONAL', can_redistribute: false, attribution: EXPECTED_ATTRIBUTION };
const job = (n: number, over: Record<string, unknown> = {}) => ({
  source_id: 'jobicy', external_id: String(n), original_url: `https://jobicy.com/jobs/${n}-x`, canonical_url: `https://jobicy.com/jobs/${n}-x`,
  fingerprint: `fp${n}`, description: 'plain text', ...over,
});
const run = { status: 'ok', finished_at: '2026-10-10T05:00:00Z', fetched: 3, upserted: 3, duplicates: 0, closed: 0, http_errors: 0, error_class: null };
const good = () => ({ source, runs: [run], jobs: [job(1), job(2), job(3)], otherSourceJobs: 0, anonJobs: 0 });

describe('first ingestion: preflight', () => {
  const ok = { keyKind: 'secret', source, jobsTotal: 0, syncRunsTotal: 0 };
  it('passes on the state the owner confirmed', () => expect(evaluatePreflight(ok).failures).toEqual([]));
  it.each([
    ['legacy service_role JWT', { keyKind: 'service_role_jwt' }],
    ['publishable key', { keyKind: 'publishable' }],
    ['source already published', { source: { ...source, can_redistribute: true } }],
    ['wrong status', { source: { ...source, status: 'READY' } }],
    ['missing source', { source: null }],
    ['jobs not empty', { jobsTotal: 1 }],
    ['sync_runs not empty', { syncRunsTotal: 1 }],
    ['changed attribution', { source: { ...source, attribution: 'x' } }],
  ])('refuses: %s', (_n, over) => expect(evaluatePreflight({ ...ok, ...over }).failures.length).toBeGreaterThan(0));
});

describe('first ingestion: verification', () => {
  it('passes on a clean pass', () => expect(evaluateVerification(good())).toEqual({ failures: [], warnings: [] }));
  it.each([
    ['source got published', { source: { ...source, can_redistribute: true } }],
    ['anon sees jobs', { anonJobs: 3 }],
    ['no jobs', { jobs: [] }],
    ['two run rows', { runs: [run, run] }],
    ['run failed', { runs: [{ ...run, status: 'failed', error_class: 'http_429' }] }],
    ['run left running', { runs: [{ ...run, status: 'running', finished_at: null }] }],
    ['foreign url', { jobs: [job(1, { original_url: 'https://evil.example/x' }), job(2), job(3)] }],
    ['http (not https) url', { jobs: [job(1, { canonical_url: 'http://jobicy.com/x' }), job(2), job(3)] }],
    ['lookalike host', { jobs: [job(1, { original_url: 'https://jobicy.com.evil.io/x' }), job(2), job(3)] }],
    ['html in description', { jobs: [job(1, { description: '<script>x</script>' }), job(2), job(3)] }],
    ['other source rows', { otherSourceJobs: 1 }],
    ['wrong source_id', { jobs: [job(1, { source_id: 'lever' }), job(2), job(3)] }],
  ])('fails: %s', (_n, over) => expect(evaluateVerification({ ...good(), ...over }).failures.length).toBeGreaterThan(0));
  it('a pass that stopped at the page cap (partial/max_pages) is the expected outcome: no failure, no warning', () => {
    expect(evaluateVerification({ ...good(), runs: [{ ...run, status: 'partial', error_class: 'max_pages' }] })).toEqual({ failures: [], warnings: [] });
  });
  it('warns when the public cannot read the source row (attribution would not show)', () => {
    expect(evaluateVerification({ ...good(), anonSourceVisible: false }).warnings.length).toBe(1);
  });
  it('only warns for a partial pass and repeated fingerprints', () => {
    const r = evaluateVerification({ ...good(), runs: [{ ...run, status: 'partial', http_errors: 1, error_class: 'http_500' }], jobs: [job(1), job(2, { fingerprint: 'fp1' }), job(3)] });
    expect(r.failures).toEqual([]);
    expect(r.warnings.length).toBe(2);
  });
});
