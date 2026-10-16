import { csvRecords } from '../csv-stream';
import { maskPersonalEmails } from '../description';
import { HttpError } from '../http';
import { inlineText } from '../text';
import type { Connector, FetchPage, JobStatus, NormalizedJob } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Choisir le Service Public (France): the job offers of the three branches of the French civil service (State, local authorities, public
 * hospitals), published by the Direction générale de l'administration et de la fonction publique as open data on data.gouv.fr:
 *
 *   dataset "Les offres diffusées sur Choisir le Service Public" (https://www.data.gouv.fr/datasets/6322e99e12175f7eb26ff465), weekly CSV (~120 MB,
 *   `;`-separated, every offer of the year so far), licence `lov2` = Licence Ouverte / Open Licence 2.0 (Etalab: reuse, including commercial,
 *   republication and adaptation, with the source and the date of the data). The site itself states that its texts are under the same licence
 *   (https://choisirleservicepublic.gouv.fr/mentions-legales/). robots.txt allows the offer pages.
 *
 * The file is a week (often more) behind the site and keeps an offer until its default end of publication, so a THIRD of the offers still inside
 * that window had already been withdrawn when sampled (13 of 40, 2026-10-14). The file alone therefore never proves an offer open: every new offer
 * is checked on its own page before it is stored (`checkStatuses`), and stored offers are checked again by the revalidation pass. The page of a
 * withdrawn offer is titled "Offre dépubliée"; an offer's page by reference is https://choisirleservicepublic.gouv.fr/offre-emploi/{slug}-reference-{ref}/
 * (the site resolves the reference whatever the slug).
 *
 * What is kept, without guessing: the title as written; the employer named by the offer (its first line) or else the body it reports to, and
 * for the generic territorial bodies ("Communes", "Conseils départementaux") the authority the title names; the town only from a postal-code
 * address; the description is made of the structured facts of the file (the file has no free text besides the expected skills and the documents
 * to send), with e-mail addresses and telephone numbers masked. The work mode stays unspecified ("Télétravail: Oui" is shown as a fact).
 */

export const CSP_HOST = 'choisirleservicepublic.gouv.fr';
export const CSP_DATASET = '6322e99e12175f7eb26ff465';
export const CSP_MAX = 3000;
/** Offers first published within this many days of the file's newest offer: older ones are mostly filled even when still inside their window. */
export const CSP_RECENT_DAYS = 45;
/** One offer page a second: the site states no rate limit; this is our own politeness. */
export const CSP_PAGE_DELAY_MS = 1000;
/** Time one `checkStatuses` call may spend: a discovery pass has a 3-minute budget and a 4-minute hard stop. */
export const CSP_CALL_BUDGET_MS = 110_000;
const DATA_HOST = 'static.data.gouv.fr';
const MAX_DESCRIPTION = 6000;
const UA = 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)';

/** French telephone numbers: 0X XX XX XX XX in any grouping, or +33 / 0033 followed by 9 digits. */
export const FR_PHONE = /(?:(?:\+|\b00)33[\s.-]?(?:\(0\)[\s.-]?)?[1-9]|\b0[1-9])(?:[\s.-]?\d{2}){4}\b/g;

export const FIELDS = {
  body: 'Organisme de rattachement', ref: 'Référence', branch: 'Versant', trade: 'Métier', post: 'Statut du poste', nature: "Nature de l'emploi",
  length: 'Durée du contrat', title: 'Intitulé du poste', area: 'Localisation du poste', place: "Lieu d'affectation", studies: "Niveau d'études",
  experience: "Niveau d'expérience min. requis", vacantFrom: "Date de vacance de l'emploi", start: 'Date de début de publication par défaut',
  end: 'Date de fin de publication par défaut', first: 'Date de première publication', telework: 'Télétravail', management: 'Management',
  employer: 'Employeur', category: 'Catégorie', fullTime: 'Temps Plein', placePlain: "Lieu d'affectation (sans géolocalisation)",
  skills: 'Compétences attendues', documents: 'Documents à transmettre', contract: 'Nature de contrat',
} as const;
export type CspRow = Partial<Record<keyof typeof FIELDS, string>>;

