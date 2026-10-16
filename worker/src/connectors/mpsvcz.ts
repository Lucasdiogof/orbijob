import { cleanDescription } from '../description';
import { arrayItems } from '../json-stream';
import { inlineText } from '../text';
import { HttpError } from '../http';
import type { Connector, FetchPage, NormalizedJob, SalaryPeriod } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Úřad práce České republiky / MPSV (Czech public employment service), open data "Volná pracovní místa":
 *
 *   https://data.mpsv.cz/od/soubory/volna-mista/volna-mista.json.gz   (one JSON document, ~190 MB / 18 MB compressed, ~40,000 vacancies, refreshed daily)
 *
 * On 2026-10-16 the publisher dropped the uncompressed `volna-mista.json` (HTTP 404; only the `.gz` stays listed). The `.gz` is served with
 * `Content-Encoding: gzip`, which fetch decodes on its own; a body that still starts with the gzip magic bytes is decompressed here (`gunzipIfNeeded`).
 *   https://data.mpsv.cz/od/soubory/ciselniky/{obce,smennosti,pracovnepravni-vztahy}.json   (the code lists the vacancies point to)
 *
 * Terms: the publisher's own statement for every MPSV/ÚP ČR open dataset (https://data.mpsv.cz/web/data/podminky-uziti) says the distribution
 * contains no copyrighted works, is not a copyright-protected database, is not covered by the database maker's sui generis right and contains no
 * personal data. The file DOES carry names and e-mail addresses of employers' contact people (`prvniKontaktSeZamestnavatelem`, `pracoviste[].email`):
 * they are never read, stored or shown here. Each listing links to its own page on the public search, https://up.gov.cz/volna-mista-v-cr#/volna-mista-detail/{portalId}.
 *
 * What is stored (a rolling window, not the whole file): vacancies the office publishes (`zverejnovat` ano / anoeu), changed in the last 14 days
 * and not past their own `expirace`, the 3,000 most recently INSERTED. A vacancy that drops out of the window stops being confirmed and is expired by the
 * regular "unseen for 7 days" rule. Nothing is guessed: the place is a town only when the vacancy names exactly one; a salary only with a plausible
 * amount for its stated period (CZK); the work mode is not stated.
 */

export const MPSVCZ_HOST = 'up.gov.cz';
export const MPSVCZ_MAX = 3000;
export const MPSVCZ_CHANGED_DAYS = 14;
const MAX_DESCRIPTION = 6000;
/**
 * Czech and international telephone numbers written in groups (`777 123 456`, `+420 777 123 456`, `777-123-456`, `777123456`) or glued to
 * the country code (`+420721983270`, `00420721983270`). Longer digit runs (vacancy numbers such as `33171700713`) are not phones.
 */
export const PHONE = /(?:(?:\+|\b00)420[\s.-]?|\b)\d{3}[\s.-]?\d{3}[\s.-]?\d{3}\b/g;
const DATA_ORIGIN = 'https://data.mpsv.cz';
export const MPSVCZ_FILE = 'volna-mista/volna-mista.json.gz';

/** The body as text bytes, still streamed: decompressed when it starts with the gzip magic bytes (a client that did not apply Content-Encoding). */
export async function gunzipIfNeeded(body: ReadableStream<Uint8Array>): Promise<ReadableStream<Uint8Array>> {
  const reader = body.getReader();
  const first = await reader.read();
  let head: Uint8Array | null = first.done ? null : first.value; // looked at once, then passed on unchanged
  const whole = new ReadableStream<Uint8Array>({
    async pull(c) {
      if (head) { const h = head; head = null; c.enqueue(h); return; }
      const { value, done } = await reader.read();
      if (done) c.close(); else c.enqueue(value);
    },
    cancel(reason) { return reader.cancel(reason); },
  }, { highWaterMark: 0 });
  const gz = !!head && head.length >= 2 && head[0] === 0x1f && head[1] === 0x8b;
  return gz ? whole.pipeThrough(new DecompressionStream('gzip')) : whole;
}
const DAY = 86_400_000;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const obj = (v: unknown): Record<string, unknown> => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {});
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const idOf = (v: unknown): string => str(obj(v).id);

export interface MpsvCodes {
  /** `Obec/554782` -> "Praha" */
  towns: Map<string, string>;
  /** `Smennost/dvouSm` -> "Dvousměnný provoz" */
  shifts: Map<string, string>;
  /** `PracovnepravniVztah/plny` -> "Pracovní poměr - plný úvazek" */
  contracts: Map<string, string>;
}

