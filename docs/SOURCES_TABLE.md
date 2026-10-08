# Catálogo de fontes (gerado)

> Gerado por `node scripts/build-coverage.mjs` de `data/sources.catalog.json`. Não editar à mão.
> `Evidência`: doc = lido em texto primário; secondary = só resumo de terceiros; prior = conhecimento prévio não verificado.

| Fonte | Região | Países | Tipo | Status | Evidência | Autenticação | Limites | Termos / redistribuição | Docs |
|---|---|---|---|---|---|---|---|---|---|
| **Lever Postings API** | Global | global | public JSON per company site | `CONDITIONAL` | doc | none for reads (apply needs key) | apply POST 2/s; read limits undocumented | No API ToS in docs; postings are public, redistribution rights per employer unverified | https://github.com/lever/postings-api |
| **Greenhouse Job Board API** | Global | global | public JSON per board token | `CONDITIONAL` | secondary | none for GET | undocumented | Official page unreachable from sandbox; redistribution unverified | https://developers.greenhouse.io/job-board.html |
| **Ashby Public Job Posting API** | Global | global | public JSON per board name | `CONDITIONAL` | secondary | none | undocumented | Official page unreachable from sandbox; redistribution unverified | https://developers.ashbyhq.com/docs/public-job-posting-api |
| **Himalayas** | Global | global | public API | `RESEARCH` | secondary | none reported | not found | not found - must read before use | https://himalayas.app/docs |
| **Jobicy** | Global | global | public API v2 | `RESEARCH` | secondary | none reported | count up to 100; rate limit not found | not found - must read before use | https://jobicy.com/api/v2/remote-jobs |
| **Remotive** | Global | global | public API | `CONDITIONAL` | doc | none | max 4 fetches/day, >2 req/min blocked | Must link back to Remotive job URL and name Remotive; must NOT re-submit jobs to third-party boards; must not use jobs to collect sign-ups/emails; jobs delayed 24h | https://github.com/remotive-com/remote-jobs-api |
| **USAJOBS** | North America | US | official REST API | `CONDITIONAL` | secondary | free API key + User-Agent email | 500 rows/page, 10,000 rows/query; request rate not confirmed | Not read (official site unreachable) | https://developer.usajobs.gov/guides/ |
| **Adzuna API** | Multi | GB US AT AU BE BR CA CH DE ES FR IN IT MX NL NZ PL SG ZA | official REST API | `CONDITIONAL` | secondary | app_id + app_key | 25/min, 250/day, 1000/week, 2500/month (default) | 'Jobs by Adzuna' label >=116x23px linked on every advert; salary estimates need Jobsworth label; commercial use other than publishing listings needs written consent after 14-day trial | https://developer.adzuna.com/docs/terms_of_service |
| **Reed.co.uk API** | Europe | GB | REST API | `RESEARCH` | secondary | free API key (reported) | max 100 results/page | not found | https://www.reed.co.uk/developers |
| **France Travail - Offres d'emploi** | Europe | FR | official OAuth2 API | `CONDITIONAL` | secondary | OAuth2 client credentials after registration/licence | quotas exist, numbers not found | Offers reusable, but contact data excluded; building candidate files for non-recruitment purposes prohibited | https://francetravail.io |
| **Bundesagentur fuer Arbeit Jobsuche** | Europe | DE | community-documented internal API | `RESEARCH` | secondary | static client id header | unknown | No official public API or terms found; community docs say the agency offers no official API | https://github.com/bundesAPI/jobsuche-api |
| **Job Bank Canada open data** | North America | CA | monthly CSV open data | `CONDITIONAL` | secondary | none | batch files, not live | Licence field not confirmed (commonly Open Government Licence - Canada) | https://open.canada.ca/data/en/dataset/ea639e28-c0fc-48bf-b5dd-b8899bd43072 |
| **EURES** | Europe | AT BE BG HR CY CZ DK EE FI FR DE GR HU IS IE IT LV LI LT LU MT NL NO PL PT RO SK SI ES SE CH | portal | `EXTERNAL_ONLY` | doc | n/a | n/a | Data release limited to EURES Members/Partners or registered end users under originator consent (Decision 2017/1257); terms live in a non-public extranet | https://eur-lex.europa.eu/eli/dec_impl/2017/1257/oj/eng |
| **NHS Jobs** | Europe | GB | employer-side feeds | `EXTERNAL_ONLY` | secondary | employer ATS agreement | n/a | APIs push employer vacancies out / display own listings; no public search API found | https://www.nhsbsa.nhs.uk/join-nhs-jobs/nhs-jobs-integration-and-benefits |
| **Workforce Australia / JobSearch** | Oceania | AU | statistical open data only | `EXTERNAL_ONLY` | secondary | n/a | n/a | data.gov.au vacancy datasets are statistics (Internet Vacancy Index), licence labels inconsistent; no listing API found | https://www.data.gov.au/data/dataset/groups/internet-vacancy-index |
| **SEEK (AU/NZ)** | Oceania | AU NZ | partner API | `CONDITIONAL` | secondary | partner onboarding; employer relationships | n/a | API built for hirers (posting, apply, profile); no job-search API found. Effectively EXTERNAL_ONLY for our use | https://developer.seek.com |
| **JobStreet (SEEK group)** | Asia | MY SG ID PH TH | partner API (SEEK) | `CONDITIONAL` | prior | SEEK approval | n/a | Same SEEK API terms; no job-search API found | https://developer.seek.com |
| **JobsDB (SEEK group)** | Asia | HK TH | partner API (SEEK) | `CONDITIONAL` | prior | SEEK approval | n/a | Same SEEK API terms | https://developer.seek.com |
| **Jooble** | Global | global | API on request | `RESEARCH` | secondary | free key on request | owner reports a lifetime call cap on the free plan; not confirmed in sources found | not found | https://jooble.org/api/about |
| **Indeed** | Global | global | portal | `EXTERNAL_ONLY` | secondary | n/a | n/a | Public Publisher/Job Search API reported retired; remaining APIs are employer/partner-side and do not return search results | https://ads.indeed.com |
| **ZipRecruiter** | North America | US CA GB | partner API | `EXTERNAL_ONLY` | secondary | partnership agreement (ATS/HRIS) | n/a | No self-service search API | https://www.ziprecruiter.com |
| **LinkedIn Jobs** | Global | global | portal | `EXTERNAL_ONLY` | prior | n/a | n/a | Scraping prohibited; no open search API | https://www.linkedin.com/jobs |
| **ESCO classification API (not a job source)** | Global | global | official API / downloadable | `CONDITIONAL` | doc | none reported (third-party claim) | local API recommended for production | Software EUPL 1.2; DATA licence not confirmed - check before bundling | https://esco.ec.europa.eu/en/use-esco/use-esco-services-api |

## Candidatos ainda não investigados (todos `RESEARCH`, alternativa = busca externa)

| Região | Portais (país) |
|---|---|
| Asia | Naukri (IN), Rikunabi (JP), Mynavi (JP), Wantedly (JP), Saramin (KR), JobKorea (KR), 104 Job Bank (TW), Glints (ID), Boss Zhipin (CN), MyCareersFuture (SG) |
| Europe | StepStone (DE), Totaljobs (GB), CV-Library (GB), InfoJobs (ES), Pracuj.pl (PL), Jobs.ch (CH) |
| Africa | Jobberman (NG), BrighterMonday (KE), PNet (ZA), Careers24 (ZA), MyJobMag (NG), Fuzu (KE), WUZZUF (EG), Rekrute (MA) |
| Middle East | Bayt (AE), GulfTalent (AE), Naukrigulf (AE) |
| Oceania | Jora (AU), Trade Me Jobs (NZ) |
| Americas | Computrabajo (MX), Bumeran (AR), Catho (BR), InfoJobs Brasil (BR), Gupy (BR) |
