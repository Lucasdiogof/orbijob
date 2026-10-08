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

/** Stable fingerprint: company + title + country + city (exact-ish duplicate across sources). */
export function fingerprint(j: NormalizedJob): string {
  return [norm(j.company), norm(j.title), j.country ?? '', norm(j.city ?? '')].join('|');
}

/**
 * Dedupe strategy (see docs/DATABASE.md):
 *  1. same (source, externalId)  -> same row (upsert)
 *  2. same canonical apply/original URL -> same cluster
 *  3. same fingerprint -> same cluster
 * The first occurrence wins; others are returned in `duplicates` for audit.
 */
export function dedupe(jobs: NormalizedJob[]): { unique: NormalizedJob[]; duplicates: NormalizedJob[] } {
  const seenKey = new Set<string>();
  const seenUrl = new Set<string>();
  const seenFp = new Set<string>();
  const unique: NormalizedJob[] = [];
  const duplicates: NormalizedJob[] = [];
  for (const j of jobs) {
    const key = `${j.source}:${j.externalId}`;
    const urls = [j.applyUrl, j.originalUrl].filter((u): u is string => !!u).map(canonicalUrl);
    const fp = fingerprint(j);
    const dup = seenKey.has(key) || urls.some((u) => seenUrl.has(u)) || seenFp.has(fp);
    if (dup) {
      duplicates.push(j);
      continue;
    }
    seenKey.add(key);
    urls.forEach((u) => seenUrl.add(u));
    seenFp.add(fp);
    unique.push(j);
  }
  return { unique, duplicates };
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
