<p align="center"><img src="docs/design/identity/c-minimal/png/icon-app-256.png" width="112" alt="OrbiJob app icon"></p>

<h1 align="center">OrbiJob</h1>

<p align="center">Find opportunities worldwide. Keep your career organized.</p>

<p align="center"><img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" alt="Flutter"> <img src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" alt="Dart"> <img src="https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white" alt="Supabase"> <img src="https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white" alt="PostgreSQL"> <img src="https://img.shields.io/badge/Cloudflare-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare"> <img src="https://img.shields.io/badge/Platforms-Android_%7C_iOS_%7C_Web-555555" alt="Platforms"></p>

<p align="center"><b>English</b> · <a href="README.pt-BR.md">Português</a> · <a href="README.es.md">Español</a></p>

---

OrbiJob brings international job discovery and personal application tracking together. It covers **all professions**, including in-person, hybrid and remote roles. Flutter/mobile engineering and physiotherapy—including pelvic health—receive extra source research, but the platform is not limited to those fields.

## Features

- **Worldwide discovery:** search jobs by title, profession, specialty, country, continent and work arrangement, with professional-area navigation and current provider coverage.
- **Real job feeds:** Jobicy, Arbeitnow, Remote OK, Remotive, Sweden's Platsbanken/JobTech, Taiwan Jobs Open Data and Jobs.co.nz have been integrated. Availability is dynamic; see the [source matrix](docs/SOURCES_MATRIX.md). OrbiJob 6.0 also imports Teaching Vacancies (England), NYC Jobs, Karriere.NRW (Germany), Groupe BPCE (France), Le Forem (Belgium) and Get on Board (Latin America); they appear in the app once the owner publishes them (licences and evidence in [docs/SOURCES_6_0.md](docs/SOURCES_6_0.md)).
- **Relevant job information:** role, company, original description, location, work arrangement, source attribution, confidence and compatibility cues when supported by data.
- **Personal workspace:** account, professional experience and education, skills, languages, professional preferences, saved jobs and application tracking.
- **Résumé tools:** private PDF upload, primary résumé, replacement and deletion, local text extraction and editable review before applying suggestions to the profile.
- **Application kit:** copy verified profile details, access the primary résumé and track a submitted application after user confirmation; never submits applications on your behalf.
- **International UX:** English, Brazilian Portuguese and Spanish interfaces, light/dark/system themes, responsive mobile/tablet/desktop layout, contextual sign-in screens and an orbital loader.
- **Saved searches and alerts (3.0):** save any combination of filters, rename, edit, duplicate or delete it, and switch alerts per search (hourly, daily or weekly). New matching jobs that are open and recently verified arrive in an in-app notification centre, never twice for the same job. On Android they also arrive as push notifications; iPhone and browser push are not enabled yet.
- **Explainable recommendations (3.0):** a deterministic ranking from your professions, specialty, places, languages and work mode, for any profession, with the reasons and caveats shown for every job; nothing is claimed about visas or professional registrations.
- **Hide jobs and recent searches (3.0):** hide a job with undo and a restore list; recent searches stay on the device, per account, and can be switched off or cleared.
- **Application pipeline (3.0):** stages from interested to hired or rejected, personal notes, interview and follow-up dates with reminders in the notification centre (and Android push) and an agenda; an application is only marked as sent when you confirm it.
- **Share and compare (3.0):** share a job link and compare jobs side by side (table on wide screens, blocks on phones) using only what the listings state, including the skills a source lists.
- **Multilingual profession search (5.0):** a profession typed in one language also finds the same profession written in the others (pt, en, es, de, sv, nl, fr), from the ESCO occupation table (© European Union, CC BY 4.0), without turning a qualified profession into the whole field ("civil engineer" is not "any engineer", "pelvic physiotherapy" is not "any physiotherapy"). Saved-search alerts use exactly the same rule as the app, and an empty result suggests a broader or similarly spelled profession. Details and measured before/after: [ORBIJOB_5_0.md](docs/ORBIJOB_5_0.md).

## Screenshots

### Search and discover

<table><tr><td align="center"><img src="docs/design/orbijob-v2/01-home-light.png" width="235" alt="Home screen"><br><sub><b>Home</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/02-explore-light.png" width="235" alt="Explore jobs"><br><sub><b>Explore</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/03-filters-light.png" width="235" alt="Job search filters"><br><sub><b>Filters</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/04-job-detail-light.png" width="235" alt="Job details"><br><sub><b>Job details</b></sub></td></tr></table>

### Your career, in one place

<table><tr><td align="center"><img src="docs/design/orbijob-v2/12-profile-hub-dark.png" width="235" alt="Professional profile in dark theme"><br><sub><b>Profile</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/14-resumes-dark.png" width="235" alt="Resume management in dark theme"><br><sub><b>Résumés</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/22-resume-review-dark.png" width="235" alt="Review extracted resume details"><br><sub><b>PDF review</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/23-application-kit-dark.png" width="235" alt="Application kit"><br><sub><b>Application kit</b></sub></td></tr></table>

### Alerts, recommendations and follow-up (3.0)

