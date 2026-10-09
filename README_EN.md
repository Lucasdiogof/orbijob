<p align="center"><b>OrbiJob</b> · by Lucksrei</p>

# OrbiJob

> **Actual status: Phase 0 (foundation) complete + visual identity C applied to the UI.** No published backend, no integrated job source and no real job is shown. Real search, ranking, profile, applications and autofill do **not** work yet — they are **planned**.

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
| SQL schema + RLS | ✅ proposed, tested on PGlite · ❌ **not applied** to Supabase |
| Source catalog and coverage matrix | ✅ documented · **no source is `READY`** |
| Real worldwide search, international filters, computed 0–100 ranking + confidence, official application | 🗓️ planned |
| Profile/résumé/experience, favorites, application tracking, assisted form filling | 🗓️ planned |

## Stack
Flutter / Dart · Clean Architecture · BLoC/Cubit · GetIt · Supabase (PostgreSQL, Auth, Storage) · Cloudflare Workers (TypeScript) · GitHub Actions · PT/EN/ES i18n. Free infrastructure first, respecting limits and licenses.

## Architecture
Flutter → Cloudflare Workers (API + sync) → Supabase. Public data (jobs) is separated from private data (profile, résumé, applications), protected by RLS. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/DATABASE.md](docs/DATABASE.md).

## Platforms
Android, iOS and Web/PWA. Verified: production and preview web builds (real screenshots in [docs/design/flutter-screenshots](docs/design/flutter-screenshots/README.md)), widget tests and Android resource validation with `aapt2`. **Not verified here:** APK (no Android SDK) and iOS (no macOS/Xcode). Nothing was published to stores.

## Job integrations
Every source is `CONDITIONAL`, `RESEARCH` or `EXTERNAL_ONLY` — none is `READY` (keys, terms review and live validation pending). No prohibited scraping, no CAPTCHA bypass, no automatic applications. See [docs/GLOBAL_SOURCES.md](docs/GLOBAL_SOURCES.md) and [docs/COVERAGE_MATRIX.md](docs/COVERAGE_MATRIX.md).

## Local setup
Requires stable Flutter (tested with 3.47.6) and Node 22.
```bash
cd app && flutter pub get && flutter gen-l10n && flutter analyze && flutter test
flutter run -d chrome                           # real app (no data)
flutter run -d chrome -t lib/main_preview.dart  # same UI with FICTIONAL jobs and a warning banner
cd worker && npm ci && npm run typecheck && npm test
node scripts/build-coverage.mjs
```
Copy `.env.example` to `.env` (never commit it). No Supabase or Cloudflare project has been created.

## Directory layout
```
app/       Flutter (orbijob): lib/{core,features,l10n}, test/
worker/    Cloudflare Worker (TypeScript): src/, test/ (incl. RLS via PGlite)
supabase/  proposed migrations (not applied)
data/      source catalog, occupation seed, coverage matrix (CSV)
scripts/   coverage generation and search acceptance run
docs/      architecture, requirements, sources, database, security, roadmap, design, portfolio, evidence
.github/   CI
```

## Tests
`flutter analyze` + `flutter test` (139 tests: tokens and contrast, themes, navigation, **no overflow** across 8 sizes × 100/150/200% text, accessibility, i18n, assets/icons/splash) · `tsc` + `vitest` (43 worker tests) · web build and `aapt2` validation in CI. No on-device integration/E2E tests yet.

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
