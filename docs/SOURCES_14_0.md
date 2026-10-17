# OrbiJob 14.0 — source research (2026-10-17)

New hypotheses only; the candidates closed in [SOURCES_13_0.md](SOURCES_13_0.md) were not searched again. Method: catalogue sweeps (Socrata discovery API on both regions, data.gouv.fr, data.europa.eu, CKAN of the UK, Ireland, Australia and its states, Canada,
Switzerland, Portugal, Colombia's Socrata) followed by reading the licence text and fetching the live feed. "Public API" was never taken as a licence.

## Integrated (stored, not published)
| Source | Body / URL | Licence (read) | Automated read · storage · commercial republication | Format · volume · refresh | Attribution | Personal data | Application link | Free infrastructure |
|---|---|---|---|---|---|---|---|---|
| `calgary` — City of Calgary Careers | The City of Calgary · https://data.calgary.ca/resource/5fsi-n9xm.json (dataset page https://data.calgary.ca/d/City-of-Calgary-Careers/5fsi-n9xm) | **Open Government Licence – City of Calgary v2.1** (https://data.calgary.ca/stories/s/Open-Calgary-Terms-of-Use/u45n-7awa/): worldwide, royalty-free, perpetual, "including for commercial purposes"; copy, modify, publish, translate, adapt, distribute in any medium | yes · yes · yes | JSON · 56 rows (55 stored, one duplicate by fingerprint) · portal refresh several times a day; read once a day | "Contains information licensed under the Open Government Licence – City of Calgary" + link to the licence (stored in the source's attribution). Licence excludes personal information and use of the City's names/logos to suggest endorsement | none in the rows (id, title, area, closing date, link) | own posting on recruiting.calgary.ca, kept as given | one 20 KB GET a day |

The dataset holds no description, no publication date and no per-listing location: the employer is the City itself (its own description: "the job opportunities with The City of Calgary"), so the company is "The City of Calgary" and the city Calgary; nothing else is invented. Expired listings
are refused by their closing date. Publication is the owner's decision: `_aplicar/2026-10-17_14_0_fontes/01_publicar_calgary.sql` (guard rehearsed in a rolled-back transaction: passes; `can_redistribute` still false).

## Investigated, not integrated
| Candidate | What was verified | Decision |
|---|---|---|
| City of Edmonton "Public Job Opportunities" (Socrata `7kmt-35ac`, 35 rows, 4 refreshes a day) | Terms read (Open Data Terms of Use v2.1, Jan 2016, PDF): worldwide royalty-free licence to use, modify and distribute **including commercially**, but whoever "distributes or provides access to the datasets to any other person" must give them the Terms and ensure they are **bound by them**, plus an **indemnity** clause and cancellation "for any reason, without notice" | NOT integrated: the downstream-binding and indemnity conditions are not met by a public app; owner decision (a question to opendata@edmonton.ca would settle whether showing individual listings counts as distribution) |
| Victorian Government Jobs API (developer.vic.gov.au) | Licence terms read: grant limited to "Approved Recipients" (agencies approved to use the platform) for supplying job data to a job board of an Approved Recipient; downstream recipients may not on-supply | REJECTED (not open) |
| ACT Government "Vacant ACT Government Jobs" (data.act.gov.au `vf94-th2f`, CC BY 3.0 AU) | Row data not accessible ("non-tabular"), last updated 2012 | REJECTED (stale) |
| Government of Canada "Advertisements to the Public Service" (open.canada.ca, OGL-Canada) | One file per closed fiscal year: closed advertisements only | REJECTED (history, not listings) |
| Région Île-de-France "Offres d'emploi" (data.gouv.fr `60de8f9062812f0e7bf9ae1b`, Licence Ouverte 2.0, ODS, 206 rows) | Rows carry id, title, department, text; **no link to the individual offer** | NOT integrated (a link to the generic careers page would not open the offer) |
| Tours Métropole / Ville de Tours (ODS, Licence Ouverte 2.0, daily; 18 + 15 rows) | Per-offer links on jobaffinity.fr (the ATS the city chose), contract type, end date | VIABLE but tiny (33): left for a bundle of small French municipal feeds, when more of the same shape exist |
| Grand Paris Seine Ouest "Postes à pourvoir" (Licence Ouverte) | Last row opened in 2023, no link | REJECTED (stale, no link) |
| Vantaa (Finland) open jobs REST (CC BY 4.0, `gis.vantaa.fi/rest/tyopaikat/v1`) | Works, link to each posting on vantaa.rekrytointi.com, closing date; **9 listings**, ids are positional | VIABLE but tiny; first Finnish source if more Finnish cities appear |
| Infrabel (Belgium) open jobs (ODS `joblistinfrabel`, CC0, 255 rows) | One row per work site; no id and **no link to the offer** | NOT integrated |
| Junta de Andalucía "Ofertas de empleo de entidades instrumentales" | Mostly concluded offers; no per-offer link in the records | NOT integrated |
| UK councils (Colchester, Salford…) "current job vacancies" under OGL v3 | Each a few dozen rows, different shape per council | VIABLE only as a bundle; not built |
| Colombia `datos.gov.co` (Socrata) | Searches for vacantes / ofertas de empleo / oferta laboral return registration statistics and a "referred applicants" table, no listings | REJECTED |
| Portugal IEFP (dados.gov.pt) | Monthly statistics of offers at employment centres | REJECTED (statistics) |
| Socrata discovery sweep (US + EU regions, 7 queries, 272 datasets, updated since Sep 2026) | Only NYC Jobs (already integrated), Edmonton, Calgary are listings; the rest are payroll, permits, statistics | nothing new |

## Still pending outside this environment
USAJOBS key (owner, `docs/USAJOBS_API_REQUEST.md`); NAV Norway registration e-mail; Jooble and Work24 keys; Get on Board permission; employer permission requests (`docs/EMPLOYER_FEED_PERMISSION.md`, nothing sent).
