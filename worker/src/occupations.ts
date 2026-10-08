export interface Occupation {
  id: string;
  isco08: string;
  escoUri: string | null;
  labels: Record<string, string[]>;
  exclude: string[];
}

export interface OccupationMatch {
  occupation: Occupation;
  matchedTerm: string;
  lang: string;
  /** exact = whole query equals a label; partial = label found inside the query. */
  kind: 'exact' | 'partial';
}

const fold = (s: string) =>
  s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim();

/**
 * Resolve free text to standardized occupations. Deterministic, no AI.
 * Exclusion terms keep neighbouring-but-different occupations apart
 * (e.g. "electrician" vs "electrical engineer"). Unknown text returns [] and the
 * caller falls back to plain keyword search - never to a guessed occupation.
 */
export function resolveOccupation(query: string, occupations: Occupation[]): OccupationMatch[] {
  const q = fold(query);
  const out: OccupationMatch[] = [];
  for (const occ of occupations) {
    if (occ.exclude.some((x) => q.includes(fold(x)))) continue;
    let best: OccupationMatch | null = null;
    for (const [lang, terms] of Object.entries(occ.labels)) {
      for (const t of terms) {
        const ft = fold(t);
        if (ft === q) {
          best = { occupation: occ, matchedTerm: t, lang, kind: 'exact' };
        } else if (!best && q.includes(ft)) {
          best = { occupation: occ, matchedTerm: t, lang, kind: 'partial' };
        }
        if (best?.kind === 'exact') break;
      }
      if (best?.kind === 'exact') break;
    }
    if (best) out.push(best);
  }
  // exact first, then longest matched term (more specific)
  return out.sort((a, b) =>
    a.kind !== b.kind ? (a.kind === 'exact' ? -1 : 1) : b.matchedTerm.length - a.matchedTerm.length);
}

/** All labels of an occupation in all languages: used to expand a search into synonyms. */
export const expandTerms = (o: Occupation): string[] => [...new Set(Object.values(o.labels).flat())];
