import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OrbiJob'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navApplications.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get navApplications;

  /// No description provided for @navMain.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get navMain;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you looking for?'**
  String get homeTitle;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Any profession, any country'**
  String get homeSearchHint;

  /// No description provided for @homeAreasTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse by area'**
  String get homeAreasTitle;

  /// No description provided for @areaTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get areaTechnology;

  /// No description provided for @areaHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get areaHealth;

  /// No description provided for @areaConstruction.
  ///
  /// In en, this message translates to:
  /// **'Construction'**
  String get areaConstruction;

  /// No description provided for @areaEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get areaEducation;

  /// No description provided for @areaServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get areaServices;

  /// No description provided for @areaIndustry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get areaIndustry;

  /// No description provided for @areaTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get areaTransport;

  /// No description provided for @homeForYouTitle.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get homeForYouTitle;

  /// No description provided for @homeForYouEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches yet'**
  String get homeForYouEmptyTitle;

  /// No description provided for @homeForYouEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Matches appear here once job sources are connected and your profile is filled in.'**
  String get homeForYouEmptyBody;

  /// No description provided for @homeApplicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get homeApplicationsTitle;

  /// No description provided for @homeApplicationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No applications tracked'**
  String get homeApplicationsEmptyTitle;

  /// No description provided for @homeApplicationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Track where you applied, interviews and offers.'**
  String get homeApplicationsEmptyBody;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Any profession, e.g. electrician, nurse, Flutter developer'**
  String get searchHint;

  /// No description provided for @searchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search jobs'**
  String get searchLabel;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @exploreIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'Search for any profession'**
  String get exploreIdleTitle;

  /// No description provided for @exploreIdleBody.
  ///
  /// In en, this message translates to:
  /// **'Type a profession or pick an area. Results only ever come from approved sources.'**
  String get exploreIdleBody;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searching;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No jobs found'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try another profession or a broader search.'**
  String get emptyBody;

  /// No description provided for @noSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'No integrated source for this search'**
  String get noSourceTitle;

  /// No description provided for @noSourceBody.
  ///
  /// In en, this message translates to:
  /// **'We do not have an authorised source for this country and profession yet. Try the original job portals.'**
  String get noSourceBody;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorBody.
  ///
  /// In en, this message translates to:
  /// **'We could not load results. Check your connection and try again.'**
  String get errorBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesTitle;

  /// No description provided for @favoritesBody.
  ///
  /// In en, this message translates to:
  /// **'Saved jobs appear here.'**
  String get favoritesBody;

  /// No description provided for @applicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No applications tracked'**
  String get applicationsTitle;

  /// No description provided for @applicationsBody.
  ///
  /// In en, this message translates to:
  /// **'Track where you applied, interviews and offers. Status is updated manually.'**
  String get applicationsBody;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your professional profile is coming soon'**
  String get profileEmptyTitle;

  /// No description provided for @profileEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Résumé, experience and preferences will live here.'**
  String get profileEmptyBody;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @workModeRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get workModeRemote;

  /// No description provided for @workModeHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get workModeHybrid;

  /// No description provided for @workModeOnsite.
  ///
  /// In en, this message translates to:
  /// **'On-site'**
  String get workModeOnsite;

  /// No description provided for @compatibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Compatibility'**
  String get compatibilityLabel;

  /// No description provided for @compatibilityValue.
  ///
  /// In en, this message translates to:
  /// **'Compatibility {score} out of 100'**
  String compatibilityValue(int score);

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidenceLabel;

  /// No description provided for @confidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get confidenceHigh;

  /// No description provided for @confidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get confidenceMedium;

  /// No description provided for @confidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get confidenceLow;

  /// No description provided for @confidenceSemantic.
  ///
  /// In en, this message translates to:
  /// **'Analysis confidence: {level}'**
  String confidenceSemantic(String level);

  /// No description provided for @scoreExplainer.
  ///
  /// In en, this message translates to:
  /// **'Compatibility and confidence are separate measures.'**
  String get scoreExplainer;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {name}'**
  String sourceLabel(String name);

  /// No description provided for @favoriteAdd.
  ///
  /// In en, this message translates to:
  /// **'Save job'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favoriteRemove;

  /// No description provided for @perHour.
  ///
  /// In en, this message translates to:
  /// **'/h'**
  String get perHour;

  /// No description provided for @perDay.
  ///
  /// In en, this message translates to:
  /// **'/day'**
  String get perDay;

  /// No description provided for @perWeek.
  ///
  /// In en, this message translates to:
  /// **'/week'**
  String get perWeek;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get perMonth;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'/year'**
  String get perYear;

  /// No description provided for @publishedToday.
  ///
  /// In en, this message translates to:
  /// **'Posted today'**
  String get publishedToday;

  /// No description provided for @publishedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Posted yesterday'**
  String get publishedYesterday;

  /// No description provided for @publishedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Posted {count} days ago'**
  String publishedDaysAgo(int count);

  /// No description provided for @publishedWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Posted 1 week ago} other{Posted {count} weeks ago}}'**
  String publishedWeeksAgo(int count);

  /// No description provided for @publishedMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Posted 1 month ago} other{Posted {count} months ago}}'**
  String publishedMonthsAgo(int count);

  /// No description provided for @jobDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Job details'**
  String get jobDetailTitle;

  /// No description provided for @openOfficialApplication.
  ///
  /// In en, this message translates to:
  /// **'Open official application'**
  String get openOfficialApplication;

  /// No description provided for @selectJobHint.
  ///
  /// In en, this message translates to:
  /// **'Select a job to see its details.'**
  String get selectJobHint;

  /// No description provided for @resultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String resultsCount(int count);

  /// No description provided for @previewBanner.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW · ILLUSTRATIVE DATA, NOT REAL JOBS'**
  String get previewBanner;

  /// No description provided for @previewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview only: this action is not available.'**
  String get previewAction;

  /// No description provided for @jobLanguageSemantic.
  ///
  /// In en, this message translates to:
  /// **'Posting language: {code}'**
  String jobLanguageSemantic(String code);

  /// No description provided for @originalLanguageNote.
  ///
  /// In en, this message translates to:
  /// **'Shown in its original language ({code}). Job titles, company names and descriptions are not translated.'**
  String originalLanguageNote(String code);

  /// No description provided for @recentSearchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearchesTitle;

  /// No description provided for @recentSearchesClear.
  ///
  /// In en, this message translates to:
  /// **'Clear recent searches'**
  String get recentSearchesClear;

  /// No description provided for @interestCountriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Countries of interest'**
  String get interestCountriesTitle;

  /// No description provided for @interestCountriesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No countries chosen yet'**
  String get interestCountriesEmptyTitle;

  /// No description provided for @interestCountriesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'You will pick countries in your profile to focus recommendations.'**
  String get interestCountriesEmptyBody;

  /// No description provided for @applicationStageApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get applicationStageApplied;

  /// No description provided for @applicationStageScreening.
  ///
  /// In en, this message translates to:
  /// **'Screening'**
  String get applicationStageScreening;

  /// No description provided for @applicationStageInterview.
  ///
  /// In en, this message translates to:
  /// **'Interview'**
  String get applicationStageInterview;

  /// No description provided for @applicationStageOffer.
  ///
  /// In en, this message translates to:
  /// **'Offer'**
  String get applicationStageOffer;

  /// No description provided for @applicationStageRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get applicationStageRejected;

  /// No description provided for @applicationStageWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get applicationStageWithdrawn;

  /// No description provided for @applicationStageClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get applicationStageClosed;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts are not enabled in this build'**
  String get accountUnavailableTitle;

  /// No description provided for @accountUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Everything works on this device without signing in. Sync arrives once the service is connected.'**
  String get accountUnavailableBody;

  /// No description provided for @accountSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String accountSignedInAs(String email);

  /// No description provided for @accountSignedInNoEmail.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedInNoEmail;

  /// No description provided for @accountSignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your profile, favourites and applications in your account.'**
  String get accountSignedOutBody;

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountSignIn;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInTitle;

  /// No description provided for @authSignUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUpTitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authSignInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInAction;

  /// No description provided for @authSignUpAction.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUpAction;

  /// No description provided for @authSwitchToSignUp.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get authSwitchToSignUp;

  /// No description provided for @authSwitchToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authSwitchToSignIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get authForgotPassword;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid e-mail'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get authPasswordShort;

  /// No description provided for @authConfirmationSent.
  ///
  /// In en, this message translates to:
  /// **'Check your e-mail to confirm the account, then sign in.'**
  String get authConfirmationSent;

  /// No description provided for @authResetSent.
  ///
  /// In en, this message translates to:
  /// **'If the address has an account, a reset link is on its way.'**
  String get authResetSent;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'E-mail or password is incorrect.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your e-mail first. Check your inbox.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This e-mail is already registered. Try signing in.'**
  String get authErrorEmailTaken;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'This e-mail address is not valid.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use a longer, less common one.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get authErrorRateLimited;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the internet and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is unavailable right now.'**
  String get authErrorUnavailable;

  /// No description provided for @authErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get authErrorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
