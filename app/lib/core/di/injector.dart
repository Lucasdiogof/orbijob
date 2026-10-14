import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/applications/applications_cubit.dart';
import '../../features/browser/browser_engine.dart';
import '../../features/browser/link_share.dart';
import '../../features/browser/webview_engine.dart';
import '../../features/translation/engine_factory.dart';
import '../../features/translation/translation_cache.dart';
import '../../features/translation/translation_cubit.dart';
import '../../features/translation/translation_engine.dart';
import '../../features/translation/translation_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/applications/data/supabase_applications_repository.dart';
import '../../features/applications/domain/application_record.dart';
import '../../features/auth/data/unconfigured_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/data/prefs_recovery_marker.dart';
import '../../features/favorites/data/supabase_favorites_repository.dart';
import '../../features/favorites/domain/favorites_repository.dart';
import '../../features/preferences/data/supabase_preferences_repository.dart';
import '../../features/preferences/domain/user_preferences.dart';
import '../../features/preferences/presentation/preferences_cubit.dart';
import '../../features/compare/compare_cubit.dart';
import '../../features/hidden/data/supabase_hidden_jobs_repository.dart';
import '../../features/hidden/domain/hidden_jobs_repository.dart';
import '../../features/hidden/presentation/hidden_jobs_cubit.dart';
import '../../features/notifications/data/supabase_notifications_repository.dart';
import '../../features/recommendations/presentation/recommendations_cubit.dart';
import '../../features/notifications/domain/notifications_repository.dart';
import '../../features/notifications/presentation/notifications_cubit.dart';
import '../../features/searches/data/supabase_saved_searches_repository.dart';
import '../../features/searches/domain/saved_search.dart';
import '../../features/searches/presentation/saved_searches_cubit.dart';
import '../../features/profile/data/file_picker_pdf_picker.dart';
import '../../features/profile/data/supabase_profile_repository.dart';
import '../../features/profile/data/supabase_resume_repository.dart';
import '../../features/profile/domain/pdf_picker.dart';
import '../../features/profile/domain/professional_profile.dart';
import '../../features/profile/domain/resume_repository.dart';
import '../../features/profile/presentation/profile_cubit.dart';
import '../../features/profile/presentation/resumes_cubit.dart';

import '../../features/favorites/favorites_cubit.dart';
import '../../features/home/latest_jobs_cubit.dart';
import '../../features/home/recent_searches_cubit.dart';
import '../../features/search/data/supabase_job_catalog_repository.dart';
import '../../features/search/domain/search_repository.dart';
import '../../features/search/presentation/cubit/areas_cubit.dart';
import '../../features/search/presentation/cubit/specialties_cubit.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../../features/shell/shell_cubit.dart';
import '../locale_cubit.dart';
import '../theme_cubit.dart';
import '../../features/privacy/data/supabase_account_data_repository.dart';
import '../../features/privacy/domain/account_data_repository.dart';
import '../../features/push/data/supabase_push_devices_repository.dart';
import '../../features/push/domain/push_messaging.dart';
import '../../features/push/push_registrar.dart';

final sl = GetIt.instance;

/// Registers the app graph. [searchRepository] lets previews and tests plug another source; without one, a build with a
/// Supabase configuration reads the job catalogue ([registerSupabaseRepositories]) and a build without it reports
/// "not connected" (never "no integrated source", which means the backend answered that no source covers a search).
/// A registered dependency, or null when this build does not have it (no Supabase configuration). Cubits receive
/// null and report "not configured" instead of pretending to store data.
T? maybe<T extends Object>() => sl.isRegistered<T>() ? sl<T>() : null;

