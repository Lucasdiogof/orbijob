# OrbiJob 9.0 / 10.0 — profile intelligence, performance, observability (2026-10-14)

## 9.0 Profile and compatibility
**Résumé import audit.** Five synthetic but realistic résumés of professions that are not technology (ICU nurse EN, industrial electrician ES, maths teacher PT, truck driver DE, welder PT) were parsed with the 6.x parser. Defects found and fixed (regression tests in `app/test/profile/resume_parser_variants_test.dart`):
| Defect (real output before) | Fix |
|---|---|
| `Priya Nair, RN`: name empty and the NAME became the city; UK not detected; headline empty | a short credential after a comma is not part of the name; the name line is never a place |
| a company ending in `S.A. de C.V.` was not a header, so the first entry read the description line as its title and the second entry LOST its dates | dotted abbreviations count as header endings; a one-line `Title, Company` header is whole (the line above belongs to the previous entry's description); the same rule for the end of a description |
| `Fev/2019 – Atual`: the month stayed in the company name (`Fev/`) | month names may be followed by `/`, `-` or spaces before the year |
| `Belo Horizonte - MG` / `Santo André/SP`: no city | a city followed by a two-letter state code is a city |
| German résumé: no section found at all | headings (Berufserfahrung, Ausbildung, Sprachen, Kenntnisse …), `heute`/`bis`, German month and language names, `IHK`/Hochschule as schools; extra PT headings (Cursos complementares, Qualificações …) |
Not changed (by design): scanned PDFs are reported as unreadable (no OCR is claimed); a PDF year-only line such as `SENAI, 2011` is not a date range.
**Recommendations.** Re-read the recommender against 3,000 real open listings with five profiles: reasons are explainable and nothing claims eligibility. Observed limitation, not changed: `sameField` links a *physiotherapist* to doctors' listings (the app's `health` area is one bucket), scored 35/100 and labelled only "same professional field". A finer taxonomy of the health area would fix it (candidate for a later release; needs ESCO sub-groups, no schema change).
**Not done:** specialty/experience-years matching (listings do not state them reliably).

## 10.0 Performance, stability, observability
**Backend latency (production, public key, 2026-10-14).** Plan of the home query: 17 ms of execution over 13,565 candidate rows (sequential scan + top-N sort); a trivial PostgREST read ≈ 100 ms; the 20-row "latest" query ≈ 130–180 ms with `count=exact`, `count=planned` or none (10 runs each, no difference). Earlier the same queries showed isolated 2–4 s answers; it coincided with discovery passes writing to the free-plan database and did not reproduce in ten consecutive runs. **No index or query was changed**: nothing measured justifies it (a partial index on `published_at` would save a sort that costs milliseconds).
**Database:** 176 MB of 500 MB (jobs 152 MB). Ceilings per source keep growth bounded; ops-health warns at 400 MB.
**Monitoring (free, no paging):** `scripts/supabase/diagnostics/ops-health.sql` — one row per check with OK/WARN/ALERT: every pg_cron job (inactive, failed, silent), discovery freshness per published source (a pass stopped at the catalogue ceiling is not an error), hourly alert matcher, push backlog (notifications never pushed although the person has a device), database size, biggest tables, visible-job count, non-https links. First run: 32 OK, 1 WARN (`sources6-expire-unseen` had not run yet: created that evening, first run 04:27 UTC). Run: `npx supabase db query --linked -o csv -f scripts/supabase/diagnostics/ops-health.sql`. A scheduled GitHub workflow would need a database access secret from the owner (not created); the file is the contract.
**Flutter:** full suite 919 tests pass (including layout nets at 200 % text in three languages), `flutter analyze` clean. Not measurable without a device: cold start, scroll jank, memory; the web build is 43 MB (CanvasKit) as recorded in 6.0.

## Catalogue ceilings raised on purpose (found by watching the scheduled runs)
`Sources discover` for Arbeitnow ended red (exit 7, "catalogue full") on 2026-10-14: 2,500 stored = ceiling, while the feed holds 2,193 live listings and older ones wait 7 days to expire, so new listings were refused. With the database at 176 MB of 500 MB (about 11 KB per job), Arbeitnow was raised 2,500 to **3,200** and Jobtech 3,500 to **4,200** (it stood at 3,471). Expected cost about +14 MB; `ops-health.sql` warns at 400 MB. Commit `06d7403`.
