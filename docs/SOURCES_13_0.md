# OrbiJob 13.0 — direct employer and public-service sources (evidence of terms, licence and permission)

Read on 2026-10-16. Rule applied, as in 12.0: **an endpoint that answers without a key is not a grant to store and republish.** A source is integrated only with a stated
licence, or a stated permission, for storage and display. A new source is born `CONDITIONAL` and **not redistributable**; it appears in the app only after the owner runs the guarded
publish file (`scripts/supabase/ops/publish_source.sql`; the five files of this phase are in `_aplicar/2026-10-16_13_0_fontes/`, nothing was run by the assistant: the guard was only
rehearsed inside a transaction that was rolled back, and it passed for all five). Classes: **PERSIST** · **PENDING** · **BLOCKED** · **LINK_ONLY** · **REJECTED**.

## 1. Integrated in 13.0 (connector, tests, schedule, stored in the database, awaiting the owner's publication)

The research looked for a different kind of source than the aggregators: **public employment services and civil services that publish their offers as open data under a stated
licence**. Spain's regional services turned out to be the productive vein (the Spanish catalogue had 22 visible listings; the four feeds add 2,693 stored offers in the trades, care,
hospitality, transport, education, health, administration and industry that the aggregators lack).

| Source | Country · size | Licence (evidence) | Permission to store/republish | Terms read | Limits and update | Employer named? |
|---|---|---|---|---|---|---|
| **Choisir le Service Public** `csp` | FR · 3,051 offers in the file, 43 stored so far (each new offer costs one page request, 80 per pass, the schedule completes ≈ 2,000) | `lov2` Licence Ouverte 2.0 stated on the dataset (data.gouv.fr API, publisher DGAFP, weekly file) and on the site's legal notice | yes: reuse incl. commercial, republication and adaptation with source and date | licence text and `robots.txt` (offer pages allowed) | file ≈ 120 MB streamed; each offer confirmed on its own page before storage, re-confirmed by `csp-revalidate.yml` | yes (the administration) |
| **SEF Murcia** `sefmurcia` | ES · 244 offers, 243 valid (one has no page) | the data portal's legal notice (`datosabiertos.regiondemurcia.es/avisolegal`, Ley 37/2007): reuse, commercial or not, including copy, distribution and adaptation | yes, on four conditions kept: cite the source ("Origen de los datos"), state the date, do not distort, do not imply sponsorship | the full legal notice | one JSON of ≈ 570 KB, 4 reads a day | **no**: the SEF does not name the employer; the company stays empty, never invented |
| **Feina Activa (SOC)** `feinaactiva` | ES (Catalonia) · 4,586 offers, 1,000 stored (the cap per pass; the rest enters on the next passes), 524 employers | "Llicència oberta d'ús d'informació - Catalunya" (`web.gencat.cat/.../dades-obertes/llicencies`, default of the Generalitat's open data): reuse, distribution, public communication, adaptation worldwide, no time limit | yes, conditions kept: cite "Generalitat de Catalunya. Departament d'Empresa i Treball. SOC", state the date, do not alter or distort, no Generalitat marks | the licence page | one XML of ≈ 7 MB, 4 reads a day; no end date in the feed → offers older than 90 days refused | yes; **a name that is a person's (sole traders) is not republished** (see §4) |
| **ECYL** `ecyl` | ES (Castilla y León) · 951 offers, 850 valid (< 90 days) | Creative Commons Attribution 4.0 on the dataset's distributions (data.europa.eu metadata of the Junta's catalogue) | yes with attribution | licence link; dataset page | one JSON of ≈ 1.2 MB, twice a day | **no** |
| **Lanbide** `lanbide` | ES (Basque Country, plus neighbouring provinces) · 689 valid | Creative Commons Attribution 4.0 on the dataset's distributions (Open Data Euskadi) | yes with attribution | licence link; dataset description (only the offers Lanbide manages) | one JSON of ≈ 600 KB (ISO-8859-1 bytes), twice a day | **no** |

All five: `can_redistribute = false` until the owner publishes; attribution stored in `job_sources.attribution` (it includes the sentence that the employer is not named, which is what the
publish guard checks); links only on the source's own domain; telephone numbers masked, personal e-mail addresses masked (role addresses stay); no personal contact data kept;
presence in the feed stamps a stored offer, absence only stops the stamping (never closes anything), hidden at 72 h and `unknown` after 7 days.

## 2. Employer-run feeds and ATS platforms (the strategy of this phase): investigated, NOT integrated

