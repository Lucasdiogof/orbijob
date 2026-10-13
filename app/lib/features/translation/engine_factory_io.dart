import 'dart:io' show Platform;

import 'mlkit_engine.dart';
import 'translation_engine.dart';

/// Android and iOS use ML Kit; desktop builds and tests have no engine (everything reports "unsupported").
TranslationEngine createPlatformEngine() => Platform.isAndroid || Platform.isIOS
    ? MlKitTranslationEngine()
    : const NoTranslationEngine();
