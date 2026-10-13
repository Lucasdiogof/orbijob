# OrbiJob 6.0 — source contracts (evidence of terms, licence and permission)

Read on 2026-10-13. Classes: **PERSIST** (store and show: licence or terms allow it) · **PENDING** (missing proof, key, or an answer from a third party) ·
**BLOCKED** (terms, robots.txt or cost forbid it) · **LINK_ONLY** · **FEDERATED**. A new source is born `CONDITIONAL` and **not redistributable**; it appears
in the app only after the owner runs the guarded publish file (`scripts/supabase/ops/publish_source.sql`, pack in `_aplicar/2026-10-13_6_0_fontes/`).

## 1. Integrated in 6.0 (connector, tests, schedule, stored in the database, awaiting the owner's publication)

### 1.1 Teaching Vacancies (England) — `teachingvacancies` — PERSIST
| Item | Evidence |
|---|---|
| Official URL / API | https://teaching-vacancies.service.gov.uk · `GET /api/v1/jobs.json?page=N` (schema.org JobPosting, 100 per page, newest first, `meta.totalPages`) |
| Operator | Department for Education (England), GOV.UK service |
| Countries / professions | England (`addressCountry: GB`). Not only teachers: head teachers, teaching assistants, SENCO, administration/HR/finance, IT support, catering/cleaning/site staff, pastoral and health staff (16 `occupationalCategory` values) |
| Terms | `/pages/terms-and-conditions#terms-and-conditions-for-api-users`: "You are free to reuse job listing data under the terms of the Open Government Licence for public sector information with the following exception: you must not charge any fee or commission for contacting, interviewing or hiring a respondent to your listing if you have reused Teaching Vacancies data." (updated 9 July 2026). The API's `info.license` is OGL v3.0 |
| Permission to query and store | Yes (OGL v3.0, attribution kept in `job_sources.attribution`; OrbiJob charges nobody) |
| robots.txt | allows `/`; the API path is not disallowed |
| Quota / auth | none documented, no key; the connector reads one page every 1.5 s (≈ 70 pages per pass) |
| Update strategy | the whole feed (≈ 6,700 listings) is read each pass, 4 passes a day + a displaced twin (GitHub); only new ones are inserted (cap 700 per pass, ceiling 2,000 in the catalogue so the source cannot dominate), known ones are stamped |
| Closing strategy | the feed lists only open vacancies and every record has `validThrough` (an expired one is refused); a listing that leaves the feed stops being stamped, is hidden after 72 h and becomes `unknown` after 7 days (never `closed` by absence) |
| Normalisation | title, school (hiring organisation) as company, city (locality, else region), country as stated, employment types, salary only when the text has 1–2 plain `£` amounts and the listing gives the period (HOUR/YEAR…; "Grade 3 Point 5", "+ TLR", two scales are not read), date posted, link = the listing's own page |
| First import | 700 stored (GB), 104 with a salary, 0 invalid links, 3 short descriptions |

### 1.2 NYC Jobs (City of New York, USA) — `nycjobs` — PERSIST
| Item | Evidence |
|---|---|
| Official URL / API | NYC Open Data, Socrata dataset `kpav-sd4t` "Jobs NYC Postings" (DCAS), `https://data.cityofnewyork.us/resource/kpav-sd4t.json` (SoQL: `$where`, `$order`, `$limit`, `$offset`), refreshed daily |
| Countries / professions | New York City government, all kinds: engineering/architecture, legal, health, technology/data, finance, social services, public safety, building operations, administration (1,339 External postings on 2026-10-13) |
| Terms | NYC Open Data Law (Local Law 11 of 2012, Administrative Code §23-501 ff.): public data sets are published without registration, licence requirement or restriction on their use. The dataset says it contains "current job postings available on the City of New York's official jobs site". The portal's `robots.txt` asks for a 1 s crawl delay (the connector waits 2 s) |
| Permission to query and store | Yes (open data). **Internal postings (city employees only) are never read**: the query asks for `posting_type = 'External'` and the normaliser refuses anything else |
| Link | `https://cityjobs.nyc.gov/job/{job_id}` (the city site redirects it to the posting; an unknown id answers 404; verified 2026-10-13) |
| Update / closing | 3 pages of 500, twice a day + a twin; the dataset is the whole current list, so a posting that disappears stops being stamped (hidden at 72 h, `unknown` after 7 days). `post_until` (last day) is honoured: an expired posting is refused |
| Normalisation | country US (employer = City of New York), city "New York City" only when the work location names a borough, salary with its stated frequency (annual/hourly/daily), title-cased agency as company, qualifications and additional information as labelled sections |
| First import | 800 stored (cap per pass; 1,339 available), all with salary, 112 with a borough, 0 invalid links |

