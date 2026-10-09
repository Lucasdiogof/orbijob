import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/design/design.dart';
import 'core/di/injector.dart';
import 'core/locale_cubit.dart';
import 'core/theme_cubit.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/home/recent_searches_cubit.dart';
import 'features/session/user_scope.dart';
import 'features/search/presentation/cubit/search_cubit.dart';
import 'features/shell/shell_cubit.dart';
import 'features/shell/shell_page.dart';
import 'l10n/app_localizations.dart';

class OrbiJobApp extends StatefulWidget {
  const OrbiJobApp({super.key, this.builder});

  /// Wraps every screen (used by the preview build to pin its "illustrative data" banner).
  final TransitionBuilder? builder;

  @override
  State<OrbiJobApp> createState() => _OrbiJobAppState();
}

class _OrbiJobAppState extends State<OrbiJobApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => sl<AuthCubit>()),
      BlocProvider(create: (_) => sl<ThemeCubit>()),
      BlocProvider(create: (_) => sl<ShellCubit>()),
      BlocProvider(create: (_) => sl<SearchCubit>()),
      BlocProvider(create: (_) => sl<LocaleCubit>()),
      BlocProvider.value(value: sl<RecentSearchesCubit>()),
    ],
    child: BlocBuilder<LocaleCubit, Locale?>(
      builder: (context, locale) => BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) => MaterialApp(
          navigatorKey: _navigator,
          onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final inner = widget.builder?.call(context, child) ?? child!;
            return UserScope(navigator: _navigator, child: inner);
          },
          home: const ShellPage(),
        ),
      ),
    ),
  );
}
