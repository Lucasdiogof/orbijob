import { cleanDescription } from '../description';
import { parseGeo, singleCountry } from '../geo';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob, WorkMode } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Get on Board (https://www.getonbrd.com), the tech recruitment platform of Latin America, through its official PUBLIC API:
 *
 *   https://www.getonbrd.com/api/v0/categories/{category}/jobs?per_page=&page=&expand=
 *
 * The API reference (https://www.getonbrd.com/api-doc.html, OpenAPI spec `/doc/openapi.yaml`) describes a "Public API: open to anyone, the
 * same data visible on the platform without logging in, no authentication required" and a private one for paying companies. The catalogue
 * uses only the public side, one polite request every two seconds, and every listing is stored with the platform's name and a link to its
 * own page. Its Terms of Service were read (2026-10-13): the prohibitions found there are in the customer agreement; nothing in the public
 * API reference or the privacy page grants or denies storage or redistribution, so the source is published only after the owner reviews
 * this evidence (docs/SOURCES_6_0.md).
 *
 * The public listing carries no salary currency or period, so no salary is stored. The language is the one the listing states (es/en/pt);
 * "lang_not_specified" stays empty. `remote_modality` decides the place:
 *   no_remote / hybrid  -> on site / hybrid in the stated city (its country comes from the city record),
 *   remote_local        -> remote, eligible only in the listed countries,
 *   fully_remote        -> remote, eligibility not stated (never read as worldwide),
 *   temporarily_remote  -> mode left unspecified.
 * No listing is closed from here: a listing in the feed IS the proof that it is open (`presenceConfirmsOpen`); one that disappears stops
 * being stamped and `ops.expire_unseen_jobs` closes it after a week.
 */

export const GETONBOARD_HOST = 'getonbrd.com';
const PER_PAGE = 100;
const MAX_PAGES_PER_CATEGORY = 12;
const MAX_DESCRIPTION = 6000;

/** The 18 categories of `GET /api/v0/categories` (read 2026-10-13); a listing belongs to exactly one. */
export const GETONBOARD_CATEGORIES = [
  'programming', 'mobile-developer', 'data-science-analytics', 'machine-learning-ai', 'sysadmin-devops-qa', 'cybersecurity', 'design-ux',
  'technical-support', 'customer-support', 'sales', 'digital-marketing', 'advertising-media', 'operations-management', 'innovation-agile',
  'hr', 'hardware-electronics', 'education-coaching', 'other',
] as const;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const obj = (v: unknown): Record<string, unknown> => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {});
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const isoFromEpoch = (v: unknown): string | null => (typeof v === 'number' && Number.isFinite(v) && v > 0 ? new Date(v * 1000).toISOString() : null);

/** Country names the platform writes in Spanish and Portuguese besides the English ones `parseGeo` knows. */
const LOCAL_NAMES: Record<string, string> = {
  brasil: 'Brazil', espana: 'Spain', 'estados unidos': 'USA', mexico: 'Mexico', peru: 'Peru', panama: 'Panama', 'republica dominicana': 'Dominican Republic',
  alemania: 'Germany', 'reino unido': 'UK', canada: 'Canada',
};
const fold = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();
const asKnownName = (name: string): string => LOCAL_NAMES[fold(name)] ?? name;

/** Section text: the platform splits a listing into headline + body pairs; each is cleaned on its own and joined with blank lines. */
function describe(a: Record<string, unknown>): string {
  const parts: string[] = [];
  const add = (headline: unknown, body: unknown) => {
    const text = cleanDescription(str(body));
    if (!text) return;
    const h = inlineText(str(headline));
    parts.push(h ? `${h}\n${text}` : text);
  };
  add(a.description_headline, a.description);
  add('', a.projects);
  add(a.functions_headline, a.functions);
  add(a.benefits_headline, a.benefits);
  add(a.desirable_headline, a.desirable);
  const all = parts.join('\n\n');
  return all.length > MAX_DESCRIPTION ? `${all.slice(0, MAX_DESCRIPTION).trimEnd()}…` : all;
}

const MODE: Record<string, WorkMode> = { no_remote: 'onsite', hybrid: 'hybrid', remote_local: 'remote', fully_remote: 'remote' };
const LANG = new Set(['es', 'en', 'pt']);

export function normalizeGetOnBoard(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = str(r.id).trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9._~-]{0,199}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const a = obj(r.attributes);
  const title = inlineText(str(a.title));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = inlineText(str(obj(obj(obj(a.company).data).attributes).name));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = ownUrl(obj(r.links).public_url, GETONBOARD_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };

  const modality = str(a.remote_modality);
  const workMode = MODE[modality] ?? 'unspecified';
  const cities = arr(obj(a.location_cities).data).map((c) => obj(obj(c).attributes)).filter((c) => str(c.name));
  const named = arr(a.countries).map((c) => str(c).trim()).filter(Boolean);
  const places = named.filter((c) => fold(c) !== 'remote');
  const geo = parseGeo(places.map(asKnownName).join(', '));

  let country: string | null = null;
  let city: string | null = null;
  let restrictions: string[] = [];
  if (modality === 'remote_local') {
    // remote, but only inside the listed countries
    country = singleCountry(geo);
    restrictions = country ? [] : [...geo.countries, ...geo.unknown];
  } else if (modality === 'fully_remote') {
    // "Remote": the platform does not say from where; eligibility stays unknown unless countries are named
    restrictions = [...geo.countries, ...geo.unknown];
  } else if (cities.length > 0) {
    // on site / hybrid: the city record states town and country
    const first = cities[0]!;
    city = inlineText(str(first.name)) || null;
    const g = parseGeo(asKnownName(str(first.country)));
    country = cities.length === 1 || cities.every((c) => fold(str(c.country)) === fold(str(first.country))) ? singleCountry(g) : null;
    if (cities.length > 1) city = cities.map((c) => inlineText(str(c.name))).filter(Boolean).slice(0, 3).join(', ') || city;
  } else {
    country = singleCountry(geo);
  }

  const lang = str(a.lang).trim().toLowerCase();
  const job: NormalizedJob = {
    source: 'getonboard', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open',
    language: LANG.has(lang) ? lang : null,
    externalId: id, company, title, description: describe(a),
    country, city, workMode, contractType: null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null, // the public listing states no currency or period
    publishedAt: isoFromEpoch(a.published_at), originalUrl: url, applyUrl: url,
    geoRestrictions: restrictions,
  };
  return { ok: true, job };
}

