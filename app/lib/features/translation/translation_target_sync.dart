import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'translation_cubit.dart';

/// Keeps the translation target equal to the interface language: when the person changes the app language (or the device
/// language while "device language" is selected), listings are translated into the new one, or show their original until ready.
class TranslationTargetSync extends StatelessWidget {
  const TranslationTargetSync({super.key, required this.child});
  final Widget child;

  static const _supported = {'pt', 'en', 'es'};

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (_supported.contains(code)) {
      final cubit = context.read<TranslationCubit>();
      // state changes must not happen during a build
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => cubit.setTarget(code),
      );
    }
    return child;
  }
}
