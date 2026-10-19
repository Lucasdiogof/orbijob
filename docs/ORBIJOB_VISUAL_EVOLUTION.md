# OrbiJob visual evolution (batch 1, 19–20/10/2026)

Scope of this batch: a first coherent step of the visual evolution, applied through the shared design system so every screen inherits it. It is **not** the complete redesign the brief describes (see "Not done yet").

## Diagnosis (from real captures of the previous build, `before/`)
Clean and consistent (identity C, Minimal Tech: Space Grotesk + Inter, violet on navy) but flat: cards were plain rectangles with no sense of light, the primary action had no presence, the Home headline had the same voice as a section title, company names had no visual anchor, and press/favourite feedback was absent.

## Direction
Keep the identity and evolve it: "orbital editorial". Depth from light rather than decoration; one editorial moment per screen; motion that is short, optional and never delays content.

## What changed
| Area | Change |
|---|---|
| Surfaces (`core/design/tokens/app_surfaces.dart`, new) | Card lit from the top (barely lighter top edge in dark, cooler base in light), one soft shadow in light mode only, hover edge taking the brand tint, brand gradient and glow for the primary action (glow light mode only), hero ambient light. All derived from existing tokens, so no new literal colour; gradients only move toward more contrast with the text on them (tested). |
| Typography | `hero` style (32/37, 44/48 wide, tight tracking) for the Home headline; `figures` (tabular digits) for salaries; greeting as a small mono eyebrow in the accent colour. |
| `OrbiCard` | Lit surface, hover edge, press feedback; tinted cards stay flat. Every card of the product inherits it. |
| Primary button | Gradient, glow (light), press feedback. |
| Job card and detail | `OrbiMonogram`: company initial on a tinted tile (tint chosen from the name; decorative, hidden from screen readers, not drawn when the name has no letter or at very large text). Detail header gets a larger monogram and `headlineLarge` title. |
| Home | `OrbitBackdrop`: static glow + two fading orbit lines echoing the logo ring behind the hero (repaint-isolated, not animated); hero elements enter in sequence (`Reveal`, first screenful only). |
| Motion (`core/motion/motion.dart`, new) | `Pressable` (scale 0.98, raw pointer events, no interference with taps), `Reveal` (fade + 10 px rise, 45 ms steps, capped), `reduceMotion()`; favourite heart pops (`AnimatedSwitcher`); fade-forwards page transitions on Android/web/desktop, native slide on iOS. Everything is skipped with the system "reduce motion" setting. |

## Decisions and rejections
* **No grain/shader textures** in this batch: the web build runs on CanvasKit/Skwasm and a fragment shader behind long lists is a performance and contrast risk for little gain; a static glow and lit surfaces give the depth at no per-frame cost.
* **No new dependencies**; no React/HTML references were ported. The listed galleries and libraries (Superdesign, Better Design, Design Taste, Motion Primitives, Paper Shaders, 60fps.design and the others) were **not** studied or installed in this batch; the direction above comes from the existing identity and general principles. They remain open for later batches.
* Entrance animation is not applied to list rows (they rebuild while scrolling); only the Home hero.
* Shadows are kept to one soft layer because the screenshot renderer drew heavier layered shadows as hard bands.

## Evidence (`docs/design/visual-evolution/`)
Real renders of the app (real fonts, in-memory data) before/after: Home dark and light, Explore light, detail dark and light, desktop Explore dark, login dark, profile hub light. Regenerate with `CAPTURE=1 CAPTURE_OUT=<dir> flutter test test/tool/capture_screens_test.dart` (the generator now accepts `CAPTURE_OUT`).

## Verification
`flutter analyze` clean; 1,078 Flutter tests pass (8 new in `test/design/visual_evolution_test.dart`: monogram rules, Reveal/Pressable behaviour including reduced motion, contrast ≥ 4.5:1 of ink/muted on both card-gradient ends and on-primary on both button-gradient ends, light and dark). One existing test (`navigation_test`) needed a taller viewport (2800 instead of 2400 px) because the Home grew by about 30 px and the bottom bar covered a tile; no assertion was weakened. Performance was not measured on devices; the added work per frame is a decoration paint and, on Home only, one cached custom paint.