<table><tr><td align="center"><img src="docs/design/orbijob-v3/02-recommendations-en-light.png" width="188" alt="Recommendations"><br><sub><b>Recommendations</b></sub></td><td align="center"><img src="docs/design/orbijob-v3/05-saved-searches-en-light.png" width="188" alt="Saved searches"><br><sub><b>Saved searches</b></sub></td><td align="center"><img src="docs/design/orbijob-v3/06-notifications-en-light.png" width="188" alt="Notifications"><br><sub><b>Notifications</b></sub></td><td align="center"><img src="docs/design/orbijob-v3/08-applications-en-light.png" width="188" alt="Applications"><br><sub><b>Applications</b></sub></td><td align="center"><img src="docs/design/orbijob-v3/11-compare-phone-light.png" width="188" alt="Compare"><br><sub><b>Compare</b></sub></td></tr></table>

More 3.0 captures (en/pt/es, light/dark, phone/desktop): [3.0 gallery](docs/design/orbijob-v3/README.md).

More real Flutter widget captures (light, dark, desktop, tablet, PT and ES) are available in [the screenshot gallery](docs/design/orbijob-v2/README.md). They use controlled test data; they are not evidence of live job inventory.

## Architecture

```text
Flutter (Android / iOS / Web)
  ├─ Public job discovery, details and filters
  └─ Supabase Auth → private profiles, résumés, saved jobs, applications
          │
          └─ PostgreSQL + RLS + private Storage

Public job providers → TypeScript connectors → validated job catalogue
                                      ├─ incremental discovery
                                      ├─ revalidation / freshness
                                      └─ retention, deduplication and monitoring

GitHub Actions + Supabase scheduled jobs
```

Source attribution and original URLs stay attached to listings. Visibility depends on publisher permission and freshness; a missing result does not imply there are no jobs in that country or profession. The project prioritizes free infrastructure and safe provider integration. [Architecture](docs/ARCHITECTURE.md) · [Source matrix](docs/SOURCES_MATRIX.md) · [Freshness policy](docs/FRESHNESS_POLICY.md) · [Privacy and security](docs/SECURITY.md).

## Tech stack

| Area | Technology |
|---|---|
| Application | Flutter / Dart, feature-first Clean Architecture, Cubit/BLoC, GetIt |
| Design & localization | OrbiJob 2.0 design system, light/dark, Flutter ARB — EN / PT-BR / ES |
| Backend | Supabase Auth, PostgreSQL, Row Level Security, Storage, scheduled SQL jobs |
| Ingestion | TypeScript / Cloudflare Worker code, provider adapters, GitHub Actions |
| Quality | Flutter widget/accessibility tests, TypeScript tests, PostgreSQL 16/17, GitHub Actions CI |

## Run locally

Prerequisites: compatible Flutter SDK (the current app requires Dart `^3.13.5`), Node.js and the project's Supabase public configuration. Never commit tokens or service-role credentials.

```bash
cd app
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run -d chrome --dart-define-from-file=dart_defines.web.json
```

For mobile, use the appropriate local, ignored `dart_defines.dev.json` configuration. Consult [Supabase setup](docs/SUPABASE_SETUP.md) and [Windows web run](docs/WINDOWS_WEB_RUN.md); local configuration files must contain only client-safe values. The web command assumes the local configuration file already exists.

Worker checks:

```bash
cd worker
npm ci
npm run typecheck
npm test
```

## Repository

```text
app/        Flutter application and widget tests
worker/     TypeScript ingestion/API components and tests
supabase/   Database migrations, policies and SQL tests
scripts/    Operational and validation scripts
data/       Source and occupation metadata
docs/       Architecture, sources, security, UX and screenshots
.github/    CI and scheduled jobs
```

## Important limits

- Job coverage varies by country, sector, provider terms and recency. Listing counts change continuously.
- Job information originates from third parties; applications and eligibility requirements must be confirmed with the employer.
- Résumé parsing works locally on text-based PDFs; scanned or encrypted PDFs are not automatically read. Extracted fields always require review.
- The application kit helps prepare and track applications; OrbiJob does **not** submit applications or automatically fill third-party forms.
- Mobile job links may open in an in-app browser, with an external-browser escape route; embedded third-party websites and authentication may have limitations.
- Automatic listing translation is under development; its availability is not guaranteed on every platform or language pair.

## Availability and status

Android, iOS and Web are supported by the Flutter codebase. The app has passed automated tests, an Android debug APK build and a Web release build; full on-device verification and store publication are **not claimed** here. See [OrbiJob 2.0 status](docs/ORBIJOB_2_0_STATUS.md), [2.0 progress](docs/ORBIJOB_2_0_PROGRESS.md) and [3.0 guide](docs/ORBIJOB_3_0.md). No Play Store / App Store links are published until listings are live.

## Privacy and licensing

Private candidate information and résumé files are protected by account-scoped access controls. No credentials belong in source control. Public job feeds have their own licensing and attribution obligations; see the [source matrix](docs/SOURCES_MATRIX.md). No repository-wide open-source license is declared; all rights reserved.

## Credits

Built by **Lucksrei** · [lucksrei.com](https://lucksrei.com) · Lucas Diogo França.
