import 'package:equatable/equatable.dart';

import '../../search/domain/entities/job_posting.dart';

/// Matches the `applications.stage` check constraint.
enum ApplicationStage {
  /// Saved to follow, nothing sent: a listing the person wants to keep an eye on or apply to later.
  interested,
  applied,
  screening,
  interview,
  offer,
  hired,
  rejected,
  withdrawn,
  closed;

  /// The stages of a process that is still going (the pipeline).
  bool get isActive => switch (this) {
    interested || applied || screening || interview || offer => true,
    _ => false,
  };

  /// Reaching this stage means the person says they applied (or went further): it is the first one with an application date.
  bool get impliesApplied => switch (this) {
    applied || screening || interview || offer || hired => true,
    _ => false,
  };
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
    this.interviewAt,
    this.followUpAt,
  });
  final String id;
  final JobPosting job;
  final ApplicationStage stage;
  final String? channel;
  final DateTime? appliedAt;
  final String? note;
  final String? profileId;

  /// When the interview is (date and time), if the person noted it.
  final DateTime? interviewAt;

  /// When to follow up with the employer, if the person noted it.
  final DateTime? followUpAt;

  ApplicationRecord copyWith({
    ApplicationStage? stage,
    DateTime? appliedAt,
    String? note,
    bool clearNote = false,
    DateTime? interviewAt,
    bool clearInterview = false,
    DateTime? followUpAt,
    bool clearFollowUp = false,
  }) => ApplicationRecord(
    id: id,
    job: job,
    stage: stage ?? this.stage,
    channel: channel,
    appliedAt: appliedAt ?? this.appliedAt,
    note: clearNote ? null : (note ?? this.note),
    profileId: profileId,
    interviewAt: clearInterview ? null : (interviewAt ?? this.interviewAt),
    followUpAt: clearFollowUp ? null : (followUpAt ?? this.followUpAt),
  );

  /// The next date that matters, for sorting and for the agenda: an interview first, otherwise the follow-up.
  DateTime? get nextDate => stage.isActive ? (interviewAt ?? followUpAt) : null;

  @override
  List<Object?> get props => [
    id,
    job,
    stage,
    channel,
    appliedAt,
    note,
    profileId,
    interviewAt,
    followUpAt,
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

  /// Sets or clears the dates the person keeps (a null value clears it); [appliedAt] only ever sets.
  Future<void> updateDates(
    String id, {
    DateTime? appliedAt,
    DateTime? interviewAt,
    bool clearInterview = false,
    DateTime? followUpAt,
    bool clearFollowUp = false,
  });
  Future<void> delete(String id);
  Future<List<ApplicationEvent>> history(String id);
}
