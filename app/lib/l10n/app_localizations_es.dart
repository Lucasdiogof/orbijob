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
      'Añade países en tu perfil para enfocarte en ellos.';

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
      'Inicia sesión para guardar tu perfil, favoritos y candidaturas en tu cuenta.';

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

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonOptional => 'Opcional';

  @override
  String get commonRequired => 'Campo obligatorio';

  @override
  String get commonDeleteConfirmBody => 'Esta acción no se puede deshacer.';

  @override
  String get fieldStartDate => 'Fecha de inicio';

  @override
  String get fieldEndDate => 'Fecha de finalización';

  @override
  String get dateChoose => 'Elegir fecha';

  @override
  String get dateClear => 'Borrar fecha';

  @override
  String tooLongError(int max) {
    return 'Demasiado largo (máximo $max caracteres)';
  }

  @override
  String get dataLoadErrorTitle => 'No se pudieron cargar tus datos';

  @override
  String get dataSignInTitle => 'Inicia sesión para continuar';

  @override
  String get dataFailureNotConfigured =>
      'Esta versión de la app no está conectada a un servicio de cuentas, así que aquí no se puede guardar nada.';

  @override
  String get dataFailureSignedOut =>
      'Tus datos se guardan en tu cuenta. Inicia sesión para verlos y cambiarlos.';

  @override
  String get dataFailureSessionExpired =>
      'Tu sesión terminó. Inicia sesión de nuevo para continuar.';

  @override
  String get dataFailureNetwork =>
      'Sin conexión. Revisa tu internet e inténtalo de nuevo.';

  @override
  String get dataFailureDenied =>
      'El servidor no permitió esta acción para tu cuenta.';

  @override
  String get dataFailureQuota =>
      'Alcanzaste el límite para este tipo de elemento. Elimina uno para añadir otro.';

  @override
  String get dataFailureDuplicate => 'Esto ya existe.';

  @override
  String get dataFailureInvalid =>
      'Algún dato no es válido. Revisa los campos e inténtalo de nuevo.';

  @override
  String get dataFailureTooLarge => 'El archivo supera los 5 MB.';

  @override
  String get dataFailureNotPdf => 'Solo se aceptan archivos PDF.';

  @override
  String get dataFailureEmptyFile => 'El archivo está vacío.';

  @override
  String get dataFailureNotFound =>
      'Este elemento ya no existe. Actualiza e inténtalo de nuevo.';

  @override
  String get dataFailureUnavailable =>
      'El servicio no está disponible ahora. Inténtalo más tarde.';

  @override
  String get dataFailureUnknown => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get applicationsAdd => 'Añadir candidatura';

  @override
  String get applicationsDisclaimer =>
      'OrbiJob nunca envía candidaturas. Aquí registras las que enviaste por tu cuenta.';

  @override
  String get applicationNewTitle => 'Nueva candidatura';

  @override
  String get applicationDetailTitle => 'Candidatura';

  @override
  String get applicationCompany => 'Empresa';

  @override
  String get applicationJobTitle => 'Puesto de la vacante';

  @override
  String get applicationLink => 'Enlace de la vacante';

  @override
  String get applicationLinkInvalid =>
      'Introduce un enlace que empiece por https://';

  @override
  String get applicationChannel => 'Dónde te postulaste';

  @override
  String get applicationStageLabel => 'Etapa';

  @override
  String get applicationAppliedOn => 'Postulación el';

  @override
  String get applicationNote => 'Notas';

  @override
  String get applicationSaveNote => 'Guardar notas';

  @override
  String get applicationOpenLink => 'Abrir vacante';

  @override
  String get applicationLinkCannotOpen => 'No se pudo abrir el enlace.';

  @override
  String get applicationHistory => 'Historial';

  @override
  String get applicationHistoryEmpty =>
      'Aún no hay cambios de etapa registrados.';

  @override
  String get applicationDeleteTitle => '¿Eliminar esta candidatura?';

  @override
  String get applicationNoDate => 'Fecha no indicada';

  @override
  String homeApplicationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count candidaturas en seguimiento',
      one: '1 candidatura en seguimiento',
    );
    return '$_temp0';
  }

  @override
  String get profileSectionProfessional => 'Perfil profesional';

  @override
  String get profileCreateTitle => 'Crea tu perfil profesional';

  @override
  String get profileCreateBody =>
      'Cuenta quién eres profesionalmente. Cualquier profesión es bienvenida.';

  @override
  String get profileCreateAction => 'Crear perfil';

  @override
  String get profileEditAction => 'Editar perfil';

  @override
  String get profileFieldName => 'Nombre profesional';

  @override
  String get profileFieldHeadline => 'Cargo o profesión';

  @override
  String get profileFieldSummary => 'Resumen';

  @override
  String get profileFieldCountry => 'País de residencia (código de 2 letras)';

  @override
  String get profileFieldCity => 'Ciudad';

  @override
  String get profileFieldWorkMode => 'Modalidad de trabajo deseada';

  @override
  String get profileWorkModeAny => 'Sin preferencia';

  @override
  String get profileFieldSkills => 'Competencias';

  @override
  String get profileSkillAdd => 'Añadir competencia';

  @override
  String profileSkillRemove(String name) {
    return 'Quitar competencia $name';
  }

  @override
  String get profileSkillsLimit => 'Hasta 200 competencias.';

  @override
  String get profileCountryInvalid =>
      'Usa un código de 2 letras, por ejemplo BR';

  @override
  String get profileSaved => 'Perfil guardado';

  @override
  String get profileNeedsProfile => 'Crea tu perfil primero para añadir esto.';

  @override
  String get profileSignInBody =>
      'Inicia sesión para crear y mantener tu perfil profesional.';

  @override
  String get experienceSection => 'Experiencia profesional';

  @override
  String get experienceAdd => 'Añadir experiencia';

  @override
  String get experienceNewTitle => 'Nueva experiencia';

  @override
  String get experienceEditTitle => 'Editar experiencia';

  @override
  String get experienceCompany => 'Empresa';

  @override
  String get experienceRole => 'Cargo';

  @override
  String get experienceCurrent => 'Trabajo aquí actualmente';

  @override
  String get experienceDescription => 'Descripción';

  @override
  String get experiencePresent => 'Actual';

  @override
  String get experienceEmpty => 'Aún no has añadido experiencia.';

  @override
  String get experienceDatesInvalid =>
      'La fecha de finalización no puede ser anterior a la de inicio';

  @override
  String get experienceCurrentNeedsStart =>
      'Elige la fecha de inicio para un trabajo actual';

  @override
  String get experienceDeleteTitle => '¿Eliminar esta experiencia?';

  @override
  String get educationSection => 'Formación académica';

  @override
  String get educationAdd => 'Añadir formación';

  @override
  String get educationNewTitle => 'Nueva formación';

  @override
  String get educationEditTitle => 'Editar formación';

  @override
  String get educationInstitution => 'Institución';

  @override
  String get educationDegree => 'Grado (si lo hay)';

  @override
  String get educationField => 'Curso o área de estudio';

  @override
  String get educationEmpty => 'Aún no has añadido formación. Es opcional.';

  @override
  String get educationDeleteTitle => '¿Eliminar esta formación?';

  @override
  String get resumesSection => 'Currículos';

  @override
  String get resumesBody =>
      'Solo PDF, hasta 5 MB cada uno, hasta 10 archivos. Se guardan de forma privada en tu cuenta.';

  @override
  String get resumesUpload => 'Subir PDF';

  @override
  String get resumesUploading => 'Subiendo…';

  @override
  String get resumesEmpty => 'Aún no has subido ningún currículo.';

  @override
  String resumeItem(String date) {
    return 'Currículo del $date';
  }

  @override
  String get resumeOpen => 'Abrir';

  @override
  String get resumeUploaded => 'Currículo subido';

  @override
  String get resumeDeleteTitle => '¿Eliminar este currículo?';

  @override
  String get resumeDeleteBody => 'El archivo se elimina de tu cuenta.';

  @override
  String get preferencesSection => 'Preferencias de búsqueda';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSystem => 'Idioma del dispositivo';

  @override
  String get languagePt => 'Português';

  @override
  String get languageEn => 'English';

  @override
  String get languageEs => 'Español';

  @override
  String get preferencesLocalOnly =>
      'Inicia sesión para guardar estas opciones en tu cuenta. Hasta entonces solo valen en este dispositivo.';

  @override
  String get countriesTitle => 'Países de interés';

  @override
  String get countriesHint => 'Añadir país (código de 2 letras)';

  @override
  String get countriesEmpty => 'Ningún país elegido.';

  @override
  String get countriesInvalid =>
      'Usa un código de 2 letras que aún no esté en la lista, por ejemplo DE';

  @override
  String countriesRemove(String code) {
    return 'Quitar país $code';
  }

  @override
  String get savedSearchesTitle => 'Búsquedas guardadas';

  @override
  String get savedSearchesNote => 'Guardadas en tu cuenta.';

  @override
  String get recentSearchesNote =>
      'Las búsquedas recientes se quedan en este dispositivo.';

  @override
  String get savedSearchSave => 'Guardar esta búsqueda';

  @override
  String get savedSearchSaved => 'Búsqueda guardada';

  @override
  String savedSearchRemove(String term) {
    return 'Quitar búsqueda guardada $term';
  }

  @override
  String get authNewPasswordTitle => 'Elige una nueva contraseña';

  @override
  String get authNewPasswordLabel => 'Nueva contraseña';

  @override
  String get authNewPasswordAction => 'Guardar nueva contraseña';

  @override
  String get authPasswordChanged => 'Contraseña actualizada.';

  @override
  String get authSessionExpired => 'Tu sesión terminó. Inicia sesión de nuevo.';

  @override
  String get authErrorLinkInvalid =>
      'Este enlace caducó o ya se usó. Solicita uno nuevo.';

  @override
  String get authErrorSamePassword =>
      'Elige una contraseña distinta de la actual.';

  @override
  String get authCancelRecovery => 'Cancelar';

  @override
  String get commonLoading => 'Cargando';
}
