import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/app.dart';
import 'package:orbijob/core/di/injector.dart';
import 'package:orbijob/features/auth/domain/auth_repository.dart';
import 'package:orbijob/features/favorites/domain/favorites_repository.dart';
import 'package:orbijob/features/profile/domain/pdf_picker.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/preview/in_memory_favorites.dart';

import 'fakes.dart';

/// Loads the bundled fonts so text is measured and drawn with the real faces (not the test "Ahem" box font).
Future<void> loadBrandFonts() async {
  const families = {
    'SpaceGrotesk': [
      'SpaceGrotesk-500',
      'SpaceGrotesk-600',
      'SpaceGrotesk-700',
    ],
    'Inter': ['Inter-400', 'Inter-500', 'Inter-600', 'Inter-700'],
    'JetBrainsMono': ['JetBrainsMono-500'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      final bytes = File('assets/fonts/$f.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// Pumps the real app at [size] with [textScale]; the repository is injectable (defaults to "no source").
Future<void> pumpApp(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeMode? themeMode,
  Brightness platformBrightness = Brightness.light,
  SearchRepository? repo,
  FavoritesRepository? favorites,
  Fakes? fakes,
  AuthRepository? auth,
  PdfPicker? pdfPicker,
  Locale? locale,
  double devicePixelRatio = 1,
}) async {
  t.view.physicalSize = size * devicePixelRatio;
  t.view.devicePixelRatio = devicePixelRatio;
  t.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  if (locale != null) t.platformDispatcher.localesTestValue = [locale];
  addTearDown(() {
    t.view.reset();
    t.platformDispatcher.clearAllTestValues();
  });
  await sl.reset();
  configureDependencies(
    searchRepository: repo,
    authRepository: auth,
    pdfPicker: pdfPicker,
    favoritesRepository: favorites ?? InMemoryFavoritesRepository(),
  );
  (fakes ?? Fakes()).register();
  await t.pumpWidget(const OrbiJobApp());
  await t.pumpAndSettle();
}

/// Path of a repository file relative to the app directory (tests run from app/).
File repoFile(String relative) => File(relative);
