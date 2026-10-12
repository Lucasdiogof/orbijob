import { describe, expect, it } from 'vitest';
import { deadlineOf, normalizeTaiwanJob, taiwanJobsConnector } from '../src/connectors/taiwanjobs';
import { HttpError } from '../src/http';
import { runScheduledSync } from '../src/scheduled';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/taiwanjobs.sanitized.json';
import { World } from './helpers/world';

// Real records of the Taiwan Jobs open dataset (read 2026-10-12): 8 vacancies of 8 professional categories.
const NOW = '2026-10-12T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const recs = fixture.result.records as Record<string, string>[];
const ok = (r: ReturnType<typeof normalizeTaiwanJob>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const KEY = (code: string) => Object.keys(recs[0]!).find((k) => k.startsWith(code))!;
const withField = (rec: Record<string, string>, code: string, value: string) => ({ ...rec, [KEY(code)]: value });

describe('Taiwan Jobs normalizer (real records)', () => {
  it('maps every record without inventing anything: Taiwan from the national site, TWD salary only when method and amount are stated, original Chinese kept', () => {
    const jobs = recs.map((r) => ok(normalizeTaiwanJob(r, NOW)));
    expect(jobs).toHaveLength(8);
    for (const j of jobs) {
      expect(j.source).toBe('twjobs');
      expect(j).toMatchObject({ country: 'TW', language: null, workMode: 'unspecified', status: 'open', geoRestrictions: [], lastCheckedAt: NOW });
      expect(new URL(j.originalUrl).hostname).toBe('job.taiwanjobs.gov.tw');
      expect(j.externalId).toMatch(/^[0-9]{3,20}$/);
      expect(j.title).not.toBe('');
      expect(j.company).not.toBe('');
      expect(j.description).toContain('職務類別：');
      expect(j.publishedAt).toMatch(/^20\d\d-/);
    }
    expect(new Set(jobs.map((j) => j.externalId)).size).toBe(8);
    const priced = jobs.filter((j) => j.salaryMin !== null);
    expect(priced.length).toBeGreaterThan(0);
    for (const j of priced) expect(j).toMatchObject({ salaryCurrency: 'TWD', salaryPeriod: expect.stringMatching(/^(month|hour|day)$/) });
  });

  it('the title is the posting\'s own; without one it is the occupation category the record was filed under', () => {
    const base = recs[1]!;
    expect(ok(normalizeTaiwanJob(withField(base, 'OCCU_DESC', '資深業務經理'), NOW)).title).toBe('資深業務經理');
    const category = base[KEY('CJOB_NAME2')]!;
    expect(ok(normalizeTaiwanJob(withField(base, 'OCCU_DESC', ''), NOW)).title).toBe(category);
  });

  it('salary: month, hour and day are mapped; "by experience", per-piece and missing amounts stay empty; a range that is upside down is dropped', () => {
    const base = recs[1]!;
    const sal = (method: string, lo: string, hi: string) => ok(normalizeTaiwanJob(withField(withField(withField(base, 'SALARYCD', method), 'NT_L', lo), 'NT_U', hi), NOW));
    expect(sal('月薪', '33000', '35000')).toMatchObject({ salaryMin: 33000, salaryMax: 35000, salaryCurrency: 'TWD', salaryPeriod: 'month' });
    expect(sal('時薪', '200', '400')).toMatchObject({ salaryMin: 200, salaryMax: 400, salaryPeriod: 'hour' });
    expect(sal('日薪', '1500', '1500')).toMatchObject({ salaryPeriod: 'day' });
    expect(sal('月薪', '40000', '-')).toMatchObject({ salaryMin: 40000, salaryMax: 40000 });
    expect(sal('依學經歷、證照核薪(每月經常性薪資達4萬元以上)', '-', '-')).toMatchObject({ salaryMin: null, salaryCurrency: null, salaryPeriod: null });
    expect(sal('論件計酬', '100', '200')).toMatchObject({ salaryMin: null });
    expect(sal('月薪', '50000', '30000')).toMatchObject({ salaryMin: null, salaryMax: null });
    expect(sal('月薪', '0', '0')).toMatchObject({ salaryMin: null });
  });

  it('the application deadline is respected: an ad whose deadline passed is not imported; "until filled" and future dates are', () => {
    const base = recs[1]!;
    expect(normalizeTaiwanJob(withField(base, 'STOP_DATE', '20260101'), NOW)).toMatchObject({ ok: false, reason: 'expired' });
    expect(normalizeTaiwanJob(withField(base, 'STOP_DATE', '20261012'), NOW).ok).toBe(true); // the deadline day itself, Taipei time, is still open at 12:00 UTC
    expect(normalizeTaiwanJob(withField(base, 'STOP_DATE', '額滿為止'), NOW).ok).toBe(true);
    expect(deadlineOf('20261115')).toBe(Date.parse('2026-11-15T15:59:59Z'));
    expect(deadlineOf('額滿為止')).toBeNull();
  });

  it('rejects what cannot be shown honestly, with a reason', () => {
    const base = recs[1]!;
    expect(normalizeTaiwanJob(withField(base, 'URL_QUERY', 'https://evil.example/JobDetail.aspx?HIRE_ID=123456'), NOW)).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeTaiwanJob(withField(base, 'URL_QUERY', 'http://job.taiwanjobs.gov.tw/Internet/jobwanted/JobDetail.aspx?HIRE_ID=123456'), NOW)).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeTaiwanJob(withField(base, 'URL_QUERY', 'https://job.taiwanjobs.gov.tw.evil.io/JobDetail.aspx?HIRE_ID=123456'), NOW)).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeTaiwanJob(withField(base, 'URL_QUERY', 'https://job.taiwanjobs.gov.tw/Internet/jobwanted/JobDetail.aspx?EMPLOYER_ID=1'), NOW)).toMatchObject({ ok: false, reason: 'invalid_url' });
    expect(normalizeTaiwanJob(withField(withField(base, 'OCCU_DESC', ''), 'CJOB_NAME2', ''), NOW)).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(normalizeTaiwanJob(withField(base, 'COMPNAME', ' '), NOW)).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(normalizeTaiwanJob(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
  });
});

