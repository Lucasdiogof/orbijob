import 'package:equatable/equatable.dart';

import 'application_record.dart';

enum AgendaKind { interview, followUp }

/// One date the person noted on a process that is still going: an interview or a follow-up with the employer.
class AgendaItem extends Equatable {
  const AgendaItem(
    this.application,
    this.kind,
    this.at, {
    required this.overdue,
  });
  final ApplicationRecord application;
  final AgendaKind kind;
  final DateTime at;

  /// The date has passed and the process is still open: a reminder to act or to update the stage.
  final bool overdue;

  @override
  List<Object?> get props => [application.id, kind, at, overdue];
}

/// What is coming up (the next [days] days) and what slipped past, oldest first within each group: overdue first, then by date.
/// Only processes still going count: once a process is hired, rejected, withdrawn or closed its dates are history.
/// A date is an interview or a follow-up exactly as the person wrote it; nothing is inferred from the stage.
List<AgendaItem> buildAgenda(
  Iterable<ApplicationRecord> applications,
  DateTime now, {
  int days = 14,
  int overdueDays = 30,
}) {
  final from = now.subtract(Duration(days: overdueDays));
  final to = now.add(Duration(days: days));
  final out = <AgendaItem>[];
  for (final a in applications) {
    if (!a.stage.isActive) continue;
    void add(AgendaKind k, DateTime? at) {
      if (at == null) return;
      // a follow-up is a day, not an hour: it is overdue only after that day is over
      final end = k == AgendaKind.followUp
          ? DateTime(at.year, at.month, at.day).add(const Duration(days: 1))
          : at;
      final overdue = end.isBefore(now);
      if (at.isBefore(from) || at.isAfter(to)) return;
      out.add(AgendaItem(a, k, at, overdue: overdue));
    }

    add(AgendaKind.interview, a.interviewAt?.toLocal());
    add(AgendaKind.followUp, a.followUpAt?.toLocal());
  }
  out.sort((x, y) {
    if (x.overdue != y.overdue) return x.overdue ? -1 : 1;
    final c = x.at.compareTo(y.at);
    return c != 0 ? c : x.application.id.compareTo(y.application.id);
  });
  return out;
}
