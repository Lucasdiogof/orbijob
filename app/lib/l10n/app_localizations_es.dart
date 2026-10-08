// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'OrbiJob';

  @override
  String get searchHint =>
      'Cualquier profesión, p. ej. electricista, enfermero, desarrollador Flutter';

  @override
  String get emptyTitle => 'Busca cualquier profesión';

  @override
  String get emptyBody =>
      'Aún no hay ninguna fuente de empleos conectada. Los resultados solo mostrarán datos reales de fuentes aprobadas.';

  @override
  String get loading => 'Buscando…';

  @override
  String get errorTitle => 'Algo salió mal';

  @override
  String get retry => 'Reintentar';

  @override
  String get noSourceTitle => 'Sin fuente integrada para esta búsqueda';

  @override
  String get noSourceBody => 'Prueba los portales originales.';

  @override
  String get navHome => 'Inicio';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navApplications => 'Postulaciones';

  @override
  String get profile => 'Perfil';

  @override
  String get homeTitle => 'Bienvenido a OrbiJob';

  @override
  String get homeBody =>
      'Tus coincidencias y actividad reciente aparecerán aquí cuando haya fuentes de empleo conectadas.';

  @override
  String get favoritesTitle => 'Aún no hay favoritos';

  @override
  String get favoritesBody => 'Los empleos guardados aparecerán aquí.';

  @override
  String get applicationsTitle => 'Sin postulaciones registradas';

  @override
  String get applicationsBody =>
      'Sigue dónde te postulaste, entrevistas y ofertas. El estado se actualiza manualmente.';

  @override
  String get profileSoon =>
      'Perfil, currículum y experiencias llegarán pronto.';
}
