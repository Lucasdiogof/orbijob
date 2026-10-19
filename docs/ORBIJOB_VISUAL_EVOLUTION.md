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

## Batch 3 (19/10/2026): account screens and loading
Visual only; no change to the auth cubit, validation, navigation or the OTP/new-password order.
| Area | Change |
|---|---|
| `AuthHeader` (sign in, sign up, recovery code, new password) | Brand symbol on a lit tile with a soft accent halo; symbol, headline and subtitle reveal in sequence; headline/subtitle cross-fade when switching between sign in and sign up. |
| `AuthMessage` | Enters with the shared reveal and carries a hairline edge in the message colour (error or notice), still a live region. |
| Skeletons | New `SkeletonPulse`: `OrbiSkeletonList` now runs one shimmer clock for the whole list instead of one controller per block (about 7 per card); a lone `OrbiSkeleton` still runs its own. Static with reduced motion. |

Evidence: `batch3/10-login-*`, `batch3/11-signup-*`. Only the dark sign-in capture was inspected (no overflow, hierarchy fine, halo subtle). Recovery-code and new-password screens inherit the header but have no capture. `flutter analyze` clean, 1,079 tests pass. Skeleton cost was not measured.

## Batch 4 (19/10/2026): chip motion, Hero and texture decisions
| Area | Change |
|---|---|
| `OrbiFilterChip` | Fill and text colour cross-fade (120 ms), the check mark grows in with the chip width (`AnimatedSize`), press feedback (scale 0.96). Applies to every filter and quick-filter chip. With reduced motion: no animated size, zero-length colour change. Two tests added (check appears while animating and settles; check present on the first frame with reduced motion). |
| Hover and focus | Hover already existed on cards (brand edge) and chips (hover layer); profile hub chevron nudges on hover (batch 2). Keyboard focus keeps the existing 2 px `FocusRing`; not changed. |

### Decisions (reasoned from the code, not prototyped)
* **Shared-element (Hero) list → detail: not implemented.** The detail page is opened from 6 call sites and the shell keeps every tab alive in an `IndexedStack`, so the same job can be on screen in Home, Explore and Favourites at once; Hero tags must be unique per route subtree, so that would assert or need a per-list tag scheme. Titles are also rebuilt by the translation builder and the monogram is dropped on narrow cards or large text, so the shared element would not match between the two screens. Cost and risk are higher than the gain; the existing fade-forwards transition stays.
* **Grain/shader texture: still not applied.** A static grain needs either an image asset (bundle size, and it must be tiled without banding on CanvasKit) or a per-pixel painter/shader; both are repainted behind scrolling lists, and grain lowers text contrast margins that batch 1 tested to ≥ 4.5:1. The static glow, lit card surfaces and orbit lines give depth at no per-frame cost. A grain could be tried on a single non-scrolling surface (login backdrop) if the owner wants it; no performance data was collected either way.

Evidence: `batch4/03-filters-*` (dark inspected: chips, selected chip with check, no overflow). Stills cannot show the transition itself. `flutter analyze` clean, 1,081 tests pass.

## Batch 5 (19/10/2026): audit and fixes
**Method.** The existing layout safety net (`test/features/i18n_layout_test.dart`: ~30 screens × PT/EN/ES × text 1× and 2× on a narrow phone, no overflow, nothing throws) was run against every batch and passes. New `test/features/reduced_motion_audit_test.dart`: Favourites, Applications and the profile hub at 320 × 568, text ×2, PT/EN/ES, with the system "reduce motion" flag: nothing half-transparent in the first frames, no overflow (checked to fail when the flag is off). Capture generator gained `textScale` and two scenes (`50-…`, `51-…`).

**Found and fixed from the captures (`batch5/`, BEFORE and after, dark inspected):**
1. Home hero at text ×2 cut "opportunity" mid-word. The hero now follows the text size up to ×1.5 (`TextScaler.clamp`); every other text still scales fully. Trade-off: the display headline is ~25 % smaller than a strict ×2 for users at the maximum setting.
2. Profile hub at 320 px, ES, ×2: the decorative icon tile took width from titles and words were cut (`compe|tencias`). The tile is dropped at very large text. The e-mail address in the account card still breaks across lines (unavoidable for an address without spaces).

**CI incident (fixed).** Commit d672785 failed the CI `app` job at the `dart format` step (analyze and tests did not run there). Cause: the local Flutter SDK is a master/dev build whose formatter differs from the CI's stable Dart 3.13.5; `visual_evolution_test.dart` was formatted by the wrong one. Reproduced with the 3.47.7 SDK in the fvm cache (`/Volumes/DevSSD/Flutter/fvm_cache/versions/3.47.7`, Dart 3.13.5) and fixed; run `<that dart> format --output=none --set-exit-if-changed lib test` before pushing. Earlier batch commits passed CI.