## Not done yet (honest list)
Full-app pass over Perfil/Currículos/Candidaturas/Auth beyond what inherits the new card and button; custom empty states with motion; filter chip transitions; shared-element list→detail transition; section-header refinements; measured performance on a device; reduced-motion and 200 %-text captures of the new Home; study of the listed references. These are the next batches.

Observed on the live site after deploy (800 px window, two-column Home): the monogram narrows the title column and long titles wrap to four lines; consider hiding the monogram below a card width of about 300 px in the next batch.

---

## Batch 2 (19/10/2026): narrow cards, shared empty-state art, profile hub, application tiles

### References actually consulted (README level only, via page fetch)
* **ibelick/motion-primitives** (MIT): React + Tailwind + `motion` kit; the README does not list components (catalogue lives on its docs site, not read). Used only as confirmation that the pattern is "small, optional entrance/hover motion"; nothing ported.
* **madebymustafa/design-taste** (MIT): workflow "design read, avoid default patterns, pre-flight checklist"; names duration/easing tokens, reduced-motion support and a "never animate" list. Specific values are in SKILL.md files that were not read.
* **marvkr/better-design** (MIT): topics hierarchy, spacing, typography, depth, motion; includes a self-review accessibility checklist. Details not read.
* **Not consulted yet**: Superdesign, Canvas UI, Paper Shaders, UI Layouts, Hyperiux, Cursify, Trickle UI Kit and all the galleries (scrolltide, navbar.gallery, footer.design, cta.gallery, 404s.design, unsection, bentogrids, 60fps.design). No claim is made about them.

### Changes
| Area | Change |
|---|---|
| Job card (fix from batch 1) | Monogram is drawn only when the card's own content width is ≥ 280 px (`LayoutBuilder`), so the title keeps the room in two-column layouts. Commit 2c33aaf, with a width test. |
| `OrbiArt` / `OrbiEmptyState` | Tile lit from above with a soft accent halo; art settles in (fade + 0.92→1 scale), title/body/action reveal in sequence. All empty, gate and error states inherit it. Static with reduced motion. |
| Profile hub | Rows and account card reveal in sequence (first screenful only); icon tiles get a subtle gradient; on hover the chevron nudges and takes the brand colour (desktop). |
| Applications list | Company monogram on each tile (same rules as job cards: decorative, hidden at large text). |
| Favourites | Empty ↔ list ↔ loading switch cross-fades (`AnimatedSwitcher`, instant with reduced motion). |

### Evidence
`docs/design/visual-evolution/batch2/`: favourites empty, applications empty, profile hub, résumés (light and dark), rendered by `capture_screens_test.dart` (settled frames, so entrance animations are not visible in stills). Profile hub dark and favourites empty light were inspected: no overflow, hierarchy intact. The other captures were saved but not individually inspected. Need `FLUTTER_ROOT` set and, on a case-sensitive volume, a lowercase symlink of `MaterialIcons-Regular.otf`.

### Verification
`flutter analyze` clean; 1,079 Flutter tests pass. No device performance measurement; entrance animations are one-shot and limited to the first screenful, nothing animates inside scrolling lists.

### Batch 2, part 2 (same day)
| Area | Change |
|---|---|
| Résumés | Main résumé takes the brand edge (`selected`), file tiles get the hub gradient, rows reveal in sequence; empty state uses `OrbiArt` instead of a bare card. Upload/read/storage logic untouched. |
| Applications | Stage badge cross-fades when the stage changes (instant with reduced motion). |
| Saved searches | Alert state also shown by an icon (bell active / off) that scales in on toggle; cards reveal in sequence. |
| Notifications | Unread cards take the brand edge until opened; items reveal in sequence. |
| Settings | Language card reveals; layout and behaviour unchanged. |

Evidence: `batch2/14-resumes-*` (dark one inspected: main résumé highlighted, no overflow) and `batch2/15-settings-*` (saved, not inspected). Saved searches and notifications changes are covered by the existing widget tests but have no capture yet. `flutter analyze` clean, 1,079 tests pass.

### Still open for the redesign
Professional profile sub-page, résumé upload progress, applications board, auth screens, filter chip transitions, Hero evaluation, textures, 200 % text / reduced-motion / ES-PT captures, remaining references.