/** Plausible CZK amounts per stated period: outside them the listing keeps no salary (the source mixes monthly figures into hourly entries). */
const RANGE: Partial<Record<SalaryPeriod, [number, number]>> = { hour: [50, 2000], month: [5000, 400_000] };

export function listingUrl(portalId: number): string | null {
  return ownUrl(`https://${MPSVCZ_HOST}/volna-mista-v-cr#/volna-mista-detail/${portalId}`, MPSVCZ_HOST);
}

/** The town of the vacancy: only when exactly one is named (the workplaces of a multi-site vacancy, or a list of districts, give none). */
function townOf(r: Record<string, unknown>, towns: Map<string, string>): string | null {
  const place = obj(r.mistoVykonuPrace);
  const ids = new Set<string>();
  const type = idOf(place.typMistaVykonuPrace);
  if (type === 'TypMistaVykonuPrace/obec' || type === 'TypMistaVykonuPrace/adrvolna') {
    if (idOf(place.obec)) ids.add(idOf(place.obec));
  } else if (type === 'TypMistaVykonuPrace/adrprov') {
    for (const w of arr(place.pracoviste)) {
      const t = idOf(obj(obj(w).adresa).obec);
      if (t) ids.add(t);
    }
  }
  if (ids.size !== 1) return null;
  return towns.get([...ids][0]!) ?? null;
}

