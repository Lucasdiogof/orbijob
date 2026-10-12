# OrbiJob 2.0 — status and decisions

## Delivered (app)
- Design system: tokens (light/dark, WCAG AA tested), `lib/core/orbi/*` component library, no hard-coded colours outside `lib/core/design`.
- Navigation: capsule bottom bar (compact), icon rail (medium), extended side navigation (expanded); profile one tap away.
- Home dashboard, Explore (search, quick chips, filters sheet with sticky footer, desktop filter sidebar, hierarchical area picker Health → Physiotherapy → Pelvic), job detail with fixed CTA.
- Contextual sign-in gates (favorites, applications, résumés, profile, saved searches); redesigned sign in / sign up / new password with show-hide password.
- Profile hub: account, professional profile (completeness from real fields), résumés (main résumé, replace, delete, open), preferences, settings (language as a radio list in a sheet; theme), privacy.
- PT-BR / EN / ES strings for everything above; old widgets (`AppButton`, `StateView`, `JobCard`, …) removed.
- Screenshots: `docs/design/orbijob-v2/` (generator: `app/test/tool/capture_screens_test.dart`).

## Decisions worth knowing
- **Main résumé** is stored in `profiles.preferences.primaryResume` (JSON column that already existed): no migration, unknown keys are preserved.
- **Replace résumé** uploads the new PDF first and removes the old one only afterwards (if the user is at the 10-file limit the old one is removed first, so a replace never fails on the quota).
- **Job cards never truncate titles** (long Swedish/German titles at 200 % text); the confidence indicator lives on the detail page next to compatibility.
- **Filters** are drafted in the sheet and applied with "Show results"; on desktop the sidebar applies immediately.

## Application assist — feasibility (not implemented, by design)
- OrbiJob never submits an application: every application happens on the original listing (stated in Privacy).
- PDF text extraction / prefill would need an on-device parser or a server function; neither exists today. If added, it must (a) run only after the user picks the file, (b) show the extracted fields for confirmation before saving, (c) never send anything to a company. Safe, cheap first step that needs no parsing: a "copy my profile data" action (name, headline, location, skills) on the job detail page.

## Not done / follow-ups
- Application and profile *forms* still use the themed `TextFormField` (they inherit the new filled style) instead of `OrbiTextField` labels above the field.
- Orbital loader is used on buttons/skeletons; a branded splash animation is not added (native splash colours were updated).
- Web preview screenshots through the Browser pane were unreliable (tiled captures); the gallery is generated with `flutter test` instead.
