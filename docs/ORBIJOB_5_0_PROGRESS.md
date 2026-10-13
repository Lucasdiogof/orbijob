# OrbiJob 5.0 — progress (global search, relevance, catalogue quality)

Work directly on `main`, small commits, CI checked after each push. Guide: [ORBIJOB_5_0.md](ORBIJOB_5_0.md). Whole-product status:
[ORBIJOB_MASTER_CHECKLIST.md](ORBIJOB_MASTER_CHECKLIST.md). Flutter for `app/`: `export PATH="/c/Users/lucas/AppData/Local/Temp/fl3477/bin:$PATH"` (3.47.7).

## Recovery of the previous session (2026-10-13)

| Item | Found |
|---|---|
| Repository | `main` = `origin/main` at `a04db18` (migration 19 + coverage/benchmark scripts), clean except 3 files never committed: `scripts/build-occupations.mjs`, `app/lib/features/search/domain/occupation_labels.g.dart` (a 795-occupation partial), local helper SQL in `_aplicar/` (untracked on purpose) |
| ESCO download | the background process had finished, not crashed: `%TEMP%/esco/details.json` held **2,938 of 2,942** occupations (checkpoint every 200, resumable); the 4 missing (*civil engineer*, *manufacturing manager*, *wood factory manager*, *wood technology engineer*) answered HTTP 500 on the current API version ("More than one value found for field 'hasSkillType'"); the same request pinned to `selectedVersion=v1.1.1` works, so they were fetched that way: **2,942 of 2,942, none failed** |
| Generator | the « » and 7-language restrictions were already in `build-occupations.mjs`; the partial `.g.dart` predated them and was regenerated |
| Migration 19 | committed, CI green, but **not applied** to the project (`migration list`: remote empty) → dry-run listed exactly that one file → applied; functions in `ops`, not executable by `anon`/`authenticated`; checked on the real catalogue (see below) |
| CI | the migration 19 commit was green; the commits of this phase are listed below |

## Steps

| # | Step | State | Commit |
|---|---|---|---|
| A | Recovery (above) | done | — |
| B | ESCO complete (2,942), fetch script versioned (`scripts/esco-fetch.mjs`, resumable, polite, `selectedVersion` fallback), table of 2,853 occupations / 31,824 names, 1 MB source, attribution | done | a6a101e |
| C | Multilingual search: resolver with required parts, hand groups kept and extended (electrician, welder, cook), false friends, title-only profession search, suggestions in the empty state | done | a6a101e |
| D | Parity: Dart reference ↔ SQL (`ops.alert_matches`) over the golden file with qualified professions; PGlite test; real PostgreSQL in CI; run on the real catalogue after applying | done | a6a101e |
| E | Benchmark before/after on the real catalogue, with samples read (`docs/evidence/search-benchmark-2026-10-13.txt`) | done | docs commit |
| F | Home/recommendations: explanation compact and right under its card, translated title in "Why this job?", custom saved-search names preserved (covered by an existing cubit test); gallery regenerated | done | 994edda |
| G | Health and coverage: `coverage.sql` run and kept; the nine parallel area counts that returned HTTP 500 (`57014`) fixed; Arbeitnow result below | done | this phase |
| H | Master checklist | done | docs commit |

## Findings

* **The 500s in the browser console** (found while exercising the web build): the nine exact area counts fired together; the free database runs one
  query at a time (≈0.5 s each), so every one exceeded its 3-second statement limit and *no area chip appeared at all* (any single failure also
  discarded the others). Now three at a time, one retry for a failed area, a failed area is left out, the rest still shows. 9 in parallel: 9 × HTTP 500;
  3 at a time: 9 × 200, 4 s in total.
* ESCO `alternativeLabel`s mix synonyms with related jobs (a physiotherapist's alternatives include occupational therapists): alternatives are kept only
  when they share the head word of a preferred name. Loosening this rule to admit single words (tried: "Elektriker" for the electrician) brought in
  specialisations and noise ("apprentice", "communard") and was reverted; common trades got hand groups instead.
* A compound such as *Bauingenieur* contains the stem "ingenieur": the loose stems of the hand groups are ignored when ESCO knows the exact term.
* The catalogue has **no** pelvic-health, civil-engineering or Flutter job today: 4.0 showed 212, 849 and 140 unrelated results for them, 5.0 shows 0.
  Coverage of those professions is a *source* question (§6 of the guide), not a search one.
* ESCO labels in the API are not versioned in the response; the attribution therefore says "taken from the public ESCO web service on 2026-10-13".

## Arbeitnow (pending item of 4.0)

The first discovery pass after the ceiling went from 1,500 to 2,500 (2026-10-13 20:17 UTC): 2,192 read, **+300 new (1,500 → 1,800)**, 0 closed, 400
rejected because Arbeitnow opened a Dutch site (`arbeitnow.nl`) whose links the host allow-list refused. `.nl` was then added (839b539). The next
scheduled Arbeitnow pass has to confirm that the 400 are accepted; the visible total today is 1,800, 2 earlier passes were `catalogue_full`.
Arbeitnow's own cadence is several hours, so this confirmation is recorded when it runs (see the end of this file).

## Blockers / owner-side
See the master checklist ("Next actions that need the owner"): a real push on a phone, privacy policy + account deletion, store accounts and
keystore, a Mac for iOS, NAV/USAJOBS/Jooble credentials, native-speaker review.
