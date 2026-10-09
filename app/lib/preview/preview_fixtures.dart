import '../features/search/domain/entities/job_posting.dart';
import '../features/search/domain/search_repository.dart';

/// ILLUSTRATIVE fixtures: fictional jobs, companies, salaries and scores used ONLY by the preview entrypoint
/// (lib/main_preview.dart) and by tests. The default app never imports this file.
/// Fixed clock for tests; the preview app passes the real date instead.
final DateTime previewNow = DateTime(2026, 10, 12);

final List<ScoredJob> previewJobs = previewJobsAt(previewNow);

/// Illustrative jobs whose publication dates are relative to [now] (3 days ago, yesterday, ...).
List<ScoredJob> previewJobsAt(DateTime now) => [
  ScoredJob(
    JobPosting(
      source: 'preview',
      externalId: 'dev',
      company: 'Empresa Exemplo Tech',
      title: 'Desenvolvedor Flutter',
      originalUrl: 'https://example.invalid/jobs/dev',
      applyUrl: 'https://example.invalid/apply/dev',
      country: 'BR',
      city: 'Remoto',
      workMode: WorkMode.remote,
      contractType: 'CLT',
      salaryMin: 9000,
      salaryMax: 12000,
      salaryCurrency: 'BRL',
      salaryPeriod: SalaryPeriod.month,
      publishedAt: now.subtract(const Duration(days: 3)),
      sourceName: 'Fonte de exemplo',
    ),
    match: const JobMatch(score: 88, confidence: ConfidenceLevel.high),
  ),
  ScoredJob(
    JobPosting(
      source: 'preview',
      externalId: 'physio',
      company: 'Clínica Exemplo',
      title: 'Fisioterapeuta pélvica',
      originalUrl: 'https://example.invalid/jobs/physio',
      country: 'DE',
      city: 'Berlim',
      workMode: WorkMode.onsite,
      contractType: 'Tempo integral',
      salaryMin: 3400,
      salaryMax: 4100,
      salaryCurrency: 'EUR',
      salaryPeriod: SalaryPeriod.month,
      publishedAt: now.subtract(const Duration(days: 1)),
      sourceName: 'Fonte de exemplo',
    ),
    match: const JobMatch(score: 81, confidence: ConfidenceLevel.medium),
  ),
  ScoredJob(
    JobPosting(
      source: 'preview',
      externalId: 'painter',
      company: 'Serviços Exemplo',
      title: 'Pintor residencial',
      originalUrl: 'https://example.invalid/jobs/painter',
      country: 'AU',
      city: 'Sydney',
      workMode: WorkMode.onsite,
      contractType: 'Autônomo',
      salaryMin: 32,
      salaryMax: 40,
      salaryCurrency: 'AUD',
      salaryPeriod: SalaryPeriod.hour,
      publishedAt: now.subtract(const Duration(days: 9)),
      sourceName: 'Fonte de exemplo',
    ),
    match: const JobMatch(score: 77, confidence: ConfidenceLevel.medium),
  ),
  ScoredJob(
    JobPosting(
      source: 'preview',
      externalId: 'mason',
      company: 'Construtora Exemplo',
      title: 'Pedreiro',
      originalUrl: 'https://example.invalid/jobs/mason',
      country: 'PT',
      city: 'Porto',
      workMode: WorkMode.onsite,
      salaryMin: 1300,
      salaryMax: 1700,
      salaryCurrency: 'EUR',
      salaryPeriod: SalaryPeriod.month,
      sourceName: 'Fonte de exemplo',
    ),
    match: const JobMatch(score: 74, confidence: ConfidenceLevel.medium),
  ),
  ScoredJob(
    JobPosting(
      source: 'preview',
      externalId: 'nurse',
      company: 'Hospital Exemplo',
      title: 'Enfermeiro',
      originalUrl: 'https://example.invalid/jobs/nurse',
      country: 'CA',
      city: 'Toronto',
      workMode: WorkMode.hybrid,
      salaryMin: 38,
      salaryMax: 46,
      salaryCurrency: 'CAD',
      salaryPeriod: SalaryPeriod.hour,
      publishedAt: now.subtract(const Duration(days: 40)),
      sourceName: 'Fonte de exemplo',
    ),
    match: const JobMatch(score: 69, confidence: ConfidenceLevel.low),
  ),
];

/// Answers every query with the illustrative jobs whose text matches it (an empty query never reaches here).
class PreviewSearchRepository implements SearchRepository {
  PreviewSearchRepository({this.delay = Duration.zero, DateTime? now})
    : _jobs = previewJobsAt(now ?? previewNow);
  final Duration delay;
  final List<ScoredJob> _jobs;

  static const Map<String, String> _areas = {
    'tecnologia': 'dev',
    'technology': 'dev',
    'tecnología': 'dev',
    'saúde': 'physio,nurse',
    'health': 'physio,nurse',
    'salud': 'physio,nurse',
    'construção': 'painter,mason',
    'construction': 'painter,mason',
    'construcción': 'painter,mason',
  };

  @override
  Future<SearchResult> search(String query, {String? countryCode}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final q = query.toLowerCase();
    final ids = (_areas[q] ?? '').split(',');
    final hits = _jobs.where((s) {
      final j = s.job;
      return ids.contains(j.externalId) ||
          '${j.title} ${j.company} ${j.city}'.toLowerCase().contains(q);
    }).toList();
    return SearchResult(jobs: hits, hasIntegratedSource: true);
  }
}
