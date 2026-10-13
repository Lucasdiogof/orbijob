import { cleanDescription } from '../description';
import { GEO_ANYWHERE, geoRestrictions, parseGeo, singleCountry } from '../geo';
import { HttpError, parseRetryAfter } from '../http';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob, WorkMode } from '../types';

/**
 * Three keyless public job feeds, read through their official endpoints and only the way each one's own rules allow:
 *
 *  - Arbeitnow  https://www.arbeitnow.com/api/job-board-api   Terms §11 (API): free, "link back to Arbeitnow.com", revocable. Paginated,
 *               ordered by `created_at`, refreshed hourly. Cloudflare answers a burst of requests with a challenge page: this adapter
 *               reads a handful of pages at a gentle pace and STOPS at the first non-JSON answer (never retried, never bypassed).
 *  - Remote OK  https://remoteok.com/api                      Legal notice in the feed: link back (follow) and credit Remote OK as the source.
 *  - Remotive   https://remotive.com/api/remote-jobs          README: link back and name Remotive; at most 4 fetches a day, never more than 2 a
 *               minute; jobs are delayed 24 h; do not submit the jobs to third-party boards.
 *
 * None of them has a status endpoint: a listing in the feed IS the proof that it is open (`presenceConfirmsOpen`), and one that
 * disappears simply stops being stamped, so the app hides it after 72 h and `ops.expire_unseen_jobs` closes it after a week.
 * Nothing is translated, guessed or filled in: a country, salary or language the feed does not state stays empty.
 */

const USER_AGENT = 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)';

/** GET JSON; an HTML answer (a challenge page, an error page) is a non-retryable 403 so the retry layer never hammers a gate. */
export async function getFeed<T>(fetchImpl: typeof fetch, url: string, timeoutMs = 20_000): Promise<T> {
  const res = await fetchImpl(url, { headers: { Accept: 'application/json', 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(timeoutMs) });
  if (!res.ok) throw new HttpError(res.status, parseRetryAfter(res.headers.get('retry-after')));
  const text = await res.text();
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new HttpError(403); // not JSON: a bot challenge or an error page; stop here
  }
}

/**
 * Remote OK sends some strings UTF-8 encoded twice ("Ciudad de MÃ©xico"). When EVERY character fits one byte and the bytes read as valid
 * UTF-8 the text is repaired; anything else is left exactly as received.
 */
export function repairMojibake(s: string): string {
  if (!/[\u00c2-\u00f4][\u0080-\u00bf]/.test(s)) return s;
  const bytes = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c > 0xff) return s;
    bytes[i] = c;
  }
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    return s;
  }
}

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const fixed = (v: unknown): string => repairMojibake(str(v));
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);

/** An https URL on the source's own host (or subdomain): the only kind of link the catalogue keeps. */
export function ownUrl(v: unknown, host: string): string | null {
  try {
    const u = new URL(str(v).trim());
    const h = u.hostname.toLowerCase();
    if (u.protocol !== 'https:' || u.username || u.password) return null;
    return h === host || h.endsWith(`.${host}`) ? u.toString() : null;
  } catch {
    return null;
  }
}

export type Normalized = { ok: true; job: NormalizedJob } | { ok: false; reason: string; externalId: string | null };

const ID = /^[A-Za-z0-9][A-Za-z0-9._~-]{0,199}$/;
const isoFromEpoch = (sec: unknown): string | null => (typeof sec === 'number' && Number.isFinite(sec) && sec > 0 ? new Date(sec * 1000).toISOString() : null);

function base(source: string, nowIso: string): Pick<NormalizedJob, 'source' | 'lastCheckedAt' | 'requirements' | 'skills' | 'language' | 'status' | 'city'> {
  return { source, lastCheckedAt: nowIso, requirements: [], skills: [], language: null, status: 'open', city: null };
}

const NO_SALARY = { salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null } as const;

