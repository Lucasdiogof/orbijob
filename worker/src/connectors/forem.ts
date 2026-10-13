import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob } from '../types';
import { FRENCH_COUNTRY, placeName } from './bpce';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Le Forem, the public employment and training service of Wallonia (Belgium): the offers it publishes, from Open Data Wallonie-Bruxelles
 * (Opendatasoft dataset `offres-d-emploi-forem`, refreshed daily, ≈ 25,000 offers; most come from staffing agencies and job boards that distribute through the Forem):
 *
 *   https://www.odwb.be/api/explore/v2.1/catalog/datasets/offres-d-emploi-forem/records?where=datefindiffusion>=now()&order_by=datedebutdiffusion desc&limit=100&offset=N
 *
 * Licence: **CC BY-SA 4.0** (stated on the dataset). Attribution is stored with the source; the ShareAlike term means the records of THIS source are shared under the
 * same licence (the attribution says so). Every offer links to its own page on https://www.leforem.be/recherche-offres/offre-detail/{numero}.
 *
 * The dataset carries NO description text: title, employer, place, contract, working time, sector, trade, education, languages, experience and driving licence. The
 * description is made of exactly those stated facts, nothing else. The country is the one the offer states among its regions ("Belgique" or, for the few abroad, the
 * French name of the country; several countries are kept as eligibility); the publication date is `datedebutdiffusion` (the start of the offer's diffusion) and `datefindiffusion` (its end) refuses an expired offer. The
 * newest offers are read (a window of 25 pages): an offer that leaves the window stops being stamped (`presenceConfirmsOpen`), is hidden after 72 h and becomes
 * `unknown` after 7 days.
 */

export const FOREM_HOST = 'leforem.be';
export const FOREM_PAGE = 100;
export const FOREM_MAX_PAGES = 25;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.map((x) => inlineText(str(x))).filter(Boolean) : []);
const fold = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();

/**
 * The country an offer states: `lieuxtravailregion` lists administrative areas and, among them, the country by its French name ("Belgique", "France", "Malte"). Exactly one
 * country is the offer's country; two or more ("Malte", "Pays-Bas") are the places the job may be done in (eligibility), never a single country; none states none. The order of
 * the entries varies ("Province de Liège", "Belgique", "RÉGION WALLONNE"), so every entry is read.
 */
export function foremPlaces(regions: unknown): { country: string | null; restrictions: string[] } {
  const codes: string[] = [];
  for (const r of Array.isArray(regions) ? regions : []) {
    const code = FRENCH_COUNTRY[fold(str(r))];
    if (code && !codes.includes(code)) codes.push(code);
  }
  return codes.length === 1 ? { country: codes[0]!, restrictions: [] } : { country: null, restrictions: codes };
}

export function normalizeForem(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = (typeof r.numerooffreforem === 'number' ? String(r.numerooffreforem) : str(r.numerooffreforem)).trim();
  if (!/^[1-9][0-9]{0,11}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.titreoffre));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = inlineText(str(r.nomemployeur));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(r.url, FOREM_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const end = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str(r.datefindiffusion));
  if (end) {
    const t = Date.UTC(Number(end[1]), Number(end[2]) - 1, Number(end[3]), 21, 59, 59);
    if (Number.isFinite(t) && t < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };
  }
  const places2 = foremPlaces(r.lieuxtravailregion);
  const places = strs(r.lieuxtravaillocalite).map(placeName).filter(Boolean);
  const facts: string[] = [];
  const fact = (label: string, values: string[]) => { if (values.length) facts.push(`${label} : ${values.join(', ')}`); };
  fact('Métier', [inlineText(str(r.metier))].filter(Boolean));
  fact('Secteur', strs(r.secteurs));
  fact('Type de contrat', [inlineText(str(r.typecontrat))].filter(Boolean));
  fact('Régime de travail', [inlineText(str(r.regimetravail))].filter(Boolean));
  if (typeof r.nombrepostes === 'number' && r.nombrepostes > 1) facts.push(`Nombre de postes : ${r.nombrepostes}`);
  fact('Niveau d’études', strs(r.niveauxetudes));
  fact('Langues', strs(r.langues));
  fact('Expérience requise', [inlineText(str(r.experiencerequise))].filter(Boolean));
  fact('Permis de conduire', strs(r.permisdeconduire));
  fact('Offre diffusée via', [inlineText(str(r.source))].filter((s) => s && s !== 'Via site Forem'));
  const description = cleanDescription(facts.join('\n'));
  const contract = [inlineText(str(r.typecontrat)), inlineText(str(r.regimetravail))].filter(Boolean).join(', ');
  const posted = Date.parse(str(r.datedebutdiffusion));
  const job: NormalizedJob = {
    source: 'forem', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: null,
    externalId: id, company, title, description,
    country: places2.country, city: places.length ? places.slice(0, 3).join(', ') : null,
    workMode: 'unspecified', contractType: contract || null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: Number.isFinite(posted) ? new Date(posted).toISOString() : null,
    originalUrl: url, applyUrl: url, geoRestrictions: places2.restrictions,
  };
  return { ok: true, job };
}

export function foremConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const ORIGIN = (opts.origin ?? 'https://www.odwb.be').replace(/\/+$/, '');
  return {
    id: 'forem',
    minIntervalMs: 1500,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      const offset = cursor ? Number(cursor) : 0;
      if (!Number.isInteger(offset) || offset < 0 || offset % FOREM_PAGE !== 0 || offset >= FOREM_PAGE * FOREM_MAX_PAGES) throw new Error('forem: invalid cursor');
      const where = encodeURIComponent('datefindiffusion >= now()');
      const order = encodeURIComponent('datedebutdiffusion desc, numerooffreforem desc');
      const data = await getFeed<{ results?: unknown; total_count?: unknown }>(
        fetchImpl, `${ORIGIN}/api/explore/v2.1/catalog/datasets/offres-d-emploi-forem/records?where=${where}&order_by=${order}&limit=${FOREM_PAGE}&offset=${offset}`,
      );
      if (!Array.isArray(data.results)) throw new Error('forem: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.results) {
        const n = normalizeForem(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'expired') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const total = typeof data.total_count === 'number' ? data.total_count : 0;
      const more = data.results.length === FOREM_PAGE && offset + FOREM_PAGE < total && offset + FOREM_PAGE < FOREM_PAGE * FOREM_MAX_PAGES;
      return { jobs, nextCursor: more ? String(offset + FOREM_PAGE) : null, isFullSnapshot: false, rejected };
    },
  };
}
