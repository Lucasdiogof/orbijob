import { describe, expect, it } from 'vitest';
import { normalizeJobicy } from '../src/connectors/jobicy';
import { cleanDescription, isRoleAddress, MASKED_EMAIL, maskPersonalEmails, tidyMarkdown } from '../src/description';
import { GEO_ANYWHERE, geoRestrictions, parseGeo } from '../src/geo';
import { assessSalary } from '../src/salary';
import { decodeEntities, htmlToText } from '../src/text';

// Regression cases from the audit of the first real ingestion (299 listings, 2026-10-10). The shapes are real; every piece of
// text below is made up. Mirrored by app/test/core/data_quality_test.dart so the app and the Worker agree.
const NOW = '2026-10-10T12:00:00.000Z';
const base = {
  id: 152711, url: 'https://jobicy.com/jobs/152711-example', jobTitle: 'Example role', companyName: 'Example Co',
  jobType: ['Full-Time'], jobGeo: 'USA', jobDescription: '<p>Plain.</p>', pubDate: '2026-10-09 18:42:49',
  salaryMin: 120000, salaryMax: 145000, salaryCurrency: 'USD', salaryPeriod: 'yearly',
};
const job = (over: Record<string, unknown>) => {
  const r = normalizeJobicy({ ...base, ...over }, NOW);
  if (!r.ok) throw new Error(r.reason);
  return r.job;
};
const sal = (j: ReturnType<typeof job>) => [j.salaryMin, j.salaryMax, j.salaryCurrency, j.salaryPeriod];

describe('1. salary: plausible figures stay, implausible ones are held back and never "fixed"', () => {
  it('Jobicy 152711 (USD 168-220 per year): held back, NOT turned into 168,000', () => {
    expect(sal(job({ salaryMin: 168, salaryMax: 220 }))).toEqual([null, null, null, null]);
  });
  it('a normal range, an hourly rate and a monthly figure are kept with currency and period', () => {
    expect(sal(job({}))).toEqual([120000, 145000, 'USD', 'year']);
    expect(sal(job({ salaryMin: 60, salaryMax: 70, salaryPeriod: 'hourly' }))).toEqual([60, 70, 'USD', 'hour']);
    expect(sal(job({ salaryMin: 4000, salaryMax: 5800, salaryPeriod: 'monthly' }))).toEqual([4000, 5800, 'USD', 'month']);
  });
  it('one-sided figures (real: 1 min-only, 4 max-only) are kept as one-sided, never completed', () => {
    expect(sal(job({ salaryMin: 90000, salaryMax: null }))).toEqual([90000, null, 'USD', 'year']);
    expect(sal(job({ salaryMin: null, salaryMax: 110000 }))).toEqual([null, 110000, 'USD', 'year']);
  });
  it('one suspicious side holds the whole figure; a typo spread (5,000-250,000) too', () => {
    expect(sal(job({ salaryMin: 90000, salaryMax: 900 }))).toEqual([null, null, null, null]);
    expect(sal(job({ salaryMin: 900, salaryMax: null }))).toEqual([null, null, null, null]);
    expect(sal(job({ salaryMin: 5000, salaryMax: 250000 }))).toEqual([null, null, null, null]);
  });
  it('boundaries of assessSalary', () => {
    expect(assessSalary(1000, null, 'year')).toBe('plausible');
    expect(assessSalary(999, null, 'year')).toBe('suspicious');
    expect(assessSalary(null, 10_000, 'hour')).toBe('plausible');
    expect(assessSalary(null, 10_001, 'hour')).toBe('suspicious');
    expect(assessSalary(100, 2000, 'month')).toBe('plausible'); // spread exactly 20
    expect(assessSalary(100, 2001, 'month')).toBe('suspicious');
    expect(assessSalary(9, 3, 'month')).toBe('inconsistent');
    expect(assessSalary(0, null, 'year')).toBe('suspicious');
  });
});