/** The bodies the file names by kind rather than by name: the offer's own title usually names the authority ("... - Commune de Nice"). */
const GENERIC_BODIES = new Set([
  'communes', 'etablissements publics de coopération intercommunale', 'conseils départementaux', 'conseils régionaux', 'etablissements publics locaux',
  "centres communaux d'action sociale", "services départementaux d'incendie et de secours", 'structures de coopération territoriale',
]);
const AUTHORITY = /^(commune|ville|mairie|région|département|conseil|communauté|métropole|ccas|cias|centre|syndicat|sdis|agglomération|grand|établissement|etablissement)\b/i;

/** dd/mm/yyyy -> yyyy-mm-dd, or '' when it is not a real date. */
export function isoDay(s: string | undefined): string {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec((s ?? '').trim());
  if (!m) return '';
  const iso = `${m[3]}-${m[2]}-${m[1]}`;
  const d = new Date(`${iso}T00:00:00Z`);
  return Number.isFinite(d.getTime()) && d.toISOString().slice(0, 10) === iso ? iso : '';
}

const fold = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
const slug = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80) || 'offre';
export const REF = /^[A-Za-z0-9][A-Za-z0-9_.-]{2,39}$/;

export function offerUrl(ref: string, title: string): string | null {
  if (!REF.test(ref)) return null;
  return ownUrl(`https://${CSP_HOST}/offre-emploi/${slug(title)}-reference-${encodeURIComponent(ref)}/`, CSP_HOST);
}

const clean = (s: string | undefined) => maskPersonalEmails((s ?? '').replace(FR_PHONE, '[téléphone]'));

export function companyOf(r: CspRow, title: string): string {
  const first = inlineText((r.employer ?? '').split('\n')[0] ?? '');
  if (first && first.length <= 80 && !/\brecrute\b/i.test(first) && !/[.:]$/.test(first) && !/^(direction|affectation)\s*:/i.test(first)) return first;
  const body = inlineText(r.body ?? '');
  if (GENERIC_BODIES.has(body.toLowerCase())) {
    const parts = title.split(/\s[-–]\s/);
    const named = parts.length > 1 ? inlineText(parts[parts.length - 1]!) : '';
    if (named && named.length <= 80 && AUTHORITY.test(named)) return named;
    // "Jardinier (h/f) - Pantin" with the town hall's address in Pantin: the employer is that commune
    const town = townOf(r);
    if (body.toLowerCase() === 'communes' && named && town && fold(named) === fold(town)) return `Commune de ${town}`;
  }
  return body;
}