/** "Worldwide"/"Anywhere"/"Global" -> the explicit no-restriction marker; names the source publishes are mapped; the rest is kept as written. */
function geoOf(raw: unknown): { country: string | null; restrictions: string[] } {
  const text = str(raw).trim();
  if (!text) return { country: null, restrictions: [] };
  if (/^(worldwide|anywhere|global|remote)$/i.test(text)) return { country: null, restrictions: [GEO_ANYWHERE] };
  const g = parseGeo(text.replace(/\bUnited States( of America)?\b/gi, 'USA').replace(/\bUnited Kingdom\b/gi, 'UK').replace(/\bNorthern America\b/gi, 'North America'));
  return { country: singleCountry(g), restrictions: geoRestrictions(g) };
}

// ───────────────────────────── Arbeitnow ─────────────────────────────

/** Arbeitnow's own regional sites: the feed links UK, French and Swiss jobs to them. */
export const ARBEITNOW_HOSTS = ['arbeitnow.com', 'arbeitnow.co.uk', 'arbeitnow.fr', 'arbeitnow.ch', 'arbeitnow.nl'] as const;

/** Country names Arbeitnow locations end with (English and the local names employers write). Codes such as "DE" are not read. */
const ARBEITNOW_COUNTRY_NAMES: Record<string, string> = {
  germany: 'DE', deutschland: 'DE', austria: 'AT', 'österreich': 'AT', switzerland: 'CH', schweiz: 'CH', suisse: 'CH', svizzera: 'CH',
  france: 'FR', uk: 'GB', 'united kingdom': 'GB', england: 'GB', scotland: 'GB', wales: 'GB', 'northern ireland': 'GB', ireland: 'IE',
  netherlands: 'NL', nederland: 'NL', belgium: 'BE', belgique: 'BE', 'belgië': 'BE', spain: 'ES', 'españa': 'ES', italy: 'IT', italia: 'IT',
  portugal: 'PT', poland: 'PL', polska: 'PL', 'czech republic': 'CZ', czechia: 'CZ', hungary: 'HU', denmark: 'DK', sweden: 'SE', norway: 'NO',
  finland: 'FI', luxembourg: 'LU', australia: 'AU', 'united states': 'US', usa: 'US', canada: 'CA',
};
/** Arbeitnow's regional sites: a job linked from one of them must be in that country, or the stated country is not trusted. */
const ARBEITNOW_SITE_COUNTRY: Record<string, string> = { 'arbeitnow.co.uk': 'GB', 'arbeitnow.fr': 'FR', 'arbeitnow.ch': 'CH', 'arbeitnow.nl': 'NL' };

const foldPlace = (s: string): string => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();

/**
 * Cities whose NAME alone identifies the country: large cities (over 100,000 people) that no other country has a notable town of the same name
 * (checked by hand 2026-10-13). A name two countries share (Birmingham, Manchester, Cambridge, Newcastle, Dublin, Rome, Saint-Denis, Altendorf...) is deliberately absent:
 * those listings stay without a country unless the location itself names one. Evidence that the table agrees with the feed: of the Arbeitnow listings whose
 * location states a country, every one that names one of these cities stated the same country (London 39/39 GB, Paris 25/25 FR, Berlin 20/20 DE,
 * Munich 15/15 DE, Zurich 17/17 CH, Lille 7/7 FR; no contradiction anywhere).
 */
