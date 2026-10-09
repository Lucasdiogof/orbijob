import 'package:get_it/get_it.dart';

import '../../features/favorites/favorites_cubit.dart';
import '../../features/search/domain/search_repository.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../../features/shell/shell_cubit.dart';
import '../theme_cubit.dart';

final sl = GetIt.instance;

/// Registers the app graph. [searchRepository] lets previews and tests plug another source;
/// by default no connector is wired and search honestly reports "no integrated source".
void configureDependencies({SearchRepository? searchRepository}) {
  sl
    ..registerLazySingleton<SearchRepository>(
      () => searchRepository ?? NoSourceSearchRepository(),
    )
    ..registerFactory<SearchCubit>(() => SearchCubit(sl<SearchRepository>()))
    ..registerFactory<ThemeCubit>(ThemeCubit.new)
    ..registerFactory<ShellCubit>(ShellCubit.new)
    ..registerFactory<FavoritesCubit>(FavoritesCubit.new);
}
