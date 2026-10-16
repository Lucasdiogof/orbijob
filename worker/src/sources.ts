import { bpceConnector, BPCE_MAX_PAGES } from './connectors/bpce';
import { ARBEITNOW_HOSTS, arbeitnowConnector, remoteOkConnector, remotiveConnector } from './connectors/feeds';
import { foremConnector, FOREM_MAX_PAGES } from './connectors/forem';
import { getOnBoardConnector } from './connectors/getonboard';
import { jobicyConnector } from './connectors/jobicy';
import { jobsCoNzConnector } from './connectors/jobsconz';
import { teachingVacanciesConnector, TEACHINGVACANCIES_MAX_PAGES } from './connectors/teachingvacancies';
import { nycJobsConnector, NYCJOBS_MAX_PAGES } from './connectors/nycjobs';
import { mpsvCzConnector } from './connectors/mpsvcz';
import { cspConnector } from './connectors/csp';
import { sefMurciaConnector } from './connectors/sefmurcia';
import { feinaActivaConnector } from './connectors/feinaactiva';
import { ecylConnector } from './connectors/ecyl';
import { lanbideConnector } from './connectors/lanbide';
import { karriereNrwConnector } from './connectors/karrierenrw';
import { taiwanJobsConnector } from './connectors/taiwanjobs';
import { JOBTECH_PASS_PAGES, jobtechConnector } from './connectors/jobtech';
import type { Connector } from './types';

/**
 * The sources the catalogue reads. One entry per `job_sources.id`; the connector, the source row (attribution text, review status)
 * and the safe defaults of a pass live together, so nothing about a source is scattered across scripts.
 *
 * A source row is born CONDITIONAL and NOT redistributable, and is published only by scripts/supabase/ops/publish_source.sql after its
 * stored records were reviewed. `docs/SOURCES_MATRIX.md` holds the evidence (terms, limits, attribution) behind every entry.
 */
export interface SourceProfile {
  id: string;
  /** `job_sources.attribution`: shown with every job of the source. Must name the source and link to it (their terms ask for a link back). */
  attribution: string;
  /** Main host of the source. */
  host: string;
  /** Every host a stored `original_url` may be on (defaults to `host`). */
  hosts?: readonly string[];
  /** Feed pages a `discover` pass may read. */
  maxPages: number;
  /** `maxPages` is the intended reading window of a newest-first feed: reaching it is a normal end (see `SyncOptions.pageWindow`). */
  pageWindow?: boolean;
  /** New jobs one pass may add. */
  newCap: number;
  /** Ceiling on FULL jobs of this source (open, or still carrying a description). */
  catalogue: number;
  make(fetchImpl: typeof fetch, now: () => Date, origin?: string): Connector;
}

