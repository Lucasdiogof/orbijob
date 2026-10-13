# OrbiJob 2.0 — final phase progress (update after every step)

Mission (user-authorised, continuous, no approval between steps): visual review, forms, animated logo loader, splash,
local PDF résumé reading, safe application prefill, i18n, tests, screenshots. Work directly on `main`, small commits, check CI.
Flutter for `app/`: `export PATH="/c/Users/lucas/AppData/Local/Temp/fl3477/bin:$PATH"` (3.47.7).

## Steps
| # | Step | State | Commit |
|---|---|---|---|
| 0 | Base 2.0 (design system, screens, gallery) | done | afb8c8b … d0ab11a |
| 1 | Visual review pass 1: tablet grid, switch contrast, profile chips/headers | done | (this batch) |
| 2 | Forms on the design system (kit `orbi_form.dart`: page with sticky save bar, discard guard, date, dropdown, tags) | done | (this batch) |
| 3 | Visual review pass 2 + fixed capture scenes (gates, login) | pending | |
| 4 | Orbital loader = the real logo (two arcs on one ring + violet core), eased half-turn loop, reduced motion, tests; frames in gallery 40-* | done | (this batch) |
| 5 | Splash: native static splashes already consistent (Android 12 anim duration 0, iOS LaunchBackground, web #splash) + Flutter hand-over `OrbiLaunchOverlay` (half turn + fade, non-blocking, skipped with reduced motion) | done | (this batch) |
| 6 | PDF résumé: local text extraction + suggestions review | pending | |
| 7 | Application prefill kit (copy profile data + open original) | pending | |
| 8 | i18n audit (long text, pt/es), a11y tests | pending | |
| 9 | Builds (web, Android if possible), final screenshots, final report | pending | |

## Findings log
- `Center(widthFactor: 1)` in `_OrbiButton` expanded to the full height inside bounded-loose parents (bottom bars): fixed with `heightFactor: 1`.
- Browser pane screenshots are tiled/unreliable; the gallery is generated with `CAPTURE=1 flutter test test/tool/capture_screens_test.dart`.

## Blockers / owner-side
- none new. (Older: NAV token, USAJOBS key, Jooble/Adzuna keys.)
