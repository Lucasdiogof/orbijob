import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/applications/data/supabase_applications_repository.dart';
import '../../features/applications/domain/application_record.dart';
import '../../features/auth/data/unconfigured_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/favorites/data/supabase_favorites_repository.dart';
import '../../features/favorites/domain/favorites_repository.dart';
import '../../features/preferences/data/supabase_preferences_repository.dart';
import '../../features/preferences/domain/user_preferences.dart';
import '../../features/profile/data/supabase_profile_repository.dart';
import '../../features/profile/data/supabase_resume_repository.dart';
import '../../features/profile/domain/professional_profile.dart';
import '../../features/profile/domain/resume_repository.dart';

import '../../features/favorites/favorites_cubit.dart';
import '../../features/home/recent_searches_cubit.dart';
import '../../features/search/domain/search_repository.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../../features/shell/shell_cubit.dart';
import '../theme_cubit.dart';

final sl = GetIt.instance;

/// Registers the app graph. [searchRepository] lets previews and tests plug another source;
/// by default no connector is wired and search honestly reports "no integrated source".
void configureDependencies({
  SearchRepository? searchRepository,
  AuthRepository? authRepository,
}) {
  sl
    ..registerLazySingleton<AuthRepository>(
      () => authRepository ?? UnconfiguredAuthRepository(),
    )
    ..registerFactory<AuthCubit>(() => AuthCubit(sl<AuthRepository>()))
    ..registerLazySingleton<SearchRepository>(
      () => searchRepository ?? NoSourceSearchRepository(),
    )
    ..registerLazySingleton<RecentSearchesCubit>(RecentSearchesCubit.new)
    ..registerFactory<SearchCubit>(
      () => SearchCubit(
        sl<SearchRepository>(),
        onQuery: sl<RecentSearchesCubit>().record,
      ),
    )
    ..registerFactory<ThemeCubit>(ThemeCubit.new)
    ..registerFactory<ShellCubit>(ShellCubit.new)
    ..registerFactory<FavoritesCubit>(FavoritesCubit.new);
}

/// Registers the Supabase-backed repositories. Called once at start-up, only when a public configuration exists.
/// They are not wired into screens yet: that happens after the remote project has been reviewed and migrated.
void registerSupabaseRepositories(SupabaseClient client) {
  sl
    ..registerLazySingleton<ProfileRepository>(
      () => SupabaseProfileRepository(client),
    )
    ..registerLazySingleton<ResumeRepository>(
      () => SupabaseResumeRepository(client),
    )
    ..registerLazySingleton<FavoritesRepository>(
      () => SupabaseFavoritesRepository(client),
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
