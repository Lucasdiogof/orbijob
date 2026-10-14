# Sources evaluated in OrbiJob 12.0 (2026-10-14)
Evidence and classes are in `docs/ORBIJOB_12_0_PROGRESS.md`. Rule applied: an API that answers without a key is **not** a grant to store and republish; a source is integrated only with a stated licence, or a stated permission, for storage and display.
Terms read: Lever postings-api README ("published jobs may be scraped by third parties"; no licence), Greenhouse Job Board API ("publicly available, no authentication for GET"; no terms), Ashby public posting API (no terms; "if you host your own careers page you can use this data"), SmartRecruiters Public Posting API (API key/OAuth; terms not covered), Himalayas API page + Terms of Service (see progress file), Get on Board (unchanged from 8.0).

## Re-checks of 2026-10-14 (second part of 12.0)
| Source | Result | Class |
|---|---|---|
| Vacatures Overheid (data.overheid.nl, CC0, publisher KOOP / data owner Werkmaatschappij) | the catalogue entry itself now says **"Niet beschikbaar"** (not available); `api.cso20.net`, `docs.api.cso20.net` and `/vacatures` all answer **503** | BLOCKED by the publisher: not retried again until the catalogue entry shows the dataset as available |
| Úřad práce ČR (`mpsvcz`) | 1,000 stored, all CZ, 931 with town, 992 with salary (CZK, month or hour), 0 without employer, 1,000 deep links in the expected form, 0 duplicate URLs; e-mails left in free text are role addresses only (hr@, info@, job@), allowed by the e-mail policy; **one phone glued to the country code (`+420…`) had escaped the mask** → regex fixed (3cf7165) and the stored row corrected (undo kept in `_aplicar/`) | INTEGRATED, **not published** (`can_redistribute=false`): publication is the owner's step |