describe('2. geographic eligibility: explicit Anywhere, missing, country, countries, region, unknown', () => {
  const geo = (jobGeo: unknown) => geoRestrictions(parseGeo(jobGeo));
  it('explicit Anywhere is a marker, not an empty list', () => {
    expect(geo('Anywhere')).toEqual([GEO_ANYWHERE]);
    expect(geo(' anywhere ')).toEqual([GEO_ANYWHERE]);
    expect(job({ jobGeo: 'Anywhere' })).toMatchObject({ country: null, geoRestrictions: ['Anywhere'] });
  });
  it('missing, empty or non-string location stays EMPTY = unknown (never read as global)', () => {
    for (const v of [undefined, null, '', '   ', ',', 42, {}]) expect(geo(v)).toEqual([]);
  });
  it('one country sets jobs.country; several do not; regions stay regions', () => {
    expect(job({ jobGeo: 'USA' })).toMatchObject({ country: 'US', geoRestrictions: ['US'] });
    expect(job({ jobGeo: 'Canada,  USA' })).toMatchObject({ country: null, geoRestrictions: ['CA', 'US'] });
    for (const r of ['EMEA', 'LATAM', 'APAC', 'Europe']) expect(job({ jobGeo: r })).toMatchObject({ country: null, geoRestrictions: [r] });
  });
  it('regions are never expanded into countries, unknown names are kept as written', () => {
    expect(geo('LATAM')).toEqual(['LATAM']);
    expect(geo('Atlantis, USA, EMEA')).toEqual(['US', 'EMEA', 'Atlantis']);
  });
  it('Anywhere together with places keeps the marker AND the places (ambiguous: the app warns)', () => {
    expect(geo('Anywhere, USA')).toEqual([GEO_ANYWHERE, 'US']);
    expect(job({ jobGeo: 'Anywhere, USA' }).country).toBeNull();
  });
});

describe('3. descriptions: readable text, no Markdown/entity residue, safe e-mail policy', () => {
  it('Markdown emphasis, rules and star bullets are cleaned (real residues: **Title, ***CAPS, ____, "* item")', () => {
    expect(tidyMarkdown('**UK Employee-specific benefits**\n\n***CURRENTLY ONLY HIRING FOR UK***\n\n______________\n\n* May vary by country\n* Second'))
      .toBe('UK Employee-specific benefits\n\nCURRENTLY ONLY HIRING FOR UK\n\n- May vary by country\n- Second');
    expect(tidyMarkdown('GD is **committed** to __equal__ opportunity')).toBe('GD is committed to equal opportunity');
    expect(tidyMarkdown('**UK Employee benefits')).toBe('UK Employee benefits'); // orphan marker
  });
  it('legitimate asterisks, underscores and snake_case survive', () => {
    expect(tidyMarkdown('Salary* depends on location. Use snake_case_names and a*b*c.')).toBe('Salary* depends on location. Use snake_case_names and a*b*c.');
  });
  it('[label](url) keeps both, # headings lose the marker', () => {
    expect(tidyMarkdown('See [our policy](https://example.com/p) now\n\n## Benefits')).toBe('See our policy (https://example.com/p) now\n\nBenefits');
  });
  it('carriage returns, zero-width characters and double-encoded entities are normalised', () => {
    expect(htmlToText('<p>a</p>\r\n<p>b​</p>\r\n\r\n\r\n<p>c</p>')).toBe('a\n\nb\n\nc');
    expect(decodeEntities('R&amp;amp;D &amp;quot;x&amp;quot; it&amp;#39;s')).toBe('R&D "x" it\'s');
    expect(decodeEntities('&amp;lt;b&amp;gt; stays text')).toBe('&lt;b&gt; stays text'); // markup is never produced
    expect(cleanDescription('<p>Fish &amp;amp; chips</p>')).toBe('Fish & chips');
  });
  it('role-based application and accommodation addresses stay', () => {
    for (const a of ['careers@example.com', 'accommodations@example.com', 'candidate_accommodations@example.com', 'hr.support@example.com',
      'recruiting@example.com', 'talent@example.com', 'jobs@example.com', 'askpeople@example.com', 'reasonable-accommodations@example.com'])
      expect(isRoleAddress(a), a).toBe(true);
  });
  it('personal-looking addresses and anything on a free-mail provider are masked', () => {
    for (const a of ['jane.doe@example.com', 'jdoe@example.com', 'jane.doe84@example.com', 'careers@gmail.com', 'hr@hotmail.com'])
      expect(isRoleAddress(a), a).toBe(false);
    expect(maskPersonalEmails('Questions? Ask jane.doe@example.com or careers@example.com.')).toBe(`Questions? Ask ${MASKED_EMAIL} or careers@example.com.`);
  });
  it('is idempotent: cleaning already-clean text changes nothing (a re-import never rewrites corrected descriptions)', () => {
    const dirty = '<p>**About us**</p><ul><li>Remote</li></ul><p>Apply: careers@example.com, jane.doe@example.com. R&amp;amp;D ______</p>';
    const once = cleanDescription(dirty);
    expect(cleanDescription(once)).toBe(once);
  });
  it('the whole pipeline on a made-up listing; the listing URL is untouched', () => {
    const j = job({
      jobDescription: '<p>**About us**</p><ul><li>Remote</li></ul><p>Apply: careers@example.com. Contact Jane at jane.doe@example.com.</p>',
    });
    expect(j.description).toBe(`About us\n\n- Remote\nApply: careers@example.com. Contact Jane at ${MASKED_EMAIL}.`);
    expect(j.originalUrl).toBe('https://jobicy.com/jobs/152711-example');
  });
});
