import 'package:equatable/equatable.dart';

import '../../search/domain/entities/job_posting.dart';

/// Matches the `applications.stage` check constraint.
enum ApplicationStage {
  applied,
  screening,
  interview,
  offer,
  rejected,
  withdrawn,
  closed,
}

class ApplicationRecord extends Equatable {
  const ApplicationRecord({
    required this.id,
    required this.job,
    required this.stage,
    this.channel,
    this.appliedAt,
    this.note,
    this.profileId,
  });
  final String id;
  final JobPosting job;
  final ApplicationStage stage;
  final String? channel;
  final DateTime? appliedAt;
  final String? note;
  final String? profileId;
  @override
  List<Object?> get props => [
    id,
    job,
    stage,
    channel,
    appliedAt,
    note,
    profileId,
  ];
}

/// One row of the stage history (written by a database trigger, never by the app).
class ApplicationEvent extends Equatable {
  const ApplicationEvent({
    required this.stage,
    required this.occurredAt,
    this.note,
  });
  final ApplicationStage stage;
  final DateTime occurredAt;
  final String? note;
  @override
  List<Object?> get props => [stage, occurredAt, note];
}

abstract class ApplicationsRepository {
  Future<List<ApplicationRecord>> list();
  Future<ApplicationRecord> create(
    JobPosting job, {
    ApplicationStage stage = ApplicationStage.applied,
    String? channel,
    DateTime? appliedAt,
    String? note,
    String? profileId,
  });
  Future<void> changeStage(String id, ApplicationStage stage);
  Future<void> updateNote(String id, String? note);
  Future<void> delete(String id);
  Future<List<ApplicationEvent>> history(String id);
}
