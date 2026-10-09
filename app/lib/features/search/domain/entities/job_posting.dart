import 'package:equatable/equatable.dart';

enum WorkMode { remote, hybrid, onsite, unspecified }

enum SalaryPeriod { hour, day, week, month, year }

/// Mirrors worker/src/types.ts NormalizedJob (subset). Every optional field stays null when the
/// source does not provide it: the UI shows nothing instead of inventing a value.
class JobPosting extends Equatable {
  const JobPosting({
    required this.source,
    required this.externalId,
    required this.company,
    required this.title,
    required this.originalUrl,
    this.applyUrl,
    this.country,
    this.city,
    this.workMode = WorkMode.unspecified,
    this.contractType,
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency,
    this.salaryPeriod,
    this.publishedAt,
    this.sourceName,
    this.language,
  });

  final String source;
  final String externalId;
  final String company;
  final String title;
  final String originalUrl;
  final String? applyUrl;
  final String? country; // ISO 3166-1 alpha-2
  final String? city;
  final WorkMode workMode;
  final String? contractType;
  final double? salaryMin;
  final double? salaryMax;
  final String? salaryCurrency; // ISO 4217
  final SalaryPeriod? salaryPeriod;
  final DateTime? publishedAt;

  /// Human-readable origin shown on the card (attribution).
  final String? sourceName;

  /// Language of the posting text (BCP-47 primary subtag, e.g. `de`). Job text is never translated silently:
  /// the UI shows it as written and flags it when it differs from the interface language.
  final String? language;

  @override
  List<Object?> get props => [source, externalId];
}

enum ConfidenceLevel { high, medium, low }

/// Compatibility (0-100) and the confidence of that analysis are independent measures.
class JobMatch extends Equatable {
  const JobMatch({required this.score, required this.confidence})
    : assert(score >= 0 && score <= 100);

  final int score;
  final ConfidenceLevel confidence;

  @override
  List<Object?> get props => [score, confidence];
}

/// A posting plus, when a profile and a ranking exist, its match. `match == null` means "not evaluated".
class ScoredJob extends Equatable {
  const ScoredJob(this.job, {this.match});

  final JobPosting job;
  final JobMatch? match;

  @override
  List<Object?> get props => [job, match];
}
