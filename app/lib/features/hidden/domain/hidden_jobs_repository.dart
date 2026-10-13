import 'package:equatable/equatable.dart';

import '../../search/domain/entities/job_posting.dart';

/// A job the person chose not to see again. Only what is needed to recognise it and to restore it is kept (title, company, link), so the list
/// stays readable after the job leaves the catalogue. Identity is `<source>:<externalId>`, like favourites.
class HiddenJob extends Equatable {
  const HiddenJob({
    required this.key,
    required this.source,
    required this.externalId,
    required this.title,
    required this.hiddenAt,
    this.company,
    this.originalUrl,
  });

  final String key;
  final String source;
  final String externalId;
  final String title;
  final String? company;
  final String? originalUrl;
  final DateTime hiddenAt;

  factory HiddenJob.of(JobPosting j, DateTime at) => HiddenJob(
    key: hiddenKey(j),
    source: j.source,
    externalId: j.externalId,
    title: j.title.length > 300 ? j.title.substring(0, 300) : j.title,
    company: j.company.isEmpty
        ? null
        : (j.company.length > 200 ? j.company.substring(0, 200) : j.company),
    originalUrl: j.originalUrl.isEmpty ? null : j.originalUrl,
    hiddenAt: at,
  );

  @override
  List<Object?> get props => [key, title, company, originalUrl, hiddenAt];
}

String hiddenKey(JobPosting j) => '${j.source}:${j.externalId}';

/// Hidden jobs of the account (row level security: the owner only). Hiding is idempotent; restoring a job that is not hidden is not an error.
abstract class HiddenJobsRepository {
  Future<List<HiddenJob>> list();
  Future<void> hide(JobPosting job);
  Future<void> restore(String key);
}
