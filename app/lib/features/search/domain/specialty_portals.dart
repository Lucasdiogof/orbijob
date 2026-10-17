import 'health_specialty.dart';

/// Specialised job boards the app only LINKS to. None of them offers an API or feed, and their terms do not allow copying
/// listings into another catalogue (docs/SOURCES_MATRIX.md, "Saúde"), so nothing from them is stored or shown as a job:
/// the person opens the portal itself. Kept apart from the catalogue on purpose, so the origin of every listing stays clear.
class SpecialtyPortal {
  const SpecialtyPortal({
    required this.name,
    required this.url,
    required this.region,
    required this.specialties,
  });

  final String name;
  final String url;

  /// Where the portal's jobs are (free text shown as is: "Brasil", "EUA", "Reino Unido").
  final String region;

  /// Empty = every health specialty.
  final Set<HealthSpecialty> specialties;

  bool covers(HealthSpecialty? s) =>
      specialties.isEmpty ||
      s == null ||
      specialties.contains(s) ||
      (s.parent != null && specialties.contains(s.parent));
}

const specialtyPortals = <SpecialtyPortal>[
  SpecialtyPortal(
    name: 'Indeed Brasil: fisioterapeuta em Goiânia',
    url: 'https://br.indeed.com/jobs?q=fisioterapeuta&l=Goi%C3%A2nia%2C+GO',
    region: 'Goiânia, Brasil',
    specialties: {HealthSpecialty.physiotherapy},
  ),
  SpecialtyPortal(
    name: 'Indeed Brasil: fisioterapia pélvica',
    url: 'https://br.indeed.com/jobs?q=fisioterapia+p%C3%A9lvica',
    region: 'Brasil',
    specialties: {HealthSpecialty.pelvicPhysio},
  ),
  SpecialtyPortal(
    name: 'PCI Concursos: fisioterapeuta',
    url: 'https://www.pciconcursos.com.br/vagas/fisioterapeuta',
    region: 'Brasil (concursos públicos)',
    specialties: {HealthSpecialty.physiotherapy},
  ),
  SpecialtyPortal(
    // the federal university hospitals (the EBSERH network, now "HU Brasil") hire physiotherapists by public competition; its calls have named
    // "Fisioterapia na Saúde da Mulher" as a specialty (2023, 2025). Official page of the calls, no feed: a link only.
    name: 'HU Brasil (EBSERH): concursos e seleções',
    url:
        'https://www.gov.br/hubrasil/pt-br/acesso-a-informacao/agentes-publicos/concursos-e-selecoes',
    region: 'Brasil (hospitais universitários federais)',
    specialties: {HealthSpecialty.physiotherapy},
  ),
  SpecialtyPortal(
    name: 'CREFITO-5: oportunidades',
    url: 'https://www.crefito5.org.br/oportunidade/',
    region: 'Rio Grande do Sul, Brasil',
    specialties: {
      HealthSpecialty.physiotherapy,
      HealthSpecialty.occupationalTherapy,
    },
  ),
  SpecialtyPortal(
    name: 'Herman & Wallace Job Board',
    url: 'https://hermanwallace.com/job-board',
    region: 'EUA',
    specialties: {HealthSpecialty.pelvicPhysio},
  ),
  SpecialtyPortal(
    name: 'APTA Pelvic Health Career Center',
    url: 'https://careers.aptapelvichealth.org/jobs/',
    region: 'EUA',
    specialties: {HealthSpecialty.pelvicPhysio},
  ),
  SpecialtyPortal(
    name: 'Chartered Society of Physiotherapy: jobs',
    url: 'https://www.csp.org.uk/jobs',
    region: 'Reino Unido',
    specialties: {HealthSpecialty.physiotherapy},
  ),
];

/// Portals relevant to [s] (all health portals when null), most specific first.
List<SpecialtyPortal> portalsFor(HealthSpecialty? s) {
  final list = specialtyPortals.where((p) => p.covers(s)).toList();
  if (s == null) return list;
  list.sort(
    (a, b) =>
        (b.specialties.contains(s) ? 1 : 0) -
        (a.specialties.contains(s) ? 1 : 0),
  );
  return list;
}
