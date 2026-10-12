<p align="center"><b>OrbiJob</b> · by Lucksrei</p>

# OrbiJob

> **Actual status (2026-10-12):** backend is live (Supabase, RLS) with **hundreds of real jobs** (Jobicy: 699 at the last count, across 242 companies), **revalidated automatically** by Supabase Cron and **discovered incrementally** (insert-only, capped, with retention). Three more sources are implemented — Arbeitnow, Remote OK and Remotive — and only show in the app once reviewed and published ([source and licence matrix](docs/SOURCES_MATRIX.md)). Home and Explore list the newest jobs and filter by professional area; the app has not been validated end to end on a device. The Cloudflare Worker is **not** deployed.

🇧🇷 [README em português](README.md) · Previous provisional name: *JobRadar* (dropped — [why](docs/BRAND_NAME_CHECK.md)).

## Mission
Help anyone, in any profession, find, evaluate and track job opportunities worldwide — transparent about where jobs come from and where there is **no** coverage yet.

## Problem
Jobs are scattered across hundreds of portals; trades and healthcare are poorly served by tech-focused tools; applications get lost in spreadsheets.

## Features
| Feature | State |
|---|---|
| Identity **C — Minimal Tech** in the app (tokens, Space Grotesk/Inter, logo, Android/iOS/Web icons, splash, light/dark/system themes) | ✅ applied and tested (APK/iOS **not built** in this environment) |
| Home / Explore / Favorites / Applications navigation, profile in the header (bottom bar < 600 dp, rail, extended rail + list/detail) | ✅ implemented (honest empty states) |
| Components: buttons, search field, chips, job card (compatibility and confidence kept separate), favourite, badges, skeletons, states | ✅ implemented (cards only appear in the preview/tests: there is no job source yet) |
| Search with loading / empty / error / **no integrated source** states, PT/EN/ES | ✅ implemented, **no real data** |
| Multilingual occupation resolver (ISCO-08 seed, 12 occupations) | ✅ implemented and tested |
| Connector core: contract, dedupe, retry/backoff, rate limiter, job-closure rule | ✅ implemented and tested (Lever connector uses a synthetic fixture only) |
| SQL schema + RLS | ✅ tested on PostgreSQL 16/17 · ✅ 8 migrations applied to the owner's Supabase project (Auth, RLS, Storage, quotas, least-privilege `service_role`, `pg_cron` revalidation) |
| Real **Jobicy** catalogue (`CONDITIONAL` source, attribution and original-listing link kept) | ✅ 299 jobs stored · one controlled first ingestion; **no automatic import of new jobs** |
| Automatic revalidation (closes only what Jobicy confirms closed; refreshes the active ones) | ✅ Supabase Cron + `pg_net`, every 6 h, no key, no paid service · fallback: GitHub Actions · [deployed architecture](docs/DEPLOYED_ARCHITECTURE.md) |
| Source catalog and coverage matrix | ✅ documented · **no source is `READY`** |
| Real worldwide search, international filters, computed 0–100 ranking + confidence, official application | 🗓️ planned |
| Profile/résumé/experience, favorites, application tracking, assisted form filling | 🗓️ planned |

## Stack
Flutter / Dart · Clean Architecture · BLoC/Cubit · GetIt · Supabase (PostgreSQL, Auth, Storage) · Cloudflare Workers (TypeScript) · GitHub Actions · PT/EN/ES i18n. Free infrastructure first, respecting limits and licenses.

## Architecture
Deployed today: Flutter → Supabase (catalogue reads under RLS); revalidation runs inside Supabase itself (`pg_cron` + `pg_net`), with GitHub Actions as a fallback. The Cloudflare Worker code (API + sync) exists and is reused, but is **not deployed**. Public data (jobs) is separated from private data (profile, résumé, applications), protected by RLS. See [docs/DEPLOYED_ARCHITECTURE.md](docs/DEPLOYED_ARCHITECTURE.md) (what runs today and how to recover), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DATABASE.md](docs/DATABASE.md) and [docs/JOBICY_SUPABASE_CRON.md](docs/JOBICY_SUPABASE_CRON.md).

