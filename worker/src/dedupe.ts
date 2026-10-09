import type { NormalizedJob } from './types';

const norm = (s: string) =>
  s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();

/** Canonical URL: lowercase host, no tracking params, no fragment, no trailing slash. */
export function canonicalUrl(raw: string): string {
  try {
    const u = new URL(raw);
    u.hash = '';
    for (const k of [...u.searchParams.keys()]) {
      if (/^(utm_|gh_src|lever-source|ref$|source$)/i.test(k)) u.searchParams.delete(k);
    }
    return (u.origin + u.pathname.replace(/\/+$/, '') + u.search).toLowerCase();
  } catch {
    return raw.trim().toLowerCase();
  }
}

/**
 * Stable fingerprint: company + title + country + city (exact-ish duplicate across sources).
 * Without a company the match would be "same title in the same place", which merges unrelated employers, so such
 * a job is only ever identified by its own source id.
 */
export function fingerprint(j: NormalizedJob): string {
  const company = norm(j.company);
  if (!company) return `${j.source}:${j.externalId}`;
  return [company, norm(j.title), j.country ?? '', norm(j.city ?? '')].join('|');
}

/**
 * Dedupe strategy (see docs/DATABASE.md):
 *  1. same (source, externalId)  -> same row (upsert)
 *  2. same canonical apply/original URL -> same cluster
 *  3. same fingerprint -> same cluster
 * The first occurrence wins; others are returned in `duplicates` for audit.
 */
export function dedupe(jobs: NormalizedJob[]): { unique: NormalizedJob[]; duplicates: NormalizedJob[] } {
  const d = new Deduper();
  const unique: NormalizedJob[] = [];
  const duplicates: NormalizedJob[] = [];
  for (const j of jobs) (d.accept(j) ? unique : duplicates).push(j);
  return { unique, duplicates };
}

/** Incremental form of `dedupe`: remembers what it has accepted so a sync can dedupe page by page. */
export class Deduper {
  private seenKey = new Set<string>();
  private seenUrl = new Set<string>();
  private seenFp = new Set<string>();

  /** True when the job is new (and now remembered); false when it duplicates an accepted one. */
  accept(j: NormalizedJob): boolean {
    const key = `${j.source}:${j.externalId}`;
    const urls = [j.applyUrl, j.originalUrl].filter((u): u is string => !!u).map(canonicalUrl);
    const fp = fingerprint(j);
    if (this.seenKey.has(key) || urls.some((u) => this.seenUrl.has(u)) || this.seenFp.has(fp)) return false;
    this.seenKey.add(key);
    urls.forEach((u) => this.seenUrl.add(u));
    this.seenFp.add(fp);
    return true;
  }
}

/**
 * A job may only be marked closed when the source gave a FULL snapshot and
 * the job is absent from it. Absence from a "recent jobs" feed means nothing.
 */
export function shouldMarkClosed(
  page: { isFullSnapshot: boolean },
  knownOpenIds: string[],
  seenIds: Set<string>,
): string[] {
  if (!page.isFullSnapshot) return [];
  return knownOpenIds.filter((id) => !seenIds.has(id));
}
