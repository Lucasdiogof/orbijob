import { describe, expect, it } from 'vitest';
import { arbeitnowConnector, arbeitnowStatedCountry, arbeitnowStatedEligibility, normalizeArbeitnow, normalizeRemoteOk, normalizeRemotive, remoteOkConnector, remotiveConnector, repairMojibake } from '../src/connectors/feeds';
import { HttpError } from '../src/http';
import { runScheduledSync } from '../src/scheduled';
import { SOURCES, SOURCE_IDS } from '../src/sources';
import { runSync, type JobRow, type JobStore, type KnownKey } from '../src/sync';
import arbeitnow from './fixtures/arbeitnow-feed.sanitized.json';
import remoteok from './fixtures/remoteok-feed.sanitized.json';
import remotive from './fixtures/remotive-feed.sanitized.json';
import { World } from './helpers/world';

// Fixtures are real payloads of the three feeds (read 2026-10-12, one request each), descriptions truncated and addresses scrubbed.
const NOW = '2026-10-12T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const html = () => new Response('<!DOCTYPE html><html><title>Just a moment...</title></html>', { status: 403, headers: { 'content-type': 'text/html' } });
const ok = <T extends { ok: boolean }>(r: T) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return (r as unknown as { job: import('../src/types').NormalizedJob }).job; };