void configureDependencies({
  SearchRepository? searchRepository,
  AuthRepository? authRepository,
  FavoritesRepository? favoritesRepository,
  PdfPicker? pdfPicker,
  BrowserEngine? browserEngine,
  LinkShare? linkShare,
  TextShare? textShare,
  TranslationEngine? translationEngine,
  TranslationCache? translationCache,
  SharedPreferences? preferences,
  PushMessaging? pushMessaging,

  /// How often the open app re-reads the notifications; null = never (tests, which must not leave a timer behind).
  Duration? notificationsRefresh = const Duration(minutes: 5),
}) {
  if (favoritesRepository != null) {
    sl.registerLazySingleton<FavoritesRepository>(() => favoritesRepository);
  }
  if (searchRepository != null) {
    sl.registerLazySingleton<SearchRepository>(() => searchRepository);
  }
  sl
    ..registerLazySingleton<BrowserEngine>(
      () => browserEngine ?? const WebViewBrowserEngine(),
    )
    ..registerLazySingleton<LinkShare>(() => linkShare ?? shareLinkWithSystem)
    ..registerLazySingleton<TextShare>(() => textShare ?? shareTextWithSystem)
    ..registerLazySingleton<TranslationService>(
      () => TranslationService(
        engine: translationEngine ?? createPlatformEngine(),
        cache: translationCache ?? PrefsTranslationCache(),
      ),
    )
    ..registerLazySingleton<TranslationCubit>(
      () => TranslationCubit(sl<TranslationService>(), prefs: preferences),
    )
    ..registerLazySingleton<PdfPicker>(() => pdfPicker ?? FilePickerPdfPicker())
    ..registerLazySingleton<AuthRepository>(
      () => authRepository ?? UnconfiguredAuthRepository(),
    )
    ..registerLazySingleton<PushRegistrar>(
      () => PushRegistrar(
        pushMessaging ?? const NoPushMessaging(),
        maybe<PushDevicesRepository>(),
      ),
    )
    ..registerFactory<AuthCubit>(
      () => AuthCubit(
        sl<AuthRepository>(),
        recoveryMarker: preferences == null
            ? null
            : PrefsRecoveryMarker(preferences),
        beforeSignOut: sl<PushRegistrar>().beforeSignOut,
        afterAccountDeleted: () async {
          sl<RecentSearchesCubit>().clear();
          await sl<TranslationService>().cache.clear();
        },
      ),
    )
    ..registerLazySingleton<RecentSearchesCubit>(
      () => RecentSearchesCubit(
        prefs: preferences,
        debounce: notificationsRefresh == null
            ? Duration.zero
            : const Duration(milliseconds: 800),
      ),
    )
    ..registerFactory<SearchCubit>(
      () => SearchCubit(
        maybe<SearchRepository>() ?? UnconfiguredSearchRepository(),
        onQuery: sl<RecentSearchesCubit>().record,
      ),
    )
    ..registerFactory<AreasCubit>(() => AreasCubit(maybe<SearchRepository>()))
    ..registerFactory<SpecialtiesCubit>(
      () => SpecialtiesCubit(maybe<SearchRepository>()),
    )
    ..registerFactory<LatestJobsCubit>(
      () => LatestJobsCubit(
        maybe<SearchRepository>() ?? UnconfiguredSearchRepository(),
      ),
    )
    ..registerFactory<RemoteJobsCubit>(
      () => RemoteJobsCubit(
        maybe<SearchRepository>() ?? UnconfiguredSearchRepository(),
      ),
    )
    ..registerFactory<ThemeCubit>(ThemeCubit.new)
    ..registerFactory<LocaleCubit>(LocaleCubit.new)
    ..registerFactory<ShellCubit>(ShellCubit.new)
    ..registerFactory<FavoritesCubit>(
      () => FavoritesCubit(maybe<FavoritesRepository>()),
    )
    ..registerFactory<ProfileCubit>(
      () => ProfileCubit(maybe<ProfileRepository>()),
    )
    ..registerFactory<ApplicationsCubit>(
      () => ApplicationsCubit(maybe<ApplicationsRepository>()),
    )
    ..registerFactory<PreferencesCubit>(
      () => PreferencesCubit(maybe<PreferencesRepository>()),
    )
    ..registerFactory<RecommendationsCubit>(
      () => RecommendationsCubit(maybe<SearchRepository>()),
    )
    ..registerFactory<CompareCubit>(CompareCubit.new)
    ..registerFactory<HiddenJobsCubit>(
      () => HiddenJobsCubit(maybe<HiddenJobsRepository>()),
    )
    ..registerFactory<NotificationsCubit>(
      () => NotificationsCubit(
        maybe<NotificationsRepository>(),
        maybe<AccountSettingsRepository>(),
        refreshEvery: notificationsRefresh,
      ),
    )
    ..registerFactory<SavedSearchesCubit>(
      () => SavedSearchesCubit(maybe<SavedSearchesRepository>()),
    )
    ..registerFactoryParam<ResumesCubit, String, void>(
      (profileId, _) => ResumesCubit(maybe<ResumeRepository>(), profileId),
    );
}

/// Registers the Supabase-backed repositories. Called once at start-up, only when a public configuration exists.
/// The screens read them through their Cubits (see [maybe]); a repository registered earlier (previews, tests) wins.
void registerSupabaseRepositories(SupabaseClient client) {
  if (!sl.isRegistered<PushDevicesRepository>()) {
    sl.registerLazySingleton<PushDevicesRepository>(
      () => SupabasePushDevicesRepository(client),
    );
  }
  if (!sl.isRegistered<FavoritesRepository>()) {
    sl.registerLazySingleton<FavoritesRepository>(
      () => SupabaseFavoritesRepository(client),
    );
  }
  if (!sl.isRegistered<SearchRepository>()) {
    sl.registerLazySingleton<SearchRepository>(
      () => SupabaseJobCatalogRepository(
        client,
        maxVerificationAge: jobMaxVerificationAge(
          const int.fromEnvironment(
            'JOB_MAX_VERIFICATION_HOURS',
            defaultValue: 72,
          ),
        ),
      ),
    );
  }
  sl
    ..registerLazySingleton<ProfileRepository>(
      () => SupabaseProfileRepository(client),
    )
    ..registerLazySingleton<ResumeRepository>(
      () => SupabaseResumeRepository(client),
    )
    ..registerLazySingleton<ApplicationsRepository>(
      () => SupabaseApplicationsRepository(client),
    )
    ..registerLazySingleton<PreferencesRepository>(
      () => SupabasePreferencesRepository(client),
    )
    ..registerLazySingleton<SavedSearchesRepository>(
      () => SupabaseSavedSearchesRepository(client),
    )
    ..registerLazySingleton<HiddenJobsRepository>(
      () => SupabaseHiddenJobsRepository(client),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => SupabaseNotificationsRepository(client),
    )
    ..registerLazySingleton<AccountDataRepository>(
      () => SupabaseAccountDataRepository(client),
    )
    ..registerLazySingleton<AccountSettingsRepository>(
      () => SupabaseAccountSettingsRepository(client),
    );
}
