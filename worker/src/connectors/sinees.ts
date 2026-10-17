import { csvRecords } from '../csv-stream';
import { HttpError } from '../http';
import { inlineText } from '../text';
import type { Connector, NormalizedJob } from '../types';
import { ownUrl, type Normalized } from './feeds';
import { snapshotConnector } from './snapshot';

/**
 * SINE-ES, the Agências do Trabalhador of the state of Espírito Santo (Brazil): the vacancies their public employment offices hold, as open data of the state
 * government (dataset "Vagas das agências estaduais do trabalhador", SETADES, Creative Commons Attribution, on https://dados.es.gov.br):
 *
 *   https://dados.es.gov.br/api/3/action/package_show?id=c43d6653-634a-4e6e-bd66-c9ca3f6ee106   (CKAN: one CSV resource per office, rewritten every morning)
 *
 * Each CSV has the same eight columns: occupation (VAGA), vacancy code, the standard description of the occupation (the Brazilian occupation classification's text,
 * not the employer's own ad), qualification and schooling required (free text, typed by the office, kept as written), number of positions, the date the office
 * updated the record (MM/DD/YYYY) and the office (posto).
 *
 * What the data does NOT hold, and the connector therefore does not invent: the employer (the SINE does not name it: the company stays empty and the source's
 * attribution says so), a publication date (the update date is not the date the vacancy was opened: it is shown as "updated", not stored as published_at), a
 * salary, a work mode, a link to the individual vacancy. The link is the state's own page that lists these vacancies by office (https://setades.es.gov.br/vagas-de-empregos,
 * a viewer of this same dataset); the `#/vaga/<code>` route fragment keeps each listing's URL distinct (the catalogue de-duplicates by canonical URL and keeps a fragment only when it is a route like this), it does not change the page. Candidates apply through the
 * Agência do Trabalhador named in the listing.
 *
 * Freshness: the SETADES page itself says the data "reflect the last bulletin available from each agency". A record whose update date is older than 21 days is
 * refused (a whole office that stops updating drops out); the file lists only open vacancies, so one that leaves it stops being stamped (`presenceConfirmsOpen`).
 * A blank quantity counts as one position, as the SETADES page does; zero is refused.
 */

export const SINEES_HOST = 'es.gov.br';
export const SINEES_DATASET = 'c43d6653-634a-4e6e-bd66-c9ca3f6ee106';
export const SINEES_ORIGIN = 'https://dados.es.gov.br';
export const SINEES_PAGE = 'https://setades.es.gov.br/vagas-de-empregos';
export const SINEES_MAX_AGE_DAYS = 21;

const USER_AGENT = 'OrbiJob/1 (+https://github.com/Lucasdiogof/orbijob; job catalogue with attribution and original links)';
const MAX_FILES = 40;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const fold = (s: string): string => s.toLowerCase().normalize('NFD').replace(/\p{M}/gu, '').replace(/[^a-z0-9]+/g, ' ').trim();

