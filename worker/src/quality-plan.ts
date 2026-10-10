import { cleanDescription, MASKED_EMAIL } from './description';
import { GEO_ANYWHERE, geoRestrictions, parseGeo } from './geo';
import { assessSalary } from './salary';
import type { SalaryPeriod } from './types';

/**
 * Plan (never an execution) for correcting records that were stored BEFORE the data-quality rules existed.
 * Pure functions: the script worker/scripts/jobicy-quality-plan.mjs reads the rows (read-only), calls these, and writes a report
 * and a guarded SQL file for the owner to review. Nothing here talks to a database.
 *
 * What may change in stored data, and what may not:
 *   description   cleaned with the same rules as new imports (Markdown residue, CR, invisible characters, double-encoded
 *                 entities, personal e-mail addresses). Only rows whose text actually changes.
 *   geo           only when the SOURCE confirms "Anywhere" (evidence file) for a row whose list is empty. An empty list alone is
 *                 ambiguous (absent vs Anywhere) and is never rewritten on a guess.
 *   salary        NEVER changed. Suspicious figures are only listed: the app already hides them, and the real value must come
 *                 from the source. 168 per year is not turned into 168,000.
 */
export interface StoredRow {
  external_id: string;
  description: string | null;
  /** md5(description) as computed by the database, used as a guard in the generated SQL. */
  description_md5: string | null;
  geo_restrictions: string[];
  country: string | null;
  salary_min: number | null;
  salary_max: number | null;
  salary_currency: string | null;
  salary_period: string | null;
}

export interface DescriptionChange {
  externalId: string;
  md5Before: string;
  after: string;
  emailsMasked: number;
  lengthBefore: number;
  lengthAfter: number;
}
export interface SalaryFinding { externalId: string; min: number | null; max: number | null; currency: string | null; period: string | null; verdict: string }
export interface GeoChange { externalId: string; to: string[] }

export interface QualityPlan {
  totalRows: number;
  description: DescriptionChange[];
  geo: GeoChange[];
  salaryNeedsSource: SalaryFinding[];
  /** Rows with an empty geo list and no source evidence: left alone (absent or Anywhere cannot be told apart from the database). */
  geoUnresolved: string[];
}

const PERIODS = new Set(['hour', 'day', 'week', 'month', 'year']);

/** `sourceGeo`: external_id -> the raw `jobGeo` string the source published (captured from the feed), as evidence for "Anywhere". */
export function buildPlan(rows: StoredRow[], sourceGeo: Record<string, string> = {}): QualityPlan {
  const plan: QualityPlan = { totalRows: rows.length, description: [], geo: [], salaryNeedsSource: [], geoUnresolved: [] };
  for (const r of rows) {
    if (r.description) {
      const after = cleanDescription(r.description);
      if (after !== r.description && after.length > 0 && r.description_md5) {
        plan.description.push({
          externalId: r.external_id,
          md5Before: r.description_md5,
          after,
          emailsMasked: after.split(MASKED_EMAIL).length - 1 - (r.description.split(MASKED_EMAIL).length - 1),
          lengthBefore: r.description.length,
          lengthAfter: after.length,
        });
      }
    }
    const period = r.salary_period && PERIODS.has(r.salary_period) ? (r.salary_period as SalaryPeriod) : null;
    if ((r.salary_min !== null || r.salary_max !== null) && period) {
      const verdict = assessSalary(r.salary_min, r.salary_max, period);
      if (verdict !== 'plausible') {
        plan.salaryNeedsSource.push({ externalId: r.external_id, min: r.salary_min, max: r.salary_max, currency: r.salary_currency, period: r.salary_period, verdict });
      }
    }
    if (r.geo_restrictions.length === 0 && r.country === null) {
      const raw = sourceGeo[r.external_id];
      const parsed = raw === undefined ? null : parseGeo(raw);
      const target = parsed ? geoRestrictions(parsed) : null;
      if (target && target.length === 1 && target[0] === GEO_ANYWHERE) plan.geo.push({ externalId: r.external_id, to: target });
      else plan.geoUnresolved.push(r.external_id);
    }
  }
  return plan;
}

const lit = (s: string) => `'${s.replace(/'/g, "''")}'`;

