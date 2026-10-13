import { describe, expect, it } from 'vitest';
import { deadlineMs, karriereNrwConnector, normalizeKarriereNrw } from '../src/connectors/karrierenrw';
import { HttpError } from '../src/http';
import { SOURCES } from '../src/sources';
import fixture from './fixtures/karrierenrw.sanitized.json';

// Real postings of the Open.NRW interface of Karriere.NRW (read 2026-10-13): 7 job offers and 3 apprenticeships of different authorities;
// long texts trimmed, e-mail addresses and telephone numbers scrubbed, contact persons removed.
const NOW = '2026-10-13T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const recs = fixture as Record<string, unknown>[];
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (r: ReturnType<typeof normalizeKarriereNrw>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };

describe('Karriere.NRW normalizer (real postings)', () => {
  it('maps a posting without inventing anything: Germany from the state portal, the stated place, no salary, a link to the posting\'s own page', () => {
    const jobs = recs.map((r) => ok(normalizeKarriereNrw(r, NOW)));
    expect(jobs).toHaveLength(10);
    for (const j of jobs) {
      expect(j).toMatchObject({ source: 'karrierenrw', country: 'DE', language: null, workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, geoRestrictions: [], salaryMin: null, salaryCurrency: null });
      expect(j.originalUrl).toBe(`https://karriere.nrw/stellenausschreibung/${j.externalId}`);
      expect(j.applyUrl).toBe(j.originalUrl);
      expect(j.company).not.toBe('');
      expect(j.city).toBeTruthy();
      expect(j.description).not.toMatch(/<[a-z/][^>]*>/i);
      expect(j.publishedAt).toMatch(/^2026-/);
    }
    expect(jobs[0]).toMatchObject({ company: 'Stadt Mülheim an der Ruhr', city: 'Mülheim an der Ruhr' });
    expect(jobs[0]!.description).toContain('Besoldung/Entgelt: TVöD 13'); // a pay grade goes into the text, never into a salary
    expect(jobs[0]!.description).toContain('Bewerbungsfrist: 2026-10-27');
  });

  it('marks an apprenticeship in its contract type and never reads the contact persons', () => {
    const apprentices = recs.filter((r) => r.type === 'apprenticeship').map((r) => ok(normalizeKarriereNrw(r, NOW)));
    expect(apprentices).toHaveLength(3);
    for (const a of apprentices) expect(a.contractType).toMatch(/^Ausbildung \/ Duales Studium/);
    const jobs = recs.filter((r) => r.type === 'joboffer').map((r) => ok(normalizeKarriereNrw(r, NOW)));
    for (const j of jobs) expect(j.contractType ?? '').not.toMatch(/Ausbildung/);
    const withContact = ok(normalizeKarriereNrw({ ...recs[0]!, ansprechpartner: [{ name: 'Frau Muster', e_mail: 'frau.muster@example.com', telefon: '0201 123456' }] }, NOW));
    expect(JSON.stringify(withContact)).not.toMatch(/Muster|0201 123456/);
  });

  it('uses the posting\'s own deadline: an expired posting is refused, one with no deadline is kept', () => {
    expect(deadlineMs('2026-10-27')).toBe(Date.UTC(2026, 9, 27, 21, 59, 59));
    for (const bad of ['', 'bald', '27.10.2026', '2026-02-30', '2026-13-01', null, undefined, 5]) expect(deadlineMs(bad), String(bad)).toBeNull();
    const r = (over: Record<string, unknown>) => normalizeKarriereNrw({ ...recs[0]!, ...over }, NOW);
    expect(r({ bewerbungsfrist: '2026-10-12' })).toMatchObject({ ok: false, reason: 'expired' });
    expect(r({ bewerbungsfrist: '2026-10-13' }).ok).toBe(true); // open through the end of that day
    expect(r({ bewerbungsfrist: null }).ok).toBe(true);
  });

  it('rejects what cannot be shown honestly, with a reason and never an exception', () => {
    const r = (over: Record<string, unknown>) => normalizeKarriereNrw({ ...recs[0]!, ...over }, NOW);
    expect(r({ uuid: 'not-a-uuid' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ uuid: '../../x' })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ uuid: undefined })).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(r({ titel_der_stelle: ' ' })).toMatchObject({ ok: false, reason: 'missing_title' });
    expect(r({ behoerde: '', ausschreibende_behoerde: '' })).toMatchObject({ ok: false, reason: 'missing_company' });
    expect(normalizeKarriereNrw(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeKarriereNrw([], NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    // the contracting authority stands in for a missing employer; the dienststelle's place for a missing place
    expect(ok(r({ behoerde: '', ausschreibende_behoerde: 'Land NRW' })).company).toBe('Land NRW');
    expect(ok(r({ ort: '', dienststelle: { ort: 'Essen' } })).city).toBe('Essen');
    expect(ok(r({ ort: '', dienststelle: null })).city).toBeNull();
  });

  it('caps the text and keeps the facts at the end', () => {
    const j = ok(normalizeKarriereNrw({ ...recs[0]!, stellenbeschreibung: '<p>' + 'Wort '.repeat(3000) + '</p>' }, NOW));
    expect(j.description.length).toBeLessThanOrEqual(6001);
    expect(j.description.endsWith('…')).toBe(true);
    const k = ok(normalizeKarriereNrw({ ...recs[0]!, stellenbeschreibung: '<p>Kurz.</p>', besoldung_entgelt: ['A 13'], arbeitszeit: ['Vollzeit'], taetigkeitsfeld: ['Verwaltung und Büro'], laufbahngruppe: 'Gehobener Dienst', befristung: 'Unbefristet' }, NOW));
    expect(k.description).toBe('Kurz.\n\nBesoldung/Entgelt: A 13\nArbeitszeit: Vollzeit\nLaufbahngruppe: Gehobener Dienst\nBefristung: Unbefristet\nTätigkeitsfeld: Verwaltung und Büro\nBewerbungsfrist: 2026-10-27');
    expect(k.contractType).toBe('Vollzeit, Unbefristet');
  });
});

describe('Karriere.NRW connector', () => {
  it('reads the whole list in one request and has no next page', async () => {
    const urls: string[] = [];
    const f = (async (u: string | URL | Request) => { urls.push(String(u)); return json(recs); }) as typeof fetch;
    const c = karriereNrwConnector(f, nowFn);
    expect(c).toMatchObject({ id: 'karrierenrw', presenceConfirmsOpen: true });
    const p = await c.fetchPage(null, 'discover');
    expect(p.jobs).toHaveLength(10);
    expect(p.nextCursor).toBeNull();
    expect(p.isFullSnapshot).toBe(false);
    expect(urls).toEqual(['https://api.karriere.nrw/v1.0/opennrw/stellenausschreibungen/']);
  });

  it('refuses any cursor, an unexpected body and an HTML gate; limits surface as HttpError', async () => {
    const c = karriereNrwConnector((async () => json(recs)) as typeof fetch, nowFn);
    for (const bad of ['1', '0', 'x', '']) await expect(c.fetchPage(bad, 'discover')).rejects.toThrow(/invalid cursor/);
    await expect(karriereNrwConnector((async () => json({ count: 1 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/unexpected response/);
    await expect(karriereNrwConnector((async () => new Response('<html>Wartung</html>', { status: 200 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(karriereNrwConnector((async () => new Response('', { status: 503 })) as typeof fetch, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
  });

  it('drops expired postings silently and records other refusals', async () => {
    const f = (async () => json([recs[0], { ...recs[1], bewerbungsfrist: '2020-01-01' }, { ...recs[2], uuid: 'x' }, 7])) as typeof fetch;
    const p = await karriereNrwConnector(f, nowFn).fetchPage(null, 'discover');
    expect(p.jobs).toHaveLength(1);
    expect(p.rejected).toEqual([{ externalId: null, reason: 'invalid_id' }, { externalId: null, reason: 'not_an_object' }]);
  });

  it('is registered as a source with the Namensnennung attribution the licence asks for', () => {
    const s = SOURCES.karrierenrw!;
    expect(s).toMatchObject({ id: 'karrierenrw', host: 'karriere.nrw' });
    expect(s.attribution).toMatch(/Karriere\.NRW/);
    expect(s.attribution).toMatch(/Datenlizenz Deutschland/);
    expect(s.attribution).toMatch(/https:\/\/karriere\.nrw/);
    expect(s.make(fetch, nowFn).id).toBe('karrierenrw');
  });
});
