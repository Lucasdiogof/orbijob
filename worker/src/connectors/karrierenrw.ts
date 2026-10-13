import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Karriere.NRW, the employer portal of the German state of North Rhine-Westphalia: the vacancies of the state administration, the municipalities,
 * universities, police, justice and road authorities. Read through the portal's Open.NRW interface:
 *
 *   https://api.karriere.nrw/v1.0/opennrw/stellenausschreibungen/      the whole current list in one JSON array (~1,000 postings, ~6.5 MB)
 *
 * Licence: the dataset "Stellenangebote des Arbeitgeberportals des Landes - Karriere.NRW" (GovData, publisher Open.NRW) lists this interface with the
 * licence `dl-by-de/2.0`, Datenlizenz Deutschland – Namensnennung – Version 2.0 (https://www.govdata.de/dl-de/by-2-0): free reuse, including storing and
 * showing, with the name of the source, the licence and a link: the catalogue shows "Jobs via Karriere.NRW ... Datenlizenz Deutschland – Namensnennung 2.0"
 * with every posting, linking to the posting's own page `https://karriere.nrw/stellenausschreibung/{uuid}`.
 *
 * Both job offers and apprenticeships (`type`: joboffer | apprenticeship, "Ausbildung"/"Duales Studium") are kept; an apprenticeship says so in its contract type.
 * The contact persons of the posting (`ansprechpartner`: name, telephone, e-mail of public employees) are NEVER read. The pay grade (`besoldung_entgelt`:
 * "TVöD 10", "A 13") is a grade, not an amount: it goes into the description, no salary is stored. The country is Germany because the portal is a German
 * state's; the place is the stated `ort`. The deadline (`bewerbungsfrist`) is honoured: an expired posting is refused. A listing that leaves the list stops being
 * stamped (`presenceConfirmsOpen`), is hidden after 72 h and becomes `unknown` after 7 days.
 */

export const KARRIERENRW_HOST = 'karriere.nrw';
const MAX_DESCRIPTION = 6000;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.map((x) => inlineText(str(x))).filter(Boolean) : []);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** "2026-10-27" (the last day to apply) -> the end of that day in Germany expressed in UTC (22:00 the day before in summer time at the latest): used only to refuse an expired posting. */
export function deadlineMs(v: unknown): number | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str(v).trim());
  if (!m) return null;
  const t = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 21, 59, 59); // 23:59:59 in summer time (UTC+2) is 21:59:59 UTC: never earlier than the real end of the day
  const d = new Date(t);
  return Number.isFinite(t) && d.getUTCDate() === Number(m[3]) && d.getUTCMonth() === Number(m[2]) - 1 ? t : null; // 2026-02-30 or month 13 would roll over
}

export function normalizeKarriereNrw(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = str(r.uuid).trim().toLowerCase();
  if (!UUID.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.titel_der_stelle));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = inlineText(str(r.behoerde)) || inlineText(str(r.ausschreibende_behoerde));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(`https://${KARRIERENRW_HOST}/stellenausschreibung/${id}`, KARRIERENRW_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const deadline = deadlineMs(r.bewerbungsfrist);
  if (deadline !== null && deadline < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };

  const facts: string[] = [];
  const fact = (label: string, values: string[]) => { if (values.length) facts.push(`${label}: ${values.join(', ')}`); };
  fact('Besoldung/Entgelt', strs(r.besoldung_entgelt));
  fact('Arbeitszeit', strs(r.arbeitszeit));
  fact('Laufbahngruppe', [inlineText(str(r.laufbahngruppe))].filter(Boolean));
  fact('Befristung', [inlineText(str(r.befristung))].filter(Boolean));
  fact('Tätigkeitsfeld', strs(r.taetigkeitsfeld));
  fact('Bewerbungsfrist', [inlineText(str(r.bewerbungsfrist))].filter(Boolean));
  const body = cleanDescription(str(r.stellenbeschreibung));
  let description = [body, facts.join('\n')].filter(Boolean).join('\n\n');
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;

  const apprenticeship = str(r.type) === 'apprenticeship';
  const hours = strs(r.arbeitszeit).join(', ');
  const contract = [apprenticeship ? 'Ausbildung / Duales Studium' : '', hours, inlineText(str(r.befristung))].filter(Boolean).join(', ');
  const posted = Date.parse(str(r.erscheinungsdatum));
  const job: NormalizedJob = {
    source: 'karrierenrw', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: null,
    externalId: id, company, title, description,
    country: 'DE', city: inlineText(str(r.ort)) || inlineText(str(obj(r.dienststelle).ort)) || null,
    workMode: 'unspecified', contractType: contract || null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null, // a pay grade is not an amount
    publishedAt: Number.isFinite(posted) ? new Date(posted).toISOString() : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

function obj(v: unknown): Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}

export function karriereNrwConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const ORIGIN = (opts.origin ?? 'https://api.karriere.nrw').replace(/\/+$/, '');
  return {
    id: 'karrierenrw',
    minIntervalMs: 60_000, // one 6.5 MB answer per pass; never more than one a minute
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      if (cursor !== null) throw new Error('karrierenrw: invalid cursor');
      const data = await getFeed<unknown>(fetchImpl, `${ORIGIN}/v1.0/opennrw/stellenausschreibungen/`, 90_000);
      if (!Array.isArray(data)) throw new Error('karrierenrw: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data) {
        const n = normalizeKarriereNrw(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'expired') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      return { jobs, nextCursor: null, isFullSnapshot: false, rejected };
    },
  };
}