/** A dollar-quote tag that does not occur in [text]. */
function tagFor(text: string, i: number): string {
  let tag = `q${i}`;
  while (text.includes(`$${tag}$`)) tag += 'x';
  return `$${tag}$`;
}

/**
 * The SQL for the owner to review and run (it is NOT run by any script of this repository). Safety properties:
 *  - one transaction; short lock and statement timeouts;
 *  - aborts unless the table still has exactly the rows the plan was made from;
 *  - every UPDATE is keyed by (source_id, external_id) AND guarded by md5 of the text the plan saw, so a row edited since the plan,
 *    or an id that is not in the plan, is never touched;
 *  - each UPDATE must change EXACTLY the planned number of rows, otherwise the whole transaction fails (so a second run, which
 *    finds nothing to change, also fails instead of silently doing nothing);
 *  - only `description` and, with evidence, `geo_restrictions` are written; salary, can_redistribute and every other column never.
 */
export function renderSql(plan: QualityPlan, sourceId = 'jobicy'): string {
  const out: string[] = [];
  out.push('-- Jobicy data-quality correction. GENERATED. Review before running; run once, in one go.');
  out.push(`-- rows in plan: ${plan.totalRows}; descriptions: ${plan.description.length}; geo (confirmed Anywhere): ${plan.geo.length}`);
  out.push('begin;', "set local lock_timeout = '5s';", "set local statement_timeout = '60s';");
  out.push(`do $$ begin if (select count(*) from public.jobs where source_id = ${lit(sourceId)}) <> ${plan.totalRows} then raise exception 'jobs of % changed since the plan (expected ${plan.totalRows}); regenerate the plan', ${lit(sourceId)}; end if; end $$;`);
  if (plan.description.length) {
    out.push('create temp table _fix_desc (ext text primary key, h text not null, d text not null) on commit drop;');
    plan.description.forEach((c, i) => {
      const tag = tagFor(c.after, i);
      out.push(`insert into _fix_desc values (${lit(c.externalId)}, ${lit(c.md5Before)}, ${tag}${c.after}${tag});`);
    });
    out.push(`do $$ declare n int; begin
  with u as (update public.jobs j set description = f.d from _fix_desc f
             where j.source_id = ${lit(sourceId)} and j.external_id = f.ext and md5(j.description) = f.h returning 1)
  select count(*) into n from u;
  if n <> ${plan.description.length} then raise exception 'descriptions: expected ${plan.description.length} rows, changed %', n; end if;
end $$;`);
  }
  if (plan.geo.length) {
    out.push(`do $$ declare n int; begin
  with u as (update public.jobs set geo_restrictions = array[${lit(GEO_ANYWHERE)}]
             where source_id = ${lit(sourceId)} and external_id in (${plan.geo.map((g) => lit(g.externalId)).join(', ')})
               and geo_restrictions = '{}' and country is null returning 1)
  select count(*) into n from u;
  if n <> ${plan.geo.length} then raise exception 'geo: expected ${plan.geo.length} rows, changed %', n; end if;
end $$;`);
  }
  out.push('commit;');
  return out.join('\n') + '\n';
}

/** Text report with counts and ids only: no description content, no addresses. */
export function renderReport(plan: QualityPlan): string {
  const emails = plan.description.reduce((n, c) => n + Math.max(0, c.emailsMasked), 0);
  const lines = [
    `rows read: ${plan.totalRows}`,
    `descriptions that would change: ${plan.description.length} (e-mail addresses masked: ${emails})`,
    `geo set to Anywhere (source-confirmed): ${plan.geo.length}`,
    `geo empty and unresolved (left as is): ${plan.geoUnresolved.length}${plan.geoUnresolved.length ? ` [${plan.geoUnresolved.join(', ')}]` : ''}`,
    `salaries needing the source (NOT changed): ${plan.salaryNeedsSource.length}`,
    ...plan.salaryNeedsSource.map((s) => `  - ${s.externalId}: ${s.min ?? '-'}..${s.max ?? '-'} ${s.currency ?? '?'} per ${s.period} (${s.verdict})`),
    'nothing was written anywhere.',
  ];
  return lines.join('\n');
}