### 1.3 Get on Board (Latin America, tech) — `getonboard` — PERSIST (conditional on the owner's decision, see the note)
| Item | Evidence |
|---|---|
| Official URL / API | https://www.getonbrd.com · public API `GET /api/v0/categories/{category}/jobs?per_page=&page=&expand=["company","location_cities"]` (18 categories, ≤ 120 per page). Reference: https://www.getonbrd.com/api-doc.html (OpenAPI `/doc/openapi.yaml`) |
| Countries / professions | Latin America (Chile, Colombia, Mexico, Peru, Argentina, Brazil, Ecuador …) and remote; technology and tech-adjacent (programming, mobile, data, DevOps, design, sales, HR, operations, marketing, education…). 956 listings on 2026-10-13 |
| Terms | The API reference: "Public API — Open to anyone. Access the same data visible on the platform without logging in: job categories, company profiles, published jobs, and a job search endpoint. No authentication required." The Terms of Service (`/about/tos`) restrict automatic downloading in the **customer agreement** (paying companies); the privacy page mentions "people and organisations that consume our API". **Nothing grants or denies storage or redistribution of public listings.** robots.txt: no restrictions |
| Permission | Not explicit. Published only on the owner's decision; a confirmation request is recommended (draft below) |
| Quota / auth | none documented, no key; 1 request every 2 s, ≈ 23 requests per pass |
| Update strategy | all categories are read each pass (twice a day + twin); cap 600 new per pass, ceiling 1,500 |
| Closing strategy | full read each pass; absent listings stop being stamped (hidden at 72 h, `unknown` after 7 days) |
| Normalisation | `remote_modality` decides the place: `no_remote`/`hybrid` → on-site/hybrid in the city of the city record (country from that record); `remote_local` → remote, country only when exactly one is named; `fully_remote` → remote, eligibility not stated (never read as worldwide). The language is the one stated (es/en/pt); `lang_not_specified` stays empty. **No salary** (the public listing gives no currency or period). Sections (profile, projects, duties, benefits, nice-to-have) joined as plain text |
| First import | 600 stored (CL 278, CO 10, PE 8, AR 4, MX 2, BR 1, EC 1, 296 remote without a country), 28 mobile titles, 4 mention Flutter; 343 more wait for the next passes |

Draft e-mail to the platform (to be sent by the owner; nothing was sent): *"Hello, OrbiJob (https://github.com/Lucasdiogof/orbijob) is a free job search app. We read the public
API of Get on Board (categories/jobs) twice a day at one request every two seconds, store title, company, place and description, show them with 'Jobs via Get on Board' and a
link to the listing's own page on getonbrd.com, and never apply on anyone's behalf. May we keep doing so? We will stop on request."*

## 2. Analysed and not integrated

| Source | Region | Class | Why (evidence) |
|---|---|---|---|
| Landing.jobs | Portugal / Europe, tech | **BLOCKED** | an open API exists (`/api/v1/jobs`) but `robots.txt` says `Disallow: /api/`; no terms page found |
| Trampos.co | Brazil, all professions | **BLOCKED** | Terms of use §2.5: forbids "mecanismos, software ou scripts", "Robot/Crawler" copies and reproduction of the site's contents without authorisation |
| MyCareersFuture | Singapore | **BLOCKED** | Terms of use §5/§16: no reproduction, republication or use of Website Content without SWDA's written permission |
| Torre | Latin America | **BLOCKED** | commercial API with credits; `robots.txt` has `Disallow: /api/` |
| Bundesagentur für Arbeit (Jobsuche) | Germany | PENDING | the host answers 403 with an empty body to every request from this environment (not circumvented); no official reuse terms read |
| Gupy portal | Brazil | PENDING | robots.txt allows all, but no documented public API and the terms were not read; not scraped |
| Open Jobs CC0 | global (ATS) | PENDING (freshness) | CC0 export; `diffs/index.json` head is still 2026-10-05 (8 days old on 2026-10-13): no honest 72 h verification possible |
| Latvia NVA "Vakances" (data.gov.lv, CC0, CSV daily, ~1,400 state-sector vacancies) | Latvia | PENDING (candidate) | licence is clear, but the file has no employer name (only a registration number), no description and is public-sector only; would need the company register to name employers |
| City of Calgary Careers (open data, 61 postings) | Canada | PENDING (candidate) | title, area, closing date and link only: no description, no company field, 61 rows |
| We Work Remotely RSS | remote | PENDING | the RSS answers, but the terms page is behind a Cloudflare challenge (not bypassed), so the terms are unread |
| Finland Työmarkkinatori, Estonia Töötukassa | Europe | PENDING | no open read API found (404 / unreachable) |
| Open-data portals of Mexico, Peru, Spain, Ireland, Brazil | Latin America / Europe | PENDING | refuse automated access (403 / 418 / 429 / 401); not circumvented. Colombia's `datos.gov.co` holds only registration statistics, no vacancy list |
| Canada Job Bank open data | Canada | LINK_ONLY | monthly files of past postings: statistics, not the active catalogue |
| NAV (NO), France Travail (FR), USAJOBS (US), Jooble, Adzuna, Reed, Careerjet | — | PENDING (owner) | need a key, a registration e-mail or are paid (see `docs/SOURCES_60_MATRIX.md`) |

Everything not listed here keeps its class in `docs/SOURCES_60_MATRIX.md`.
