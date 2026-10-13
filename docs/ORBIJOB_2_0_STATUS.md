# OrbiJob 2.0 — status and decisions (final phase)

Progress log with commits: `docs/ORBIJOB_2_0_PROGRESS.md`. Screenshots: `docs/design/orbijob-v2/` (generator: `app/test/tool/capture_screens_test.dart`, run with `CAPTURE=1`).

## Delivered (app)
- Design system: tokens (light/dark, WCAG AA tested), `lib/core/orbi/*` component library, no hard-coded colours outside `lib/core/design`.
- Navigation: capsule bottom bar (compact), icon rail (medium), extended side navigation (expanded); profile one tap away.
- Home dashboard (job grid: 1 column on phones, 2 on tablets, 3 on desktop), Explore (search, quick chips, filters sheet with sticky footer, desktop filter sidebar, hierarchical area picker Health → Physiotherapy → Pelvic), job detail with fixed CTA.
- Contextual sign-in gates; redesigned sign in / sign up / new password.
- Profile hub: account, professional profile (completeness from real fields), résumés (main résumé, replace, delete, open, read-for-suggestions), preferences, settings (language as a radio list in a sheet; theme), privacy.
- **Forms on the design system** (`orbi_form.dart`): sticky save bar above keyboard/safe area, label above field with "Optional" marker, validation on interaction, "check the highlighted fields" feedback, saving state, success snackbar on the screen underneath, discard-changes guard, date field with clear, dropdown, tag input for skills, autofill hints, text-input actions. Profile form gained contact e-mail and phone (stored inside `personal`, no migration).
- **Orbital loader = the real logo**: two opposing arcs on one ring + violet core, eased half-turn loop with no seam, light/dark, single-colour mode for buttons, still logo with reduced motion.
- **Splash**: native splashes (Android incl. 12+, iOS LaunchBackground, web `#splash`) were already static and consistent; added `OrbiLaunchOverlay`, a short non-blocking Flutter hand-over (same background and mark, one half turn, fade; skipped with reduced motion; nothing waits for it).
- **PDF résumés, local only**: `pdf_text.dart` is a pure-Dart reader (no network, no service): classic and compressed (object stream) files, Flate/ASCIIHex/ASCII85, simple and Type0 fonts (ToUnicode + glyph widths so kerning splits do not become spaces), form XObjects. Honest statuses: *no text layer* (scans), *encrypted*, *unreadable*. `resume_parser.dart` turns text into suggestions (name, headline, summary, e-mail, phone, links, city/country, skills, languages, experiences, education) from pt/en/es headings; it only ever quotes the text. The review screen shows every suggestion editable, with checkboxes; existing profile data is replaced only where ticked; entries already in the profile are flagged and skipped; nothing is saved until "Apply". Entry points: after uploading a résumé (offer), the résumé menu ("Fill my profile from this résumé", downloads with the user's own session so storage RLS applies), and "Start from a PDF résumé" when no profile exists (nothing is uploaded).
- **Application kit** on the job detail (see below).
- i18n: PT-BR / EN / ES for everything; layout net test: 18 screens × 3 languages × text 1×/2× at 320 px.

## Application assist — what is really supported
OrbiJob does **not** fill, send or touch forms on other sites, on any platform. What exists (`application_kit.dart`):
- Copy own profile data piece by piece or all at once (clipboard: works on Android, iOS and web from a user tap).
- Open the main résumé through a short-lived signed link (download it to attach on the listing).
- Open the original listing in the system browser.
- "I applied: track it": asks first, then records an application dated today (OrbiJob cannot verify it).

Why no autofill: an in-app WebView injecting values into third-party pages is fragile, differs per portal, breaks on CAPTCHAs/protections, and would touch sites whose terms forbid automation. It is not offered and no compatibility is promised.

Platform notes: clipboard and `url_launcher` behave per platform (Android/iOS/web); verified here by widget tests with mocked platform channels, a debug Android APK build (builds) and a release web build (loads, no console errors). Not verified on a physical iOS device (no Mac in this environment) nor on an Android device/emulator.

## Decisions worth knowing
- **Main résumé** is stored in `profiles.preferences.primaryResume` (existing JSON column): no migration.
- **Replace résumé** uploads first and removes the old file afterwards.
- **Job cards never truncate titles** (long Swedish/German titles at 200 % text).
- **Filters** are drafted in the sheet and applied with "Show results"; on desktop the sidebar applies immediately; with large text or narrow windows the sheet's actions stack.
- Sheet footers are capped at 45 % of the sheet and scroll beyond that.

## Limits / follow-ups
- The PDF reader targets text-based résumés from Word/Google Docs/LibreOffice/browsers (tested with real Chrome-made PDFs in pt/en/es plus synthetic structures). Exotic encodings, scans and password-protected files are reported, not guessed. Heuristic parsing can mis-assign fields; that is why the review screen exists.
- No OCR (would need a native/ML dependency or a service).
- Not verified on physical devices (see above). Web screenshots through the Browser pane were unreliable; the gallery is generated with `flutter test`.
