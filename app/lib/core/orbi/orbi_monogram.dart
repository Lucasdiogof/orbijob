import 'package:flutter/material.dart';

import '../design/design.dart';

/// The company's first letter on a tinted tile: a quiet visual anchor for a card, standing in for a logo the catalogue does not have.
/// The tint is chosen from the name, so the same company always looks the same. Decorative: hidden from screen readers (the name is read in the card).
class OrbiMonogram extends StatelessWidget {
  const OrbiMonogram({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  static final _alnum = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// First letter of [name] (letters and digits only), or null when it has none.
  static String? initialOf(String name) {
    for (final r in name.trim().runes) {
      final ch = String.fromCharCode(r);
      if (_alnum.hasMatch(ch)) return ch.toUpperCase();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final letter = initialOf(name);
    if (letter == null) return const SizedBox.shrink();
    final c = context.colors;
    final tints = <(Color, Color)>[
      (c.primaryContainer, c.onPrimaryContainer),
      (c.successContainer, c.onSuccessContainer),
      (c.warningContainer, c.onWarningContainer),
      (c.containerHigh, c.ink),
    ];
    var h = 0;
    for (final r in name.trim().toLowerCase().runes) {
      h = (h * 31 + r) & 0x7fffffff;
    }
    final (bg, fg) = tints[h % tints.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          letter,
          style: context.text.titleMedium!.copyWith(color: fg),
        ),
      ),
    );
  }
}
