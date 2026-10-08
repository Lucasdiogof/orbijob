// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OrbiJob';

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

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navApplications => 'Applications';

  @override
  String get profile => 'Profile';

  @override
  String get homeTitle => 'Welcome to OrbiJob';

  @override
  String get homeBody =>
      'Your matches and recent activity will appear here once job sources are connected.';

  @override
  String get favoritesTitle => 'No favorites yet';

  @override
  String get favoritesBody => 'Saved jobs will appear here.';

  @override
  String get applicationsTitle => 'No applications tracked';

  @override
  String get applicationsBody =>
      'Track where you applied, interviews and offers. Status is updated manually.';

  @override
  String get profileSoon => 'Profile, résumé and experiences are coming soon.';
}
