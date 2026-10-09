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
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navApplications => 'Applications';

  @override
  String get navMain => 'Main navigation';

  @override
  String get profile => 'Profile';

  @override
  String get back => 'Back';

  @override
  String get homeTitle => 'What are you looking for?';

  @override
  String get homeSearchHint => 'Any profession, any country';

  @override
  String get homeAreasTitle => 'Browse by area';

  @override
  String get areaTechnology => 'Technology';

  @override
  String get areaHealth => 'Health';

  @override
  String get areaConstruction => 'Construction';

  @override
  String get areaEducation => 'Education';

  @override
  String get areaServices => 'Services';

  @override
  String get areaIndustry => 'Industry';

  @override
  String get areaTransport => 'Transport';

  @override
  String get homeForYouTitle => 'For you';

  @override
  String get homeForYouEmptyTitle => 'No matches yet';

  @override
  String get homeForYouEmptyBody =>
      'Matches appear here once job sources are connected and your profile is filled in.';

  @override
  String get homeApplicationsTitle => 'Applications';

  @override
  String get homeApplicationsEmptyTitle => 'No applications tracked';

  @override
  String get homeApplicationsEmptyBody =>
      'Track where you applied, interviews and offers.';

  @override
  String get searchHint =>
      'Any profession, e.g. electrician, nurse, Flutter developer';

  @override
  String get searchLabel => 'Search jobs';

  @override
  String get searchClear => 'Clear search';

  @override
  String get exploreIdleTitle => 'Search for any profession';

  @override
  String get exploreIdleBody =>
      'Type a profession or pick an area. Results only ever come from approved sources.';

  @override
  String get searching => 'Searching…';

  @override
  String get emptyTitle => 'No jobs found';

  @override
  String get emptyBody => 'Try another profession or a broader search.';

  @override
  String get noSourceTitle => 'No integrated source for this search';

  @override
  String get noSourceBody =>
      'We do not have an authorised source for this country and profession yet. Try the original job portals.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorBody =>
      'We could not load results. Check your connection and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get favoritesTitle => 'No favorites yet';

  @override
  String get favoritesBody => 'Saved jobs appear here.';

  @override
  String get applicationsTitle => 'No applications tracked';

  @override
  String get applicationsBody =>
      'Track where you applied, interviews and offers. Status is updated manually.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get workModeRemote => 'Remote';

  @override
  String get workModeHybrid => 'Hybrid';

  @override
  String get workModeOnsite => 'On-site';

  @override
  String get compatibilityLabel => 'Compatibility';

  @override
  String compatibilityValue(int score) {
    return 'Compatibility $score out of 100';
  }

  @override
  String get confidenceLabel => 'Confidence';

  @override
  String get confidenceHigh => 'High confidence';

  @override
  String get confidenceMedium => 'Medium confidence';

  @override
  String get confidenceLow => 'Low confidence';

  @override
  String confidenceSemantic(String level) {
    return 'Analysis confidence: $level';
  }

  @override
  String get scoreExplainer =>
      'Compatibility and confidence are separate measures.';

  @override
  String sourceLabel(String name) {
    return 'Source: $name';
  }

  @override
  String get favoriteAdd => 'Save job';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get perHour => '/h';

  @override
  String get perDay => '/day';

  @override
  String get perWeek => '/week';

  @override
  String get perMonth => '/month';

  @override
  String get perYear => '/year';

  @override
  String get publishedToday => 'Posted today';

  @override
  String get publishedYesterday => 'Posted yesterday';

  @override
  String publishedDaysAgo(int count) {
    return 'Posted $count days ago';
  }

  @override
  String publishedWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posted $count weeks ago',
      one: 'Posted 1 week ago',
    );
    return '$_temp0';
  }

  @override
  String publishedMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posted $count months ago',
      one: 'Posted 1 month ago',
    );
    return '$_temp0';
  }

  @override
  String get jobDetailTitle => 'Job details';

  @override
  String get openOfficialApplication => 'Open official application';

  @override
  String get selectJobHint => 'Select a job to see its details.';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get previewBanner => 'PREVIEW · ILLUSTRATIVE DATA, NOT REAL JOBS';

  @override
  String get previewAction => 'Preview only: this action is not available.';

  @override
  String jobLanguageSemantic(String code) {
    return 'Posting language: $code';
  }

  @override
  String originalLanguageNote(String code) {
    return 'Shown in its original language ($code). Job titles, company names and descriptions are not translated.';
  }

  @override
  String get recentSearchesTitle => 'Recent searches';

  @override
  String get recentSearchesClear => 'Clear recent searches';

  @override
  String get interestCountriesTitle => 'Countries of interest';

  @override
  String get interestCountriesEmptyTitle => 'No countries chosen yet';

  @override
  String get interestCountriesEmptyBody =>
      'Add countries in your profile to focus on them.';

  @override
  String get applicationStageApplied => 'Applied';

  @override
  String get applicationStageScreening => 'Screening';

  @override
  String get applicationStageInterview => 'Interview';

  @override
  String get applicationStageOffer => 'Offer';

  @override
  String get applicationStageRejected => 'Rejected';

  @override
  String get applicationStageWithdrawn => 'Withdrawn';

  @override
  String get applicationStageClosed => 'Closed';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountUnavailableTitle =>
      'Accounts are not enabled in this build';

  @override
  String get accountUnavailableBody =>
      'Everything works on this device without signing in. Sync arrives once the service is connected.';

  @override
  String accountSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get accountSignedInNoEmail => 'Signed in';

  @override
  String get accountSignedOutBody =>
      'Sign in to keep your profile, favorites and applications in your account.';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignUpTitle => 'Create account';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Password';

  @override
  String get authSignInAction => 'Sign in';

  @override
  String get authSignUpAction => 'Create account';

  @override
  String get authSwitchToSignUp => 'No account yet? Create one';

  @override
  String get authSwitchToSignIn => 'Already have an account? Sign in';

  @override
  String get authForgotPassword => 'Forgot password';

  @override
  String get authEmailInvalid => 'Enter a valid e-mail';

  @override
  String get authPasswordShort => 'Use at least 8 characters';

  @override
  String get authConfirmationSent =>
      'Check your e-mail to confirm the account, then sign in.';

  @override
  String get authResetSent =>
      'If the address has an account, a reset link is on its way.';

  @override
  String get authErrorInvalidCredentials => 'E-mail or password is incorrect.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirm your e-mail first. Check your inbox.';

  @override
  String get authErrorEmailTaken =>
      'This e-mail is already registered. Try signing in.';

  @override
  String get authErrorInvalidEmail => 'This e-mail address is not valid.';

  @override
  String get authErrorWeakPassword =>
      'Password is too weak. Use a longer, less common one.';

  @override
  String get authErrorRateLimited =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get authErrorNetwork =>
      'No connection. Check the internet and try again.';

  @override
  String get authErrorUnavailable => 'The service is unavailable right now.';

  @override
  String get authErrorUnknown => 'Something went wrong. Try again.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonRequired => 'Required field';

  @override
  String get commonDeleteConfirmBody => 'This cannot be undone.';

  @override
  String get fieldStartDate => 'Start date';

  @override
  String get fieldEndDate => 'End date';

  @override
  String get dateChoose => 'Choose a date';

  @override
  String get dateClear => 'Clear date';

  @override
  String tooLongError(int max) {
    return 'Too long (maximum $max characters)';
  }

  @override
  String get dataLoadErrorTitle => 'Could not load your data';

  @override
  String get dataSignInTitle => 'Sign in to continue';

  @override
  String get dataFailureNotConfigured =>
      'This build is not connected to an account service, so nothing can be saved here.';

  @override
  String get dataFailureSignedOut =>
      'Your data is kept in your account. Sign in to see and change it.';

  @override
  String get dataFailureSessionExpired =>
      'Your session ended. Sign in again to continue.';

  @override
  String get dataFailureNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get dataFailureDenied =>
      'The server did not allow this action for your account.';

  @override
  String get dataFailureQuota =>
      'You reached the limit for this kind of item. Remove one to add another.';

  @override
  String get dataFailureDuplicate => 'This already exists.';

  @override
  String get dataFailureInvalid =>
      'Some data is not valid. Check the fields and try again.';

  @override
  String get dataFailureTooLarge => 'The file is larger than 5 MB.';

  @override
  String get dataFailureNotPdf => 'Only PDF files are accepted.';

  @override
  String get dataFailureEmptyFile => 'The file is empty.';

  @override
  String get dataFailureNotFound =>
      'This item no longer exists. Refresh and try again.';

  @override
  String get dataFailureUnavailable =>
      'The service is unavailable right now. Try again later.';

  @override
  String get dataFailureUnknown => 'Something went wrong. Try again.';

  @override
  String get applicationsAdd => 'Add application';

  @override
  String get applicationsDisclaimer =>
      'OrbiJob never sends applications. Here you record the ones you sent yourself.';

  @override
  String get applicationNewTitle => 'New application';

  @override
  String get applicationDetailTitle => 'Application';

  @override
  String get applicationCompany => 'Company';

  @override
  String get applicationJobTitle => 'Job title';

  @override
  String get applicationLink => 'Link to the posting';

  @override
  String get applicationLinkInvalid => 'Enter a link starting with https://';

  @override
  String get applicationChannel => 'Where you applied';

  @override
  String get applicationStageLabel => 'Stage';

  @override
  String get applicationAppliedOn => 'Applied on';

  @override
  String get applicationNote => 'Notes';

  @override
  String get applicationSaveNote => 'Save notes';

  @override
  String get applicationOpenLink => 'Open posting';

  @override
  String get applicationLinkCannotOpen => 'Could not open the link.';

  @override
  String get applicationHistory => 'History';

  @override
  String get applicationHistoryEmpty => 'No stage changes recorded yet.';

  @override
  String get applicationDeleteTitle => 'Delete this application?';

  @override
  String get applicationNoDate => 'Date not informed';

  @override
  String homeApplicationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count applications tracked',
      one: '1 application tracked',
    );
    return '$_temp0';
  }

  @override
  String get profileSectionProfessional => 'Professional profile';

  @override
  String get profileCreateTitle => 'Create your professional profile';

  @override
  String get profileCreateBody =>
      'Say who you are professionally. Any profession is welcome.';

  @override
  String get profileCreateAction => 'Create profile';

  @override
  String get profileEditAction => 'Edit profile';

  @override
  String get profileFieldName => 'Professional name';

  @override
  String get profileFieldHeadline => 'Role or profession';

  @override
  String get profileFieldSummary => 'Summary';

  @override
  String get profileFieldCountry => 'Country of residence (2-letter code)';

  @override
  String get profileFieldCity => 'City';

  @override
  String get profileFieldWorkMode => 'Preferred work mode';

  @override
  String get profileWorkModeAny => 'No preference';

  @override
  String get profileFieldSkills => 'Skills';

  @override
  String get profileSkillAdd => 'Add skill';

  @override
  String profileSkillRemove(String name) {
    return 'Remove skill $name';
  }

  @override
  String get profileSkillsLimit => 'Up to 200 skills.';

  @override
  String get profileCountryInvalid => 'Use a 2-letter code, for example BR';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileNeedsProfile => 'Create your profile first to add this.';

  @override
  String get profileSignInBody =>
      'Sign in to create and keep your professional profile.';

  @override
  String get experienceSection => 'Experience';

  @override
  String get experienceAdd => 'Add experience';

  @override
  String get experienceNewTitle => 'New experience';

  @override
  String get experienceEditTitle => 'Edit experience';

  @override
  String get experienceCompany => 'Company';

  @override
  String get experienceRole => 'Role';

  @override
  String get experienceCurrent => 'I currently work here';

  @override
  String get experienceDescription => 'Description';

  @override
  String get experiencePresent => 'Present';

  @override
  String get experienceEmpty => 'No experience added yet.';

  @override
  String get experienceDatesInvalid =>
      'The end date must not be before the start date';

  @override
  String get experienceCurrentNeedsStart =>
      'Choose a start date for a current job';

  @override
  String get experienceDeleteTitle => 'Delete this experience?';

  @override
  String get educationSection => 'Education';

  @override
  String get educationAdd => 'Add education';

  @override
  String get educationNewTitle => 'New education';

  @override
  String get educationEditTitle => 'Edit education';

  @override
  String get educationInstitution => 'Institution';

  @override
  String get educationDegree => 'Degree (if any)';

  @override
  String get educationField => 'Course or field of study';

  @override
  String get educationEmpty => 'No education added. It is optional.';

  @override
  String get educationDeleteTitle => 'Delete this education?';

  @override
  String get resumesSection => 'Résumés';

  @override
  String get resumesBody =>
      'PDF only, up to 5 MB each, up to 10 files. Stored privately in your account.';

  @override
  String get resumesUpload => 'Upload PDF';

  @override
  String get resumesUploading => 'Uploading…';

  @override
  String get resumesEmpty => 'No résumé uploaded yet.';

  @override
  String resumeItem(String date) {
    return 'Résumé from $date';
  }

  @override
  String get resumeOpen => 'Open';

  @override
  String get resumeUploaded => 'Résumé uploaded';

  @override
  String get resumeDeleteTitle => 'Delete this résumé?';

  @override
  String get resumeDeleteBody => 'The file is removed from your account.';

  @override
  String get preferencesSection => 'Search preferences';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'Device language';

  @override
  String get languagePt => 'Português';

  @override
  String get languageEn => 'English';

  @override
  String get languageEs => 'Español';

  @override
  String get preferencesLocalOnly =>
      'Sign in to keep these choices in your account. Until then they only apply on this device.';

  @override
  String get countriesTitle => 'Countries of interest';

  @override
  String get countriesHint => 'Add a country (2-letter code)';

  @override
  String get countriesEmpty => 'No countries chosen.';

  @override
  String get countriesInvalid =>
      'Use a 2-letter code that is not already in the list, for example DE';

  @override
  String countriesRemove(String code) {
    return 'Remove country $code';
  }

  @override
  String get savedSearchesTitle => 'Saved searches';

  @override
  String get savedSearchesNote => 'Kept in your account.';

  @override
  String get recentSearchesNote => 'Recent searches stay on this device.';

  @override
  String get savedSearchSave => 'Save this search';

  @override
  String get savedSearchSaved => 'Search saved';

  @override
  String savedSearchRemove(String term) {
    return 'Remove saved search $term';
  }

  @override
  String get authNewPasswordTitle => 'Choose a new password';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authNewPasswordAction => 'Save new password';

  @override
  String get authPasswordChanged => 'Password updated.';

  @override
  String get authSessionExpired => 'Your session ended. Sign in again.';

  @override
  String get authErrorLinkInvalid =>
      'This link has expired or was already used. Request a new one.';

  @override
  String get authErrorSamePassword =>
      'Choose a password different from the current one.';

  @override
  String get authCancelRecovery => 'Cancel';

  @override
  String get commonLoading => 'Loading';
}