const ARBEITNOW_PLACES: [string, string[]][] = [
  ['DE', ['berlin', 'hamburg', 'munich', 'munchen', 'koln', 'cologne', 'frankfurt', 'frankfurt am main', 'stuttgart', 'dusseldorf', 'dortmund', 'essen', 'leipzig', 'bremen',
    'dresden', 'hannover', 'hanover', 'nurnberg', 'nuremberg', 'duisburg', 'bochum', 'wuppertal', 'bielefeld', 'bonn', 'munster', 'karlsruhe', 'mannheim', 'augsburg', 'wiesbaden',
    'aachen', 'braunschweig', 'kiel', 'chemnitz', 'freiburg', 'freiburg im breisgau', 'mainz', 'erfurt', 'rostock', 'kassel', 'potsdam', 'heidelberg', 'darmstadt', 'regensburg',
    'ingolstadt', 'ulm', 'wolfsburg', 'offenbach am main', 'osnabruck', 'detmold', 'jena', 'saarbrucken', 'paderborn', 'gottingen', 'bayreuth']],
  ['GB', ['london', 'glasgow', 'edinburgh', 'leeds', 'liverpool', 'sheffield', 'bristol', 'cardiff', 'leicester', 'nottingham', 'southampton', 'belfast', 'oxford', 'milton keynes']],
  ['FR', ['paris', 'lyon', 'marseille', 'toulouse', 'nantes', 'bordeaux', 'lille', 'strasbourg', 'montpellier', 'rennes', 'grenoble', 'nancy', 'limoges', 'dijon', 'toulon', 'reims', 'angers', 'nimes', 'bayonne']],
  ['CH', ['zurich', 'bern', 'basel', 'geneva', 'geneve', 'lausanne', 'winterthur', 'lugano', 'lucerne', 'luzern', 'st gallen', 'zug', 'payerne']],
  ['NL', ['amsterdam', 'rotterdam', 'the hague', 'den haag', 'utrecht', 'eindhoven', 'delft', 'groningen', 'tilburg', 'almere', 'breda', 'nijmegen', 'leiden', 'haarlem']],
  ['AT', ['vienna', 'wien', 'graz', 'linz', 'salzburg', 'innsbruck']],
  ['BE', ['brussels', 'bruxelles', 'brussel', 'antwerp', 'antwerpen', 'ghent', 'gent', 'leuven']],
  ['ES', ['madrid', 'barcelona', 'valencia', 'seville', 'sevilla', 'malaga', 'bilbao']],
  ['PT', ['lisbon', 'lisboa']],
  ['IT', ['milan', 'milano', 'turin', 'torino', 'naples', 'napoli']],
  ['PL', ['warsaw', 'warszawa', 'krakow', 'wroclaw', 'poznan', 'gdansk']],
  ['CZ', ['prague', 'praha', 'brno']],
  ['DK', ['copenhagen', 'kobenhavn', 'aarhus']],
  ['SE', ['stockholm', 'gothenburg', 'goteborg', 'malmo']],
  ['NO', ['oslo', 'bergen']],
  ['FI', ['helsinki', 'espoo', 'tampere']],
];
const ARBEITNOW_PLACE_COUNTRY: Record<string, string> = Object.fromEntries(ARBEITNOW_PLACES.flatMap(([code, names]) => names.map((n) => [n, code] as [string, string])));

/** Regions an employer writes after a city ("München, Bavaria"); a part that is not one of these (or the city again) makes the location ambiguous. */
const ARBEITNOW_REGIONS: [string, string[]][] = [
  ['DE', ['bayern', 'bavaria', 'nordrhein-westfalen', 'north rhine-westphalia', 'nrw', 'baden-wurttemberg', 'baden wurttemberg', 'hessen', 'hesse', 'niedersachsen', 'lower saxony',
    'sachsen', 'saxony', 'berlin', 'hamburg', 'brandenburg', 'thuringen', 'thuringia', 'rheinland-pfalz', 'rhineland-palatinate', 'schleswig-holstein', 'saarland',
    'mecklenburg-vorpommern', 'sachsen-anhalt', 'bremen']],
  ['GB', ['england', 'scotland', 'wales', 'northern ireland', 'greater london', 'south east', 'north west', 'west midlands', 'yorkshire']],
  ['FR', ['ile-de-france', 'ile de france', 'auvergne-rhone-alpes', 'occitanie', 'nouvelle-aquitaine', 'hauts-de-france', 'grand est', 'pays de la loire', 'bretagne', 'normandie',
    'provence-alpes-cote d azur', 'bourgogne-franche-comte', 'centre-val de loire']],
  ['CH', ['zurich', 'bern', 'vaud', 'geneve', 'geneva', 'basel-stadt', 'ticino', 'luzern', 'zug', 'aargau', 'st gallen']],
  ['NL', ['noord-holland', 'zuid-holland', 'utrecht', 'noord-brabant', 'gelderland', 'overijssel', 'groningen', 'north holland', 'south holland']],
  ['AT', ['wien', 'vienna', 'steiermark', 'styria', 'tirol', 'tyrol', 'salzburg', 'oberosterreich', 'upper austria']],
];
const ARBEITNOW_REGION_COUNTRY: Record<string, string> = Object.fromEntries(ARBEITNOW_REGIONS.flatMap(([code, names]) => names.map((n) => [n, code] as [string, string])));

