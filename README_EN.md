# JobRadar (provisional name)

> **Actual status: Phase 0 — foundation and planning.** No published backend, no integrated job source and no real job is shown. The name is provisional and carries a **high trademark-conflict risk** ([details](docs/BRAND_NAME_CHECK.md)).

A platform to search and track jobs for **any profession**, in every country where legally usable sources exist — transparent about what is and is not covered.

## Features
| Feature | State |
|---|---|
| Search screen with loading/empty/error/no-source states, light/dark theme, pt/en/es | ✅ implemented (no real data) |
| Multilingual occupation resolver (ISCO-08 seed, 12 occupations) | ✅ implemented and tested |
| Connector contract, dedupe, retry/backoff, rate limiter, closure rule | ✅ implemented and tested (Lever connector uses a synthetic fixture only) |
| SQL schema + RLS | ✅ proposed, tested on PGlite; ❌ not applied to Supabase |
| Source catalog and coverage matrix | ✅ documented; no source is `READY` |
| Real sources, profiles, ranking, favorites, applications, autofill | 🗓️ planned ([roadmap](docs/ROADMAP.md)) |

## Stack
Flutter/Dart · BLoC/Cubit · get_it · Cloudflare Workers (TypeScript) · Supabase · Vitest · GitHub Actions.

## Run
```bash
cd app && flutter pub get && flutter gen-l10n && flutter analyze && flutter test
cd worker && npm ci && npm run typecheck && npm test
node scripts/build-coverage.mjs
```
Copy `.env.example` to `.env` (never commit it). See `docs/` for architecture, sources, database, security and roadmap. No LICENSE yet (undecided).
