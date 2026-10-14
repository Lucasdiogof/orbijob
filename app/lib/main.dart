import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/supabase_bootstrap.dart';
import 'core/design/design.dart';
import 'core/di/injector.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/push/data/firebase_push_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  registerEscoAttribution();
  registerJobSourceAttributions();
  // Public configuration only (--dart-define). Without it the app runs fully offline-first, without accounts.
  final config = AppConfig.fromEnvironment();
  final client = await initSupabase(config);
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    prefs = null; // storage unavailable: settings and the translation cache simply do not persist
  }
  configureDependencies(
    preferences: prefs,
    pushMessaging: client == null ? null : FirebasePushMessaging(),
    authRepository: client == null
        ? null
        : SupabaseAuthRepository(client, redirectTo: config.redirectTo),
  );
  if (client != null) registerSupabaseRepositories(client);
  runApp(const OrbiJobApp());
}

/// Exposes the bundled OFL font licences in Flutter's licence page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, path) in AppAssets.fontLicenses) {
      yield LicenseEntryWithLineBreaks(<String>[
        name,
      ], await rootBundle.loadString(path));
    }
  });
}

/// Open-data job sources whose licence asks for attribution (and, for CC BY-SA, says the records stay under that licence).
void registerJobSourceAttributions() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['Job listings (open data)'],
      '''
Teaching Vacancies, Department for Education (England): Open Government Licence v3.0, https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/ (https://teaching-vacancies.service.gov.uk).
NYC Jobs: NYC Open Data, "Jobs NYC Postings", Department of Citywide Administrative Services, City of New York (https://data.cityofnewyork.us/d/kpav-sd4t).
Karriere.NRW, employer portal of North Rhine-Westphalia (https://karriere.nrw), Open.NRW: Datenlizenz Deutschland - Namensnennung - Version 2.0, https://www.govdata.de/dl-de/by-2-0.
Groupe BPCE open data (https://recrutement.bpce.fr): Licence Ouverte v2.0 (Etalab), https://www.etalab.gouv.fr/licence-ouverte-open-licence/.
Le Forem (https://www.leforem.be), Open Data Wallonie-Bruxelles: CC BY-SA 4.0, https://creativecommons.org/licenses/by-sa/4.0/. The records taken from this source are shared under the same licence.
Taiwan Jobs: Open Government Data License v1.0 (https://data.gov.tw/en/datasets/44062). Platsbanken / Arbetsformedlingen: CC0.
Listings are shown as published by their sources, with a link to the original; OrbiJob may have shortened or reformatted the text.''',
    );
  });
}

/// ESCO (CC BY 4.0) names the professions OrbiJob searches under their other names; the attribution is part of the licence page.
void registerEscoAttribution() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['ESCO'],
      '''
OrbiJob uses profession names from ESCO (European Skills, Competences, Qualifications and Occupations), taken from the public ESCO web service on 2026-10-13, to search a profession under its names in other languages.
© European Union, https://esco.ec.europa.eu, licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
The names were filtered and grouped by OrbiJob; the European Commission does not endorse OrbiJob.''',
    );
  });
}