/** Words an employer adds after a city ("Berlin Office", "Munich HQ"); they say nothing about another place. */
const PLACE_NOISE = /\s+(office|hq|headquarters|area)$/i;

/**
 * The country an Arbeitnow location STATES, or null:
 *  - it ends with a country name ("München, Bayern, Germany"), or is just a country name ("United Kingdom");
 *  - or its first part is one of the cities of ARBEITNOW_PLACE_COUNTRY, with nothing after it that names another country or another table city.
 * A list of places, a contradiction with the listing's regional site, or a name two countries share gives null.
 */
export function arbeitnowStatedCountry(location: string, url: string): string | null {
  if (!location || /[;|/]/.test(location)) return null; // several places
  const parts = location.split(',').map((p) => p.trim()).filter(Boolean);
  if (parts.length === 0) return null;
  const names = parts.map((p) => foldPlace(p).replace(PLACE_NOISE, ''));
  let code: string | null = ARBEITNOW_COUNTRY_NAMES[names[names.length - 1]!] ?? null;
  if (code && names.slice(0, -1).some((p) => ARBEITNOW_COUNTRY_NAMES[p] && ARBEITNOW_COUNTRY_NAMES[p] !== code)) return null; // two different countries named
  if (!code) {
    const first = ARBEITNOW_PLACE_COUNTRY[names[0]!];
    const rest = names.slice(1);
    // the rest may only repeat the city or be a region of the same country ("Bavaria", "England"); anything else (an unknown country, another place) makes it ambiguous
    if (first && rest.every((p) => p === names[0] || ARBEITNOW_REGION_COUNTRY[p] === first || ARBEITNOW_PLACE_COUNTRY[p] === first)) code = first;
  }
  if (!code) return null;
  let host = '';
  try { host = new URL(url).hostname.replace(/^www./, ''); } catch { /* checked by the caller */ }
  const site = ARBEITNOW_SITE_COUNTRY[host];
  return site && site !== code ? null : code;
}

export function normalizeArbeitnow(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const slug = str(r.slug).trim();
  if (!ID.test(slug)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.title));
  if (!title) return { ok: false, reason: 'missing_title', externalId: slug };
  const company = inlineText(str(r.company_name));
  if (!company) return { ok: false, reason: 'missing_company', externalId: slug };
  const url = ARBEITNOW_HOSTS.map((h) => ownUrl(r.url, h)).find((u) => u !== null) ?? null;
  if (!url) return { ok: false, reason: 'invalid_url', externalId: slug };
  const types = arr(r.job_types).map((t) => inlineText(str(t))).filter(Boolean);
  const remote = r.remote === true;
  // `remote: false` does not say "on site" (it can be hybrid): only an explicit remote flag sets the mode.
  const workMode: WorkMode = remote ? 'remote' : 'unspecified';
  const location = inlineText(str(r.location));
  return {
    ok: true,
    job: {
      ...base('arbeitnow', nowIso), externalId: slug, company, title, description: cleanDescription(str(r.description)),
      // the location sometimes ENDS with the country, written out by the employer ("München, Bayern, Germany"), or is a country, or a city that only
      // one country has (ARBEITNOW_PLACES): that is stated, not guessed. A name two countries share ("Birmingham") stays without a country.
      country: arbeitnowStatedCountry(location, url),
      workMode, contractType: types.length ? types.join(', ') : null, ...NO_SALARY,
      publishedAt: isoFromEpoch(r.created_at), originalUrl: url, applyUrl: url,
      geoRestrictions: [], // the feed names no eligible region: eligibility is unknown, never read as global
      ...(location ? { city: location } : {}),
    },
  };
}

export function arbeitnowConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const BASE = `${(opts.origin ?? 'https://www.arbeitnow.com').replace(/\/+$/, '')}/api/job-board-api`;
  return {
    id: 'arbeitnow',
    // Cloudflare challenged a 1.5-second walk at page 19: one request every 4 seconds is this adapter's own conservative pace.
    minIntervalMs: 4000,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      const page = cursor ? Number(cursor) : 1;
      if (!Number.isInteger(page) || page < 1 || page > 1000) throw new Error('arbeitnow: invalid cursor');
      const data = await getFeed<{ data?: unknown; links?: { next?: unknown } }>(fetchImpl, `${BASE}?page=${page}`);
      if (!Array.isArray(data.data)) throw new Error('arbeitnow: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.data) {
        const n = normalizeArbeitnow(raw, nowIso);
        if (n.ok) jobs.push(n.job); else rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const hasNext = typeof data.links?.next === 'string' && data.links.next !== '' && data.data.length > 0;
      return { jobs, nextCursor: hasNext ? String(page + 1) : null, isFullSnapshot: false, rejected };
    },
  };
}