export function normalizeMpsvJob(raw: unknown, nowIso: string, codes: MpsvCodes): Normalized {
  const r = obj(raw);
  const portalId = r.portalId;
  if (typeof portalId !== 'number' || !Number.isInteger(portalId) || portalId <= 0) return { ok: false, reason: 'invalid_id', externalId: null };
  const id = String(portalId);
  const publish = idOf(r.zverejnovat);
  if (publish !== 'ZverejnovatVpm/ano' && publish !== 'ZverejnovatVpm/anoeu') return { ok: false, reason: 'not_published', externalId: id };
  const title = inlineText(str(obj(r.pozadovanaProfese).cs));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const company = inlineText(str(obj(r.zamestnavatel).nazev));
  if (!company) return { ok: false, reason: 'missing_company', externalId: id };
  const url = listingUrl(portalId);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const expires = Date.parse(str(r.expirace));
  if (Number.isFinite(expires) && expires + DAY <= Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: id };

  const facts: string[] = [];
  const fact = (label: string, value: string) => {
    if (value) facts.push(`${label}: ${value}`);
  };
  const shift = codes.shifts.get(idOf(r.smennost)) ?? '';
  fact('Směnnost', shift && idOf(r.smennost) !== 'Smennost/neurceno' ? shift : '');
  const hours = Number(r.pocetHodinTydne);
  fact('Hodin týdně', Number.isFinite(hours) && hours > 0 && hours <= 80 ? String(hours) : '');
  const slots = Number(r.pocetMist);
  fact('Počet volných míst', Number.isInteger(slots) && slots > 1 ? String(slots) : '');
  fact('Nástup', /^\d{4}-\d{2}-\d{2}$/.test(str(r.terminZahajeniPracovnihoPomeru)) ? str(r.terminZahajeniPracovnihoPomeru) : '');
  const benefits = arr(r.vyhodyVolnehoMista).map((b) => inlineText(str(obj(b).popis))).filter(Boolean);
  fact('Výhody', benefits.join('; '));
  // employers sometimes write a contact person's phone number into the free text: telephone numbers are not kept (the listing's own page has the contact)
  const body = cleanDescription(str(obj(r.upresnujiciInformace).cs)).replace(PHONE, '[telefon]');
  let description = [body, facts.join('\n')].filter(Boolean).join('\n\n');
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;

  const contract = arr(r.pracovnePravniVztahy).map((c) => codes.contracts.get(idOf(c)) ?? '').filter(Boolean).join(', ');

  const period: SalaryPeriod | null = idOf(r.typMzdy) === 'TypMzdy/mesic' ? 'month' : idOf(r.typMzdy) === 'TypMzdy/hod' ? 'hour' : null;
  const lo = Number(r.mesicniMzdaOd);
  const hiRaw = r.mesicniMzdaDo === null || r.mesicniMzdaDo === undefined ? lo : Number(r.mesicniMzdaDo);
  const range = period ? RANGE[period] : undefined;
  const salaryOk = !!range && Number.isFinite(lo) && Number.isFinite(hiRaw) && lo >= range[0] && hiRaw <= range[1] && hiRaw >= lo;
  const posted = Date.parse(str(r.datumVlozeni));

  const job: NormalizedJob = {
    source: 'mpsvcz', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: 'cs',
    externalId: id, company, title, description,
    country: 'CZ', city: townOf(r, codes.towns), workMode: 'unspecified', contractType: contract || null,
    salaryMin: salaryOk ? lo : null, salaryMax: salaryOk ? hiRaw : null, salaryCurrency: salaryOk ? 'CZK' : null, salaryPeriod: salaryOk ? period : null,
    publishedAt: Number.isFinite(posted) ? new Date(posted).toISOString() : null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

/** The cheap checks done on the parsed element BEFORE normalizing it (most of the 40,000 elements are outside the window). */
export function inWindow(r: Record<string, unknown>, nowMs: number): boolean {
  const publish = idOf(r.zverejnovat);
  if (publish !== 'ZverejnovatVpm/ano' && publish !== 'ZverejnovatVpm/anoeu') return false;
  const changed = Date.parse(str(r.datumZmeny));
  return Number.isFinite(changed) && nowMs - changed <= MPSVCZ_CHANGED_DAYS * DAY && changed <= nowMs + DAY;
}

async function codeList(fetchImpl: typeof fetch, origin: string, name: string): Promise<Record<string, unknown>[]> {
  const d = await getFeed<unknown>(fetchImpl, `${origin}/ciselniky/${name}.json`, 60_000);
  const items = obj(d).polozky;
  if (!Array.isArray(items)) throw new Error(`mpsvcz: unexpected code list ${name}`);
  return items.map(obj);
}
const names = (items: Record<string, unknown>[]) => new Map(items.map((i) => [str(i.id), inlineText(str(obj(i.nazev).cs))] as [string, string]).filter(([k, v]) => k && v));

export function mpsvCzConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string; max?: number; minTowns?: number; minVacancies?: number } = {}): Connector {
  const ORIGIN = `${(opts.origin ?? DATA_ORIGIN).replace(/\/+$/, '')}/od/soubory`;
  const MAX = opts.max ?? MPSVCZ_MAX;
  return {
    id: 'mpsvcz',
    minIntervalMs: 60_000, // one ~190 MB answer per pass, never more than one a minute (the data refreshes once a day)
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      if (cursor !== null) throw new Error('mpsvcz: invalid cursor');
      const codes: MpsvCodes = {
        towns: names(await codeList(fetchImpl, ORIGIN, 'obce')),
        shifts: names(await codeList(fetchImpl, ORIGIN, 'smennosti')),
        contracts: names(await codeList(fetchImpl, ORIGIN, 'pracovnepravni-vztahy')),
      };
      if (codes.towns.size < (opts.minTowns ?? 1000)) throw new Error('mpsvcz: the town list is implausibly small');
      const res = await fetchImpl(`${ORIGIN}/${MPSVCZ_FILE}`, {
        headers: { Accept: 'application/json', 'User-Agent': 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)' },
        signal: AbortSignal.timeout(300_000),
      });
      if (!res.ok || !res.body) throw new HttpError(res.status || 502);
      const nowDate = now();
      const nowIso = nowDate.toISOString();
      const nowMs = nowDate.getTime();
      type Entry = { inserted: number; id: number; job: NormalizedJob };
      let kept: Entry[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      let seen = 0;
      for await (const text of arrayItems(await gunzipIfNeeded(res.body), 'polozky')) {
        seen++;
        let r: Record<string, unknown>;
        try {
          r = obj(JSON.parse(text));
        } catch {
          rejected.push({ externalId: null, reason: 'unparsable_element' });
          continue;
        }
        if (!inWindow(r, nowMs)) continue;
        const n = normalizeMpsvJob(r, nowIso, codes);
        if (!n.ok) {
          if (n.reason !== 'expired') rejected.push({ externalId: n.externalId, reason: n.reason });
          continue;
        }
        kept.push({ inserted: Date.parse(n.job.publishedAt ?? '') || 0, id: Number(n.job.externalId), job: n.job });
        if (kept.length > MAX * 2) kept = kept.sort((a, b) => b.inserted - a.inserted || b.id - a.id).slice(0, MAX);
      }
      if (seen < (opts.minVacancies ?? 1000)) throw new Error(`mpsvcz: the file holds only ${seen} vacancies, which is implausible`);
      kept.sort((a, b) => b.inserted - a.inserted || b.id - a.id);
      return { jobs: kept.slice(0, MAX).map((e) => e.job), nextCursor: null, isFullSnapshot: false, rejected };
    },
  };
}
