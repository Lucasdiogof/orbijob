import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// "5 minutes ago", "3 hours ago", "yesterday", "4 days ago"; past two weeks, the date itself. [at] and [now] are compared in UTC so a change of
/// time zone never makes a notification look like it is from the future.
String agoLabel(DateTime at, DateTime now, AppLocalizations l) {
  final d = now.toUtc().difference(at.toUtc());
  if (d.isNegative || d.inMinutes < 1) return l.agoJustNow;
  if (d.inMinutes < 60) return l.agoMinutes(d.inMinutes);
  if (d.inHours < 24) return l.agoHours(d.inHours);
  final days = DateTime(now.year, now.month, now.day)
      .difference(
        DateTime(at.toLocal().year, at.toLocal().month, at.toLocal().day),
      )
      .inDays;
  if (days <= 1) return l.agoYesterday;
  if (days < 14) return l.agoDays(days);
  return DateFormat.yMMMd(l.localeName).format(at.toLocal());
}
