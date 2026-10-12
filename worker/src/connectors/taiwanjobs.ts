import { cleanDescription } from '../description';
import { inlineText } from '../text';
import type { Connector, FetchPage, NormalizedJob, SalaryPeriod } from '../types';
import { getFeed, ownUrl, type Normalized } from './feeds';

/**
 * Taiwan Jobs (臺灣就業通), the job list the Workforce Development Agency of Taiwan's Ministry of Labor publishes as open data:
 *
 *   https://apiservice.mol.gov.tw/OdService/rest/datastore/A17000000J-030144-VAL   no key, no account, JSON, at most 1 000 records
 *   Dataset page: https://data.gov.tw/en/datasets/44062   License: "Open Government Data License, version 1.0" (perpetual, worldwide, royalty-free,
 *   commercial use and derivative works allowed; the attribution notice is mandatory, and without it the license is void: kept in `job_sources.attribution`).
 *
 * The dataset holds 1 000 vacancies (992 in Taipei City), refreshed once a day (`updateTime`), of every profession. Each record links to its page on
 * job.taiwanjobs.gov.tw. There is no status endpoint: a listing in the dataset IS the evidence (`presenceConfirmsOpen`), and one that is not listed
 * any more is never closed by absence (the dataset is a daily extract, not a complete register): the expiry turns it 'unknown' (migration 14).
 * The record's own application deadline (`STOP_DATE`) is respected: an ad whose deadline passed is not imported. Nothing is translated or guessed.
 */

export const TAIWANJOBS_HOST = 'job.taiwanjobs.gov.tw';
const RESOURCE = 'A17000000J-030144-VAL';
const PAGE = 1000;
const MAX_DESCRIPTION = 4000;

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const num = (v: unknown): number | null => {
  const n = typeof v === 'number' ? v : Number(str(v).replace(/[, ]/g, ''));
  return Number.isFinite(n) && n > 0 ? n : null;
};

/** The dataset names its fields "OCCU_DESC（職務名稱）": the code before the full-width parenthesis is the stable part. */
function byCode(raw: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(raw)) out[k.split('（')[0]!.trim()] = typeof v === 'string' ? v : v == null ? '' : String(v);
  return out;
}

/** "20261115" -> Date at the end of that day in Taipei (UTC+8); null for "額滿為止" (until filled) or anything else. */
export function deadlineOf(v: string): number | null {
  const m = /^(\d{4})(\d{2})(\d{2})$/.exec(v.trim());
  if (!m) return null;
  const t = Date.UTC(+m[1]!, +m[2]! - 1, +m[3]!, 23, 59, 59) - 8 * 3_600_000;
  return Number.isFinite(t) ? t : null;
}

const toIsoDate = (v: string): string | null => {
  const m = /^(\d{4})(\d{2})(\d{2})$/.exec(v.trim());
  if (!m) return null;
  const t = Date.UTC(+m[1]!, +m[2]! - 1, +m[3]!, 0, 0, 0) - 8 * 3_600_000;
  return Number.isFinite(t) ? new Date(t).toISOString() : null;
};

const PERIOD: Record<string, SalaryPeriod> = { 月薪: 'month', 時薪: 'hour', 日薪: 'day', '部分工時(月薪)': 'month' };