## Platforms
Android, iOS and Web/PWA. Verified: production and preview web builds (real screenshots in [docs/design/flutter-screenshots](docs/design/flutter-screenshots/README.md)), widget tests and Android resource validation with `aapt2`. **Not verified here:** APK (no Android SDK) and iOS (no macOS/Xcode). Nothing was published to stores.

## Job integrations
Sources with real data: **Jobicy** and, once published, **Arbeitnow**, **Remote OK** and **Remotive** (all `CONDITIONAL`, official keyless APIs, attribution and original link kept). The rest are `RESEARCH`, `EXTERNAL_ONLY` or blocked by a key or licence — see [docs/SOURCES_MATRIX.md](docs/SOURCES_MATRIX.md). No scraping, no CAPTCHA or anti-bot bypass. No prohibited scraping, no CAPTCHA bypass, no automatic applications. See [docs/GLOBAL_SOURCES.md](docs/GLOBAL_SOURCES.md) and [docs/COVERAGE_MATRIX.md](docs/COVERAGE_MATRIX.md).

## Local setup
Requires stable Flutter (tested with 3.47.6) and Node 22.
```bash
cd app && flutter pub get && flutter gen-l10n && flutter analyze && flutter test
flutter run -d chrome                           # real app (no data)
flutter run -d chrome -t lib/main_preview.dart  # same UI with FICTIONAL jobs and a warning banner
cd worker && npm ci && npm run typecheck && npm test
node scripts/build-coverage.mjs
```
Copy `.env.example` to `.env` (never commit it). The owner's Supabase project exists (8 migrations applied); nothing is published on Cloudflare.

## Directory layout
```
app/       Flutter (orbijob): lib/{core,features,l10n}, test/
worker/    Cloudflare Worker (TypeScript): src/, test/ (incl. RLS via PGlite)
supabase/  migrations (1–8 applied to the owner's project), SQL tests and rollbacks
data/      source catalog, occupation seed, coverage matrix (CSV)
scripts/   coverage generation and search acceptance run
docs/      architecture, requirements, sources, database, security, roadmap, design, portfolio, evidence
.github/   CI, revalidation (fallback) and monitor
```

## Tests
`flutter analyze` + `flutter test` (tokens and contrast, themes, navigation, **no overflow** across sizes and text scales, accessibility, i18n, Supabase repositories against a simulated HTTP backend) · `tsc` + `vitest` in `worker/` (connectors, lease, revalidation, RLS and the SQL revalidation on real PostgreSQL via PGlite) · SQL tests on PostgreSQL 16 and 17 (`supabase/tests/run.sh`) · web build and `aapt2` validation in CI. Current counts are in CI. No on-device integration/E2E tests yet.

## Security
Owner-only RLS, private résumé bucket (planned/proposed), no secrets in the (**public**) repository, no prohibited scraping, no automatic applications, autofill only on allow-listed domains. [docs/SECURITY.md](docs/SECURITY.md)

## Visual identity
Official identity: **C — Minimal Tech** (two-arc "O" symbol with a violet point; ORBIJOB in Space Grotesk). [docs/design/identity/c-minimal/APPLIED.md](docs/design/identity/c-minimal/APPLIED.md) · [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md). Proposals A and B are kept as history.

## Roadmap
[docs/ROADMAP.md](docs/ROADMAP.md) · issues by area on GitHub · [docs/HANDOFF.md](docs/HANDOFF.md)

## Screenshots
Real app captures in [docs/design/flutter-screenshots](docs/design/flutter-screenshots/README.md) (light/dark, mobile/tablet/desktop; the ones with jobs are an always-flagged fictional preview).

## License
Not decided yet; **all rights reserved** until then (no LICENSE file).

## Credits
A **Lucksrei** product · developed by Lucas Diogo França.