describe('Arbeitnow normalizer (real payloads)', () => {
  it('maps a listing without inventing anything: the country only from a place only one country has, no salary, no language; the mode only when the feed says remote', () => {
    const rows = arbeitnow.data.map((r) => ok(normalizeArbeitnow(r, NOW)));
    for (const j of rows) {
      expect(j.source).toBe('arbeitnow');
      expect(j).toMatchObject({ country: 'DE', salaryMin: null, salaryCurrency: null, language: null, status: 'open', geoRestrictions: [], lastCheckedAt: NOW }); // Hamburg, Berlin, München, Munich: only Germany has them
      expect(new URL(j.originalUrl).hostname).toBe('www.arbeitnow.com');
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.company).not.toBe('');
      expect(j.description).not.toMatch(/<[a-z/][^>]*>/i);
    }
    expect(rows.filter((j) => j.workMode === 'remote')).toHaveLength(2);
    expect(rows.filter((j) => j.workMode === 'unspecified')).toHaveLength(6); // "remote: false" is not "on site"
    expect(rows[0]).toMatchObject({ title: 'Systemadministrator (m/w/d)', city: 'Hamburg' });
    expect(rows[0]!.contractType).toContain('Full time');
    expect(rows[0]!.publishedAt).toMatch(/^2026-/);
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const good = { ...arbeitnow.data[0] } as Record<string, unknown>;
    const r = (over: Record<string, unknown>) => normalizeArbeitnow({ ...good, ...over }, NOW);
    expect(r({ slug: '' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ slug: '../x y' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ title: '  ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ company_name: '' })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(r({ url: 'https://evil.example/jobs/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'http://www.arbeitnow.com/jobs/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://user:pw@www.arbeitnow.com/jobs/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(r({ url: 'https://www.arbeitnow.com.evil.io/jobs/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    for (const h of ['www.arbeitnow.co.uk', 'www.arbeitnow.fr', 'www.arbeitnow.ch', 'www.arbeitnow.nl']) expect(r({ url: `https://${h}/jobs/1` })).toMatchObject({ ok: true });
    expect(r({ url: 'https://www.arbeitnow.de/jobs/1' })).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeArbeitnow(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeArbeitnow('x', NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });

  it('paginates by page number, follows links.next, and stops on the last page', async () => {
    const seen: string[] = [];
    const c = arbeitnowConnector(async (u) => {
      const page = new URL(String(u)).searchParams.get('page');
      seen.push(page!);
      return json({ ...arbeitnow, links: { next: page === '3' ? null : 'x' } });
    }, nowFn);
    let cur: string | null = null;
    let jobs = 0;
    do { const p = await c.fetchPage(cur, ''); jobs += p.jobs.length; cur = p.nextCursor; } while (cur);
    expect(seen).toEqual(['1', '2', '3']);
    expect(jobs).toBe(24);
    expect(c.presenceConfirmsOpen).toBe(true);
    expect(c.minIntervalMs).toBeGreaterThanOrEqual(4000);
  });

  it('a bot challenge (HTML) is a non-retryable 403: one request, then the pass stops and nothing is written or retried', async () => {
    let calls = 0;
    const c = arbeitnowConnector(async () => { calls++; return html(); }, nowFn);
    await expect(c.fetchPage(null, '')).rejects.toMatchObject({ status: 403 });
    const w = new World();
    let hits = 0;
    w.hosts['www.arbeitnow.com'] = () => { hits++; return html(); };
    const out = await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow' }), w.deps({ retry: { retries: 4, baseMs: 1, maxMs: 1 } }));
    expect(out).toMatchObject({ status: 'failed', summary: { error_class: 'http_403', upserted: 0 } });
    expect(hits).toBe(1); // 403 is never retried: a gate is not hammered
    expect(calls).toBe(1);
    expect(w.jobs.size).toBe(0);
  });

  it('a 200 answer that is not JSON is treated the same way', async () => {
    const c = arbeitnowConnector(async () => new Response('<html>nope</html>', { status: 200 }), nowFn);
    await expect(c.fetchPage(null, '')).rejects.toBeInstanceOf(HttpError);
  });

  it('refuses a malformed cursor and an unexpected body', async () => {
    const c = arbeitnowConnector(async () => json({ nothing: true }), nowFn);
    await expect(c.fetchPage('abc', '')).rejects.toThrow(/invalid cursor/);
    await expect(c.fetchPage('2', '')).rejects.toThrow(/unexpected response/);
  });
});

describe('Remote OK normalizer and connector (real payloads)', () => {
  it('skips the legal notice, keeps the link back to Remote OK, never invents a salary, repairs doubly-encoded text', async () => {
    const c = remoteOkConnector(async () => json(remoteok), nowFn);
    const p = await c.fetchPage(null, '');
    expect(p.jobs).toHaveLength(6);
    expect(p.rejected).toEqual([]);
    expect(p.nextCursor).toBeNull();
    for (const j of p.jobs) {
      expect(j.source).toBe('remoteok');
      expect(new URL(j.originalUrl).hostname).toBe('remoteok.com'); // "remoteOK.com" in the feed, normalised
      expect(j).toMatchObject({ workMode: 'remote', salaryMin: null, salaryCurrency: null, status: 'open' });
    }
    const mx = p.jobs.find((j) => j.externalId === '1137482')!;
    expect(mx.country).toBeNull();
    expect(mx.geoRestrictions.join(' ')).toContain('México'); // the feed said "MÃ©xico"
    expect(p.jobs.find((j) => j.externalId === '1137481')!.geoRestrictions).toEqual([]); // empty location = eligibility unknown
  });

  it('repairMojibake touches only text that is provably doubly encoded', () => {
    expect(repairMojibake('Ciudad de MÃ©xico')).toBe('Ciudad de México');
    expect(repairMojibake('São Paulo')).toBe('São Paulo'); // already correct: unchanged
    expect(repairMojibake('Ã©Ã')).toBe('Ã©Ã'); // not valid UTF-8 once decoded: left as received
    expect(repairMojibake('日本')).toBe('日本');
    expect(repairMojibake('plain')).toBe('plain');
  });

  it('rejects a bad id, a missing title or company, and a link that is not on remoteok.com', () => {
    const good = { ...remoteok[1] } as Record<string, unknown>;
    const r = (over: Record<string, unknown>) => normalizeRemoteOk({ ...good, ...over }, NOW);
    expect(r({ id: 'abc' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ position: '' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ company: '' })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(r({ url: 'https://example.com/x' })).toMatchObject({ ok: false, reason: 'invalid_url' });
  });
});

describe('Remotive normalizer and connector (real payloads)', () => {
  it('reads the documented fields: contract type mapped, worldwide as the explicit marker, countries mapped, free-text salary NOT parsed', async () => {
    const c = remotiveConnector(async () => json(remotive), nowFn);
    const p = await c.fetchPage(null, '');
    expect(p.jobs).toHaveLength(6);
    const byId = new Map(p.jobs.map((j) => [j.externalId, j]));
    expect(byId.get('2086540')).toMatchObject({ contractType: 'Full-Time', geoRestrictions: ['Anywhere'], country: null, workMode: 'remote', salaryMin: null });
    expect(byId.get('2091149')!.geoRestrictions).toEqual(expect.arrayContaining(['US', 'GB', 'IN', 'AU', 'IE', 'NZ', 'PH', 'PK', 'SG', 'MX']));
    expect(byId.get('1185979')!.contractType).toBe('Freelance');
    expect(byId.get('2091133')!.geoRestrictions).toEqual(expect.arrayContaining(['Europe', 'US', 'CA', 'APAC']));
    expect(new URL(byId.get('2086540')!.originalUrl).hostname).toBe('remotive.com');
    expect(c.minIntervalMs).toBeGreaterThanOrEqual(30_000); // the README blocks more than 2 requests a minute
  });

  it('rejects an invalid record without stopping the page', async () => {
    const bad = { ...remotive, jobs: [...remotive.jobs, { id: 'x', title: 't' }, { ...remotive.jobs[0], url: 'https://evil.example/j' }] };
    const p = await remotiveConnector(async () => json(bad), nowFn).fetchPage(null, '');
    expect(p.jobs).toHaveLength(6);
    expect(p.rejected!.map((x) => x.reason).sort()).toEqual(['invalid_id', 'invalid_url']);
  });
});

describe('source registry', () => {
  it('every source names itself and links to its own host (their terms ask for a link back), and has sane caps', () => {
    expect(SOURCE_IDS.sort()).toEqual(['arbeitnow', 'bpce', 'csp', 'forem', 'getonboard', 'jobicy', 'jobsconz', 'jobtech', 'karrierenrw', 'mpsvcz', 'nycjobs', 'remoteok', 'remotive', 'sefmurcia', 'teachingvacancies', 'twjobs']);
    for (const s of Object.values(SOURCES)) {
      expect(s.attribution).toContain(`https://`);
      expect(s.attribution).toContain(s.host.replace(/^www\./, ''));
      expect(s.newCap).toBeGreaterThan(0);
      expect(s.catalogue).toBeGreaterThanOrEqual(s.newCap);
      expect(s.maxPages).toBeGreaterThanOrEqual(1);
      expect(s.make(async () => json({}), nowFn).id).toBe(s.id);
    }
  });
});

// ───────── discover over a source WITHOUT a status endpoint ─────────

class MemoryStore implements JobStore {
  rows = new Map<string, JobRow & { status: string }>();
  stamped: string[][] = [];
  async upsertJobs(): Promise<void> { throw new Error('discover must never upsert'); }
  async listOpenExternalIds() { return []; }
  async markClosed(): Promise<void> { throw new Error('discover must never close'); }
  async recordRun() {}
  async listKnownKeys(): Promise<KnownKey[]> {
    return [...this.rows.values()].map((r) => ({ external_id: r.external_id, fingerprint: r.fingerprint, canonical_url: r.canonical_url, status: r.status as KnownKey['status'] }));
  }
  async countFullJobs() { return [...this.rows.values()].filter((r) => r.status !== 'closed' || r.description !== '').length; }
  async insertNewJobs(rows: JobRow[]) { let n = 0; for (const r of rows) if (!this.rows.has(r.external_id)) { this.rows.set(r.external_id, { ...r, status: 'open' }); n++; } return n; }
  async confirmOpen(_s: string, ids: string[]) { this.stamped.push(ids); }
}
const arbConnector = (jobs = arbeitnow.data) => arbeitnowConnector(async () => json({ data: jobs, links: { next: null } }), nowFn);
const run = (store: MemoryStore, over: Partial<Parameters<typeof runSync>[0]> = {}) =>
  runSync({ connector: arbConnector(), store, mode: 'discover', now: nowFn, sleep: async () => {}, retry: { retries: 0, baseMs: 1, maxMs: 1 }, recordRun: async () => {}, ...over });

describe('discover without a status endpoint (feed presence is the evidence)', () => {
  it('inserts the new listings with no status request, and stamps nothing on a first pass', async () => {
    const s = new MemoryStore();
    const out = await run(s);
    expect(out).toMatchObject({ status: 'ok', fetched: 8, upserted: 8, alreadyKnown: 0, confirmed: 0, inactive: 0 });
    expect(s.rows.size).toBe(8);
    expect(s.stamped).toEqual([]);
  });

  it('a second pass inserts nothing and stamps the open ones it still sees; it never touches content', async () => {
    const s = new MemoryStore();
    await run(s);
    const before = JSON.stringify([...s.rows.entries()]);
    const out = await run(s);
    expect(out).toMatchObject({ status: 'ok', upserted: 0, alreadyKnown: 8, confirmed: 8 });
    expect(s.stamped).toHaveLength(1);
    expect(s.stamped[0]).toHaveLength(8);
    expect(JSON.stringify([...s.rows.entries()])).toBe(before);
  });

  it('reaching the reading window of a newest-first feed ends ok (pageWindow); without it the page cap is partial', async () => {
    const endless = arbeitnowConnector(async (u) => json({ data: arbeitnow.data.map((r) => ({ ...r, slug: `${r.slug}-${new URL(String(u)).searchParams.get('page')}` })), links: { next: 'more' } }), nowFn);
    expect(await run(new MemoryStore(), { connector: endless, maxPages: 2, pageWindow: true })).toMatchObject({ status: 'ok', pages: 2, upserted: 8, duplicates: 8 });
    expect((await run(new MemoryStore(), { connector: endless, maxPages: 2, pageWindow: true })).error_class).not.toBe('max_pages');
    expect(await run(new MemoryStore(), { connector: endless, maxPages: 2 })).toMatchObject({ status: 'partial', pages: 2, error_class: 'max_pages' });
    expect(SOURCES.arbeitnow!.pageWindow).toBe(true);
    expect(SOURCES.jobicy!.pageWindow).toBeUndefined();
  });

  it('a stored job that is closed is not stamped and not re-opened even if the feed still lists it', async () => {
    const s = new MemoryStore();
    await run(s);
    const closedId = [...s.rows.keys()][0]!;
    s.rows.get(closedId)!.status = 'closed';
    s.stamped = [];
    await run(s);
    expect(s.stamped[0]).not.toContain(closedId);
    expect(s.rows.get(closedId)!.status).toBe('closed');
  });

  it('a job that left the feed is simply not stamped (the app hides it after 72 h; expire_unseen_jobs closes it later)', async () => {
    const s = new MemoryStore();
    await run(s);
    s.stamped = [];
    await run(s, { connector: arbConnector(arbeitnow.data.slice(0, 3)) });
    expect(s.stamped[0]).toHaveLength(3);
  });

  it('a source with neither a status endpoint nor feed-presence evidence is refused (nothing could justify importing)', async () => {
    const s = new MemoryStore();
    const c = { ...arbConnector(), presenceConfirmsOpen: false };
    const out = await run(s, { connector: c });
    expect(out).toMatchObject({ status: 'failed', error_class: 'discover_unverifiable', upserted: 0 });
    expect(s.rows.size).toBe(0);
  });

  it('the per-pass cap and the full-job ceiling apply to every source', async () => {
    const capped = new MemoryStore();
    expect(await run(capped, { maxNewJobs: 3 })).toMatchObject({ upserted: 3, skippedNew: 5 });
    const ceiling = new MemoryStore();
    expect(await run(ceiling, { maxTotalJobs: 5 })).toMatchObject({ status: 'partial', upserted: 5, error_class: 'catalogue_full' });
  });
});

// ───────── the whole pass: lease + store + connector, per source ─────────

describe('SYNC_SOURCE through the scheduled pass', () => {
  const feedHost = (w: World, jobs = arbeitnow.data) => { w.hosts['www.arbeitnow.com'] = () => json({ data: jobs, links: { next: null } }); };
  const rows = (w: World, source: string) => [...w.jobs.values()].filter((j) => j.source_id === source);

  it('imports an Arbeitnow listing under its own source id, with its own run row and attribution link', async () => {
    const w = new World();
    feedHost(w);
    const out = await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow' }), w.deps());
    expect(out).toMatchObject({ status: 'ok', summary: { upserted: 8 } });
    expect(rows(w, 'arbeitnow')).toHaveLength(8);
    expect(rows(w, 'jobicy')).toHaveLength(0);
    expect(w.runs[0]).toMatchObject({ source_id: 'arbeitnow', scope: 'discover', status: 'ok', upserted: 8 });
    for (const j of rows(w, 'arbeitnow')) expect(String(j.original_url)).toMatch(/^https:\/\/www\.arbeitnow\.com\//);
  });

  it('leases are per source: a Jobicy pass in the same hour does not block Arbeitnow, and each blocks only itself', async () => {
    const w = new World();
    feedHost(w);
    expect((await runScheduledSync(w.env({ SYNC_MODE: 'discover' }), w.deps())).status).toBe('ok'); // Jobicy
    expect((await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow' }), w.deps())).status).toBe('ok');
    expect(await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow' }), w.deps())).toEqual({ status: 'skipped', reason: 'too_soon' });
    expect(await runScheduledSync(w.env({ SYNC_MODE: 'discover' }), w.deps())).toEqual({ status: 'skipped', reason: 'too_soon' });
  });

  it('the second pass stamps what is still listed and never changes the stored content', async () => {
    const w = new World();
    feedHost(w);
    await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow' }), w.deps());
    const content = () => JSON.stringify(rows(w, 'arbeitnow').map((j) => ({ ...j, last_checked_at: undefined })));
    const before = content();
    w.clock = new Date(w.clock.getTime() + 6 * 3_600_000);
    const out = await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow' }), w.deps());
    expect(out).toMatchObject({ status: 'ok', summary: { upserted: 0, confirmed: 8, alreadyKnown: 8 } });
    expect(content()).toBe(before);
    // the store stamps with the real clock (the injected one only drives the lease): every date moved forward from the first pass
    expect(rows(w, 'arbeitnow').every((j) => Date.parse(String(j.last_checked_at)) > Date.parse('2026-10-10T12:00:00.000Z'))).toBe(true);
  });

  it('refuses an unknown SYNC_SOURCE and a non-local SOURCE_API_URL; the defaults of a source come from its profile', async () => {
    const w = new World();
    await expect(runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'indeed' }), w.deps())).rejects.toThrow(/SYNC_SOURCE/);
    await expect(runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow', SOURCE_API_URL: 'https://evil.example' }), w.deps())).rejects.toThrow(/SOURCE_API_URL/);
    const { loadConfig } = await import('../src/env');
    const cfg = loadConfig(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow' }));
    expect(cfg).toMatchObject({ source: 'arbeitnow', maxPages: SOURCES.arbeitnow!.maxPages, maxNewJobs: SOURCES.arbeitnow!.newCap, maxCatalogue: SOURCES.arbeitnow!.catalogue });
  });

  it('revalidate mode stays Jobicy-only in effect: a source without a status endpoint fails that mode instead of closing anything', async () => {
    const w = new World();
    feedHost(w);
    await runScheduledSync(w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'arbeitnow' }), w.deps());
    w.clock = new Date(w.clock.getTime() + 3 * 3_600_000);
    const out = await runScheduledSync(w.env({ SYNC_MODE: 'revalidate', SYNC_SOURCE: 'arbeitnow' }), w.deps());
    expect(out).toMatchObject({ status: 'failed', summary: { error_class: 'no_status_check', closed: 0 } });
    expect(rows(w, 'arbeitnow').every((j) => j.status === 'open')).toBe(true);
  });
});

describe('Arbeitnow: a country only when the location states it (or names a place only one country has)', () => {
  it('reads the country written at the end of the location, in English or the local name', () => {
    expect(arbeitnowStatedCountry('München, Bayern, Germany', 'https://www.arbeitnow.com/jobs/a')).toBe('DE');
    expect(arbeitnowStatedCountry('Köln, Deutschland', 'https://www.arbeitnow.com/jobs/a')).toBe('DE');
    expect(arbeitnowStatedCountry('Zurich, Switzerland', 'https://www.arbeitnow.ch/jobs/a')).toBe('CH');
    expect(arbeitnowStatedCountry('Lyon, France', 'https://www.arbeitnow.fr/jobs/a')).toBe('FR');
    expect(arbeitnowStatedCountry('Manchester, United Kingdom', 'https://www.arbeitnow.co.uk/jobs/a')).toBe('GB');
  });
  it('a city, or a country, that only one country has is a stated place', () => {
    const u = 'https://www.arbeitnow.com/jobs/a';
    expect(arbeitnowStatedCountry('Berlin', u)).toBe('DE');
    expect(arbeitnowStatedCountry('München', u)).toBe('DE');
    expect(arbeitnowStatedCountry('Munich, Bavaria', u)).toBe('DE');
    expect(arbeitnowStatedCountry('Berlin Office', u)).toBe('DE');
    expect(arbeitnowStatedCountry('Frankfurt am Main', u)).toBe('DE');
    expect(arbeitnowStatedCountry('Paris, Paris', 'https://www.arbeitnow.fr/jobs/a')).toBe('FR');
    expect(arbeitnowStatedCountry('London, England, United Kingdom', 'https://www.arbeitnow.co.uk/jobs/a')).toBe('GB');
    expect(arbeitnowStatedCountry('Zürich', u)).toBe('CH');
    expect(arbeitnowStatedCountry('Germany', u)).toBe('DE');
    expect(arbeitnowStatedCountry('United Kingdom', 'https://www.arbeitnow.co.uk/jobs/a')).toBe('GB');
    expect(arbeitnowStatedCountry('Switzerland', 'https://www.arbeitnow.ch/jobs/a')).toBe('CH');
  });
  it('never guesses: a name two countries share, a mode, a code, several places, an unknown region or a contradiction with the regional site give nothing', () => {
    for (const [loc, url] of [
      ['Birmingham', 'https://www.arbeitnow.co.uk/jobs/a'],
      ['Manchester', 'https://www.arbeitnow.co.uk/jobs/a'],
      ['Cambridge', 'https://www.arbeitnow.co.uk/jobs/a'],
      ['Dublin', 'https://www.arbeitnow.com/jobs/a'],
      ['Saint-Denis', 'https://www.arbeitnow.fr/jobs/a'],
      ['Altendorf', 'https://www.arbeitnow.ch/jobs/a'],
      ['Remote', 'https://www.arbeitnow.com/jobs/a'],
      ['Remote Switzerland', 'https://www.arbeitnow.ch/jobs/a'],
      ['Homeoffice', 'https://www.arbeitnow.com/jobs/a'],
      ['Hamburg, DE', 'https://www.arbeitnow.com/jobs/a'],
      ['London, Cyprus', 'https://www.arbeitnow.co.uk/jobs/a'],
      ['Berlin, Texas', 'https://www.arbeitnow.com/jobs/a'],
      ['Berlin, Paris', 'https://www.arbeitnow.com/jobs/a'],
      ['Berlin, Germany, France', 'https://www.arbeitnow.com/jobs/a'],
      ['Northern Ireland; Birmingham; London, UK', 'https://www.arbeitnow.co.uk/jobs/a'],
      ['United States, Canada, Spain, Czech Republic', 'https://www.arbeitnow.com/jobs/a'],
      ['Basel, Switzerland, Germany', 'https://www.arbeitnow.com/jobs/a'],
      ['London', 'https://www.arbeitnow.fr/jobs/a'], // the French site contradicts it
      ['Paris', 'https://www.arbeitnow.co.uk/jobs/a'],
      ['', 'https://www.arbeitnow.com/jobs/a'],
    ] as const) expect(arbeitnowStatedCountry(loc, url), loc).toBeNull();
  });
  it('a list of country names is the eligibility of the job, never a single country', () => {
    expect(arbeitnowStatedEligibility('United States, Canada, Spain, Czech Republic')).toEqual(['US', 'CA', 'ES', 'CZ']);
    expect(arbeitnowStatedEligibility('Germany; Austria; Switzerland')).toEqual(['DE', 'AT', 'CH']);
    expect(arbeitnowStatedEligibility('Germany, Deutschland')).toEqual([]); // the same country twice is one country
    for (const loc of ['Berlin, Germany', 'Germany', 'Remote, Germany, France', 'Europe, Germany', '', 'Atlantis, Germany']) expect(arbeitnowStatedEligibility(loc), loc).toEqual([]);
    const r = normalizeArbeitnow({ ...arbeitnow.data[0], location: 'United States, Canada, Spain, Czech Republic', url: 'https://www.arbeitnow.com/jobs/x' }, NOW);
    expect(r).toMatchObject({ ok: true, job: { country: null, geoRestrictions: ['US', 'CA', 'ES', 'CZ'] } });
  });
  it('the normaliser stores it, and still keeps the location as written', () => {
    const r = normalizeArbeitnow({ ...arbeitnow.data[0], location: 'Leipzig, Sachsen, Germany', url: 'https://www.arbeitnow.com/jobs/x' }, NOW);
    expect(r).toMatchObject({ ok: true, job: { country: 'DE', city: 'Leipzig, Sachsen, Germany' } });
  });
});