// ───────────────────────────── Remote OK ─────────────────────────────

export function normalizeRemoteOk(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = typeof r.id === 'number' ? String(r.id) : str(r.id).trim();
  if (!/^[1-9][0-9]{0,15}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(fixed(r.position));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = inlineText(fixed(r.company));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(r.url, 'remoteok.com');
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const geo = geoOf(fixed(r.location));
  return {
    ok: true,
    job: {
      ...base('remoteok', nowIso), externalId: id, company, title, description: cleanDescription(fixed(r.description)),
      country: geo.country, workMode: 'remote', contractType: null, ...NO_SALARY, // the feed does not state currency or period: no salary is shown
      publishedAt: typeof r.date === 'string' && Number.isFinite(Date.parse(r.date)) ? new Date(r.date).toISOString() : isoFromEpoch(r.epoch),
      originalUrl: url, applyUrl: url, // the link back the terms ask for; the application button goes through the listing page
      geoRestrictions: geo.restrictions,
    },
  };
}

export function remoteOkConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const URL_ = `${(opts.origin ?? 'https://remoteok.com').replace(/\/+$/, '')}/api`;
  return {
    id: 'remoteok',
    minIntervalMs: 4000,
    presenceConfirmsOpen: true,
    async fetchPage(): Promise<FetchPage> {
      const data = await getFeed<unknown[]>(fetchImpl, URL_);
      if (!Array.isArray(data)) throw new Error('remoteok: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      // element 0 is the legal notice ({ legal, last_updated }), not a job
      for (const raw of data.filter((x) => typeof x === 'object' && x !== null && !('legal' in (x as object)))) {
        const n = normalizeRemoteOk(raw, nowIso);
        if (n.ok) jobs.push(n.job); else rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      return { jobs, nextCursor: null, isFullSnapshot: false, rejected };
    },
  };
}

// ───────────────────────────── Remotive ─────────────────────────────

const REMOTIVE_TYPE: Record<string, string> = { full_time: 'Full-Time', part_time: 'Part-Time', contract: 'Contract', freelance: 'Freelance', internship: 'Internship' };

export function normalizeRemotive(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = typeof r.id === 'number' ? String(r.id) : str(r.id).trim();
  if (!/^[1-9][0-9]{0,15}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.title));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = inlineText(str(r.company_name));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(r.url, 'remotive.com');
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const geo = geoOf(r.candidate_required_location);
  const type = REMOTIVE_TYPE[str(r.job_type).trim().toLowerCase()] ?? null;
  const published = Date.parse(str(r.publication_date));
  return {
    ok: true,
    job: {
      ...base('remotive', nowIso), externalId: id, company, title, description: cleanDescription(str(r.description)),
      country: geo.country, workMode: 'remote', contractType: type, ...NO_SALARY, // `salary` is free text ("$50k-$70k"): not parsed, not shown
      publishedAt: Number.isFinite(published) ? new Date(published).toISOString() : null,
      originalUrl: url, applyUrl: url, geoRestrictions: geo.restrictions,
    },
  };
}

export function remotiveConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const URL_ = `${(opts.origin ?? 'https://remotive.com').replace(/\/+$/, '')}/api/remote-jobs`;
  return {
    id: 'remotive',
    minIntervalMs: 30_000, // the README blocks more than 2 requests a minute
    presenceConfirmsOpen: true,
    async fetchPage(): Promise<FetchPage> {
      const data = await getFeed<{ jobs?: unknown }>(fetchImpl, URL_);
      if (!Array.isArray(data.jobs)) throw new Error('remotive: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.jobs) {
        const n = normalizeRemotive(raw, nowIso);
        if (n.ok) jobs.push(n.job); else rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      return { jobs, nextCursor: null, isFullSnapshot: false, rejected };
    },
  };
}
