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
  String get navHome => 'Inicio';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navApplications => 'Postulaciones';

  @override
  String get navMain => 'Navegación principal';

  @override
  String get profile => 'Perfil';

  @override
  String get back => 'Volver';

  @override
  String get homeTitle => '¿Qué estás buscando?';

  @override
  String get homeSearchHint => 'Cualquier profesión o país';

  @override
  String get homeAreasTitle => 'Explorar por área';

  @override
  String get areaTechnology => 'Tecnología';

  @override
  String get areaHealth => 'Salud';

  @override
  String get areaConstruction => 'Construcción';

  @override
  String get areaEducation => 'Educación';

  @override
  String get areaServices => 'Servicios';

  @override
  String get areaIndustry => 'Industria';

  @override
  String get areaTransport => 'Transporte';

  @override
  String get homeForYouTitle => 'Para ti';

  @override
  String get homeForYouEmptyTitle => 'Aún no hay coincidencias';

  @override
  String get homeForYouEmptyBody =>
      'Las coincidencias aparecerán aquí cuando haya fuentes de empleo conectadas y tu perfil esté completo.';

  @override
  String get homeApplicationsTitle => 'Postulaciones';

  @override
  String get homeApplicationsEmptyTitle => 'Sin postulaciones registradas';

  @override
  String get homeApplicationsEmptyBody =>
      'Sigue dónde te postulaste, entrevistas y ofertas.';

  @override
  String get searchHint =>
      'Cualquier profesión, p. ej. electricista, enfermero, desarrollador Flutter';

  @override
  String get searchLabel => 'Buscar empleos';

  @override
  String get searchClear => 'Borrar búsqueda';

  @override
  String get exploreIdleTitle => 'Busca cualquier profesión';

  @override
  String get exploreIdleBody =>
      'Escribe una profesión o elige un área. Los resultados solo provienen de fuentes aprobadas.';

  @override
  String get searching => 'Buscando…';

  @override
  String get emptyTitle => 'No se encontraron empleos';

  @override
  String get emptyBody => 'Prueba otra profesión o una búsqueda más amplia.';

  @override
  String get noSourceTitle => 'Sin fuente integrada para esta búsqueda';

  @override
  String get noSourceBody =>
      'Aún no tenemos una fuente autorizada para este país y profesión. Prueba los portales de empleo originales.';

  @override
  String get errorTitle => 'Algo salió mal';

  @override
  String get errorBody =>
      'No pudimos cargar los resultados. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get retry => 'Reintentar';

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
  String get profileTitle => 'Perfil';

  @override
  String get profileEmptyTitle => 'Tu perfil profesional llegará pronto';

  @override
  String get profileEmptyBody =>
      'Currículum, experiencia y preferencias estarán aquí.';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get workModeRemote => 'Remoto';

  @override
  String get workModeHybrid => 'Híbrido';

  @override
  String get workModeOnsite => 'Presencial';

  @override
  String get compatibilityLabel => 'Compatibilidad';

  @override
  String compatibilityValue(int score) {
    return 'Compatibilidad $score de 100';
  }

  @override
  String get confidenceLabel => 'Confianza';

  @override
  String get confidenceHigh => 'Confianza alta';

  @override
  String get confidenceMedium => 'Confianza media';

  @override
  String get confidenceLow => 'Confianza baja';

  @override
  String confidenceSemantic(String level) {
    return 'Confianza del análisis: $level';
  }

  @override
  String get scoreExplainer =>
      'Compatibilidad y confianza son medidas separadas.';

  @override
  String sourceLabel(String name) {
    return 'Fuente: $name';
  }

  @override
  String get favoriteAdd => 'Guardar empleo';

  @override
  String get favoriteRemove => 'Quitar de favoritos';

  @override
  String get perHour => '/h';

  @override
  String get perDay => '/día';

  @override
  String get perWeek => '/semana';

  @override
  String get perMonth => '/mes';

  @override
  String get perYear => '/año';

  @override
  String get publishedToday => 'Publicada hoy';

  @override
  String get publishedYesterday => 'Publicada ayer';

  @override
  String publishedDaysAgo(int count) {
    return 'Publicada hace $count días';
  }

  @override
  String publishedWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Publicada hace $count semanas',
      one: 'Publicada hace 1 semana',
    );
    return '$_temp0';
  }

  @override
  String publishedMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Publicada hace $count meses',
      one: 'Publicada hace 1 mes',
    );
    return '$_temp0';
  }

  @override
  String get jobDetailTitle => 'Detalles del empleo';

  @override
  String get openOfficialApplication => 'Abrir postulación oficial';

  @override
  String get selectJobHint => 'Selecciona un empleo para ver los detalles.';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
    );
    return '$_temp0';
  }

  @override
  String get previewBanner =>
      'VISTA PREVIA · DATOS ILUSTRATIVOS, NO SON EMPLEOS REALES';

  @override
  String get previewAction =>
      'Solo vista previa: esta acción no está disponible.';

  @override
  String jobLanguageSemantic(String code) {
    return 'Idioma del empleo: $code';
  }

  @override
  String originalLanguageNote(String code) {
    return 'Mostrado en su idioma original ($code). Los cargos, nombres de empresas y descripciones no se traducen.';
  }

  @override
  String get recentSearchesTitle => 'Búsquedas recientes';

  @override
  String get recentSearchesClear => 'Borrar búsquedas recientes';

  @override
  String get interestCountriesTitle => 'Países de interés';

  @override
  String get interestCountriesEmptyTitle => 'Aún no elegiste países';

  @override
  String get interestCountriesEmptyBody =>
      'Elegirás países en tu perfil para enfocar las recomendaciones.';

  @override
  String get applicationStageApplied => 'Postulado';

  @override
  String get applicationStageScreening => 'Selección';

  @override
  String get applicationStageInterview => 'Entrevista';

  @override
  String get applicationStageOffer => 'Oferta';

  @override
  String get applicationStageRejected => 'Rechazada';

  @override
  String get applicationStageWithdrawn => 'Retirada';

  @override
  String get applicationStageClosed => 'Cerrada';

  @override
  String get accountTitle => 'Cuenta';

  @override
  String get accountUnavailableTitle =>
      'Las cuentas no están activadas en esta versión';

  @override
  String get accountUnavailableBody =>
      'Todo funciona en este dispositivo sin iniciar sesión. La sincronización llegará cuando se conecte el servicio.';

  @override
  String accountSignedInAs(String email) {
    return 'Sesión iniciada como $email';
  }

  @override
  String get accountSignedInNoEmail => 'Sesión iniciada';

  @override
  String get accountSignedOutBody =>
      'Inicia sesión para guardar perfil, favoritos y postulaciones en tu cuenta.';

  @override
  String get accountSignIn => 'Iniciar sesión';

  @override
  String get accountSignOut => 'Cerrar sesión';

  @override
  String get authSignInTitle => 'Iniciar sesión';

  @override
  String get authSignUpTitle => 'Crear cuenta';

  @override
  String get authEmail => 'Correo electrónico';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authSignInAction => 'Iniciar sesión';

  @override
  String get authSignUpAction => 'Crear cuenta';

  @override
  String get authSwitchToSignUp => '¿Aún no tienes cuenta? Crea una';

  @override
  String get authSwitchToSignIn => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authForgotPassword => 'Olvidé mi contraseña';

  @override
  String get authEmailInvalid => 'Introduce un correo válido';

  @override
  String get authPasswordShort => 'Usa al menos 8 caracteres';

  @override
  String get authConfirmationSent =>
      'Revisa tu correo para confirmar la cuenta y luego inicia sesión.';

  @override
  String get authResetSent =>
      'Si la dirección tiene cuenta, se envió un enlace de restablecimiento.';

  @override
  String get authErrorInvalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirma primero tu correo. Revisa tu bandeja.';

  @override
  String get authErrorEmailTaken =>
      'Este correo ya está registrado. Intenta iniciar sesión.';

  @override
  String get authErrorInvalidEmail => 'Esta dirección de correo no es válida.';

  @override
  String get authErrorWeakPassword =>
      'Contraseña demasiado débil. Usa una más larga y poco común.';

  @override
  String get authErrorRateLimited =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';

  @override
  String get authErrorNetwork =>
      'Sin conexión. Revisa internet e inténtalo de nuevo.';

  @override
  String get authErrorUnavailable => 'El servicio no está disponible ahora.';

  @override
  String get authErrorUnknown => 'Algo salió mal. Inténtalo de nuevo.';
}
