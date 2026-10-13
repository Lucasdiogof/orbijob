import { cleanDescription } from '../description';
import { parseGeo, singleCountry } from '../geo';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Groupe BPCE (Banque Populaire, Caisse d'Epargne, Natixis and the group's other entities, France and abroad): every job offer the group publishes, shared by the
 * employer itself as open data, read through its Opendatasoft portal:
 *
 *   https://bpce.opendatasoft.com/api/explore/v2.1/catalog/datasets/groupe-bpce-offres-emploi/records?limit=100&offset=N
 *
 * Licence: the dataset "Groupe BPCE - Offres emploi publiques" on data.gouv.fr declares the Licence Ouverte v2.0 (Etalab: reuse, including commercial, with the name of
 * the producer and the date of the data) and says: "Le Groupe BPCE partage quotidiennement toutes ses offres d'emploi en Open Data ... Vous pouvez ainsi récupérer
 * toutes ces données et les mettre en page sur vos différentes plateformes d'offres d'emploi." The employer is the producer: the catalogue shows
 * "Jobs via Groupe BPCE ... Licence Ouverte 2.0" with every offer, linking to the offer's own page on https://recrutement.bpce.fr.
 *
 * The recruiter's name and e-mail (`nom_recruteur_principal`, `email_recruteur_principal`) are NEVER read. The dataset has no publication date (only `lastmodifieddate`, the last
 * edit): the publication date stays empty. `teletravail` is empty in every record: the work mode stays unspecified. The country is the one the offer states: `country` is
 * "France", or "International" with the real country in `state` (French name); an offer that states none stays without a country. A salary is not stated (the fields are empty).
 * The list is read in full on each pass (about 1,750 rows, 18 requests); an offer that leaves it stops being stamped (`presenceConfirmsOpen`), is hidden after 72 h and becomes
 * `unknown` after 7 days. The same reference is published once per location, so the offer's own address (`recrutement.bpce.fr/job/{slug}`) is the identifier.
 */

export const BPCE_HOST = 'bpce.fr';
export const BPCE_PAGE = 100;
export const BPCE_MAX_PAGES = 30;
const MAX_DESCRIPTION = 6000;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const fold = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();

/** Country names as the dataset writes them in French (`state` of an "International" offer) -> ISO 3166-1 alpha-2. */
export const FRENCH_COUNTRY: Readonly<Record<string, string>> = {
  france: 'FR', 'etats-unis': 'US', 'royaume-uni': 'GB', allemagne: 'DE', luxembourg: 'LU', espagne: 'ES', 'emirats arabes unis': 'AE', suede: 'SE', chine: 'CN',
  singapour: 'SG', suisse: 'CH', monaco: 'MC', taiwan: 'TW', australie: 'AU', 'hong kong': 'HK', italie: 'IT', 'pays-bas': 'NL', belgique: 'BE', irlande: 'IE',
  japon: 'JP', inde: 'IN', bresil: 'BR', canada: 'CA', mexique: 'MX', pologne: 'PL', portugal: 'PT', autriche: 'AT', danemark: 'DK', norvege: 'NO', finlande: 'FI',
  'coree du sud': 'KR', maroc: 'MA', tunisie: 'TN', senegal: 'SN', 'republique tcheque': 'CZ', roumanie: 'RO', grece: 'GR', turquie: 'TR', 'arabie saoudite': 'SA', qatar: 'QA',
  malte: 'MT', chypre: 'CY', bulgarie: 'BG', slovaquie: 'SK', slovenie: 'SI', hongrie: 'HU', croatie: 'HR', lituanie: 'LT', lettonie: 'LV', estonie: 'EE', islande: 'IS', liechtenstein: 'LI',
  'afrique du sud': 'ZA', egypte: 'EG', 'nouvelle-zelande': 'NZ', argentine: 'AR', chili: 'CL', colombie: 'CO', perou: 'PE', vietnam: 'VN', thailande: 'TH', malaisie: 'MY', indonesie: 'ID',
};