## Batch 6 (19/10/2026): professional profile, upload placeholder, applications filter
| Area | Change |
|---|---|
| Professional profile | Name set larger with a monogram tile (dropped at large text), sections reveal in sequence; the completeness bar fills to its value (and follows changes), instant with reduced motion. No field, validation or save logic changed. |
| Résumé upload | While a file is being stored a skeleton row (one shared shimmer clock) appears at the top of the list, announced as busy; it uses the existing `uploading` state, no new state. Not covered by an automated test; checked only by reading the code, not by a capture. |
| Applications | Changing the stage filter cross-fades the list (instant with reduced motion). The pipeline structure (agenda, filter chips, tiles) is unchanged: a board/column layout was **not** built. |

Evidence: `batch6/13-professional-profile-*` (dark inspected). Tests: 2 new (completeness bar). `dart format` verified with the CI's Dart 3.13.5, analyze clean, 1,092 tests pass. Note: batch 5's "NO" conclusion below still stands; this batch closes the professional-profile and upload-progress items only partially (no capture of the upload placeholder) and not the applications board.

## Batch 7 (19/10/2026): upload placeholder verified, applications grouped by stage
| Area | Change |
|---|---|
| Résumé upload | Test (`resume_upload_placeholder_test.dart`, upload held open with a gate added to `FakeResumes`): skeleton row and "Uploading…" while storing, then the real row. The capture showed a defect: "No résumé uploaded yet." stayed visible during the first upload; it is now hidden while uploading (asserted). |
| Applications | With "All" selected and more than one stage present, tiles are grouped under one header per stage (badge with count, announced as a heading), in pipeline order. Selecting a stage shows the plain list. Presentation only: same records, same order within a stage, nothing persisted or reordered. Test: `applications_grouping_test.dart`. |
| Existing test | `pipeline_test.dart` tapped stage chips by text; the same text is now also a group header, so the three taps target the chip (`OrbiFilterChip`) explicitly. Every assertion is unchanged. |

Evidence: `batch7/60-resume-uploading-dark.png` (inspected before the fix, which exposed the stale message; re-rendered after it but not re-inspected) and `batch7/61-applications-grouped-dark.png` (inspected: headers, tiles, monograms, no overflow). Each tile still shows its own stage badge, so the stage appears twice; kept so a tile reads on its own. `flutter analyze` clean, `dart format` clean with the CI's Dart, 1,094 tests pass.

The "NO" conclusion in the final report below still holds: remaining items are listed there, minus the upload placeholder (now tested) and the grouped applications layout (done as a grouped list, not a board with columns).

## Batch 8 (19/10/2026): upload re-inspection, references, empty-state families, grain

### Upload state re-inspected (P0)
Rendered in EN/PT/ES, light and dark (`upload/60-resume-uploading-*.png`, all six looked at). Confirmed: "No résumé uploaded yet." is gone while the first file uploads; spacing and hierarchy fine; PT/ES strings fit at 390 px. Residual found and fixed: in dark the skeleton bars were almost invisible on the card, so the placeholder row now shows a dimmed PDF tile and the "Uploading…" text over one skeleton line (re-captured and inspected: ES dark; the others were re-rendered, not all re-opened).

### References studied (page-level fetch only; no code installed or copied)
| Reference | Consulted | Principle | Applied in OrbiJob | Flutter adaptation / limits |
|---|---|---|---|---|
| superdesign-skill (MIT) | README | "design inside the existing design system, take a before-replica of current UI first" | Same method: before/after captures from the real app | **Not installed**: it needs a global unpinned npm CLI, a third-party login and sends project code to its service. |
| better-design (MIT), design-taste (MIT) | README (batch 2) | hierarchy/depth/motion tokens; duration+easing tokens; reduced motion; list of things never to animate | `AppMotion` tokens reused everywhere; nothing animates inside scrolling lists; every motion checks `reduceMotion` | Rule values live in SKILL.md files that were not read. |
| motion-primitives (MIT) | README (batch 2) | small optional entrance/hover motion | `Reveal`, hover nudge, chip transitions | React + `motion`; only the idea. Component catalogue not read. |
| ui-layouts org | org page | `uilayouts` (MIT, components/effects), `cursify` (cursor effects, licence not shown) | none | Web/React only; cursor effects are meaningless on touch and were skipped. |
| paper-design org | org page + `shaders` README | Zero-dependency canvas/WebGL shaders (Apache-2.0); README names MeshGradient and DotOrbit only | Informs the decision below | Not usable in Flutter; the equivalent would be a Flutter fragment shader, judged not worth the cost. |
| 60fps.design | home page | stagger/sequence, shimmer/fade/reveal, loading reduces perceived wait, empty states should invite action, shared-element morph | Sequenced reveals, one shared shimmer clock, empty states with a primary action; shared-element rejected (see batch 4) | Category descriptions only; individual shots not studied. |
| scrolltide.co | home page | scroll-driven templates, GPU shader backgrounds, bento blocks (React/Three.js/GSAP) | none | Scroll-jacking and WebGL backgrounds conflict with long lazy lists. |
| navbar.gallery, cta.gallery, unsection.com | home pages | navigation by content amount; CTA categories; repeatable card (label, title, badge) and a consistent taxonomy | Stage headers + badges in Applications follow the "consistent taxonomy, repeatable card"; the bottom bar was kept | Pages list categories, not guidance; no design analysis was available. |
| bentogrids.com | fetch returned only the title | — | none | Nothing could be learned; no claim made. |

