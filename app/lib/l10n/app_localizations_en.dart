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
      'If the address has an account, a 6-digit code is on its way.';

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
  String get authErrorCodeInvalid =>
      'That code is wrong or has expired. Check the e-mail or request a new code.';

  @override
  String get authRecoveryTitle => 'Reset password';

  @override
  String get authRecoverySubtitle =>
      'Enter your e-mail and we will send you a 6-digit code.';

  @override
  String get authRecoverySendCode => 'Send code';

  @override
  String authRecoveryEnterCode(String email) {
    return 'Enter the 6-digit code sent to $email.';
  }

  @override
  String get authRecoveryCodeLabel => '6-digit code';

  @override
  String get authRecoveryCodeShort => 'Enter the 6 digits';

  @override
  String get authRecoveryVerify => 'Continue';

  @override
  String get authRecoveryResend => 'Send a new code';

  @override
  String authRecoveryResendIn(int seconds) {
    return 'Send a new code in ${seconds}s';
  }

  @override
  String get authRecoveryChangeEmail => 'Use another e-mail';

  @override
  String get authCancelRecovery => 'Cancel';

  @override
  String get commonLoading => 'Loading';

  @override
  String get filtersButton => 'Filters';

  @override
  String filtersButtonCount(int count) {
    return 'Filters ($count)';
  }

  @override
  String get filtersClear => 'Clear filters';

  @override
  String get filterWorkMode => 'Work mode';

  @override
  String get filterPublished => 'Posted';

  @override
  String get filterPublished1 => 'Last 24 hours';

  @override
  String get filterPublished7 => 'Last 7 days';

  @override
  String get filterPublished30 => 'Last 30 days';

  @override
  String get filterWithSalary => 'Only with salary';

  @override
  String get filterCountry => 'Country (from your profile)';

  @override
  String get filterContinent => 'Region';

  @override
  String get homeRegionsTitle => 'Browse by region';

  @override
  String get continentEurope => 'Europe';

  @override
  String get continentOceania => 'Oceania';

  @override
  String get continentAsia => 'Asia';

  @override
  String get continentAfrica => 'Africa';

  @override
  String get continentNorthAmerica => 'North America';

  @override
  String get continentSouthAmerica => 'South America';

  @override
  String get browseLatest => 'Show latest jobs';

  @override
  String get loadMore => 'Show more';

  @override
  String get loadMoreFailed => 'Could not load more jobs.';

  @override
  String resultsShown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Showing $count jobs',
      one: 'Showing 1 job',
    );
    return '$_temp0';
  }

  @override
  String get emptyFiltersBody =>
      'No jobs match these filters. Try removing some.';

  @override
  String get openOriginalListing => 'Open original listing';

  @override
  String eligibleIn(String places) {
    return 'Open to applicants in: $places';
  }

  @override
  String get jobDescriptionTitle => 'Description';

  @override
  String get locationAnywhere => 'Anywhere';

  @override
  String get eligibleAnywhere =>
      'Open to applicants anywhere, as stated by the source';

  @override
  String get eligibilityUnknown =>
      'Location eligibility not stated by the source';

  @override
  String get eligibilityCheckOriginal =>
      'Check eligibility on the original listing before applying.';

  @override
  String salaryFrom(String amount) {
    return 'From $amount';
  }

  @override
  String salaryUpTo(String amount) {
    return 'Up to $amount';
  }

  @override
  String get areaData => 'Data & AI';

  @override
  String get areaDesign => 'Design';

  @override
  String get areaProduct => 'Product & projects';

  @override
  String get areaSales => 'Sales';

  @override
  String get areaMarketing => 'Marketing & content';

  @override
  String get areaSupport => 'Customer support';

  @override
  String get areaFinance => 'Finance & legal';

  @override
  String get areaPeople => 'People & operations';

  @override
  String get areaHospitality => 'Hospitality & tourism';

  @override
  String get areaPublic => 'Public sector & nonprofit';

  @override
  String get areaAll => 'All areas';

  @override
  String get notConfiguredTitle => 'This build is not connected to OrbiJob';

  @override
  String get notConfiguredBody =>
      'The app was started without the backend configuration (SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY). Developers: run it with --dart-define-from-file.';

  @override
  String get homeLatestTitle => 'Latest jobs';

  @override
  String get homeLatestSeeAll => 'See all';

  @override
  String get homeLatestEmpty =>
      'There are no jobs to show right now. Try again later.';

  @override
  String get specPhysiotherapy => 'Physiotherapy';

  @override
  String get specPelvicPhysio => 'Pelvic physiotherapy';

  @override
  String get specNursing => 'Nursing';

  @override
  String get specMedicine => 'Medicine';

  @override
  String get specPsychology => 'Psychology';

  @override
  String get specOccupationalTherapy => 'Occupational therapy';

  @override
  String get specNutrition => 'Nutrition';

  @override
  String get specDentistry => 'Dentistry';

  @override
  String get specPharmacy => 'Pharmacy';

  @override
  String get specSpeechTherapy => 'Speech therapy';

  @override
  String get specRadiology => 'Radiology';

  @override
  String get specHospitalManagement => 'Hospital management';

  @override
  String get specAll => 'All health';

  @override
  String get portalsButton => 'Specialised job boards';

  @override
  String get portalsTitle => 'Search on specialised boards';

  @override
  String get portalsNote =>
      'External links. These boards do not allow their listings to be copied, so they are not part of the OrbiJob catalogue: the link opens the board itself.';

  @override
  String get specialtyEmpty =>
      'No open job in this specialty in the catalogue right now. Try the specialised boards below.';

  @override
  String get gateCreateAccount => 'Create account';

  @override
  String get gateKeepExploring => 'Keep exploring jobs';

  @override
  String get gateFavoritesTitle => 'Your best opportunities, in one place.';

  @override
  String get gateFavoritesBody =>
      'Save the jobs that catch your eye and come back to them whenever you want.';

  @override
  String get gateFavorites1 => 'Save jobs from any country and profession';

  @override
  String get gateFavorites2 => 'Find them again on any device';

  @override
  String get gateFavorites3 => 'See at a glance whether a job is still open';

  @override
  String get gateApplicationsTitle =>
      'Follow every step of your next opportunity.';

  @override
  String get gateApplicationsBody =>
      'A simple board for the processes you are in, from interest to offer.';

  @override
  String get gateApplications1 => 'Record where you applied and when';

  @override
  String get gateApplications2 => 'Move each process through its stages';

  @override
  String get gateApplications3 => 'Keep notes and important dates';

  @override
  String get gateResumesTitle =>
      'Have your résumé ready when the right job shows up.';

  @override
  String get gateResumesBody =>
      'Your files stay private in your account and are never shared without you.';

  @override
  String get gateResumes1 => 'Upload PDF résumés and keep several versions';

  @override
  String get gateResumes2 => 'Choose which one is your main résumé';

  @override
  String get gateResumes3 => 'Open or replace a file whenever you need';

  @override
  String get gateProfileTitle => 'Your professional profile, always at hand.';

  @override
  String get gateProfileBody =>
      'Tell who you are professionally, in any profession and any country.';

  @override
  String get gateProfile1 => 'Present your experience, education and skills';

  @override
  String get gateProfile2 => 'Reuse your data when you apply';

  @override
  String get gateProfile3 => 'Set the work modes and countries you prefer';

  @override
  String get gateSavedSearchesTitle => 'Keep the searches that matter.';

  @override
  String get gateSavedSearchesBody =>
      'Save a search once and run it again with a single tap.';

  @override
  String get gateSavedSearches1 => 'Searches live in your account';

  @override
  String get gateSavedSearches2 => 'Reopen them from Home';

  @override
  String get gateSavedSearches3 => 'Remove them whenever you want';

  @override
  String get homeHeadline => 'Find your next opportunity';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeRemoteTitle => 'Remote jobs';

  @override
  String get homeContinueTitle => 'Pick up where you left off';

  @override
  String get homeQuickLast7 => 'New this week';

  @override
  String get areasPageTitle => 'Professional areas';

  @override
  String get areasPageBody =>
      'Pick an area to see its open jobs. Only areas with jobs right now are listed.';

  @override
  String areaJobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
    );
    return '$_temp0';
  }

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersApply => 'Show results';

  @override
  String get filtersReset => 'Clear all';

  @override
  String get filterArea => 'Professional area';

  @override
  String get filterAreaChip => 'Area';

  @override
  String get filterSalary => 'Salary';

  @override
  String get filterRegionAny => 'Anywhere in the world';

  @override
  String get filterCountryAny => 'Any country';

  @override
  String get filterAreaAny => 'All areas';

  @override
  String get areaPickerTitle => 'Choose an area';

  @override
  String get areaPickerSpecialties => 'Specialties';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get exploreOpenFilters => 'Open filters';

  @override
  String exploreFiltersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters active',
      one: '1 filter active',
    );
    return '$_temp0';
  }

  @override
  String get authSignInHeadline => 'Welcome back';

  @override
  String get authSignInSubtitle =>
      'Sign in to see your favorites, applications and résumés.';

  @override
  String get authSignUpHeadline => 'Create your OrbiJob account';

  @override
  String get authSignUpSubtitle =>
      'Free. Save jobs, track applications and keep your résumés in one place.';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authBrowseWithoutAccount => 'Keep browsing without an account';

  @override
  String get authNewPasswordSubtitle =>
      'Choose a new password with at least 8 characters.';

  @override
  String get profileHubProfessionalSub =>
      'Role, skills, experience and education';

  @override
  String get profileHubResumesSub => 'Your PDFs, with a main résumé';

  @override
  String get profileHubPreferences => 'Preferences';

  @override
  String get profileHubPreferencesSub =>
      'Countries of interest and saved searches';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get profileHubSettingsSub => 'Language and appearance';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get profileHubPrivacySub => 'How your data is handled';

  @override
  String get privacyIntro => 'What OrbiJob keeps, and what it never does.';

  @override
  String get privacyKeepsTitle => 'What is stored';

  @override
  String get privacyKeeps1 => 'Your e-mail and sign-in session.';

  @override
  String get privacyKeeps2 =>
      'Your professional profile, favorites, applications and preferences, only readable by you.';

  @override
  String get privacyKeeps3 =>
      'Résumés in a private area of your account, opened only through short-lived links.';

  @override
  String get privacyNeverTitle => 'What OrbiJob never does';

  @override
  String get privacyNever1 =>
      'It never applies to a job for you: every application happens on the original listing.';

  @override
  String get privacyNever2 =>
      'It never shares your résumé or profile with companies or other users.';

  @override
  String get privacyNever3 => 'It never sells your data.';

  @override
  String profileCompletenessTitle(int percent) {
    return 'Profile $percent% complete';
  }

  @override
  String get profileCompletenessHint =>
      'A complete profile helps estimate how well you fit each job. Missing:';

  @override
  String get profileCompletenessDone => 'Everything the app uses is filled in.';

  @override
  String get profileMissingHeadline => 'Role';

  @override
  String get profileMissingLocation => 'Location';

  @override
  String get profileMissingSkills => 'Skills';

  @override
  String get profileMissingSummary => 'Summary';

  @override
  String get profileMissingExperience => 'Experience';

  @override
  String get profileMissingEducation => 'Education';

  @override
  String get profileMissingResume => 'Résumé';

  @override
  String get resumePrimary => 'Main';

  @override
  String get resumeSetPrimary => 'Set as main';

  @override
  String get resumePrimarySet => 'Main résumé updated';

  @override
  String get resumeReplace => 'Replace file';

  @override
  String get resumeReplaceTitle => 'Replace this résumé?';

  @override
  String get resumeReplaceBody =>
      'Pick the new PDF. It is uploaded first; only then is the old file removed from your account.';

  @override
  String get resumeReplaced => 'Résumé replaced';

  @override
  String get resumeMoreActions => 'More actions';

  @override
  String get resumeChooseFile => 'Choose PDF';

  @override
  String get languageChooseHint => 'The app switches right away.';

  @override
  String get formDiscardTitle => 'Discard changes?';

  @override
  String get formDiscardBody => 'What you typed will be lost.';

  @override
  String get formDiscard => 'Discard';

  @override
  String get formKeepEditing => 'Keep editing';

  @override
  String get commonSaved => 'Saved';

  @override
  String get formFixErrors => 'Check the highlighted fields.';

  @override
  String get profileFieldEmail => 'Contact e-mail';

  @override
  String get profileFieldPhone => 'Phone';

  @override
  String get profileEmailInvalid => 'Enter a valid e-mail address';

  @override
  String get resumeSuggestAction => 'Fill my profile from this résumé';

  @override
  String get resumeImportStart => 'Start from a PDF résumé';

  @override
  String get resumeImportTitle => 'Review suggestions';

  @override
  String get resumeImportIntro =>
      'The text was read on this device; the file did not go anywhere. Check each item and fix what is wrong. Nothing is saved until you apply, and what you already have is only replaced where you tick it.';

  @override
  String get resumeImportReading => 'Reading the résumé…';

  @override
  String get resumeImportNoText =>
      'This PDF has no selectable text (it looks like a scan or a photo). OrbiJob does not read images, so fill your profile by hand.';

  @override
  String get resumeImportEncrypted =>
      'This PDF is password-protected, so its text cannot be read.';

  @override
  String get resumeImportUnreadable =>
      'The text of this PDF could not be read (unusual fonts or a damaged file).';

  @override
  String get resumeImportNothing =>
      'The text was read, but no profile data could be recognised in it.';

  @override
  String get resumeImportDownloadFailed =>
      'Could not open the file to read it.';

  @override
  String get resumeImportSectionIdentity => 'Identity and contact';

  @override
  String get resumeImportSectionSkills => 'Skills';

  @override
  String get resumeImportSectionLanguages => 'Languages';

  @override
  String get resumeImportSectionExperience => 'Experience';

  @override
  String get resumeImportSectionEducation => 'Education';

  @override
  String resumeImportReplaces(String value) {
    return 'Replaces: $value';
  }

  @override
  String get resumeImportAlready => 'Already in your profile';

  @override
  String get resumeImportNeedsFields =>
      'Fill in the role and the company to include this entry.';

  @override
  String get resumeImportNeedsInstitution =>
      'Fill in the institution to include this entry.';

  @override
  String get resumeImportNeedsName =>
      'A profile needs a name: tick and fill in the name.';

  @override
  String resumeImportApply(int count) {
    return 'Apply $count selected';
  }

  @override
  String get resumeImportApplied => 'Profile updated from your résumé';

  @override
  String get resumeImportOfferTitle => 'Fill your profile from this résumé?';

  @override
  String get resumeImportOfferBody =>
      'OrbiJob can read the text on this device and suggest data. You review everything before anything is saved.';

  @override
  String get resumeImportOfferYes => 'Review suggestions';

  @override
  String get resumeImportOfferNo => 'Not now';

  @override
  String get resumeImportPresent => 'present';

  @override
  String resumeImportDates(String from, String to) {
    return '$from – $to';
  }

  @override
  String get kitButton => 'Prepare my application';

  @override
  String get kitTitle => 'Application kit';

  @override
  String get kitIntro =>
      'OrbiJob never fills in or sends forms on other sites. Copy what you need from your profile, open the original listing and paste it there.';

  @override
  String get kitSignIn => 'Sign in to use the data from your profile.';

  @override
  String get kitEmpty =>
      'Your profile has no data to copy yet. Fill it in, or start from a PDF résumé.';

  @override
  String kitCopy(String field) {
    return 'Copy $field';
  }

  @override
  String kitCopied(String field) {
    return '$field copied';
  }

  @override
  String get kitCopyAll => 'Copy everything';

  @override
  String get kitAllCopied => 'Profile data copied';

  @override
  String get kitLocation => 'Location';

  @override
  String get kitLinks => 'Links';

  @override
  String get kitLastJob => 'Latest experience';

  @override
  String get kitLastEducation => 'Latest education';

  @override
  String get kitMainResume => 'Open my main résumé';

  @override
  String get kitMainResumeHint =>
      'Download it from the link to attach it on the listing.';

  @override
  String get kitTrack => 'I applied: track it';

  @override
  String get kitTrackConfirmTitle => 'Track this application?';

  @override
  String get kitTrackConfirmBody =>
      'It is added to Applications as Applied, dated today. OrbiJob cannot check whether you really applied.';

  @override
  String get kitTracked => 'Added to your applications';

  @override
  String get kitNoListing => 'This job has no original listing to open.';

  @override
  String get browserClose => 'Close';

  @override
  String get browserBack => 'Back';

  @override
  String get browserForward => 'Forward';

  @override
  String get browserReload => 'Reload';

  @override
  String get browserMore => 'More options';

  @override
  String get browserShare => 'Share link';

  @override
  String get browserCopyLink => 'Copy link';

  @override
  String get browserLinkCopied => 'Link copied';

  @override
  String get browserOpenExternal => 'Open in browser';

  @override
  String get browserSecure => 'HTTPS connection';

  @override
  String get browserNotSecure => 'Not secure (HTTP)';

  @override
  String get browserSecureHint =>
      'HTTPS encrypts the connection. OrbiJob does not check who runs the site or what it asks of you.';

  @override
  String get browserErrorTitle => 'The page could not be loaded';

  @override
  String get browserErrorBody =>
      'Check your connection and try again. If the site does not work here (sign-in, blocks, captcha), open it in your browser.';

  @override
  String get browserErrorTls =>
      'The site\'s security certificate could not be trusted, so the page was not opened.';

  @override
  String get browserBlockedLink => 'A link was blocked for your safety.';

  @override
  String get browserDownloadExternal =>
      'Files are downloaded by your browser: opening it there.';

  @override
  String get browserExternalOnly =>
      'This link can only be opened in your browser.';

  @override
  String get browserOpeningExternal => 'Opening in your browser…';

  @override
  String get browserDidYouApply => 'Did you apply?';

  @override
  String get browserCannotOpenExternal => 'Could not open the browser.';

  @override
  String get browserLanguageNotice =>
      'The original page may be in another language. OrbiJob does not translate other sites.';

  @override
  String get translationAuto => 'Automatic translation';

  @override
  String translationNote(String language) {
    return 'Translated from $language automatically. It may contain errors.';
  }

  @override
  String get translationShowOriginal => 'Show original';

  @override
  String get translationShowTranslation => 'Show translation';

  @override
  String get translationLoading => 'Translating…';

  @override
  String get translationNeedsTitle => 'Translate this listing?';

  @override
  String translationNeedsBody(int mb) {
    return 'OrbiJob translates on your device, so what you read stays on it. The first time, language data of about $mb MB is downloaded.';
  }

  @override
  String get translationNeedsBodyWeb =>
      'Your browser translates on this device, so what you read stays on it. It may download language data first.';

  @override
  String get translationDownload => 'Download and translate';

  @override
  String get translationDownloading => 'Downloading language data…';

  @override
  String translationUnsupported(String language) {
    return 'Automatic translation from $language is not available on this device. Showing the original.';
  }

  @override
  String get translationFailed =>
      'Could not translate this listing. Showing the original.';

  @override
  String get translationPartialCut =>
      'Only the first part was translated; the rest is in the original.';

  @override
  String get translationPartialLines =>
      'Some lines stay in the original so numbers, codes and names remain exact.';

  @override
  String translationOriginalLabel(String language) {
    return 'Original text ($language)';
  }

  @override
  String get translationSettingsTitle => 'Translation';

  @override
  String get translationSettingsSwitch => 'Translate listings into my language';

  @override
  String get translationSettingsBody =>
      'Uses the translation built into this device: titles are translated when the language data is already on it, the full text when you ask. The original is always one tap away.';

  @override
  String get translationClearCache => 'Clear saved translations';

  @override
  String get translationCacheCleared => 'Saved translations cleared';

  @override
  String get translationTitleOriginalHint => 'Title translated';

  @override
  String get ssTitle => 'Saved searches';

  @override
  String get ssSubtitle =>
      'Reopen a search in one tap and choose which ones alert you about new jobs.';

  @override
  String get ssEmptyTitle => 'No saved searches yet';

  @override
  String get ssEmptyBody =>
      'Search or filter in Explore, then tap “Save search”. You can turn on alerts for it.';

  @override
  String get ssGoExplore => 'Go to Explore';

  @override
  String get ssSaveAction => 'Save search';

  @override
  String get ssMine => 'My searches';

  @override
  String get ssSaveSheetTitle => 'Save this search';

  @override
  String get ssEditSheetTitle => 'Edit saved search';

  @override
  String get ssNameLabel => 'Name';

  @override
  String get ssNameHint => 'e.g. Nurse in Germany';

  @override
  String get ssNameRequired => 'Give the search a name.';

  @override
  String ssNameTooLong(int max) {
    return 'Use at most $max characters.';
  }

  @override
  String get ssAlertsLabel => 'Alert me about new jobs';

  @override
  String get ssAlertsHelp =>
      'A notification appears in OrbiJob when a new job matches. Only open jobs verified recently are announced.';

  @override
  String get ssFrequencyLabel => 'How often to check';

  @override
  String get ssFreqInstant => 'Every hour';

  @override
  String get ssFreqDaily => 'Once a day';

  @override
  String get ssFreqWeekly => 'Once a week';

  @override
  String get ssAlertsOn => 'Alerts on';

  @override
  String get ssAlertsOff => 'Alerts off';

  @override
  String ssAlertsToggle(String name) {
    return 'Alerts for $name';
  }

  @override
  String get ssSaved => 'Search saved';

  @override
  String get ssUpdated => 'Search updated';

  @override
  String get ssRemoved => 'Search deleted';

  @override
  String get ssDuplicated => 'Copy created';

  @override
  String get ssOpen => 'Open in Explore';

  @override
  String get ssRename => 'Rename';

  @override
  String get ssDuplicate => 'Duplicate';

  @override
  String get ssEdit => 'Edit';

  @override
  String get ssDelete => 'Delete';

  @override
  String ssMenu(String name) {
    return 'Actions for $name';
  }

  @override
  String get ssDeleteTitle => 'Delete this search?';

  @override
  String get ssDeleteBody =>
      'Its alerts stop. Notifications already received stay.';

  @override
  String ssCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get ssDefaultName => 'Search';

  @override
  String get ssAllJobs => 'All jobs';

  @override
  String ssSpecDays(int days) {
    return 'Last $days days';
  }

  @override
  String ssAlertsLimit(int max) {
    return 'You can have up to $max searches with alerts. Turn one off first.';
  }

  @override
  String get ssSignedOutNote =>
      'Sign in to keep searches in your account and get alerts.';

  @override
  String get homeSavedTitle => 'Saved searches';

  @override
  String get homeSavedAll => 'See all';

  @override
  String get ntTitle => 'Notifications';

  @override
  String get ntBell => 'Notifications';

  @override
  String ntBellUnread(int count) {
    return 'Notifications, $count unread';
  }

  @override
  String get ntEmptyTitle => 'Nothing new yet';

  @override
  String get ntEmptyBody =>
      'When a new job matches a saved search with alerts on, it shows up here. New jobs are checked about every hour.';

  @override
  String get ntEmptyNoAlerts => 'You have no saved search with alerts on.';

  @override
  String get ntManageSearches => 'Manage saved searches';

  @override
  String get ntMarkAllRead => 'Mark all as read';

  @override
  String get ntClearAll => 'Clear all';

  @override
  String get ntClearTitle => 'Clear all notifications?';

  @override
  String get ntClearBody =>
      'They disappear from this list. Jobs are not affected.';

  @override
  String get ntDismiss => 'Remove from list';

  @override
  String get ntUnread => 'Unread';

  @override
  String ntFromSearches(String names) {
    return 'Matches: $names';
  }

  @override
  String ntFromSearchesMore(String names, int count) {
    return 'Matches: $names and $count more';
  }

  @override
  String ntFound(String when) {
    return 'Found $when';
  }

  @override
  String get ntJobUnavailable =>
      'This job is no longer in the catalogue. You can still try the original listing.';

  @override
  String get ntSettingsTitle => 'Alerts';

  @override
  String get ntEnabled => 'Receive alerts';

  @override
  String get ntEnabledHelp =>
      'From your saved searches. Jobs found while this is off are not sent later.';

  @override
  String get ntPushNote =>
      'Alerts and reminders always arrive here. On Android they also arrive as push notifications once you allow them; iPhone and browser push are not enabled yet.';

  @override
  String get ntSignedOut => 'Sign in to receive alerts about new jobs.';

  @override
  String get ntLoadFailed => 'Could not load notifications.';

  @override
  String get ssUseCurrent => 'Replace with the current Explore search';

  @override
  String get agoJustNow => 'just now';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get agoYesterday => 'yesterday';

  @override
  String agoDays(int count) {
    return '$count days ago';
  }

  @override
  String jobMoreActions(String title) {
    return 'More actions for $title';
  }

  @override
  String get hdHide => 'Hide this job';

  @override
  String get hdHidden => 'Job hidden';

  @override
  String get hdUndo => 'Undo';

  @override
  String get hdRestore => 'Restore';

  @override
  String get hdRestored => 'Job restored';

  @override
  String get hdTitle => 'Hidden jobs';

  @override
  String get hdSubtitle =>
      'Hidden jobs do not appear in search, recommendations or alerts. Restore one to see it again.';

  @override
  String get hdEmptyTitle => 'No hidden jobs';

  @override
  String get hdEmptyBody =>
      'Open the menu on a job and choose “Hide this job” to stop seeing it.';

  @override
  String hdCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden jobs',
      one: '1 hidden job',
    );
    return '$_temp0';
  }

  @override
  String get hdProfileSub => 'Jobs you chose not to see again';

  @override
  String get hdOpenListing => 'Open listing';

  @override
  String get hdSeeHidden => 'See hidden jobs';

  @override
  String get hdFilteredNote => 'Some jobs on this page are hidden.';

  @override
  String get profileHubSavedSearches => 'Saved searches and alerts';

  @override
  String get profileHubSavedSearchesSub =>
      'Searches you keep and the ones that alert you';

  @override
  String get rsTitle => 'Search history';

  @override
  String get rsSwitch => 'Remember my recent searches';

  @override
  String get rsBody =>
      'Only the words you search for, kept on this device and never sent to the server. Turning this off also forgets the ones already kept.';

  @override
  String get rsClear => 'Clear search history';

  @override
  String get rsCleared => 'Search history cleared';

  @override
  String get rsRecent => 'Recent searches';

  @override
  String get rcTitle => 'Recommended for you';

  @override
  String get rcSubtitle =>
      'Matched to your profile on this device: profession, skills, place, work mode and language.';

  @override
  String get rcSeeAll => 'See all';

  @override
  String get rcEmptyTitle => 'No matches right now';

  @override
  String get rcEmptyBody =>
      'No open job matches your profile at the moment. Save a search with alerts to hear about new ones.';

  @override
  String get rcNeedProfileTitle => 'Tell us what you do';

  @override
  String get rcNeedProfileBody =>
      'Add your profession, where you want to work and how to your profile, and OrbiJob ranks jobs for you. It works for any profession.';

  @override
  String get rcNeedProfileAction => 'Complete my profile';

  @override
  String get rcSignInBody =>
      'Sign in and fill in your profile to get recommendations.';

  @override
  String get rcThinNote =>
      'Your profile has little information, so these matches are broad. Add your profession for better ones.';

  @override
  String get rcFitStrong => 'Strong match';

  @override
  String get rcFitGood => 'Good match';

  @override
  String get rcFitPossible => 'Possible match';

  @override
  String get rcWhy => 'Why this job?';

  @override
  String get rcWhyTitle => 'Why you see this job';

  @override
  String get rcMatches => 'What matches';

  @override
  String get rcCheck => 'Worth checking';

  @override
  String get rcDisclaimer =>
      'OrbiJob compares the text of the listing with your profile. It does not check visas, work permits, professional registration or certifications: confirm the requirements in the listing.';

  @override
  String rcScore(int score) {
    return 'Score $score of 100';
  }

  @override
  String rcSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count criteria evaluated',
      one: '1 criterion evaluated',
    );
    return '$_temp0';
  }

  @override
  String rcReasonProfessionExact(String profession) {
    return 'The title mentions your profession: $profession';
  }

  @override
  String rcReasonProfessionClose(String profession) {
    return 'Close to your profession: $profession';
  }

  @override
  String rcReasonProfessionSynonym(String profession) {
    return 'Same profession, another language: $profession';
  }

  @override
  String rcReasonSameField(String area) {
    return 'Same general area only: $area';
  }

  @override
  String rcReasonSkills(String skills) {
    return 'Mentions your skills: $skills';
  }

  @override
  String rcReasonCountryInterest(String country) {
    return 'In $country, one of your countries of interest';
  }

  @override
  String rcReasonCountryResidence(String country) {
    return 'In $country, where you live';
  }

  @override
  String rcReasonRemoteEligible(String country) {
    return 'Remote and open to candidates from $country';
  }

  @override
  String get rcReasonRemoteAnywhere =>
      'Remote, open to candidates from anywhere';

  @override
  String rcReasonCity(String city) {
    return 'In $city';
  }

  @override
  String rcReasonWorkMode(String mode) {
    return '$mode, as you prefer';
  }

  @override
  String rcReasonLanguage(String language) {
    return 'Written in $language, a language of your profile';
  }

  @override
  String get rcCaveatLocation => 'The listing does not say where the job is.';

  @override
  String rcCaveatLanguage(String language) {
    return 'Written in $language, which your profile does not list.';
  }

  @override
  String rcCaveatEligibility(String places) {
    return 'The listing restricts who can apply: $places. Check that you qualify.';
  }

  @override
  String get rcCaveatMode =>
      'The listing does not say if it is remote, hybrid or on site.';

  @override
  String get pfMustTitle => 'Must-haves for recommendations';

  @override
  String get pfMustHelp =>
      'Turn on what a job must have to be recommended to you. Everything else is only a preference: it raises a job in the list but never hides it. A listing that does not say is never hidden.';

  @override
  String get pfMustWorkMode => 'Only my work mode';

  @override
  String get pfMustCountry => 'Only my countries';

  @override
  String get pfMustLanguage => 'Only my languages';

  @override
  String get applicationStageInterested => 'Interested';

  @override
  String get applicationStageHired => 'Hired';

  @override
  String get apPipelineAll => 'All';

  @override
  String get apStageHint =>
      'You decide the stage. OrbiJob never contacts the employer and never assumes you applied.';

  @override
  String get apAgendaTitle => 'Coming up';

  @override
  String get apAgendaInterview => 'Interview';

  @override
  String get apAgendaFollowUp => 'Follow up';

  @override
  String get apOverdue => 'Overdue';

  @override
  String get apAgendaOverdueHint =>
      'The date has passed. Update the stage or set a new date.';

  @override
  String get apDatesTitle => 'Dates';

  @override
  String get apInterviewLabel => 'Interview (date and time)';

  @override
  String get apFollowUpLabel => 'Follow up on';

  @override
  String get apDateNone => 'Not set';

  @override
  String get apDatePick => 'Choose';

  @override
  String get apDateClear => 'Clear';

  @override
  String get apDatesSaved => 'Date saved';

  @override
  String get apTrackInterest => 'Track this job';

  @override
  String get apTrackedInterest =>
      'Added to your applications as “interested”. Nothing was sent.';

  @override
  String get apAlreadyTracked => 'This job is already in your applications.';

  @override
  String apNextDate(String kind, String date) {
    return '$kind: $date';
  }

  @override
  String apPipelineCount(String stage, int count) {
    return '$stage ($count)';
  }

  @override
  String get apFilteredEmpty => 'No applications in this stage.';

  @override
  String get shShare => 'Share this job';

  @override
  String get shCopied => 'Link copied. Sharing is not available here.';

  @override
  String get shNoLink => 'This job has no link to share.';

  @override
  String get cpAdd => 'Add to comparison';

  @override
  String get cpRemove => 'Remove from comparison';

  @override
  String cpFull(int max) {
    return 'You can compare up to $max jobs. Remove one first.';
  }

  @override
  String get cpAdded => 'Added to the comparison';

  @override
  String cpBar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs picked',
      one: '1 job picked',
    );
    return '$_temp0';
  }

  @override
  String get cpCompare => 'Compare';

  @override
  String get cpClear => 'Clear';

  @override
  String get cpTitle => 'Compare jobs';

  @override
  String get cpNeedTwo =>
      'Pick at least two jobs to compare them. Use the menu on a job and choose “Add to comparison”.';

  @override
  String get cpHint =>
      'Only what each listing states is shown. Nothing is estimated or filled in: “Not stated” means the listing does not say.';

  @override
  String get cpNotStated => 'Not stated';

  @override
  String get cpRowCompany => 'Company';

  @override
  String get cpRowPlace => 'Location';

  @override
  String get cpRowMode => 'Work mode';

  @override
  String get cpRowContract => 'Contract';

  @override
  String get cpRowSalary => 'Salary';

  @override
  String get cpRowPublished => 'Published';

  @override
  String get cpRowSource => 'Source';

  @override
  String get cpRowLanguage => 'Listing language';

  @override
  String get cpRowEligibility => 'Who can apply';

  @override
  String get cpEligibilityAnywhere => 'Anywhere (as the source states)';

  @override
  String cpEligibilityRestricted(String places) {
    return 'Limited to: $places';
  }

  @override
  String get cpSalaryNote =>
      'The salaries use different currencies or periods and are shown as stated, without conversion.';

  @override
  String get cpOpenListing => 'Open the listing';

  @override
  String cpRemoveOne(String title) {
    return 'Remove $title from the comparison';
  }

  @override
  String get ntReminderInterview => 'Interview in the next 24 hours';

  @override
  String get ntReminderFollowUp => 'Follow-up day for this application';

  @override
  String get cpRowSkills => 'Skills listed';

  @override
  String get ntKindNewJob => 'New job';

  @override
  String get ntKindInterview => 'Interview';

  @override
  String get ntKindFollowUp => 'Follow-up';

  @override
  String get searchSuggestTitle => 'Try instead';

  @override
  String get searchSuggestHint =>
      'Broader or similarly spelled professions. These are only suggestions: the results are whatever the catalogue holds.';

  @override
  String get pdTitle => 'Your data';

  @override
  String get pdIntro =>
      'Take a copy of everything the app keeps about you, or erase your account for good.';

  @override
  String get pdSignInHint => 'Sign in to export or delete your data.';

  @override
  String get pdExportTitle => 'Export my data';

  @override
  String get pdExportBody =>
      'One ZIP with your profile, favorites, saved searches, applications, notes and the resume PDFs you uploaded. Passwords and push tokens are never included.';

  @override
  String get pdExportAction => 'Export my data';

  @override
  String get pdExportWorking => 'Preparing your export…';

  @override
  String get pdExportDone => 'Export created. Save it where you want.';

  @override
  String pdExportMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count resume files could not be included; they are listed in the data file.',
      one:
          '1 resume file could not be included; it is listed in the data file.',
    );
    return '$_temp0';
  }

  @override
  String get pdExportFailed =>
      'Could not prepare your export. Check your connection and try again.';

  @override
  String get pdDeleteTitle => 'Delete my account';

  @override
  String get pdDeleteBody =>
      'Permanently deletes your account and everything linked to it. This cannot be undone.';

  @override
  String get pdDeleteWhatTitle => 'What is deleted';

  @override
  String get pdDelete1 =>
      'Your profile, experiences, education, skills and languages';

  @override
  String get pdDelete2 => 'The resume PDFs you uploaded';

  @override
  String get pdDelete3 => 'Favorites, hidden jobs, saved searches and alerts';

  @override
  String get pdDelete4 => 'Applications, notes, reminders and notifications';

  @override
  String get pdDelete5 => 'The push-notification registration of your devices';

  @override
  String get pdDeleteKeeps =>
      'Job listings are public and stay in the catalogue. If you want a copy of your data, export it first.';

  @override
  String get pdDeletePassword => 'Current password';

  @override
  String get pdDeleteConfirmCheck => 'I understand this cannot be undone';

  @override
  String get pdDeleteAction => 'Delete permanently';

  @override
  String get pdDeleteWrongPassword =>
      'That password is not correct. Nothing was deleted.';

  @override
  String get pdDeleteFailed =>
      'Could not delete the account right now. Nothing was lost; try again in a moment.';

  @override
  String get pdDeleted => 'Your account was deleted';

  @override
  String get pdLinkPrivacy => 'Privacy policy';

  @override
  String get pdLinkTerms => 'Terms of use';

  @override
  String get pdLinkDeletion => 'Account and data deletion';

  @override
  String get pdDeletedBody =>
      'Your account and all the data linked to it were permanently deleted. You will now be signed out on this device.';

  @override
  String get pdDeletedAction => 'OK';

  @override
  String rcReasonProfessionGroup(String profession) {
    return 'Same occupation group as your profession: $profession';
  }

  @override
  String rcReasonProfessionRelated(String profession) {
    return 'Related profession, not the same: $profession';
  }

  @override
  String officialPortalEmptyBody(String country) {
    return 'OrbiJob has no listings for $country for these filters. That country\'s own public employment service lists vacancies itself; OrbiJob does not copy them, the button opens the service.';
  }

  @override
  String get officialPortalButton => 'Official employment service';
}
