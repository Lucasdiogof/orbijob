/**
 * Geographic eligibility as written by remote-job sources ("USA", "Canada,  Ireland", "EMEA", "Anywhere").
 * Only names that the source itself publishes are mapped (Jobicy taxonomy, `?get=locations`, 2026-10-09).
 * Anything else is kept as written: a location is never guessed.
 */

const strip = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();

/** Country display name -> ISO 3166-1 alpha-2. Keys are compared after `strip`. */
const COUNTRIES: Record<string, string> = {
  argentina: 'AR', australia: 'AU', austria: 'AT', belgium: 'BE', brazil: 'BR', bulgaria: 'BG', canada: 'CA',
  china: 'CN', 'costa rica': 'CR', croatia: 'HR', cyprus: 'CY', czechia: 'CZ', denmark: 'DK', estonia: 'EE',
  finland: 'FI', france: 'FR', germany: 'DE', greece: 'GR', 'hong kong': 'HK', hungary: 'HU', ireland: 'IE',
  israel: 'IL', italy: 'IT', japan: 'JP', latvia: 'LV', lithuania: 'LT', malaysia: 'MY', mexico: 'MX',
  netherlands: 'NL', 'new zealand': 'NZ', norway: 'NO', philippines: 'PH', poland: 'PL', portugal: 'PT',
  romania: 'RO', serbia: 'RS', singapore: 'SG', slovakia: 'SK', slovenia: 'SI', 'south korea': 'KR', spain: 'ES',
  sweden: 'SE', switzerland: 'CH', thailand: 'TH', turkiye: 'TR', uae: 'AE', uk: 'GB', ukraine: 'UA', usa: 'US',
  vietnam: 'VN',
};

/** Multi-country regions: kept as a region name, never expanded into countries. */
const REGIONS: Record<string, string> = { apac: 'APAC', emea: 'EMEA', latam: 'LATAM', europe: 'Europe' };

export interface ParsedGeo {
  /** The source says the job has no geographic restriction. */
  anywhere: boolean;
  /** ISO alpha-2 codes, in the order written, without repeats. */
  countries: string[];
  /** Region names (APAC, EMEA, LATAM, Europe). */
  regions: string[];
  /** Tokens not in the source taxonomy, preserved as written. */
  unknown: string[];
}

export function parseGeo(raw: unknown): ParsedGeo {
  const out: ParsedGeo = { anywhere: false, countries: [], regions: [], unknown: [] };
  if (typeof raw !== 'string') return out;
  for (const token of raw.split(',').map((t) => t.replace(/\s+/g, ' ').trim()).filter(Boolean)) {
    const k = strip(token);
    if (k === 'anywhere') out.anywhere = true;
    else if (COUNTRIES[k]) { if (!out.countries.includes(COUNTRIES[k]!)) out.countries.push(COUNTRIES[k]!); }
    else if (REGIONS[k]) { if (!out.regions.includes(REGIONS[k]!)) out.regions.push(REGIONS[k]!); }
    else if (!out.unknown.includes(token)) out.unknown.push(token);
  }
  return out;
}

/** `jobs.country` is set only when the posting is tied to exactly one country and nothing else. */
export function singleCountry(g: ParsedGeo): string | null {
  return !g.anywhere && g.countries.length === 1 && g.regions.length === 0 && g.unknown.length === 0 ? g.countries[0]! : null;
}

/** Marker stored in `jobs.geo_restrictions` when the source says, in so many words, that there is no geographic restriction. */
export const GEO_ANYWHERE = 'Anywhere';

/**
 * Value for `jobs.geo_restrictions`: ISO codes, region names and unknown tokens as written.
 *   ['Anywhere']  the source explicitly says "Anywhere" (no restriction);
 *   []            the source said nothing usable (missing/empty): eligibility UNKNOWN, never read as global;
 *   otherwise     the places the source names (the marker is kept in front when the source wrote both).
 * The column is `text[] not null default '{}'`, so the distinction needs no schema change.
 */
export function geoRestrictions(g: ParsedGeo): string[] {
  return [...(g.anywhere ? [GEO_ANYWHERE] : []), ...g.countries, ...g.regions, ...g.unknown];
}