Every one of these answers publicly. **None states a licence or permission to store and republish a customer's postings**; the postings belong to the employer who uses the platform.

| Platform | What the official documentation / terms say (read 2026-10-16) | Class |
|---|---|---|
| Greenhouse Job Board API (`docs.greenhouse.io/job-board.html`) | "Job Board data is publicly available, so authentication is not required for any GET endpoints"; nothing on licensing, redistribution, rate limits or employer permission | PENDING: needs each employer's authorization |
| Lever Postings API (`github.com/lever/postings-api`, ToS `lever.co/terms-of-service`) | "all job postings in the `published` state are publicly viewable. These jobs may be scraped by third parties" (a statement of fact, no licence); ToS: the customer "retains all rights, title and interest in its Customer Data", competitors may not access the service | PENDING: the employer's rights are reserved by the contract |
| Ashby public posting API | unauthenticated, one company per call, no list of customers; the vendor's terms page was not retrievable (404) | PENDING |
| SmartRecruiters Public Posting API | "supports both API Key and OAuth 2.0 Client Credentials"; nothing on aggregation or redistribution | PENDING |
| Recruitee, Teamtailor, Workday | public career pages/feeds exist, official terms on third-party use not found (only third-party scraper listings) | PENDING |
| NHS Jobs (UK), jobs.ac.uk (academia) | terms pages answered 403/404 here; known to restrict automated copying | not integrated: no evidence of permission |

What would unlock them: a written authorization from the employer (hospital group, university, retailer…) for OrbiJob to read its public board and show its offers with attribution and a link
back. A request template that the owner can send is in `docs/EMPLOYER_FEED_PERMISSION.md` (nothing was sent). Each authorized employer would need only a slug in a declarative list: the snapshot shell
(`worker/src/connectors/snapshot.ts`) built in this phase from the four Spanish cases is what such connectors would reuse.

## 3. Other sources evaluated

| Source | Result | Class |
|---|---|---|
| USAJOBS API (US federal, all professions) | **Terms grant it explicitly** (`developer.usajobs.gov/guides/terms-of-service`): Public Data "may be copied, stored, reformatted, adapted, analyzed, published, redistributed" for lawful commercial or noncommercial purposes, no advance approval, attribution encouraged; the credentials require the registrant's accurate contact information | PENDING owner: only a free API key is missing (request at developer.usajobs.gov, e-mail `access@usajobs.gov`); steps in `docs/USAJOBS_API_REQUEST.md`; the assistant does not register in the owner's name |
| Canada Job Bank (open.canada.ca, OGL-Canada, monthly CSV) | the file has no employer name, no description and no link to the posting (header read: location snapshot id, title, NOC, dates, salary, hours) | REJECTED (a listing nobody can open) |
| City of Edmonton "Public Job Opportunities" (Socrata `7kmt-35ac`, 35 listings, updated 4 times a day, title/category/closing date/link) | the portal says "See terms of use"; the licence PDF ("Open Data Agreement") is not machine-readable here and the grant ("worldwide, royalty-free, non-exclusive licence to use, modify and distribute … including commercial") was seen only in a search snippet, not read by me | PENDING (read the PDF, then a ~40-line connector on the snapshot shell) |
| City of Calgary Careers (Socrata `5fsi-n9xm`, 51 listings, title + link only) | licence page not retrievable (404) | PENDING |
| Galicia (Xunta, CC BY-SA 4.0) | the dataset's RSS distribution answers 404 (`emprego.xunta.gal/portal/ws_difusion_rss.php`) | BLOCKED by the publisher (dead link) |
| Canarias (SCE), Catalonia "temporary offers", Aragón, Andalucía public offers | HTML only / department-internal / public-sector competitions, not live job offers | REJECTED |
| Poland CBOP (`oferty.praca.gov.pl`) | no open-data licence found; an API exists for integrators (gov.pl specification) without public terms; a scraper vendor relies on an undocumented endpoint | PENDING (ask the Ministry; not integrated) |
| Bundesagentur Jobsuche | answered 403 here with the documented public key (as in 6.0 and 12.0); no official terms | BLOCKED here |
| Latvia NVA "Vakances" | dataset dated 2020 | REJECTED (stale) |
| Luxembourg ADEM, Slovakia, Croatia, Ireland CSO, Netherlands CBS, Australia DEWR, Mexico/Chile datasets | statistics (vacancy counts), not listings | REJECTED |
| Brazil (dados.gov.br, SINE/Emprega Brasil), Peru, Argentina, Uruguay, Colombia | Brazil's portal answered 401/timeouts, Argentina's CKAN was blocked by a WAF (HTTP 418), Uruguay's host did not resolve, Peru answered 401; searches found no dataset of live job offers; Brazil's SINE data for intermediaries is offered under a public call and a signed responsibility term (Diário do Comércio), not as open data | BLOCKED or absent: no licensed Latin American source other than Get on Board |
| Korea Work24 / Japan Hello Work / India NCS / South Africa DPSA | need a key or a partnership, or publish PDFs | PENDING owner (keys), nothing integrated |
| Vantaa (Finland) job API, Praha 8, Tours, Île-de-France | each a few dozen listings of one municipality | PENDING (only worth it as a bundle of local governments) |