/** MM/DD/YYYY (the export's order) -> YYYY-MM-DD, or '' when it is not a real date. */
export function usDay(s: string): string {
  const m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(s.trim());
  if (!m) return '';
  const [mo, d, y] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const date = new Date(Date.UTC(y, mo - 1, d));
  if (date.getUTCFullYear() !== y || date.getUTCMonth() !== mo - 1 || date.getUTCDate() !== d) return '';
  return `${y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/** A field that is only filler ("************", "-", "n/a") says nothing. */
const filler = (s: string): boolean => !/[\p{L}\p{N}]/u.test(s) || /^(n\/?a|nao se aplica)$/i.test(fold(s));

const text = (v: unknown): string => {
  const s = str(v).replace(/\r/g, '').split('\n').map((l) => l.replace(/[ \t]+/g, ' ').trim()).filter(Boolean).join('\n').trim();
  return filler(s) ? '' : s;
};

export interface SineRecord { vaga: string; codigo: string; descricao: string; qualificacao: string; escolaridade: string; quantidade: string; atualizacao: string; posto: string }

const HEADERS: Record<string, keyof SineRecord> = {
  vaga: 'vaga', 'codigo da vaga': 'codigo', 'descricao da vaga': 'descricao', 'exigencia de qualificacao': 'qualificacao',
  'exigencia de escolarizacao': 'escolaridade', quantidade: 'quantidade', dataatualizacao: 'atualizacao', 'data atualizacao': 'atualizacao', posto: 'posto',
};

export function normalizeSineEs(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = raw as Record<string, unknown>;
  const id = str(r.codigo).trim();
  if (!/^[0-9]{5,12}$/.test(id)) return { ok: false, reason: 'invalid_id', externalId: null };
  const title = inlineText(str(r.vaga));
  if (!title) return { ok: false, reason: 'missing_title', externalId: id };
  const qtyRaw = str(r.quantidade).trim();
  const qty = qtyRaw === '' ? 1 : Number(qtyRaw);
  if (!Number.isInteger(qty) || qty < 1) return { ok: false, reason: 'no_positions', externalId: id };
  const updated = usDay(str(r.atualizacao));
  if (!updated) return { ok: false, reason: 'invalid_date', externalId: id };
  if (Date.parse(`${updated}T00:00:00Z`) < Date.parse(nowIso) - SINEES_MAX_AGE_DAYS * 86_400_000) return { ok: false, reason: 'stale', externalId: id };
  const url = ownUrl(`${SINEES_PAGE}#/vaga/${id}`, SINEES_HOST);
  if (!url) return { ok: false, reason: 'invalid_url', externalId: id };
  const posto = inlineText(str(r.posto));
  const facts: string[] = [];
  const fact = (label: string, v: string) => { if (v) facts.push(`${label}: ${v}`); };
  fact('Vagas', String(qty));
  fact('Experiência/qualificação exigida', text(r.qualificacao));
  fact('Escolaridade exigida', text(r.escolaridade));
  fact('Posto de atendimento', posto ? `Agência do Trabalhador de ${posto} (SINE-ES)` : '');
  fact('Atualizada em', updated.split('-').reverse().join('/'));
  const description = [text(r.descricao), facts.join('\n')].filter(Boolean).join('\n\n');
  const job: NormalizedJob = {
    source: 'sinees', lastCheckedAt: nowIso, requirements: [], skills: [], status: 'open', language: 'pt',
    externalId: id, company: '', title, description,
    country: 'BR', city: posto ? `${posto}, ES` : 'Espírito Santo', workMode: 'unspecified', contractType: null,
    salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
    publishedAt: null,
    originalUrl: url, applyUrl: url, geoRestrictions: [],
  };
  return { ok: true, job };
}

export function sineEsConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const origin = (opts.origin ?? SINEES_ORIGIN).replace(/\/+$/, '');
  const get = async (url: string, accept: string): Promise<Response> => {
    const res = await fetchImpl(url, { headers: { Accept: accept, 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(60_000) });
    if (!res.ok) throw new HttpError(res.status);
    return res;
  };
  return snapshotConnector({
    id: 'sinees', fetchImpl, now, accept: 'application/json', timeoutMs: 60_000, emptyIsError: true,
    url: `${origin}/api/3/action/package_show?id=${SINEES_DATASET}`,
    quiet: ['expired', 'stale'],
    records: async (pkg) => {
      let meta: unknown;
      try { meta = await pkg.json(); } catch { throw new HttpError(403); }
      const result = (meta as { success?: unknown; result?: { resources?: unknown } } | null);
      if (!result || result.success !== true || !Array.isArray(result.result?.resources)) throw new HttpError(403); // not the catalogue: a challenge or an error page
      const files = (result.result!.resources as Record<string, unknown>[])
        .filter((x) => /^csv$/i.test(str(x.format)))
        .map((x) => str(x.url))
        .filter((u) => ownUrl(u, SINEES_HOST) !== null)
        .slice(0, MAX_FILES);
      const out: SineRecord[] = [];
      for (const u of files) {
        const res = await get(opts.origin ? u.replace(SINEES_ORIGIN, origin) : u, 'text/csv');
        if (!res.body) continue;
        let cols: (keyof SineRecord | null)[] | null = null;
        for await (const rec of csvRecords(res.body)) {
          if (!cols) { cols = rec.map((h) => HEADERS[fold(h)] ?? null); continue; }
          if (rec.every((c) => c.trim() === '')) continue;
          const o: Record<string, string> = {};
          rec.forEach((c, i) => { const k = cols![i]; if (k) o[k] = c; });
          out.push(o as unknown as SineRecord);
        }
      }
      return out;
    },
    normalize: normalizeSineEs,
  });
}
