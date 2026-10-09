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
  String get profileEmptyTitle => 'Your professional profile is coming soon';

  @override
  String get profileEmptyBody =>
      'Résumé, experience and preferences will live here.';

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
      'You will pick countries in your profile to focus recommendations.';

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
      'Sign in to keep your profile, favourites and applications in your account.';

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
}