/** The town of a postal address ("... : 23320 Saint-Vaury", "75004 PARIS", "35703 RENNES CEDEX 7"), or null. */
export function townOf(r: CspRow): string | null {
  for (const raw of [r.placePlain, r.place]) {
    const line = (raw ?? '').split('\n').map((l) => l.trim()).find((l) => /\b\d{5}\b/.test(l));
    if (!line) continue;
    const m = /\b\d{5}\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ' -]*?)(?:\s+cedex\b.*)?\s*$/i.exec(line);
    if (!m) continue;
    const town = m[1]!.trim().replace(/\s+\d+$/, '');
    if (town.length < 2 || town.length > 50) continue;
    return town === town.toUpperCase() ? town.toLowerCase().replace(/(^|[\s'-])\p{L}/gu, (c) => c.toUpperCase()) : town;
  }
  return null;
}

export function normalizeCsp(r: CspRow, nowIso: string): Normalized {
  const ref = (r.ref ?? '').trim();
  if (!REF.test(ref)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(r.title ?? '');
  if (!title) return { ok: false, reason: 'missing_title', externalId: ref };
  const company = companyOf(r, title);
  if (!company) return { ok: false, reason: 'missing_company', externalId: ref };
  const today = nowIso.slice(0, 10);
  const end = isoDay(r.end);
  if (!end || end < today) return { ok: false, reason: 'expired', externalId: ref };
  const start = isoDay(r.start);
  if (start && start > today) return { ok: false, reason: 'not_yet_published', externalId: ref };
  const url = offerUrl(ref, title);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: ref };

  const facts: string[] = [];
  const fact = (label: string, v: string | undefined) => {
    const t = inlineText(clean(v));
    if (t) facts.push(`${label} : ${t}`);
  };
  fact('Métier', (r.trade ?? '').replace(/\*/g, ''));
  fact('Versant', r.branch);
  fact('Catégorie', r.category);
  fact('Statut du poste', r.post);
  fact("Nature de l'emploi", r.nature);
  fact('Nature du contrat', r.contract);
  fact('Durée du contrat', r.length);
  fact('Localisation', r.area);
  fact("Niveau d'études", r.studies);
  fact("Niveau d'expérience", r.experience);
  fact('Temps plein', r.fullTime);
  fact('Télétravail', r.telework);
  fact('Management', r.management);
  const vacant = isoDay(r.vacantFrom);
  if (vacant) facts.push(`Date de vacance : ${vacant}`);
  const blocks = [facts.join('\n')];
  const skills = clean(r.skills).trim();
  if (skills) blocks.push(`Compétences attendues :\n${skills}`);
  const docs = clean(r.documents).trim();
  if (docs) blocks.push(`Documents à transmettre :\n${docs}`);
  let description = blocks.filter(Boolean).join('\n\n');
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;

  const firstDay = isoDay(r.first) || start;
  const contract = [r.contract, r.nature].map((v) => inlineText(v ?? '')).find(Boolean) ?? null;
  const job: NormalizedJob = {
    source: 'csp', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: 'fr',
    externalId: ref, company, title, description,
    country: 'FR', city: townOf(r), workMode: 'unspecified', contractType: contract,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: firstDay ? `${firstDay}T00:00:00.000Z` : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

/** The newest weekly file of the dataset: the full ones are over 10 MB (a stray partial file of 1.6 MB exists and is skipped). */
export async function latestFileUrl(fetchImpl: typeof fetch, api = 'https://www.data.gouv.fr'): Promise<string> {
  const d = await getFeed<{ resources?: { title?: string; url?: string; format?: string; filesize?: number }[] }>(fetchImpl, `${api}/api/1/datasets/${CSP_DATASET}/`, 30_000);
  const files = (d.resources ?? [])
    .map((r) => ({ url: r.url ?? '', day: /offres-datagouv-(\d{8})\.csv$/.exec(r.title ?? '')?.[1] ?? '', size: r.filesize ?? 0 }))
    .filter((r) => r.day && r.size > 10_000_000 && ownUrl(r.url, DATA_HOST))
    .sort((a, b) => b.day.localeCompare(a.day));
  if (!files.length) throw new Error('csp: no weekly file in the dataset');
  return files[0]!.url;
}

/** What an offer's page says: its own title -> open; "Offre dépubliée" -> closed; anything else -> no answer. */
export function statusFromPage(html: string): JobStatus | null {
  const title = /<title>([^<]*)<\/title>/i.exec(html)?.[1] ?? '';
  if (/^\s*Offre dépubliée\s*\|/i.test(title)) return 'closed';
  if (/\|\s*Choisir le service public\s*$/i.test(title.trim()) && !/^\s*(Page non trouvée|Erreur)/i.test(title)) return 'open';
  return null;
}

export function cspConnector(
  fetchImpl: typeof fetch, now: () => Date = () => new Date(),
  opts: { api?: string; max?: number; minRows?: number; pageDelayMs?: number; callBudgetMs?: number; sleep?: (ms: number) => Promise<void> } = {},
): Connector {
  const MAX = opts.max ?? CSP_MAX;
  const delay = opts.pageDelayMs ?? CSP_PAGE_DELAY_MS;
  const callBudget = opts.callBudgetMs ?? CSP_CALL_BUDGET_MS;
  const sleep = opts.sleep ?? ((ms: number) => new Promise((r) => setTimeout(r, ms)));
  return {
    id: 'csp',
    // one ~120 MB file per pass (it changes once a week); the offer pages are paced by checkStatuses itself
    minIntervalMs: 1000,
    statusBatch: 25, // ~35 s per batch of pages: a revalidation batch always ends well inside the pass's hard time limit
    async fetchPage(cursor): Promise<FetchPage> {
      if (cursor !== null) throw new Error('csp: invalid cursor');
      const fileUrl = await latestFileUrl(fetchImpl, opts.api);
      const res = await fetchImpl(fileUrl, { headers: { 'User-Agent': UA }, signal: AbortSignal.timeout(300_000) });
      if (!res.ok || !res.body) throw new HttpError(res.status || 502);
      const nowIso = now().toISOString();
      let index: Map<keyof typeof FIELDS, number> | null = null;
      const all: { day: string; job: NormalizedJob }[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      const seenRefs = new Set<string>();
      let rows = 0;
      let newest = '';
      for await (const rec of csvRecords(res.body, ';')) {
        if (!index) {
          const head = rec.map((h) => h.trim());
          index = new Map();
          for (const [k, name] of Object.entries(FIELDS) as [keyof typeof FIELDS, string][]) {
            const i = head.indexOf(name);
            if (i >= 0) index.set(k, i);
          }
          for (const k of ['ref', 'title', 'body', 'end'] as const) if (!index.has(k)) throw new Error(`csp: the file lacks the column "${FIELDS[k]}"`);
          continue;
        }
        rows++;
        const r: CspRow = {};
        for (const [k, i] of index) r[k] = rec[i] ?? '';
        const day = isoDay(r.first);
        if (day > newest && day <= nowIso.slice(0, 10)) newest = day;
        const n = normalizeCsp(r, nowIso);
        if (!n.ok) {
          if (n.reason !== 'expired' && n.reason !== 'not_yet_published') rejected.push({ externalId: n.externalId, reason: n.reason });
          continue;
        }
        if (seenRefs.has(n.job.externalId)) continue; // the same reference twice in a file: the first is kept
        seenRefs.add(n.job.externalId);
        all.push({ day: day || (n.job.publishedAt ?? '').slice(0, 10), job: n.job });
      }
      if (rows < (opts.minRows ?? 10_000)) throw new Error(`csp: the file holds only ${rows} offers, which is implausible`);
      const from = newest ? new Date(Date.parse(`${newest}T00:00:00Z`) - CSP_RECENT_DAYS * 86_400_000).toISOString().slice(0, 10) : '';
      const kept = all.filter((e) => e.day >= from).sort((a, b) => b.day.localeCompare(a.day) || a.job.externalId.localeCompare(b.job.externalId));
      return { jobs: kept.slice(0, MAX).map((e) => e.job), nextCursor: null, isFullSnapshot: false, rejected };
    },
    async checkStatuses(externalIds: string[]): Promise<Record<string, JobStatus>> {
      const out: Record<string, JobStatus> = {};
      const until = now().getTime() + callBudget;
      for (const [k, ref] of externalIds.entries()) {
        if (now().getTime() >= until) break; // the rest stays unanswered (not stored when new, asked again on the next pass when stored)
        const url = offerUrl(ref, 'offre');
        if (!url) continue;
        if (k > 0) await sleep(delay);
        try {
          const res = await fetchImpl(url, { headers: { 'User-Agent': UA, Accept: 'text/html' }, signal: AbortSignal.timeout(20_000) });
          if (res.status === 429 || res.status >= 500) break; // the site is struggling: stop asking; the rest waits for the next pass
          if (!res.ok) continue;
          const s = statusFromPage(await res.text());
          if (s) out[ref] = s;
        } catch {
          // a network hiccup on one page: no answer for it
        }
      }
      return out;
    },
  };
}
