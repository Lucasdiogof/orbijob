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
  /// **'Add countries in your profile to focus on them.'**
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
  /// **'Sign in to keep your profile, favorites and applications in your account.'**
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

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get commonRequired;

  /// No description provided for @commonDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get commonDeleteConfirmBody;

  /// No description provided for @fieldStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get fieldStartDate;

  /// No description provided for @fieldEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get fieldEndDate;

  /// No description provided for @dateChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get dateChoose;

  /// No description provided for @dateClear.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get dateClear;

  /// No description provided for @tooLongError.
  ///
  /// In en, this message translates to:
  /// **'Too long (maximum {max} characters)'**
  String tooLongError(int max);

  /// No description provided for @dataLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load your data'**
  String get dataLoadErrorTitle;

  /// No description provided for @dataSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get dataSignInTitle;

  /// No description provided for @dataFailureNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'This build is not connected to an account service, so nothing can be saved here.'**
  String get dataFailureNotConfigured;

  /// No description provided for @dataFailureSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Your data is kept in your account. Sign in to see and change it.'**
  String get dataFailureSignedOut;

  /// No description provided for @dataFailureSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again to continue.'**
  String get dataFailureSessionExpired;

  /// No description provided for @dataFailureNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get dataFailureNetwork;

  /// No description provided for @dataFailureDenied.
  ///
  /// In en, this message translates to:
  /// **'The server did not allow this action for your account.'**
  String get dataFailureDenied;

  /// No description provided for @dataFailureQuota.
  ///
  /// In en, this message translates to:
  /// **'You reached the limit for this kind of item. Remove one to add another.'**
  String get dataFailureQuota;

  /// No description provided for @dataFailureDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This already exists.'**
  String get dataFailureDuplicate;

  /// No description provided for @dataFailureInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some data is not valid. Check the fields and try again.'**
  String get dataFailureInvalid;

  /// No description provided for @dataFailureTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than 5 MB.'**
  String get dataFailureTooLarge;

  /// No description provided for @dataFailureNotPdf.
  ///
  /// In en, this message translates to:
  /// **'Only PDF files are accepted.'**
  String get dataFailureNotPdf;

  /// No description provided for @dataFailureEmptyFile.
  ///
  /// In en, this message translates to:
  /// **'The file is empty.'**
  String get dataFailureEmptyFile;

  /// No description provided for @dataFailureNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item no longer exists. Refresh and try again.'**
  String get dataFailureNotFound;

  /// No description provided for @dataFailureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is unavailable right now. Try again later.'**
  String get dataFailureUnavailable;

  /// No description provided for @dataFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get dataFailureUnknown;

  /// No description provided for @applicationsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add application'**
  String get applicationsAdd;

  /// No description provided for @applicationsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'OrbiJob never sends applications. Here you record the ones you sent yourself.'**
  String get applicationsDisclaimer;

  /// No description provided for @applicationNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New application'**
  String get applicationNewTitle;

  /// No description provided for @applicationDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get applicationDetailTitle;

  /// No description provided for @applicationCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get applicationCompany;

  /// No description provided for @applicationJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job title'**
  String get applicationJobTitle;

  /// No description provided for @applicationLink.
  ///
  /// In en, this message translates to:
  /// **'Link to the posting'**
  String get applicationLink;

  /// No description provided for @applicationLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a link starting with https://'**
  String get applicationLinkInvalid;

  /// No description provided for @applicationChannel.
  ///
  /// In en, this message translates to:
  /// **'Where you applied'**
  String get applicationChannel;

  /// No description provided for @applicationStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get applicationStageLabel;

  /// No description provided for @applicationAppliedOn.
  ///
  /// In en, this message translates to:
  /// **'Applied on'**
  String get applicationAppliedOn;

  /// No description provided for @applicationNote.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get applicationNote;

  /// No description provided for @applicationSaveNote.
  ///
  /// In en, this message translates to:
  /// **'Save notes'**
  String get applicationSaveNote;

  /// No description provided for @applicationOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open posting'**
  String get applicationOpenLink;

  /// No description provided for @applicationLinkCannotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get applicationLinkCannotOpen;

  /// No description provided for @applicationHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get applicationHistory;

  /// No description provided for @applicationHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stage changes recorded yet.'**
  String get applicationHistoryEmpty;

  /// No description provided for @applicationDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this application?'**
  String get applicationDeleteTitle;

  /// No description provided for @applicationNoDate.
  ///
  /// In en, this message translates to:
  /// **'Date not informed'**
  String get applicationNoDate;

  /// No description provided for @homeApplicationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 application tracked} other{{count} applications tracked}}'**
  String homeApplicationsCount(int count);

  /// No description provided for @profileSectionProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional profile'**
  String get profileSectionProfessional;

  /// No description provided for @profileCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your professional profile'**
  String get profileCreateTitle;

  /// No description provided for @profileCreateBody.
  ///
  /// In en, this message translates to:
  /// **'Say who you are professionally. Any profession is welcome.'**
  String get profileCreateBody;

  /// No description provided for @profileCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get profileCreateAction;

  /// No description provided for @profileEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditAction;

  /// No description provided for @profileFieldName.
  ///
  /// In en, this message translates to:
  /// **'Professional name'**
  String get profileFieldName;

  /// No description provided for @profileFieldHeadline.
  ///
  /// In en, this message translates to:
  /// **'Role or profession'**
  String get profileFieldHeadline;

  /// No description provided for @profileFieldSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get profileFieldSummary;

  /// No description provided for @profileFieldCountry.
  ///
  /// In en, this message translates to:
  /// **'Country of residence (2-letter code)'**
  String get profileFieldCountry;

  /// No description provided for @profileFieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileFieldCity;

  /// No description provided for @profileFieldWorkMode.
  ///
  /// In en, this message translates to:
  /// **'Preferred work mode'**
  String get profileFieldWorkMode;

  /// No description provided for @profileWorkModeAny.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get profileWorkModeAny;

  /// No description provided for @profileFieldSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get profileFieldSkills;

  /// No description provided for @profileSkillAdd.
  ///
  /// In en, this message translates to:
  /// **'Add skill'**
  String get profileSkillAdd;

  /// No description provided for @profileSkillRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove skill {name}'**
  String profileSkillRemove(String name);

  /// No description provided for @profileSkillsLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to 200 skills.'**
  String get profileSkillsLimit;

  /// No description provided for @profileCountryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a 2-letter code, for example BR'**
  String get profileCountryInvalid;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @profileNeedsProfile.
  ///
  /// In en, this message translates to:
  /// **'Create your profile first to add this.'**
  String get profileNeedsProfile;

  /// No description provided for @profileSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create and keep your professional profile.'**
  String get profileSignInBody;

  /// No description provided for @experienceSection.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get experienceSection;

  /// No description provided for @experienceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add experience'**
  String get experienceAdd;

  /// No description provided for @experienceNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New experience'**
  String get experienceNewTitle;

  /// No description provided for @experienceEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit experience'**
  String get experienceEditTitle;

  /// No description provided for @experienceCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get experienceCompany;

  /// No description provided for @experienceRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get experienceRole;

  /// No description provided for @experienceCurrent.
  ///
  /// In en, this message translates to:
  /// **'I currently work here'**
  String get experienceCurrent;

  /// No description provided for @experienceDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get experienceDescription;

  /// No description provided for @experiencePresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get experiencePresent;

  /// No description provided for @experienceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No experience added yet.'**
  String get experienceEmpty;

  /// No description provided for @experienceDatesInvalid.
  ///
  /// In en, this message translates to:
  /// **'The end date must not be before the start date'**
  String get experienceDatesInvalid;

  /// No description provided for @experienceCurrentNeedsStart.
  ///
  /// In en, this message translates to:
  /// **'Choose a start date for a current job'**
  String get experienceCurrentNeedsStart;

  /// No description provided for @experienceDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this experience?'**
  String get experienceDeleteTitle;

  /// No description provided for @educationSection.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get educationSection;

  /// No description provided for @educationAdd.
  ///
  /// In en, this message translates to:
  /// **'Add education'**
  String get educationAdd;

  /// No description provided for @educationNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New education'**
  String get educationNewTitle;

  /// No description provided for @educationEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit education'**
  String get educationEditTitle;

  /// No description provided for @educationInstitution.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get educationInstitution;

  /// No description provided for @educationDegree.
  ///
  /// In en, this message translates to:
  /// **'Degree (if any)'**
  String get educationDegree;

  /// No description provided for @educationField.
  ///
  /// In en, this message translates to:
  /// **'Course or field of study'**
  String get educationField;

  /// No description provided for @educationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No education added. It is optional.'**
  String get educationEmpty;

  /// No description provided for @educationDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this education?'**
  String get educationDeleteTitle;

  /// No description provided for @resumesSection.
  ///
  /// In en, this message translates to:
  /// **'Résumés'**
  String get resumesSection;

  /// No description provided for @resumesBody.
  ///
  /// In en, this message translates to:
  /// **'PDF only, up to 5 MB each, up to 10 files. Stored privately in your account.'**
  String get resumesBody;

  /// No description provided for @resumesUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get resumesUpload;

  /// No description provided for @resumesUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get resumesUploading;

  /// No description provided for @resumesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No résumé uploaded yet.'**
  String get resumesEmpty;

  /// No description provided for @resumeItem.
  ///
  /// In en, this message translates to:
  /// **'Résumé from {date}'**
  String resumeItem(String date);

  /// No description provided for @resumeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get resumeOpen;

  /// No description provided for @resumeUploaded.
  ///
  /// In en, this message translates to:
  /// **'Résumé uploaded'**
  String get resumeUploaded;

  /// No description provided for @resumeDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this résumé?'**
  String get resumeDeleteTitle;

  /// No description provided for @resumeDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The file is removed from your account.'**
  String get resumeDeleteBody;

  /// No description provided for @preferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Search preferences'**
  String get preferencesSection;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystem;

  /// No description provided for @languagePt.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get languagePt;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageEs.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageEs;

  /// No description provided for @preferencesLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep these choices in your account. Until then they only apply on this device.'**
  String get preferencesLocalOnly;

  /// No description provided for @countriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Countries of interest'**
  String get countriesTitle;

  /// No description provided for @countriesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a country (2-letter code)'**
  String get countriesHint;

  /// No description provided for @countriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No countries chosen.'**
  String get countriesEmpty;

  /// No description provided for @countriesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a 2-letter code that is not already in the list, for example DE'**
  String get countriesInvalid;

  /// No description provided for @countriesRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove country {code}'**
  String countriesRemove(String code);

  /// No description provided for @savedSearchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved searches'**
  String get savedSearchesTitle;

  /// No description provided for @savedSearchesNote.
  ///
  /// In en, this message translates to:
  /// **'Kept in your account.'**
  String get savedSearchesNote;

  /// No description provided for @recentSearchesNote.
  ///
  /// In en, this message translates to:
  /// **'Recent searches stay on this device.'**
  String get recentSearchesNote;

  /// No description provided for @savedSearchSave.
  ///
  /// In en, this message translates to:
  /// **'Save this search'**
  String get savedSearchSave;

  /// No description provided for @savedSearchSaved.
  ///
  /// In en, this message translates to:
  /// **'Search saved'**
  String get savedSearchSaved;

  /// No description provided for @savedSearchRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove saved search {term}'**
  String savedSearchRemove(String term);

  /// No description provided for @authNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get authNewPasswordTitle;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPasswordLabel;

  /// No description provided for @authNewPasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get authNewPasswordAction;

  /// No description provided for @authPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get authPasswordChanged;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again.'**
  String get authSessionExpired;

  /// No description provided for @authErrorLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'This link has expired or was already used. Request a new one.'**
  String get authErrorLinkInvalid;

  /// No description provided for @authErrorSamePassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password different from the current one.'**
  String get authErrorSamePassword;

  /// No description provided for @authCancelRecovery.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authCancelRecovery;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// No description provided for @filtersButton.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersButton;

  /// No description provided for @filtersButtonCount.
  ///
  /// In en, this message translates to:
  /// **'Filters ({count})'**
  String filtersButtonCount(int count);

  /// No description provided for @filtersClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get filtersClear;

  /// No description provided for @filterWorkMode.
  ///
  /// In en, this message translates to:
  /// **'Work mode'**
  String get filterWorkMode;

  /// No description provided for @filterPublished.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get filterPublished;

  /// No description provided for @filterPublished1.
  ///
  /// In en, this message translates to:
  /// **'Last 24 hours'**
  String get filterPublished1;

  /// No description provided for @filterPublished7.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get filterPublished7;

  /// No description provided for @filterPublished30.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get filterPublished30;

  /// No description provided for @filterWithSalary.
  ///
  /// In en, this message translates to:
  /// **'Only with salary'**
  String get filterWithSalary;

  /// No description provided for @filterCountry.
  ///
  /// In en, this message translates to:
  /// **'Country (from your profile)'**
  String get filterCountry;

  /// No description provided for @browseLatest.
  ///
  /// In en, this message translates to:
  /// **'Show latest jobs'**
  String get browseLatest;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get loadMore;

  /// No description provided for @loadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more jobs.'**
  String get loadMoreFailed;

  /// No description provided for @resultsShown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Showing 1 job} other{Showing {count} jobs}}'**
  String resultsShown(int count);

  /// No description provided for @emptyFiltersBody.
  ///
  /// In en, this message translates to:
  /// **'No jobs match these filters. Try removing some.'**
  String get emptyFiltersBody;

  /// No description provided for @openOriginalListing.
  ///
  /// In en, this message translates to:
  /// **'Open original listing'**
  String get openOriginalListing;

  /// No description provided for @eligibleIn.
  ///
  /// In en, this message translates to:
  /// **'Open to applicants in: {places}'**
  String eligibleIn(String places);

  /// No description provided for @jobDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get jobDescriptionTitle;
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
