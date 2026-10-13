# OrbiJob 4.0 — progress (global expansion, job quality, refined experience)

Owner-authorised, continuous, directly on `main`. Supabase project `rpmlfxwebnlxnwadyvle` only. No APK/AAB/IPA, no store publication, no manual
device tests. Every number below was read from production with the Supabase CLI on 2026-10-13.

## 1. Audit of the real sources (before)

| Source | Open | Closed | New in 24 h | New in 7 days | Country filled | Notes |
|---|---:|---:|---:|---:|---|---|
| JobTech (Sweden) | 2,365 | 27 | 671 | 2,181 | all SE | healthy; 74 jobs carry structured skills |
| Arbeitnow (DE/EU) | 1,500 | 0 | 329 | 1,498 | **none** (city only) | hit its 1,500 ceiling: last two passes `partial/catalogue_full` |
| Taiwan Jobs | 1,090 | 0 | 0 | 106 | all TW | 593 descriptions under 200 characters (the source publishes short texts) |
| Jobicy (remote) | 938 | 16 | 55 | 716 | partly | healthy |
| Jobs.co.nz | 225 | 102 | 0 | 104 | all NZ | healthy (expiry by evidence works: 102 closed) |
| Remote OK | 102 | 0 | 0 | 11 | rarely | slow feed |
| Remotive | 18 | 0 | 0 | 2 | rarely | **stagnant**: the public API exposes ~20 jobs |
| **Total** | **6,238** | 145 | | | 4,352 with a country | 1,886 without a country (1,500 of them Arbeitnow) |

Work modes of open jobs: 4,282 unspecified, 1,173 remote, 733 on-site, 50 hybrid. Duplicates: 0 same-source duplicate URLs, **3** fingerprints shared
by two sources (the cross-source de-duplication of discovery holds). 0 stale open jobs older than the 72 h verification window. Database 109 MB of 500 MB.
Every discovery and revalidation run of the last 24 h ended `ok` except the two Arbeitnow ceiling stops.

Compared with `docs/SOURCES_MATRIX.md`: every source listed as integrated is delivering; Remotive is integrated but nearly empty by nature.

## 2. New sources researched (2026-10-13)

| Source | Country | Real, current jobs | Access | Licence / terms (primary text) | Decision |
|---|---|---|---|---|---|
| **NAV — pam-stilling-feed** (arbeidsplassen.nav.no) | Norway | yes, every profession; tested: 1,000-entry pages, full ad per entry, ACTIVE/INACTIVE status | JWT bearer; a **public token "for experimenting"** that rotates; production consumers **register by e-mail** (nav.team.arbeidsplassen@nav.no) with written acceptance of the terms | `/vilkar-api`: consumers *may republish and show* the ads; must deep-link to the application; must remove an ad **immediately** when it becomes inactive; must not keep personal data longer than needed | **BLOCKED on the owner**: registration e-mail. Technically ready to build (status in the feed covers the removal rule) |
| **Työmarkkinatori** (KEHA-keskus) | Finland | yes | credentials + IP allow-listing after an onboarding notice tied to a Finnish business ID (Y-tunnus) | terms of use, no open licence | **BLOCKED** (registration requires a Finnish organisation) |
| USAJOBS | USA (public sector) | yes | free key requested by e-mail | API terms | **BLOCKED on the owner** (key) |
| Adzuna | 19 countries incl. BR, MX | yes | account: free plan = 25 test calls in total; full access **£8/month** | — | **REJECTED** (paid) |
| Jooble | many incl. BR | yes | key on request | to be read when a key exists | **BLOCKED on the owner** (key request) |
| France Travail, Reed (UK), Bundesagentur für Arbeit, MyCareersFuture (SG) | FR, UK, DE, SG | yes | registration, or undocumented/internal API without terms | — | not integrated (see the matrix) |

No new source could be integrated without an action of the owner or a paid plan; nothing was scraped and no access control was bypassed.

## 3. Quality and de-duplication

| Change | Evidence | Commit |
|---|---|---|
| Arbeitnow: country only when the employer's location **ends with a country name** ("München, Bayern, Germany"), never from a bare city, a region, a code, a list of places or a contradiction with the regional site (.co.uk/.fr/.ch) | 9 refusal cases + 5 accepted cases in `worker/test/feeds.test.ts`; applied to the 276 stored locations with a comma: **170** got a stated country (DE 54, FR 48, CH 36, GB 32), undo file kept in `_aplicar/` | 4f3e295 (worker), data fix 2026-10-13 |
| Arbeitnow ceiling 1,500 → 2,500 (database at 109 MB) | the first pass after it is reported below | 7676785 |
| Recommendations: no single source above half of the list while other sources have relevant jobs; nothing relevant is dropped when there is not enough variety | 2 tests in `recommender_test.dart` | 844e6ce |
| Cross-source duplicates | 3 shared fingerprints among 6,238 open jobs; the discovery already refuses a second copy by fingerprint/URL. Not merged in the app: two different jobs with the same title and company must stay apart | audit only |

## 4. Notification centre (refined)

Compact alerts switch with a one-line explanation; a coloured **kind badge** (New job / Interview / Follow-up) with the time on the same line; the
job title in bold and **translated when the shared translation has it** (with the "translated" mark; the original stays available in the job);
unread state shown by a dot and a stronger title instead of a heavy border; the remove action says "Remove from list". PT-BR, EN, ES; light and
dark; 200 % text covered by the existing layout tests. Screenshots: `docs/design/orbijob-v3/06-notifications-*.png`.

## 5. Job cards and details

Reviewed against the brief: country, work mode, company and source are shown; salary only when the source states amount, currency and period; an
unknown work mode is not shown (never displayed as "on-site"); the in-app WebView and the translation with "see original" are unchanged. No change
was needed.

## 6. Pending (external)

* NAV Norway: registration e-mail by the owner, then the connector (status-driven removal) can be built and published.
* USAJOBS and Jooble keys (owner requests); Finland requires a Finnish organisation.
* iOS and web push (from 3.0).
