/// The official PUBLIC employment service of a country, as a plain link. OrbiJob does not copy, store or show anything from these portals
/// (most have no open licence or API, or a few forbid it): when the catalogue has nothing for a country, the person is pointed to where that
/// country's own listings live. Each address was opened on 2026-10-14 and is the service's own site (a ministry, a public agency or a national
/// job bank), never a private board. Kept apart from the catalogue on purpose, so the origin of every listing stays clear.
class CountryPortal {
  const CountryPortal(this.name, this.url);
  final String name;
  final String url;
}

const _portals = <String, CountryPortal>{
  'BR': CountryPortal(
    'Emprega Brasil (Ministério do Trabalho e Emprego)',
    'https://empregabrasil.mte.gov.br/',
  ),
  'PT': CountryPortal(
    'IEFP, Instituto do Emprego e Formação Profissional',
    'https://www.iefp.pt/',
  ),
  'ES': CountryPortal(
    'SEPE, Servicio Público de Empleo Estatal',
    'https://www.sepe.es/',
  ),
  'MX': CountryPortal(
    'Portal del Empleo (Servicio Nacional de Empleo)',
    'https://www.empleo.gob.mx/',
  ),
  'AR': CountryPortal(
    'Argentina.gob.ar: Trabajo',
    'https://www.argentina.gob.ar/trabajo',
  ),
  'CL': CountryPortal('Bolsa Nacional de Empleo (BNE)', 'https://www.bne.cl/'),
  'CO': CountryPortal(
    'Servicio Público de Empleo',
    'https://www.serviciodeempleo.gov.co/',
  ),
  'UY': CountryPortal(
    'Uruguay Concursa',
    'https://www.uruguayconcursa.gub.uy/',
  ),
  'CA': CountryPortal(
    'Job Bank (Government of Canada)',
    'https://www.jobbank.gc.ca/findajob',
  ),
  'US': CountryPortal(
    'USAJOBS (US federal government)',
    'https://www.usajobs.gov/',
  ),
  'AU': CountryPortal(
    'Workforce Australia',
    'https://www.workforceaustralia.gov.au/individuals/jobs',
  ),
  'NZ': CountryPortal(
    'Govt.nz Jobs (NZ public sector)',
    'https://www.jobs.govt.nz/',
  ),
  'IE': CountryPortal(
    'JobsIreland (Department of Social Protection)',
    'https://www.jobsireland.ie/',
  ),
  'DE': CountryPortal(
    'Bundesagentur für Arbeit: Jobsuche',
    'https://www.arbeitsagentur.de/jobsuche/',
  ),
  'FR': CountryPortal(
    'France Travail: offres d’emploi',
    'https://candidat.francetravail.fr/offres/recherche',
  ),
  'NO': CountryPortal('NAV: Arbeidsplassen', 'https://arbeidsplassen.nav.no/'),
  'DK': CountryPortal(
    'Jobnet (Danish public employment service)',
    'https://www.jobnet.dk/',
  ),
  'FI': CountryPortal(
    'Työmarkkinatori (Job Market Finland)',
    'https://tyomarkkinatori.fi/',
  ),
  'JP': CountryPortal(
    'Hello Work Internet Service (Ministry of Health, Labour and Welfare)',
    'https://www.hellowork.mhlw.go.jp/',
  ),
  'KR': CountryPortal(
    'Work24 (Ministry of Employment and Labor)',
    'https://www.work24.go.kr/',
  ),
  'SG': CountryPortal(
    'MyCareersFuture (Workforce Singapore)',
    'https://www.mycareersfuture.gov.sg/',
  ),
  'IN': CountryPortal(
    'National Career Service (Ministry of Labour and Employment)',
    'https://www.ncs.gov.in/',
  ),
  'ZA': CountryPortal(
    'ESSA, Employment Services of South Africa (Department of Employment and Labour)',
    'https://essa.labour.gov.za/',
  ),
};

/// The official employment service of [countryCode] (ISO 3166-1 alpha-2), or null when none is listed.
CountryPortal? officialPortalFor(String? countryCode) =>
    countryCode == null ? null : _portals[countryCode.toUpperCase()];

/// Every country that has one (tests and documentation).
Iterable<String> get countriesWithOfficialPortal => _portals.keys;