## 4. Personal data found in the feeds, and what was done

* **Sole traders' names as the employer** (Feina Activa): the employer field holds whatever the author typed, including an individual's own name. Such a name is not republished: a company that reads as a
  person (a known given name followed by surnames, no organisation word) is left empty, and "Person - Trade name" / "Person (Trade name)" keeps only the trade name. 4 of the first 1,000 stored offers had no
  employer because of it (tests use made-up names; the fixture holds none).
* **Contact lines inside the free text** (ECYL, Lanbide, Feina Activa, SEF Murcia): telephone numbers become `[teléfono]` / `[telèfon]`, e-mail addresses become `[e-mail]` unless they are role
  addresses; SEF Murcia's whole registration section (office e-mail, an instruction to send an ID number, the deadline) is dropped. After import: 0 telephone numbers and 0 e-mail addresses in the stored descriptions
  of the five sources (four ECYL texts keep role addresses such as `info@…`, allowed by the policy).
* The publish guard no longer demands a company for a source whose attribution says it does not name one (rule 4 of `publish_source.sql`); for every other source it still does.

## 5. Quality checks (stored rows of the five sources, 2026-10-16)

43 / 243 / 1,000 / 850 / 600 stored, all open; 0 mojibake; 0 duplicate URLs; links sampled (6 per source for four sources, all HTTP 200; Lanbide's host is not reachable from the owner's machine but answers from GitHub);
short descriptions (< 150 characters): ECYL 213 of 850 (the offices write one-liners), Lanbide 15, Feina Activa 2, SEF Murcia 0; offers older than 60 days: Feina Activa 822 (the portal keeps offers for months and
the feed has no end date; refused at 90 days), ECYL 112, SEF Murcia 17.

## Production validation after publication (2026-10-16, publishable key)
| Source | Visible | Country / place | Employer | Personal data left | Links | Notes |
|---|---:|---|---|---|---|---|
| csp | 43 | FR 43; 38 with a town (postal address) | named by the offer, or the authority its title names | 0 e-mails, 0 phones | 43 on choisirleservicepublic.gouv.fr | every offer confirmed on its own page before storing; one real revalidation (43 confirmed); fills ≈ 80 asked per pass |
| sefmurcia | 243 | ES 243, all with a town | empty (the SEF does not name it; attribution says so) | 0 / 0 | sefoficinavirtual.carm.es | 17 older than 60 days; 7 pairs with the same title and town (distinct offer ids) |
| feinaactiva | 1,000 | ES 1,000, all with a town | 996 named; 4 empty (a person's name is never republished) | 0 / 0 | feinaactiva.gencat.cat | 822 older than 60 days (the portal keeps them open); salary range not mapped (no unit) |
| ecyl | 850 | ES 814 → 829 after the fix; 21 EURES offers name no country | empty (the ECYL does not name it) | role addresses only (`info@`, `job@`); **3 foreign phones found and masked (fix ab65c1c + stored rows)** | empleo.jcyl.es (public host, never gestorcontenidos) | 11 identical title+town+text pairs with different ids (published twice by the office); 112 older than 60 days |
| lanbide | 600 | ES 600, all with a town | empty (Lanbide does not name it) | 0 / 0 | web.lanbide.eus | 0 mojibake (Latin-1 decoded); 3 short descriptions |

The licence page of the app names each of them with its real licence (Licence Ouverte 2.0; Llicència oberta d'ús d'informació - Catalunya; CC BY 4.0 for ECYL and Lanbide;
Murcia's legal notice), guarded by `app/test/features/licences_attribution_test.dart`.

**Czech source (12.0), found in this round:** since 2026-10-16 the publisher serves only `volna-mista.json.gz` (the uncompressed file answers 404); the connector reads the `.gz`
(fix 6122fb1). The file's `Last-Modified` was 2026-10-14 23:02 when read on 16/10: watch whether the publisher resumes the daily refresh.
