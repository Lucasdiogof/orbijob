import 'package:get_it/get_it.dart';

import '../../features/search/domain/search_repository.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';

final sl = GetIt.instance;

void configureDependencies() {
  sl
    ..registerLazySingleton<SearchRepository>(() => NoSourceSearchRepository())
    ..registerFactory<SearchCubit>(() => SearchCubit(sl<SearchRepository>()));
}