/** The country an offer states: "France", or the name in `state` when `country` is "International"; null when it states none. */
export function bpceCountry(country: unknown, state: unknown): string | null {
  const c = fold(str(country));
  if (!c) return null;
  if (c === 'international') return FRENCH_COUNTRY[fold(str(state))] ?? null;
  return FRENCH_COUNTRY[c] ?? parseGeoCountry(str(country));
}
function parseGeoCountry(name: string): string | null {
  return singleCountry(parseGeo(name));
}

/** "BELFORT" -> "Belfort", "SAINT-GRÉGOIRE" -> "Saint-Grégoire"; a name already in mixed case is untouched. */
export function placeName(raw: string): string {
  const s = inlineText(raw);
  if (!s || s !== s.toUpperCase() || s === s.toLowerCase()) return s;
  return s.toLowerCase().replace(/(^|[\s'’-])([a-zà-ÿ])/g, (_m, sep: string, ch: string) => sep + ch.toUpperCase());
}

export function normalizeBpce(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const url = ownUrl(r.url, BPCE_HOST);
  const slug = url ? /^\/job\/([A-Za-z0-9][A-Za-z0-9._~-]{0,198})$/.exec(new URL(url).pathname)?.[1] ?? null : null;
  if (!url || !slug) return { ok: false, reason: 'invalid_url', externalId: null };
  const title = inlineText(str(r.title));
  if (!title) return { ok: false, reason: 'missing_title', externalId: slug };
  const company = inlineText(str(r.organization)) || inlineText(str(r.company));
  if (!company) return { ok: false, reason: 'missing_company', externalId: slug };
  let description = cleanDescription(str(r.description));
  const facts = [
    ['Métier', inlineText(str(r.category))], ['Domaine', inlineText(str(r.jobindustry))], ['Niveau d’études', inlineText(str(r.degree))],
  ].filter(([, v]) => v).map(([k, v]) => `${k} : ${v}`);
  if (facts.length) description = `${description}${description ? '\n\n' : ''}${facts.join('\n')}`;
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;
  const job: NormalizedJob = {
    source: 'bpce', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: null,
    externalId: slug, company, title, description,
    country: bpceCountry(r.country, r.state), city: placeName(str(r.city)) || null,
    workMode: 'unspecified', contractType: inlineText(str(r.jobtype)) || null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: null, // `lastmodifieddate` is the last edit, not the publication
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function bpceConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const ORIGIN = (opts.origin ?? 'https://bpce.opendatasoft.com').replace(/\/+$/, '');
  return {
    id: 'bpce',
    minIntervalMs: 1500,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      const offset = cursor ? Number(cursor) : 0;
      if (!Number.isInteger(offset) || offset < 0 || offset % BPCE_PAGE !== 0 || offset >= BPCE_PAGE * BPCE_MAX_PAGES) throw new Error('bpce: invalid cursor');
      const order = encodeURIComponent('referencenumber,url,city');
      const data = await getFeed<{ results?: unknown; total_count?: unknown }>(
        fetchImpl, `${ORIGIN}/api/explore/v2.1/catalog/datasets/groupe-bpce-offres-emploi/records?limit=${BPCE_PAGE}&offset=${offset}&order_by=${order}`,
      );
      if (!Array.isArray(data.results)) throw new Error('bpce: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.results) {
        const n = normalizeBpce(raw, nowIso);
        if (n.ok) jobs.push(n.job); else rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const total = typeof data.total_count === 'number' ? data.total_count : 0;
      const more = data.results.length === BPCE_PAGE && offset + BPCE_PAGE < total && offset + BPCE_PAGE < BPCE_PAGE * BPCE_MAX_PAGES;
      return { jobs, nextCursor: more ? String(offset + BPCE_PAGE) : null, isFullSnapshot: false, rejected };
    },
  };
}
