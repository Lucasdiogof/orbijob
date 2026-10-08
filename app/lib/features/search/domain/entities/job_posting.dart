import 'package:equatable/equatable.dart';

enum WorkMode { remote, hybrid, onsite, unspecified }

/// Mirrors worker/src/types.ts NormalizedJob (subset for Phase 0).
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
  });

  final String source;
  final String externalId;
  final String company;
  final String title;
  final String originalUrl;
  final String? applyUrl;
  final String? country;
  final String? city;
  final WorkMode workMode;

  @override
  List<Object?> get props => [source, externalId];
}