export const SOURCES: Record<string, SourceProfile> = {
  jobicy: {
    id: 'jobicy', attribution: 'Remote jobs via Jobicy (https://jobicy.com)', host: 'jobicy.com',
    maxPages: 40, newCap: 200, catalogue: 4000,
    make: (f, n, origin) => jobicyConnector(f, n, { origin }),
  },
  arbeitnow: {
    id: 'arbeitnow', attribution: 'Jobs via Arbeitnow (https://www.arbeitnow.com)', host: 'arbeitnow.com', hosts: ARBEITNOW_HOSTS,
    maxPages: 8, pageWindow: true, newCap: 300, catalogue: 3200,
    make: (f, n, origin) => arbeitnowConnector(f, n, { origin }),
  },
  remoteok: {
    id: 'remoteok', attribution: 'Remote jobs via Remote OK (https://remoteok.com)', host: 'remoteok.com',
    maxPages: 1, newCap: 150, catalogue: 300,
    make: (f, n, origin) => remoteOkConnector(f, n, { origin }),
  },
  remotive: {
    id: 'remotive', attribution: 'Remote jobs via Remotive (https://remotive.com)', host: 'remotive.com',
    maxPages: 1, newCap: 100, catalogue: 200,
    make: (f, n, origin) => remotiveConnector(f, n, { origin }),
  },
  jobtech: {
    id: 'jobtech', attribution: 'Jobs via Arbetsförmedlingen / Platsbanken (https://arbetsformedlingen.se), open data CC0 from JobTech Dev', host: 'arbetsformedlingen.se',
    maxPages: JOBTECH_PASS_PAGES, pageWindow: true, newCap: 600, catalogue: 4200,
    make: (f, n, origin) => jobtechConnector(f, n, { origin }),
  },
  twjobs: {
    id: 'twjobs',
    attribution: 'Jobs via Taiwan Jobs (臺灣就業通), Workforce Development Agency, Ministry of Labor, Taiwan (https://job.taiwanjobs.gov.tw), Open Government Data License v1.0 (https://data.gov.tw/en/datasets/44062)',
    host: 'taiwanjobs.gov.tw',
    maxPages: 3, newCap: 1000, catalogue: 1500,
    make: (f, n, origin) => taiwanJobsConnector(f, n, { origin }),
  },
  jobsconz: {
    id: 'jobsconz', attribution: 'Jobs via Jobs.co.nz (https://jobs.co.nz), New Zealand', host: 'jobs.co.nz',
    maxPages: 6, newCap: 400, catalogue: 800,
    make: (f, n, origin) => jobsCoNzConnector(f, n, { origin }),
  },
  getonboard: {
    id: 'getonboard', attribution: 'Jobs via Get on Board (https://www.getonbrd.com), tech jobs in Latin America', host: 'getonbrd.com',
    maxPages: 40, newCap: 600, catalogue: 600,
    make: (f, n, origin) => getOnBoardConnector(f, n, { origin }),
  },
  teachingvacancies: {
    id: 'teachingvacancies',
    attribution: 'Jobs via Teaching Vacancies, Department for Education (England) (https://teaching-vacancies.service.gov.uk), Open Government Licence v3.0 (https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)',
    host: 'teaching-vacancies.service.gov.uk',
    maxPages: TEACHINGVACANCIES_MAX_PAGES, newCap: 700, catalogue: 3500, // 2026-10-14: was 2000 (hit; database 206 MB of 500, all ceilings together ~29,300 rows)
    make: (f, n, origin) => teachingVacanciesConnector(f, n, { origin }),
  },
  nycjobs: {
    id: 'nycjobs',
    attribution: 'Jobs via NYC Open Data, "Jobs NYC Postings", Department of Citywide Administrative Services, City of New York (https://data.cityofnewyork.us/d/kpav-sd4t); apply on https://cityjobs.nyc.gov',
    host: 'cityjobs.nyc.gov',
    maxPages: NYCJOBS_MAX_PAGES, newCap: 800, catalogue: 2000,
    make: (f, n, origin) => nycJobsConnector(f, n, { origin }),
  },
  karrierenrw: {
    id: 'karrierenrw',
    attribution: 'Jobs via Karriere.NRW, employer portal of the state of North Rhine-Westphalia (https://karriere.nrw), Open.NRW, Datenlizenz Deutschland – Namensnennung – Version 2.0 (https://www.govdata.de/dl-de/by-2-0)',
    host: 'karriere.nrw',
    maxPages: 1, newCap: 1000, catalogue: 1500,
    make: (f, n, origin) => karriereNrwConnector(f, n, { origin }),
  },
  bpce: {
    id: 'bpce',
    attribution: 'Jobs via Groupe BPCE open data (https://recrutement.bpce.fr), dataset "Groupe BPCE - Offres emploi publiques" on data.gouv.fr, Licence Ouverte v2.0 (https://www.etalab.gouv.fr/licence-ouverte-open-licence/)',
    host: 'bpce.fr',
    maxPages: BPCE_MAX_PAGES, newCap: 1000, catalogue: 2000,
    make: (f, n, origin) => bpceConnector(f, n, { origin }),
  },
  forem: {
    id: 'forem',
    attribution: 'Jobs via Le Forem, public employment and training service of Wallonia (https://www.leforem.be), Open Data Wallonie-Bruxelles (https://www.odwb.be/explore/dataset/offres-d-emploi-forem/), licence CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/): the records of this source are shared under the same licence',
    host: 'leforem.be',
    maxPages: FOREM_MAX_PAGES, pageWindow: true, newCap: 1000, catalogue: 2000,
    make: (f, n, origin) => foremConnector(f, n, { origin }),
  },
  mpsvcz: {
    id: 'mpsvcz',
    attribution: 'Jobs via Úřad práce České republiky / MPSV, Czech public employment service (https://up.gov.cz), open data "Volná pracovní místa" (https://data.mpsv.cz/od/soubory/volna-mista/), published without copyright, database or personal-data restrictions (https://data.mpsv.cz/web/data/podminky-uziti)',
    host: 'up.gov.cz',
    maxPages: 1, newCap: 1000, catalogue: 3500,
    make: (f, n, origin) => mpsvCzConnector(f, n, { origin }),
  },
  csp: {
    id: 'csp',
    attribution: 'Jobs via Choisir le Service Public, the job site of the French civil service (https://choisirleservicepublic.gouv.fr), open data "Les offres diffusées sur Choisir le Service Public" by the DGAFP on data.gouv.fr (https://www.data.gouv.fr/datasets/6322e99e12175f7eb26ff465), Licence Ouverte v2.0 (https://www.etalab.gouv.fr/licence-ouverte-open-licence/); every offer is confirmed on its own page before it is shown',
    host: 'choisirleservicepublic.gouv.fr',
    // each new offer costs one page request (1 s apart) before it is stored: 80 per pass fits the 3-minute discovery budget. Every stored
    // offer must be re-confirmed within 72 h (the app hides older confirmations): 4 revalidations a day of ~450 pages cover 2,000
    maxPages: 1, newCap: 80, catalogue: 2000,
    make: (f, n, origin) => cspConnector(f, n, origin ? { api: origin } : {}),
  },
  sefmurcia: {
    id: 'sefmurcia',
    attribution: 'Jobs via SEF, Servicio de Empleo y Formación de la Región de Murcia (https://sefoficinavirtual.carm.es), open data of the Región de Murcia "Ofertas de empleo activas en la Región de Murcia" (https://datosabiertos.regiondemurcia.es), reuse authorised by its legal notice (https://datosabiertos.regiondemurcia.es/avisolegal); origin of the data: Región de Murcia. The SEF does not name the employer',
    host: 'carm.es',
    // one request returns every active offer (≈ 250): no cap is needed, the ceiling only keeps the source in proportion
    maxPages: 1, newCap: 500, catalogue: 1000,
    make: (f, n, origin) => sefMurciaConnector(f, n, { origin }),
  },
  feinaactiva: {
    id: 'feinaactiva',
    attribution: 'Jobs via Feina Activa, Servei Públic d\'Ocupació de Catalunya (SOC) (https://feinaactiva.gencat.cat), open data of the Generalitat de Catalunya "Portal Feina Activa. Ofertes de feina", Llicència oberta d\'ús d\'informació - Catalunya (https://web.gencat.cat/ca/generalitat/dades-indicadors/dades-obertes/llicencies); origin of the data: Generalitat de Catalunya, Departament d\'Empresa i Treball, Servei Públic d\'Ocupació de Catalunya. Some offers show no employer name (a person\'s name is not republished)',
    host: 'feinaactiva.gencat.cat',
    // one 7 MB XML read returns every published offer (≈ 4,600); at most 1,000 new ones per pass, 3,000 in the catalogue (the portal keeps offers for months)
    maxPages: 1, newCap: 1000, catalogue: 3000,
    make: (f, n, origin) => feinaActivaConnector(f, n, { origin }),
  },
  ecyl: {
    id: 'ecyl',
    attribution: 'Jobs via ECYL, Servicio Público de Empleo de Castilla y León (https://empleo.jcyl.es), open data of the Junta de Castilla y León "Ofertas de Empleo" (https://datosabiertos.jcyl.es), Creative Commons Attribution 4.0 (https://creativecommons.org/licenses/by/4.0/deed.es_ES); origin of the data: Junta de Castilla y León. The ECYL does not name the employer',
    host: 'jcyl.es',
    // one 1.2 MB JSON read returns every offer (≈ 950); the catalogue ceiling keeps the source in proportion
    maxPages: 1, newCap: 1000, catalogue: 1500,
    make: (f, n, origin) => ecylConnector(f, n, { origin }),
  },
  lanbide: {
    id: 'lanbide',
    attribution: 'Jobs via Lanbide, Servicio Vasco de Empleo (https://web.lanbide.eus), open data of the Basque Government "Ofertas de empleo de Lanbide" (https://opendata.euskadi.eus), Creative Commons Attribution 4.0 (https://creativecommons.org/licenses/by/4.0/); origin of the data: Gobierno Vasco, Lanbide. The offers do not name the employer',
    host: 'lanbide.eus',
    // one 600 KB JSON read returns every offer Lanbide manages (≈ 500); the catalogue ceiling keeps the source in proportion
    maxPages: 1, newCap: 600, catalogue: 1000,
    make: (f, n, origin) => lanbideConnector(f, n, { origin }),
  },
};

export const SOURCE_IDS = Object.keys(SOURCES);
