import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injector.dart';
import 'core/theme/app_theme.dart';
import 'features/search/presentation/cubit/search_cubit.dart';
import 'features/shell/shell_page.dart';
import 'l10n/app_localizations.dart';

class OrbiJobApp extends StatelessWidget {
  const OrbiJobApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider(
      create: (_) => sl<SearchCubit>(),
      child: const ShellPage(),
    ),
  );
}
