<p align="center"><img src="docs/design/identity/c-minimal/png/icon-app-256.png" width="112" alt="OrbiJob app icon"></p>

<h1 align="center">OrbiJob</h1>

<p align="center">Encontre oportunidades no mundo todo. Organize sua carreira.</p>

<p align="center"><img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" alt="Flutter"> <img src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" alt="Dart"> <img src="https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white" alt="Supabase"> <img src="https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white" alt="PostgreSQL"> <img src="https://img.shields.io/badge/Cloudflare-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare"> <img src="https://img.shields.io/badge/Platforms-Android_%7C_iOS_%7C_Web-555555" alt="Platforms"></p>

<p align="center"><a href="README.md">English</a> · <b>Português</b> · <a href="README.es.md">Español</a></p>

---

O OrbiJob reúne a busca internacional de empregos e o acompanhamento de candidaturas em um só lugar. É voltado a **todas as profissões**, com oportunidades presenciais, híbridas e remotas. Flutter/desenvolvimento mobile e fisioterapia — inclusive pélvica — recebem pesquisa adicional de fontes, sem limitar o público do aplicativo.

## Funcionalidades

- **Busca mundial:** pesquise por cargo, profissão, especialidade, país, continente e modalidade de trabalho.
- **Fontes reais:** Jobicy, Arbeitnow, Remote OK, Remotive, Platsbanken/JobTech (Suécia), Taiwan Jobs Open Data e Jobs.co.nz. A disponibilidade muda continuamente; confira a [matriz de fontes](docs/SOURCES_MATRIX.md).
- **Detalhes transparentes:** cargo, empresa, descrição original, localização, modalidade, atribuição da fonte e indicadores de compatibilidade e confiança quando houver dados suficientes.
- **Carreira organizada:** perfil profissional, experiência, formação, habilidades, idiomas, preferências, favoritos e acompanhamento de candidaturas.
- **Currículos em PDF:** upload privado, currículo principal, substituição, exclusão, leitura local de texto e revisão editável antes de aplicar sugestões ao perfil.
- **Kit de candidatura:** copiar informações do perfil, acessar currículo e registrar candidatura mediante confirmação. O OrbiJob não envia candidaturas automaticamente.
- **Experiência internacional:** interface em português, inglês e espanhol; temas claro/escuro/sistema; layout responsivo e loading com a identidade orbital.

## Capturas de tela

### Busca e descoberta

<table><tr><td align="center"><img src="docs/design/orbijob-v2/01-home-light.png" width="235" alt="Home screen"><br><sub><b>Home</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/02-explore-light.png" width="235" alt="Explore jobs"><br><sub><b>Explore</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/03-filters-light.png" width="235" alt="Job search filters"><br><sub><b>Filters</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/04-job-detail-light.png" width="235" alt="Job details"><br><sub><b>Job details</b></sub></td></tr></table>

### Sua carreira em um só lugar

<table><tr><td align="center"><img src="docs/design/orbijob-v2/12-profile-hub-dark.png" width="235" alt="Professional profile in dark theme"><br><sub><b>Profile</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/14-resumes-dark.png" width="235" alt="Resume management in dark theme"><br><sub><b>Résumés</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/22-resume-review-dark.png" width="235" alt="Review extracted resume details"><br><sub><b>PDF review</b></sub></td><td align="center"><img src="docs/design/orbijob-v2/23-application-kit-dark.png" width="235" alt="Application kit"><br><sub><b>Application kit</b></sub></td></tr></table>

Mais capturas reais dos widgets Flutter (claro, escuro, desktop, tablet, PT e ES) estão na [galeria](docs/design/orbijob-v2/README.md). Usam dados controlados de teste, não comprovam a quantidade de vagas em produção.

## Arquitetura

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

## Tecnologias

| Area | Technology |
|---|---|
| Application | Flutter / Dart, feature-first Clean Architecture, Cubit/BLoC, GetIt |
| Design & localization | OrbiJob 2.0 design system, light/dark, Flutter ARB — EN / PT-BR / ES |
| Backend | Supabase Auth, PostgreSQL, Row Level Security, Storage, scheduled SQL jobs |
| Ingestion | TypeScript / Cloudflare Worker code, provider adapters, GitHub Actions |
| Quality | Flutter widget/accessibility tests, TypeScript tests, PostgreSQL 16/17, GitHub Actions CI |

## Execução local

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

## Estrutura do repositório

```text
app/        Flutter application and widget tests
worker/     TypeScript ingestion/API components and tests
supabase/   Database migrations, policies and SQL tests
scripts/    Operational and validation scripts
data/       Source and occupation metadata
docs/       Architecture, sources, security, UX and screenshots
.github/    CI and scheduled jobs
```

## Limitações importantes

- Job coverage varies by country, sector, provider terms and recency. Listing counts change continuously.
- Job information originates from third parties; applications and eligibility requirements must be confirmed with the employer.
- Résumé parsing works locally on text-based PDFs; scanned or encrypted PDFs are not automatically read. Extracted fields always require review.
- The application kit helps prepare and track applications; OrbiJob does **not** submit applications or automatically fill third-party forms.
- Mobile job links may open in an in-app browser, with an external-browser escape route; embedded third-party websites and authentication may have limitations.
- Automatic listing translation is under development; its availability is not guaranteed on every platform or language pair.

## Plataformas e estado

Android, iOS and Web are supported by the Flutter codebase. The app has passed automated tests, an Android debug APK build and a Web release build; full on-device verification and store publication are **not claimed** here. See [OrbiJob 2.0 status](docs/ORBIJOB_2_0_STATUS.md) and [progress](docs/ORBIJOB_2_0_PROGRESS.md). No Play Store / App Store links are published until listings are live.

## Privacidade e licenciamento

Private candidate information and résumé files are protected by account-scoped access controls. No credentials belong in source control. Public job feeds have their own licensing and attribution obligations; see the [source matrix](docs/SOURCES_MATRIX.md). No repository-wide open-source license is declared; all rights reserved.

## Créditos

Built by **Lucksrei** · [lucksrei.com](https://lucksrei.com) · Lucas Diogo França.
