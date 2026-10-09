import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/design/design.dart';
import 'core/di/injector.dart';
import 'core/theme_cubit.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/favorites/favorites_cubit.dart';
import 'features/home/recent_searches_cubit.dart';
import 'features/search/presentation/cubit/search_cubit.dart';
import 'features/shell/shell_cubit.dart';
import 'features/shell/shell_page.dart';
import 'l10n/app_localizations.dart';

class OrbiJobApp extends StatelessWidget {
  const OrbiJobApp({super.key, this.builder});

  /// Wraps every screen (used by the preview build to pin its "illustrative data" banner).
  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => sl<AuthCubit>()),
      BlocProvider(create: (_) => sl<ThemeCubit>()),
      BlocProvider(create: (_) => sl<ShellCubit>()),
      BlocProvider(create: (_) => sl<SearchCubit>()),
      BlocProvider(create: (_) => sl<FavoritesCubit>()),
      BlocProvider.value(value: sl<RecentSearchesCubit>()),
    ],
    child: BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) => MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: builder,
        home: const ShellPage(),
      ),
    ),
  );
}
