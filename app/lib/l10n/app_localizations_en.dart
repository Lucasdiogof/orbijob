// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'JobRadar';

  @override
  String get searchHint =>
      'Any profession, e.g. electrician, nurse, Flutter developer';

  @override
  String get emptyTitle => 'Search for any profession';

  @override
  String get emptyBody =>
      'No job source is connected yet. Results will only ever show real data from approved sources.';

  @override
  String get loading => 'Searching…';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get retry => 'Try again';

  @override
  String get noSourceTitle => 'No integrated source for this search';

  @override
  String get noSourceBody => 'Try the original portals instead.';
}