### Empty-state family (new)
`OrbiArtStyle`: **orbit** (default: the full ring system, "nothing here yet"), **broken** (dashed outer ring, satellite off its ring: offline, service down, not configured, no source), **calm** (single ring: no search results). Applied through `OrbiEmptyState.artStyle` in `DataFailureView` and the Explore states. Capture `batch8/62-art-styles-*` (dark and light both opened? only dark was opened).

### Grain (decision changed: applied, narrowly)
`OrbiGrain`: ≤ 6,000 dots drawn once from a fixed seed with `drawRawPoints`, own repaint layer, no asset, no shader, no animation, ignored by hit-testing and semantics. Used inside `OrbitBackdrop` (Home hero, sign-in screen). **Dark theme only**: probing the numbers showed secondary text over the light hero glow is at 4.68:1 and a grain dot would take it to 4.25:1, so the light theme draws none (test asserts it). Dark worst case (glow + full-strength dot) keeps ink 10.9:1, muted 5.3:1 (tested). Cost not measured on a device; one static layer per screen and no effect on list scrolling since it sits in the hero/backdrop only. Visible effect is subtle (inspected: sign-in dark).

Tests: grain contrast, not-drawn-in-light, capped paint; full suite 1,097 pass; `dart format` clean with the CI's Dart; analyze clean.

## Final report
1. **HEAD**: start of this mission 70d0f2f (the local clone was at 14c323c and was fast-forwarded); end: see the last commit of this batch on `main`.
2. **Repo state**: stashes kept (an old local iOS build stash, generated l10n output, accidental formatting by the dev SDK); nothing discarded, no force push.
3. **References really consulted**: READMEs of motion-primitives, design-taste and better-design (all MIT; details not read). Not consulted: Superdesign, Canvas UI, Paper Shaders, UI Layouts, Hyperiux, Cursify, Trickle UI Kit and the 8 galleries.
4. **Narrow cards**: monogram only when the card content is ≥ 280 px wide, judged by `LayoutBuilder`; test at 240 and 330 px.
5. **By screen**: Home (hero ×1.5 cap), job cards, Profile hub, Résumés, Applications (monogram, stage cross-fade), Favourites (state cross-fade), Saved searches (alert icon), Notifications (unread edge), Settings (reveal), Sign in/up/recovery/new password (shared header and message), all empty states (art), skeleton lists, filter chips.
6. **Components**: `OrbiArt`, `OrbiEmptyState`, `AuthHeader`, `AuthMessage`, `OrbiFilterChip`, `SkeletonPulse`/`OrbiSkeleton`, `_HubRow`, `OrbiJobCard`.
7. **Motion**: sequenced reveals (first screenful only), state cross-fades, chip transitions, hover chevron; all skipped with reduced motion.
8. **Textures/effects**: static glow, lit surfaces, orbit lines applied; grain/shader and Hero evaluated and not applied (reasoning above, not prototyped or measured).
9. **Responsive/a11y**: covered by the layout net and the audit above (320 px, ×2 text, PT/EN/ES, reduced motion). Not done: keyboard-navigation and screen-reader passes on the new widgets beyond what the existing tests assert.
10. **Performance**: not measured on a device. Skeleton lists now use one ticker instead of about 7 per card.
11. **Screenshots**: `batch2`–`batch5`; only the ones named as inspected were looked at. Stills cannot show animation.
12. **Tests**: `flutter analyze` clean; 1,090 Flutter tests pass; worker untouched.
13. **Conclusion — premium redesign applied consistently with visual evidence and no proven functional regression? NO.** Not done or not verified: professional-profile sub-page and résumé upload progress redesign, applications board layout, recovery-code/new-password and several other screens inspected only through their shared components, real-device performance, keyboard/screen-reader review, texture experiments, 7 of 10 reference repos and all galleries not studied, manual run with a real account. The product-level visual direction is in place; the finish of the remaining screens is incomplete.

### Still open for the redesign
Professional profile sub-page, résumé upload progress, applications board, OTP/new-password captures, final audit (200 % text, reduced-motion, ES/PT, small-phone captures; CI status), filter chip transitions, Hero evaluation, textures, 200 % text / reduced-motion / ES-PT captures, remaining references.