export function normalizeTaiwanJob(raw: unknown, nowIso: string): Normalized {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return { ok: false, reason: 'not_an_object', externalId: null };
  const r = byCode(raw as Record<string, unknown>);
  const url = ownUrl(r.URL_QUERY, TAIWANJOBS_HOST);
  const hire = url ? new URL(url).searchParams.get('HIRE_ID') : null;
  if (!url || !hire || !/^[0-9]{3,20}$/.test(hire)) return { ok: false, reason: 'invalid_url', externalId: hire };
  const title = inlineText(r.OCCU_DESC ?? '') || inlineText(r.CJOB_NAME2 ?? ''); // the posting's own title; else the occupation category it was filed under
  if (!title) return { ok: false, reason: 'missing_title', externalId: hire };
  const company = inlineText(r.COMPNAME ?? '');
  if (!company) return { ok: false, reason: 'missing_company', externalId: hire };
  const deadline = deadlineOf(r.STOP_DATE ?? '');
  if (deadline !== null && deadline < Date.parse(nowIso)) return { ok: false, reason: 'expired', externalId: hire };

  const lines = [r.JOB_DETAIL, r.WKTIME ? `工作時間：${r.WKTIME}` : '', r.EXPERIENCE ? `工作經驗：${r.EXPERIENCE}` : '', r.EDGRDESC ? `最低學歷要求：${r.EDGRDESC}` : '', r.CJOB_NAME1 ? `職務類別：${r.CJOB_NAME1}${r.CJOB_NAME2 ? ` / ${r.CJOB_NAME2}` : ''}` : '']
    .map((x) => cleanDescription(x ?? '')).filter(Boolean);
  let description = lines.join('\n\n');
  if (description.length > MAX_DESCRIPTION) description = `${description.slice(0, MAX_DESCRIPTION).trimEnd()}…`;

  const period = PERIOD[r.SALARYCD ?? ''] ?? null;
  const lo = num(r.NT_L);
  const hi = num(r.NT_U);
  const salaryOk = period !== null && lo !== null && (hi === null || hi >= lo);
  const city = inlineText(r.CITYNAME ?? '') || null;
  return {
    ok: true,
    job: {
      source: 'twjobs', lastCheckedAt: nowIso, requirements: [], skills: [], language: null, status: 'open',
      externalId: hire, company, title, description,
      country: 'TW', // the dataset is the national Taiwan Jobs site: every record is a vacancy in Taiwan (the cities are Taiwanese)
      city, workMode: 'unspecified', contractType: inlineText(r.WK_TYPE ?? '') || null,
      salaryMin: salaryOk ? lo : null, salaryMax: salaryOk ? (hi ?? lo) : null, salaryCurrency: salaryOk ? 'TWD' : null, salaryPeriod: salaryOk ? period : null,
      publishedAt: toIsoDate(r.TRANDATE ?? ''), // "職缺更新日期": the date the record was last updated, the only date the dataset gives
      originalUrl: url, applyUrl: url,
      geoRestrictions: [],
    } satisfies NormalizedJob,
  };
}

export function taiwanJobsConnector(fetchImpl: typeof fetch, now: () => Date = () => new Date(), opts: { origin?: string } = {}): Connector {
  const BASE = `${(opts.origin ?? 'https://apiservice.mol.gov.tw').replace(/\/+$/, '')}/OdService/rest/datastore/${RESOURCE}`;
  return {
    id: 'twjobs',
    minIntervalMs: 3000,
    presenceConfirmsOpen: true,
    async fetchPage(cursor): Promise<FetchPage> {
      const offset = cursor ? Number(cursor) : 0;
      if (!Number.isInteger(offset) || offset < 0 || offset % PAGE !== 0 || offset > 20 * PAGE) throw new Error('twjobs: invalid cursor');
      const data = await getFeed<{ success?: unknown; result?: { records?: unknown } }>(fetchImpl, `${BASE}?limit=${PAGE}&offset=${offset}`, 45_000);
      if (data.success !== true || !Array.isArray(data.result?.records)) throw new Error('twjobs: unexpected response');
      const nowIso = now().toISOString();
      const jobs: NormalizedJob[] = [];
      const rejected: { externalId: string | null; reason: string }[] = [];
      for (const raw of data.result.records) {
        const n = normalizeTaiwanJob(raw, nowIso);
        if (n.ok) jobs.push(n.job); else if (n.reason !== 'expired') rejected.push({ externalId: n.externalId, reason: n.reason });
      }
      const full = data.result.records.length === PAGE;
      return { jobs, nextCursor: full ? String(offset + PAGE) : null, isFullSnapshot: false, rejected };
    },
  };
}