/** Cursor: `{categoryIndex}:{page}`. */
function parseCursor(cursor: string | null): { cat: number; page: number } {
  if (cursor === null) return { cat: 0, page: 1 };
  const m = /^(\d{1,2}):(\d{1,3})$/.exec(cursor);
  if (!m) throw new Error('getonboard: invalid cursor');
  const cat = Number(m[1]);
  const page = Number(m[2]);
  if (cat >= GETONBOARD_CATEGORIES.length || page < 1 || page > MAX_PAGES_PER_CATEGORY) throw new Error('getonboard: invalid cursor');
  return { cat, page };
}

export function getOnBoardConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const ORIGIN = (opts.origin ?? 'https://www.getonbrd.com').replace(/\/+$/, '');
  const EXPAND = encodeURIComponent('["company","location_cities"]');
  return {
    id: 'getonboard',
    minIntervalMs: 2000,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      const { cat, page } = parseCursor(cursor);
      const category = GETONBOARD_CATEGORIES[cat]!;
      const data = await getFeed<{ data?: unknown; meta?: { total_pages?: unknown } }>(
        fetchImpl, `${ORIGIN}/api/v0/categories/${category}/jobs?per_page=${PER_PAGE}&page=${page}&expand=${EXPAND}`,
      );
      if (!Array.isArray(data.data)) throw new Error('getonboard: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.data) {
        const n = normalizeGetOnBoard(raw, nowIso);
        if (n.ok) jobs.push(n.job); else rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const totalPages = typeof data.meta?.total_pages === 'number' ? data.meta.total_pages : 1;
      let next: string | null;
      if (page < totalPages && page < MAX_PAGES_PER_CATEGORY && data.data.length > 0) next = `${cat}:${page + 1}`;
      else next = cat + 1 < GETONBOARD_CATEGORIES.length ? `${cat + 1}:1` : null;
      return { jobs, nextCursor: next, isFullSnapshot: false, rejected };
    },
  };
}
