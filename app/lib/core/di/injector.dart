import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/applications/applications_cubit.dart';
import '../../features/applications/data/supabase_applications_repository.dart';
import '../../features/applications/domain/application_record.dart';
import '../../features/auth/data/unconfigured_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/favorites/data/supabase_favorites_repository.dart';
import '../../features/favorites/domain/favorites_repository.dart';
import '../../features/preferences/data/supabase_preferences_repository.dart';
import '../../features/preferences/domain/user_preferences.dart';
import '../../features/preferences/presentation/preferences_cubit.dart';
import '../../features/preferences/presentation/saved_searches_cubit.dart';
import '../../features/profile/data/file_picker_pdf_picker.dart';
import '../../features/profile/data/supabase_profile_repository.dart';
import '../../features/profile/data/supabase_resume_repository.dart';
import '../../features/profile/domain/pdf_picker.dart';
import '../../features/profile/domain/professional_profile.dart';
import '../../features/profile/domain/resume_repository.dart';
import '../../features/profile/presentation/profile_cubit.dart';
import '../../features/profile/presentation/resumes_cubit.dart';

import '../../features/favorites/favorites_cubit.dart';
import '../../features/home/recent_searches_cubit.dart';
import '../../features/search/data/supabase_job_catalog_repository.dart';
import '../../features/search/domain/search_repository.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../../features/shell/shell_cubit.dart';
import '../locale_cubit.dart';
import '../theme_cubit.dart';

final sl = GetIt.instance;

/// Registers the app graph. [searchRepository] lets previews and tests plug another source; without one, a build with a
/// Supabase configuration reads the job catalogue ([registerSupabaseRepositories]) and a build without it honestly
/// reports "no integrated source".
/// A registered dependency, or null when this build does not have it (no Supabase configuration). Cubits receive
/// null and report "not configured" instead of pretending to store data.
T? maybe<T extends Object>() => sl.isRegistered<T>() ? sl<T>() : null;

void configureDependencies({
  SearchRepository? searchRepository,
  AuthRepository? authRepository,
  FavoritesRepository? favoritesRepository,
  PdfPicker? pdfPicker,
}) {
  if (favoritesRepository != null) {
    sl.registerLazySingleton<FavoritesRepository>(() => favoritesRepository);
  }
  if (searchRepository != null) {
    sl.registerLazySingleton<SearchRepository>(() => searchRepository);
  }
  sl
    ..registerLazySingleton<PdfPicker>(() => pdfPicker ?? FilePickerPdfPicker())
    ..registerLazySingleton<AuthRepository>(
      () => authRepository ?? UnconfiguredAuthRepository(),
    )
    ..registerFactory<AuthCubit>(() => AuthCubit(sl<AuthRepository>()))
    ..registerLazySingleton<RecentSearchesCubit>(RecentSearchesCubit.new)
    ..registerFactory<SearchCubit>(
      () => SearchCubit(
        maybe<SearchRepository>() ?? NoSourceSearchRepository(),
        onQuery: sl<RecentSearchesCubit>().record,
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
    );
}
