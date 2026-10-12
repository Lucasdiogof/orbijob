# OrbiJob 2.0 — screenshot gallery

Generated from the real app (brand fonts, in-memory data), not mocks:

    cd app
    CAPTURE=1 flutter test test/tool/capture_screens_test.dart

Without `CAPTURE=1` the generator is skipped, so the normal suite never writes files.

| Files | Screen |
|---|---|
| 01-home | Home: greeting, search with filters shortcut, quick chips, latest jobs, regions |
| 02-explore / 03-filters | Explore results and the filters bottom sheet (sticky footer) |
| 04-job-detail | Job detail with the call to action fixed at the bottom |
| 05/06 | Favorites and Applications for a signed-out visitor (contextual gates) |
| 07/08 | Favorites and Applications empty states (signed in) |
| 09 / 12 | Profile hub: visitor and signed in |
| 10 / 11 | Sign in / create account |
| 13 / 14 / 15 / 16 / 17 | Professional profile (completeness), résumés (main/replace), settings, language list, privacy |
| 20 / 21 | Tablet home; desktop Explore as master/detail |
| 30–33 | Home, Explore, profile hub and language list in `pt` and `es` |

Each screen exists in `-light` and `-dark`.
