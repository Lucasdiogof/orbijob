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

  @override
  String get filtersButton => 'Filtros';

  @override
  String filtersButtonCount(int count) {
    return 'Filtros ($count)';
  }

  @override
  String get filtersClear => 'Limpiar filtros';

  @override
  String get filterWorkMode => 'Modalidad';

  @override
  String get filterPublished => 'Publicada';

  @override
  String get filterPublished1 => 'Últimas 24 horas';

  @override
  String get filterPublished7 => 'Últimos 7 días';

  @override
  String get filterPublished30 => 'Últimos 30 días';

  @override
  String get filterWithSalary => 'Solo con salario';

  @override
  String get filterCountry => 'País (de tu perfil)';

  @override
  String get filterContinent => 'Región';

  @override
  String get homeRegionsTitle => 'Explorar por región';

  @override
  String get continentEurope => 'Europa';

  @override
  String get continentOceania => 'Oceanía';

  @override
  String get continentAsia => 'Asia';

  @override
  String get continentAfrica => 'África';

  @override
  String get continentNorthAmerica => 'América del Norte';

  @override
  String get continentSouthAmerica => 'América del Sur';

  @override
  String get browseLatest => 'Ver empleos recientes';

  @override
  String get loadMore => 'Mostrar más';

  @override
  String get loadMoreFailed => 'No se pudieron cargar más empleos.';

  @override
  String resultsShown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrando $count empleos',
      one: 'Mostrando 1 empleo',
    );
    return '$_temp0';
  }

  @override
  String get emptyFiltersBody =>
      'Ningún empleo con estos filtros. Prueba a quitar alguno.';

  @override
  String get openOriginalListing => 'Abrir anuncio original';

  @override
  String eligibleIn(String places) {
    return 'Abierta a candidatos en: $places';
  }

  @override
  String get jobDescriptionTitle => 'Descripción';

  @override
  String get locationAnywhere => 'Cualquier lugar';

  @override
  String get eligibleAnywhere =>
      'Abierta a candidatos de cualquier lugar, según la fuente';

  @override
  String get eligibilityUnknown =>
      'Elegibilidad geográfica no indicada por la fuente';

  @override
  String get eligibilityCheckOriginal =>
      'Verifica la elegibilidad en el anuncio original antes de postularte.';

  @override
  String salaryFrom(String amount) {
    return 'Desde $amount';
  }

  @override
  String salaryUpTo(String amount) {
    return 'Hasta $amount';
  }

  @override
  String get areaData => 'Datos e IA';

  @override
  String get areaDesign => 'Diseño';

  @override
  String get areaProduct => 'Producto y proyectos';

  @override
  String get areaSales => 'Ventas';

  @override
  String get areaMarketing => 'Marketing y contenido';

  @override
  String get areaSupport => 'Atención y soporte';

  @override
  String get areaFinance => 'Finanzas y legal';

  @override
  String get areaPeople => 'Personas y operaciones';

  @override
  String get areaHospitality => 'Hostelería y turismo';

  @override
  String get areaPublic => 'Sector público y ONG';

  @override
  String get areaAll => 'Todas las áreas';

  @override
  String get notConfiguredTitle => 'Esta versión no está conectada a OrbiJob';

  @override
  String get notConfiguredBody =>
      'La app se inició sin la configuración del servidor (SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY). Desarrolladores: ejecútela con --dart-define-from-file.';

  @override
  String get homeLatestTitle => 'Empleos recientes';

  @override
  String get homeLatestSeeAll => 'Ver todos';

  @override
  String get homeLatestEmpty =>
      'No hay empleos para mostrar ahora. Inténtelo más tarde.';

  @override
  String get specPhysiotherapy => 'Fisioterapia';

  @override
  String get specPelvicPhysio => 'Fisioterapia pélvica';

  @override
  String get specNursing => 'Enfermería';

  @override
  String get specMedicine => 'Medicina';

  @override
  String get specPsychology => 'Psicología';

  @override
  String get specOccupationalTherapy => 'Terapia ocupacional';

  @override
  String get specNutrition => 'Nutrición';

  @override
  String get specDentistry => 'Odontología';

  @override
  String get specPharmacy => 'Farmacia';

  @override
  String get specSpeechTherapy => 'Fonoaudiología';

  @override
  String get specRadiology => 'Radiología';

  @override
  String get specHospitalManagement => 'Gestión hospitalaria';

  @override
  String get specAll => 'Toda la salud';

  @override
  String get portalsButton => 'Portales especializados';

  @override
  String get portalsTitle => 'Busca en portales especializados';

  @override
  String get portalsNote =>
      'Enlaces externos. Estos portales no permiten copiar sus vacantes, por eso no forman parte del catálogo de OrbiJob: el enlace abre el propio portal.';

  @override
  String get specialtyEmpty =>
      'Ninguna vacante abierta de esta especialidad en el catálogo ahora. Mira los portales especializados abajo.';

  @override
  String get gateCreateAccount => 'Crear cuenta';

  @override
  String get gateKeepExploring => 'Seguir explorando empleos';

  @override
  String get gateFavoritesTitle =>
      'Tus mejores oportunidades, en un solo lugar.';

  @override
  String get gateFavoritesBody =>
      'Guarda los empleos que te interesan y vuelve a ellos cuando quieras.';

  @override
  String get gateFavorites1 => 'Guarda empleos de cualquier país y profesión';

  @override
  String get gateFavorites2 => 'Encuéntralos de nuevo en cualquier dispositivo';

  @override
  String get gateFavorites3 => 'Mira de un vistazo si el empleo sigue abierto';

  @override
  String get gateApplicationsTitle =>
      'Sigue cada etapa de tu próxima oportunidad.';

  @override
  String get gateApplicationsBody =>
      'Un panel sencillo de los procesos en los que participas, del interés a la oferta.';

  @override
  String get gateApplications1 => 'Registra dónde y cuándo te postulaste';

  @override
  String get gateApplications2 => 'Mueve cada proceso por sus etapas';

  @override
  String get gateApplications3 => 'Guarda notas y fechas importantes';

  @override
  String get gateResumesTitle =>
      'Ten tu currículum listo cuando aparezca el empleo adecuado.';

  @override
  String get gateResumesBody =>
      'Tus archivos quedan privados en tu cuenta y nunca se comparten sin ti.';

  @override
  String get gateResumes1 => 'Sube currículos en PDF y guarda varias versiones';

  @override
  String get gateResumes2 => 'Elige cuál es tu currículum principal';

  @override
  String get gateResumes3 => 'Abre o reemplaza un archivo cuando lo necesites';

  @override
  String get gateProfileTitle => 'Tu perfil profesional, siempre a mano.';

  @override
  String get gateProfileBody =>
      'Cuenta quién eres profesionalmente, en cualquier profesión y país.';

  @override
  String get gateProfile1 => 'Presenta tu experiencia, formación y habilidades';

  @override
  String get gateProfile2 => 'Reutiliza tus datos al postularte';

  @override
  String get gateProfile3 =>
      'Define las modalidades y los países que prefieres';

  @override
  String get gateSavedSearchesTitle => 'Guarda las búsquedas que importan.';

  @override
  String get gateSavedSearchesBody =>
      'Guarda una búsqueda una vez y repítela con un toque.';

  @override
  String get gateSavedSearches1 => 'Las búsquedas quedan en tu cuenta';

  @override
  String get gateSavedSearches2 => 'Reábrelas desde Inicio';

  @override
  String get gateSavedSearches3 => 'Quítalas cuando quieras';

  @override
  String get homeHeadline => 'Encuentra tu próxima oportunidad';

  @override
  String get homeGreetingMorning => 'Buenos días';

  @override
  String get homeGreetingAfternoon => 'Buenas tardes';

  @override
  String get homeGreetingEvening => 'Buenas noches';

  @override
  String get homeRemoteTitle => 'Empleos remotos';

  @override
  String get homeContinueTitle => 'Continúa donde lo dejaste';

  @override
  String get homeQuickLast7 => 'Nuevos de la semana';

  @override
  String get areasPageTitle => 'Áreas profesionales';

  @override
  String get areasPageBody =>
      'Elige un área para ver sus empleos abiertos. Solo aparecen áreas con empleos ahora.';

  @override
  String areaJobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count empleos',
      one: '1 empleo',
    );
    return '$_temp0';
  }

  @override
  String get filtersTitle => 'Filtros';

  @override
  String get filtersApply => 'Ver resultados';

  @override
  String get filtersReset => 'Borrar todo';

  @override
  String get filterArea => 'Área profesional';

  @override
  String get filterAreaChip => 'Área';

  @override
  String get filterSalary => 'Salario';

  @override
  String get filterRegionAny => 'Cualquier lugar del mundo';

  @override
  String get filterCountryAny => 'Cualquier país';

  @override
  String get filterAreaAny => 'Todas las áreas';

  @override
  String get areaPickerTitle => 'Elige un área';

  @override
  String get areaPickerSpecialties => 'Especialidades';

  @override
  String get sortNewest => 'Más recientes primero';

  @override
  String get exploreOpenFilters => 'Abrir filtros';

  @override
  String exploreFiltersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filtros activos',
      one: '1 filtro activo',
    );
    return '$_temp0';
  }

  @override
  String get authSignInHeadline => 'Qué bueno verte de nuevo';

  @override
  String get authSignInSubtitle =>
      'Inicia sesión para ver tus favoritos, postulaciones y currículums.';

  @override
  String get authSignUpHeadline => 'Crea tu cuenta de OrbiJob';

  @override
  String get authSignUpSubtitle =>
      'Gratis. Guarda empleos, sigue tus postulaciones y reúne tus currículums en un solo lugar.';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authBrowseWithoutAccount => 'Seguir sin cuenta';

  @override
  String get authNewPasswordSubtitle =>
      'Elige una nueva contraseña de al menos 8 caracteres.';

  @override
  String get profileHubProfessionalSub =>
      'Cargo, competencias, experiencia y formación';

  @override
  String get profileHubResumesSub => 'Tus PDF, con un currículum principal';

  @override
  String get profileHubPreferences => 'Preferencias';

  @override
  String get profileHubPreferencesSub =>
      'Países de interés y búsquedas guardadas';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get profileHubSettingsSub => 'Idioma y apariencia';

  @override
  String get privacyTitle => 'Privacidad';

  @override
  String get profileHubPrivacySub => 'Cómo se tratan tus datos';

  @override
  String get privacyIntro => 'Qué guarda OrbiJob y qué nunca hace.';

  @override
  String get privacyKeepsTitle => 'Qué se guarda';

  @override
  String get privacyKeeps1 => 'Tu correo y la sesión de acceso.';

  @override
  String get privacyKeeps2 =>
      'Tu perfil profesional, favoritos, postulaciones y preferencias, legibles solo por ti.';

  @override
  String get privacyKeeps3 =>
      'Currículums en un área privada de tu cuenta, abiertos solo mediante enlaces temporales.';

  @override
  String get privacyNeverTitle => 'Qué nunca hace OrbiJob';

  @override
  String get privacyNever1 =>
      'Nunca postula por ti: toda postulación ocurre en el anuncio original.';

  @override
  String get privacyNever2 =>
      'Nunca comparte tu currículum o perfil con empresas ni otros usuarios.';

  @override
  String get privacyNever3 => 'Nunca vende tus datos.';

  @override
  String profileCompletenessTitle(int percent) {
    return 'Perfil $percent% completo';
  }

  @override
  String get profileCompletenessHint =>
      'Un perfil completo ayuda a estimar tu compatibilidad con cada empleo. Falta:';

  @override
  String get profileCompletenessDone => 'Todo lo que usa la app está completo.';

  @override
  String get profileMissingHeadline => 'Cargo';

  @override
  String get profileMissingLocation => 'Ubicación';

  @override
  String get profileMissingSkills => 'Competencias';

  @override
  String get profileMissingSummary => 'Resumen';

  @override
  String get profileMissingExperience => 'Experiencia';

  @override
  String get profileMissingEducation => 'Formación';

  @override
  String get profileMissingResume => 'Currículum';

  @override
  String get resumePrimary => 'Principal';

  @override
  String get resumeSetPrimary => 'Definir como principal';

  @override
  String get resumePrimarySet => 'Currículum principal actualizado';

  @override
  String get resumeReplace => 'Reemplazar archivo';

  @override
  String get resumeReplaceTitle => '¿Reemplazar este currículum?';

  @override
  String get resumeReplaceBody =>
      'Elige el nuevo PDF. Se sube primero; solo después se elimina el archivo anterior de tu cuenta.';

  @override
  String get resumeReplaced => 'Currículum reemplazado';

  @override
  String get resumeMoreActions => 'Más acciones';

  @override
  String get resumeChooseFile => 'Elegir PDF';

  @override
  String get languageChooseHint => 'La app cambia al instante.';

  @override
  String get formDiscardTitle => '¿Descartar los cambios?';

  @override
  String get formDiscardBody => 'Lo que escribiste se perderá.';

  @override
  String get formDiscard => 'Descartar';

  @override
  String get formKeepEditing => 'Seguir editando';

  @override
  String get commonSaved => 'Guardado';

  @override
  String get formFixErrors => 'Revisa los campos resaltados.';

  @override
  String get profileFieldEmail => 'Correo de contacto';

  @override
  String get profileFieldPhone => 'Teléfono';

  @override
  String get profileEmailInvalid => 'Introduce un correo válido';

  @override
  String get resumeSuggestAction => 'Completar mi perfil con este currículum';

  @override
  String get resumeImportStart => 'Empezar con un currículum en PDF';

  @override
  String get resumeImportTitle => 'Revisa las sugerencias';

  @override
  String get resumeImportIntro =>
      'El texto se leyó en este dispositivo; el archivo no se envió a ningún sitio. Revisa cada elemento y corrige lo que esté mal. No se guarda nada hasta que lo apliques, y lo que ya tienes solo se reemplaza donde lo marques.';

  @override
  String get resumeImportReading => 'Leyendo el currículum…';

  @override
  String get resumeImportNoText =>
      'Este PDF no tiene texto seleccionable (parece un escaneo o una foto). OrbiJob no lee imágenes, así que completa tu perfil a mano.';

  @override
  String get resumeImportEncrypted =>
      'Este PDF está protegido con contraseña, así que no se puede leer su texto.';

  @override
  String get resumeImportUnreadable =>
      'No se pudo leer el texto de este PDF (fuentes poco comunes o archivo dañado).';

  @override
  String get resumeImportNothing =>
      'Se leyó el texto, pero no se reconoció ningún dato de perfil.';

  @override
  String get resumeImportDownloadFailed =>
      'No se pudo abrir el archivo para leerlo.';

  @override
  String get resumeImportSectionIdentity => 'Identidad y contacto';

  @override
  String get resumeImportSectionSkills => 'Competencias';

  @override
  String get resumeImportSectionLanguages => 'Idiomas';

  @override
  String get resumeImportSectionExperience => 'Experiencia';

  @override
  String get resumeImportSectionEducation => 'Formación';

  @override
  String resumeImportReplaces(String value) {
    return 'Reemplaza: $value';
  }

  @override
  String get resumeImportAlready => 'Ya está en tu perfil';

  @override
  String get resumeImportNeedsFields =>
      'Completa el cargo y la empresa para incluir esta entrada.';

  @override
  String get resumeImportNeedsInstitution =>
      'Completa la institución para incluir esta entrada.';

  @override
  String get resumeImportNeedsName =>
      'Un perfil necesita un nombre: marca y completa el nombre.';

  @override
  String resumeImportApply(int count) {
    return 'Aplicar $count seleccionados';
  }

  @override
  String get resumeImportApplied => 'Perfil actualizado con tu currículum';

  @override
  String get resumeImportOfferTitle =>
      '¿Completar tu perfil con este currículum?';

  @override
  String get resumeImportOfferBody =>
      'OrbiJob puede leer el texto en este dispositivo y sugerir datos. Revisas todo antes de guardar nada.';

  @override
  String get resumeImportOfferYes => 'Ver sugerencias';

  @override
  String get resumeImportOfferNo => 'Ahora no';

  @override
  String get resumeImportPresent => 'actualidad';

  @override
  String resumeImportDates(String from, String to) {
    return '$from – $to';
  }

  @override
  String get kitButton => 'Preparar mi postulación';

  @override
  String get kitTitle => 'Kit de postulación';

  @override
  String get kitIntro =>
      'OrbiJob nunca rellena ni envía formularios en otros sitios. Copia lo que necesites de tu perfil, abre el anuncio original y pégalo allí.';

  @override
  String get kitSignIn => 'Inicia sesión para usar los datos de tu perfil.';

  @override
  String get kitEmpty =>
      'Tu perfil aún no tiene datos para copiar. Complétalo o empieza con un currículum en PDF.';

  @override
  String kitCopy(String field) {
    return 'Copiar $field';
  }

  @override
  String kitCopied(String field) {
    return '$field copiado';
  }

  @override
  String get kitCopyAll => 'Copiar todo';

  @override
  String get kitAllCopied => 'Datos del perfil copiados';

  @override
  String get kitLocation => 'Ubicación';

  @override
  String get kitLinks => 'Enlaces';

  @override
  String get kitLastJob => 'Experiencia más reciente';

  @override
  String get kitLastEducation => 'Formación más reciente';

  @override
  String get kitMainResume => 'Abrir mi currículum principal';

  @override
  String get kitMainResumeHint =>
      'Descárgalo desde el enlace para adjuntarlo en el anuncio.';

  @override
  String get kitTrack => 'Ya postulé: hacer seguimiento';

  @override
  String get kitTrackConfirmTitle => '¿Hacer seguimiento de esta postulación?';

  @override
  String get kitTrackConfirmBody =>
      'Se añade a Postulaciones como Postulado, con la fecha de hoy. OrbiJob no puede comprobar si realmente postulaste.';

  @override
  String get kitTracked => 'Añadida a tus postulaciones';

  @override
  String get kitNoListing =>
      'Este empleo no tiene un anuncio original que abrir.';

  @override
  String get browserClose => 'Cerrar';

  @override
  String get browserBack => 'Atrás';

  @override
  String get browserForward => 'Adelante';

  @override
  String get browserReload => 'Recargar';

  @override
  String get browserMore => 'Más opciones';

  @override
  String get browserShare => 'Compartir enlace';

  @override
  String get browserCopyLink => 'Copiar enlace';

  @override
  String get browserLinkCopied => 'Enlace copiado';

  @override
  String get browserOpenExternal => 'Abrir en el navegador';

  @override
  String get browserSecure => 'Conexión HTTPS';

  @override
  String get browserNotSecure => 'No segura (HTTP)';

  @override
  String get browserSecureHint =>
      'HTTPS cifra la conexión. OrbiJob no comprueba quién gestiona el sitio ni lo que te pide.';

  @override
  String get browserErrorTitle => 'No se pudo cargar la página';

  @override
  String get browserErrorBody =>
      'Revisa tu conexión e inténtalo de nuevo. Si el sitio no funciona aquí (inicio de sesión, bloqueos, captcha), ábrelo en el navegador.';

  @override
  String get browserErrorTls =>
      'El certificado de seguridad del sitio no es de confianza, así que no se abrió la página.';

  @override
  String get browserBlockedLink => 'Se bloqueó un enlace por seguridad.';

  @override
  String get browserDownloadExternal =>
      'Los archivos los descarga tu navegador: abriéndolo allí.';

  @override
  String get browserExternalOnly =>
      'Este enlace solo se puede abrir en el navegador.';

  @override
  String get browserOpeningExternal => 'Abriendo en el navegador…';

  @override
  String get browserDidYouApply => '¿Postulaste?';

  @override
  String get browserCannotOpenExternal => 'No se pudo abrir el navegador.';

  @override
  String get browserLanguageNotice =>
      'La página original puede estar en otro idioma. OrbiJob no traduce otros sitios.';

  @override
  String get translationAuto => 'Traducción automática';

  @override
  String translationNote(String language) {
    return 'Traducido del $language automáticamente. Puede contener errores.';
  }

  @override
  String get translationShowOriginal => 'Ver original';

  @override
  String get translationShowTranslation => 'Ver traducción';

  @override
  String get translationLoading => 'Traduciendo…';

  @override
  String get translationNeedsTitle => '¿Traducir este empleo?';

  @override
  String translationNeedsBody(int mb) {
    return 'OrbiJob traduce en tu dispositivo, así que lo que lees se queda en él. La primera vez se descargan datos de idioma de unos $mb MB.';
  }

  @override
  String get translationNeedsBodyWeb =>
      'Tu navegador traduce en este dispositivo, así que lo que lees se queda en él. Puede descargar datos de idioma antes.';

  @override
  String get translationDownload => 'Descargar y traducir';

  @override
  String get translationDownloading => 'Descargando datos de idioma…';

  @override
  String translationUnsupported(String language) {
    return 'La traducción automática del $language no está disponible en este dispositivo. Mostrando el original.';
  }

  @override
  String get translationFailed =>
      'No se pudo traducir este empleo. Mostrando el original.';

  @override
  String get translationPartialCut =>
      'Solo se tradujo la primera parte; el resto está en el original.';

  @override
  String get translationPartialLines =>
      'Algunas líneas se quedan en el original para que números, códigos y nombres sigan siendo exactos.';

  @override
  String translationOriginalLabel(String language) {
    return 'Texto original ($language)';
  }

  @override
  String get translationSettingsTitle => 'Traducción';

  @override
  String get translationSettingsSwitch => 'Traducir empleos a mi idioma';

  @override
  String get translationSettingsBody =>
      'Usa la traducción integrada en este dispositivo: los títulos se traducen cuando los datos del idioma ya están en él, y el texto completo cuando lo pides. El original siempre está a un toque.';

  @override
  String get translationClearCache => 'Borrar traducciones guardadas';

  @override
  String get translationCacheCleared => 'Traducciones guardadas borradas';

  @override
  String get translationTitleOriginalHint => 'Título traducido';

  @override
  String get ssTitle => 'Búsquedas guardadas';

  @override
  String get ssSubtitle =>
      'Reabre una búsqueda con un toque y elige cuáles te avisan de empleos nuevos.';

  @override
  String get ssEmptyTitle => 'Aún no hay búsquedas guardadas';

  @override
  String get ssEmptyBody =>
      'Busca o filtra en Explorar y toca “Guardar búsqueda”. Puedes activar alertas para ella.';

  @override
  String get ssGoExplore => 'Ir a Explorar';

  @override
  String get ssSaveAction => 'Guardar búsqueda';

  @override
  String get ssMine => 'Mis búsquedas';

  @override
  String get ssSaveSheetTitle => 'Guardar esta búsqueda';

  @override
  String get ssEditSheetTitle => 'Editar búsqueda guardada';

  @override
  String get ssNameLabel => 'Nombre';

  @override
  String get ssNameHint => 'p. ej., Enfermero en Alemania';

  @override
  String get ssNameRequired => 'Ponle un nombre a la búsqueda.';

  @override
  String ssNameTooLong(int max) {
    return 'Usa como máximo $max caracteres.';
  }

  @override
  String get ssAlertsLabel => 'Avisarme de empleos nuevos';

  @override
  String get ssAlertsHelp =>
      'Aparece una notificación en OrbiJob cuando un empleo nuevo coincide. Solo se avisa de empleos abiertos y verificados recientemente.';

  @override
  String get ssFrequencyLabel => 'Con qué frecuencia comprobar';

  @override
  String get ssFreqInstant => 'Cada hora';

  @override
  String get ssFreqDaily => 'Una vez al día';

  @override
  String get ssFreqWeekly => 'Una vez por semana';

  @override
  String get ssAlertsOn => 'Alertas activos';

  @override
  String get ssAlertsOff => 'Alertas desactivados';

  @override
  String ssAlertsToggle(String name) {
    return 'Alertas de $name';
  }

  @override
  String get ssSaved => 'Búsqueda guardada';

  @override
  String get ssUpdated => 'Búsqueda actualizada';

  @override
  String get ssRemoved => 'Búsqueda eliminada';

  @override
  String get ssDuplicated => 'Copia creada';

  @override
  String get ssOpen => 'Abrir en Explorar';

  @override
  String get ssRename => 'Renombrar';

  @override
  String get ssDuplicate => 'Duplicar';

  @override
  String get ssEdit => 'Editar';

  @override
  String get ssDelete => 'Eliminar';

  @override
  String ssMenu(String name) {
    return 'Acciones de $name';
  }

  @override
  String get ssDeleteTitle => '¿Eliminar esta búsqueda?';

  @override
  String get ssDeleteBody =>
      'Sus alertas se detienen. Las notificaciones ya recibidas se conservan.';

  @override
  String ssCopyName(String name) {
    return '$name (copia)';
  }

  @override
  String get ssDefaultName => 'Búsqueda';

  @override
  String get ssAllJobs => 'Todos los empleos';

  @override
  String ssSpecDays(int days) {
    return 'Últimos $days días';
  }

  @override
  String ssAlertsLimit(int max) {
    return 'Puedes tener hasta $max búsquedas con alertas. Desactiva una primero.';
  }

  @override
  String get ssSignedOutNote =>
      'Inicia sesión para guardar búsquedas en tu cuenta y recibir alertas.';

  @override
  String get homeSavedTitle => 'Búsquedas guardadas';

  @override
  String get homeSavedAll => 'Ver todas';

  @override
  String get ntTitle => 'Notificaciones';

  @override
  String get ntBell => 'Notificaciones';

  @override
  String ntBellUnread(int count) {
    return 'Notificaciones, $count sin leer';
  }

  @override
  String get ntEmptyTitle => 'Nada nuevo por ahora';

  @override
  String get ntEmptyBody =>
      'Cuando un empleo nuevo coincida con una búsqueda guardada con alertas, aparecerá aquí. Los empleos nuevos se comprueban aproximadamente cada hora.';

  @override
  String get ntEmptyNoAlerts =>
      'No tienes ninguna búsqueda guardada con alertas activas.';

  @override
  String get ntManageSearches => 'Gestionar búsquedas guardadas';

  @override
  String get ntMarkAllRead => 'Marcar todas como leídas';

  @override
  String get ntClearAll => 'Borrar todo';

  @override
  String get ntClearTitle => '¿Borrar todas las notificaciones?';

  @override
  String get ntClearBody =>
      'Desaparecen de esta lista. Los empleos no se ven afectados.';

  @override
  String get ntDismiss => 'Descartar';

  @override
  String get ntUnread => 'Sin leer';

  @override
  String ntFromSearches(String names) {
    return 'Coincide con: $names';
  }

  @override
  String ntFromSearchesMore(String names, int count) {
    return 'Coincide con: $names y $count más';
  }

  @override
  String ntFound(String when) {
    return 'Encontrado $when';
  }

  @override
  String get ntJobUnavailable =>
      'Este empleo ya no está en el catálogo. Aún puedes probar el anuncio original.';

  @override
  String get ntSettingsTitle => 'Alertas';

  @override
  String get ntEnabled => 'Recibir alertas';

  @override
  String get ntEnabledHelp =>
      'Desactiva para dejar de recibir notificaciones sin tocar tus búsquedas guardadas. Los empleos que aparezcan mientras esté desactivado no se entregan después.';

  @override
  String get ntPushNote =>
      'Las alertas llegan dentro de OrbiJob. Las notificaciones push en el móvil o el navegador aún no están activadas.';

  @override
  String get ntSignedOut =>
      'Inicia sesión para recibir alertas de empleos nuevos.';

  @override
  String get ntLoadFailed => 'No se pudieron cargar las notificaciones.';

  @override
  String get ssUseCurrent => 'Sustituir por la búsqueda actual de Explorar';

  @override
  String get agoJustNow => 'hace un momento';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count minutos',
      one: 'hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String get agoYesterday => 'ayer';

  @override
  String agoDays(int count) {
    return 'hace $count días';
  }

  @override
  String jobMoreActions(String title) {
    return 'Más acciones para $title';
  }

  @override
  String get hdHide => 'Ocultar este empleo';

  @override
  String get hdHidden => 'Empleo oculto';

  @override
  String get hdUndo => 'Deshacer';

  @override
  String get hdRestore => 'Restaurar';

  @override
  String get hdRestored => 'Empleo restaurado';

  @override
  String get hdTitle => 'Empleos ocultos';

  @override
  String get hdSubtitle =>
      'Los empleos ocultos no aparecen en la búsqueda, las recomendaciones ni las alertas. Restaura uno para verlo de nuevo.';

  @override
  String get hdEmptyTitle => 'Ningún empleo oculto';

  @override
  String get hdEmptyBody =>
      'Abre el menú de un empleo y elige “Ocultar este empleo” para dejar de verlo.';

  @override
  String hdCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count empleos ocultos',
      one: '1 empleo oculto',
    );
    return '$_temp0';
  }

  @override
  String get hdProfileSub => 'Empleos que elegiste no volver a ver';

  @override
  String get hdOpenListing => 'Abrir anuncio';

  @override
  String get hdSeeHidden => 'Ver empleos ocultos';

  @override
  String get hdFilteredNote => 'Algunos empleos de esta página están ocultos.';

  @override
  String get profileHubSavedSearches => 'Búsquedas guardadas y alertas';

  @override
  String get profileHubSavedSearchesSub =>
      'Búsquedas que guardas y las que te avisan';

  @override
  String get rsTitle => 'Historial de búsquedas';

  @override
  String get rsSwitch => 'Recordar mis búsquedas recientes';

  @override
  String get rsBody =>
      'Solo las palabras que buscas, guardadas en este dispositivo y nunca enviadas al servidor. Al desactivarlo también se borran las ya guardadas.';

  @override
  String get rsClear => 'Borrar historial de búsquedas';

  @override
  String get rsCleared => 'Historial de búsquedas borrado';

  @override
  String get rsRecent => 'Búsquedas recientes';

  @override
  String get rcTitle => 'Recomendados para ti';

  @override
  String get rcSubtitle =>
      'Comparados con tu perfil en este dispositivo: profesión, competencias, lugar, modalidad e idioma.';

  @override
  String get rcSeeAll => 'Ver todos';

  @override
  String get rcEmptyTitle => 'Nada coincide ahora';

  @override
  String get rcEmptyBody =>
      'Ningún empleo abierto coincide con tu perfil por ahora. Guarda una búsqueda con alertas para enterarte de los nuevos.';

  @override
  String get rcNeedProfileTitle => 'Cuéntanos a qué te dedicas';

  @override
  String get rcNeedProfileBody =>
      'Añade a tu perfil tu profesión, dónde quieres trabajar y cómo, y OrbiJob ordena los empleos para ti. Sirve para cualquier profesión.';

  @override
  String get rcNeedProfileAction => 'Completar mi perfil';

  @override
  String get rcSignInBody =>
      'Inicia sesión y completa tu perfil para recibir recomendaciones.';

  @override
  String get rcThinNote =>
      'Tu perfil tiene poca información, así que estas coincidencias son amplias. Añade tu profesión para mejorarlas.';

  @override
  String get rcFitStrong => 'Coincide mucho';

  @override
  String get rcFitGood => 'Coincide bien';

  @override
  String get rcFitPossible => 'Puede interesar';

  @override
  String get rcWhy => '¿Por qué este empleo?';

  @override
  String get rcWhyTitle => 'Por qué ves este empleo';

  @override
  String get rcMatches => 'Qué coincide';

  @override
  String get rcCheck => 'Conviene comprobar';

  @override
  String get rcDisclaimer =>
      'OrbiJob compara el texto del anuncio con tu perfil. No verifica visados, permisos de trabajo, registro profesional ni certificaciones: confirma los requisitos en el anuncio.';

  @override
  String rcScore(int score) {
    return 'Puntuación $score de 100';
  }

  @override
  String rcSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count criterios evaluados',
      one: '1 criterio evaluado',
    );
    return '$_temp0';
  }

  @override
  String rcReasonProfessionExact(String profession) {
    return 'El título menciona tu profesión: $profession';
  }

  @override
  String rcReasonProfessionClose(String profession) {
    return 'Cercana a tu profesión: $profession';
  }

  @override
  String rcReasonProfessionSynonym(String profession) {
    return 'La misma profesión en otro idioma: $profession';
  }

  @override
  String rcReasonSameField(String area) {
    return 'Mismo campo profesional: $area';
  }

  @override
  String rcReasonSkills(String skills) {
    return 'Menciona tus competencias: $skills';
  }

  @override
  String rcReasonCountryInterest(String country) {
    return 'En $country, uno de tus países de interés';
  }

  @override
  String rcReasonCountryResidence(String country) {
    return 'En $country, donde vives';
  }

  @override
  String rcReasonRemoteEligible(String country) {
    return 'Remoto y abierto a candidatos de $country';
  }

  @override
  String get rcReasonRemoteAnywhere =>
      'Remoto, abierto a candidatos de cualquier lugar';

  @override
  String rcReasonCity(String city) {
    return 'En $city';
  }

  @override
  String rcReasonWorkMode(String mode) {
    return '$mode, como prefieres';
  }

  @override
  String rcReasonLanguage(String language) {
    return 'Escrito en $language, un idioma de tu perfil';
  }

  @override
  String get rcCaveatLocation => 'El anuncio no dice dónde está el empleo.';

  @override
  String rcCaveatLanguage(String language) {
    return 'Escrito en $language, que tu perfil no incluye.';
  }

  @override
  String rcCaveatEligibility(String places) {
    return 'El anuncio limita quién puede postularse: $places. Comprueba que cumples.';
  }

  @override
  String get rcCaveatMode =>
      'El anuncio no dice si es remoto, híbrido o presencial.';

  @override
  String get pfMustTitle => 'Requisitos para las recomendaciones';

  @override
  String get pfMustHelp =>
      'Activa lo que un empleo debe tener para recomendártelo. Lo demás es solo una preferencia: sube el empleo en la lista pero nunca lo oculta. Un anuncio que no lo indica nunca se oculta.';

  @override
  String get pfMustWorkMode => 'Solo mi modalidad';

  @override
  String get pfMustCountry => 'Solo mis países';

  @override
  String get pfMustLanguage => 'Solo mis idiomas';

  @override
  String get applicationStageInterested => 'Interesado';

  @override
  String get applicationStageHired => 'Contratado';

  @override
  String get apPipelineAll => 'Todas';

  @override
  String get apStageHint =>
      'Tú decides la etapa. OrbiJob nunca contacta al empleador ni da por hecho que te postulaste.';

  @override
  String get apAgendaTitle => 'Próximos compromisos';

  @override
  String get apAgendaInterview => 'Entrevista';

  @override
  String get apAgendaFollowUp => 'Seguimiento';

  @override
  String get apOverdue => 'Atrasado';

  @override
  String get apAgendaOverdueHint =>
      'La fecha pasó. Actualiza la etapa o fija una nueva fecha.';

  @override
  String get apDatesTitle => 'Fechas';

  @override
  String get apInterviewLabel => 'Entrevista (fecha y hora)';

  @override
  String get apFollowUpLabel => 'Dar seguimiento el';

  @override
  String get apDateNone => 'Sin definir';

  @override
  String get apDatePick => 'Elegir';

  @override
  String get apDateClear => 'Quitar';

  @override
  String get apDatesSaved => 'Fecha guardada';

  @override
  String get apTrackInterest => 'Seguir este empleo';

  @override
  String get apTrackedInterest =>
      'Añadido a tus postulaciones como “interesado”. No se envió nada.';

  @override
  String get apAlreadyTracked => 'Este empleo ya está en tus postulaciones.';

  @override
  String apNextDate(String kind, String date) {
    return '$kind: $date';
  }

  @override
  String apPipelineCount(String stage, int count) {
    return '$stage ($count)';
  }

  @override
  String get apFilteredEmpty => 'Ninguna postulación en esta etapa.';
}