describe('Taiwan Jobs connector', () => {
  it('reads 1 000 records a page and follows offsets until a short page', async () => {
    const urls: string[] = [];
    const c = taiwanJobsConnector(async (u) => {
      urls.push(String(u));
      const offset = Number(new URL(String(u)).searchParams.get('offset'));
      return json({ success: true, result: { records: offset === 0 ? Array.from({ length: 1000 }, () => recs[0]) : recs } });
    }, nowFn);
    const p1 = await c.fetchPage(null, '');
    expect(p1.nextCursor).toBe('1000');
    const p2 = await c.fetchPage('1000', '');
    expect(p2.nextCursor).toBeNull();
    expect(p2.jobs).toHaveLength(8);
    expect(urls[0]).toContain('limit=1000');
    expect(urls[0]).toMatch(/^https:\/\/apiservice\.mol\.gov\.tw\/OdService\/rest\/datastore\/A17000000J-030144-VAL\?/);
  });

  it('refuses a malformed cursor, an unexpected body and a non-JSON answer (a gate is not hammered)', async () => {
    const c = taiwanJobsConnector(async () => json({ success: false }), nowFn);
    for (const bad of ['x', '10', '99000', '-1000']) await expect(c.fetchPage(bad, '')).rejects.toThrow(/invalid cursor/);
    await expect(c.fetchPage(null, '')).rejects.toThrow(/unexpected response/);
    const gate = taiwanJobsConnector(async () => new Response('<html>blocked</html>', { status: 200 }), nowFn);
    await expect(gate.fetchPage(null, '')).rejects.toBeInstanceOf(HttpError);
  });

  it('is registered with its mandatory attribution, its host, sane caps and a Chinese-safe attribution text', () => {
    const s = SOURCES.twjobs!;
    expect(s.attribution).toContain('Open Government Data License');
    expect(s.attribution).toContain('https://data.gov.tw/en/datasets/44062');
    expect(s.newCap).toBeLessThanOrEqual(s.catalogue);
  });
});

describe('Taiwan Jobs through the scheduled pass', () => {
  it('imports the records under their own source id with their own run row, and the second pass only stamps', async () => {
    const w = new World();
    w.hosts['apiservice.mol.gov.tw'] = () => json({ success: true, result: { records: recs } });
    const env = w.env({ SYNC_MODE: 'discover', SYNC_SOURCE: 'twjobs' });
    const out = await runScheduledSync(env, w.deps());
    expect(out).toMatchObject({ status: 'ok', summary: { upserted: 8 } });
    expect([...w.jobs.values()].filter((j) => j.source_id === 'twjobs')).toHaveLength(8);
    expect(w.runs[0]).toMatchObject({ source_id: 'twjobs', scope: 'discover', status: 'ok', upserted: 8 });
    w.clock = new Date(w.clock.getTime() + 3 * 3_600_000);
    const again = await runScheduledSync(env, w.deps());
    expect(again).toMatchObject({ status: 'ok', summary: { upserted: 0, confirmed: 8 } });
  });
});
