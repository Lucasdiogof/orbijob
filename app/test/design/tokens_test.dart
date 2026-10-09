import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final source = jsonDecode(
    File('../docs/design/identity/c-minimal/tokens.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final colors = source['color'] as Map<String, dynamic>;

  test(
    'Dart tokens equal the identity C tokens.json (single source of truth)',
    () {
      for (final mode in ['light', 'dark']) {
        final expected = (colors[mode] as Map<String, dynamic>)
            .cast<String, String>();
        final actual = mode == 'light' ? AppColors.light : AppColors.dark;
        expect(AppColors.roles.toSet(), expected.keys.toSet());
        for (final role in AppColors.roles) {
          expect(
            _hex(actual.byName(role)),
            expected[role]!.toUpperCase(),
            reason: '$mode.$role',
          );
        }
      }
    },
  );

  test('official anchors: white / #111113 / #5B3DF5 (light), #0C0C0E / #A593FF (dark)', () {
    expect(_hex(AppColors.light.bg), '#FFFFFF');
    expect(_hex(AppColors.light.ink), '#111113');
    expect(_hex(AppColors.light.primary), '#5B3DF5');
    expect(_hex(AppColors.dark.bg), '#0C0C0E');
    expect(_hex(AppColors.dark.primary), '#A593FF');
  });

  final textPairs = <(String, String)>[
    ('ink', 'bg'),
    ('ink', 'surface'),
    ('ink', 'container'),
    ('ink', 'containerHigh'),
    ('muted', 'bg'),
    ('muted', 'surface'),
    ('muted', 'container'),
    ('muted', 'containerHigh'),
    ('onPrimary', 'primary'),
    ('primary', 'bg'),
    ('primary', 'surface'),
    ('onPrimaryContainer', 'primaryContainer'),
    ('onSecondary', 'secondary'),
    ('onSecondaryContainer', 'secondaryContainer'),
    ('onError', 'error'),
    ('onErrorContainer', 'errorContainer'),
    ('error', 'surface'),
    ('onSuccess', 'success'),
    ('onSuccessContainer', 'successContainer'),
    ('success', 'surface'),
    ('onWarning', 'warning'),
    ('onWarningContainer', 'warningContainer'),
    ('warning', 'surface'),
  ];
  final uiPairs = <(String, String)>[
    ('outline', 'bg'),
    ('outline', 'surface'),
    ('focus', 'bg'),
    ('focus', 'surface'),
    ('primary', 'surface'),
  ];

  for (final mode in ['light', 'dark']) {
    final c = mode == 'light' ? AppColors.light : AppColors.dark;
    test('WCAG AA text contrast ($mode)', () {
      for (final (fg, bg) in textPairs) {
        expect(
          contrast(c.byName(fg), c.byName(bg)),
          greaterThanOrEqualTo(4.5),
          reason: '$mode $fg/$bg',
        );
      }
    });
    test('WCAG 3:1 for controls, borders and focus ($mode)', () {
      for (final (fg, bg) in uiPairs) {
        expect(
          contrast(c.byName(fg), c.byName(bg)),
          greaterThanOrEqualTo(3.0),
          reason: '$mode $fg/$bg',
        );
      }
      // component aliases
      expect(contrast(c.inputBorder, c.inputFill), greaterThanOrEqualTo(3.0));
      expect(contrast(c.chipBorder, c.chipBg), greaterThanOrEqualTo(3.0));
      expect(contrast(c.navSelected, c.navBg), greaterThanOrEqualTo(4.5));
      expect(contrast(c.navUnselected, c.navBg), greaterThanOrEqualTo(4.5));
      expect(
        contrast(c.chipSelectedFg, c.chipSelectedBg),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  test('state layers are subtle but perceptible', () {
    expect(AppStateLayer.hover, inInclusiveRange(0.04, 0.16));
    expect(AppStateLayer.pressed, inInclusiveRange(0.08, 0.2));
    expect(AppStateLayer.focus, inInclusiveRange(0.08, 0.2));
  });

  test('widgets never hardcode colours (only the design folder may)', () {
    final offenders = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final p = f.path.replaceAll('\\', '/');
      if (p.contains('lib/core/design/') || p.contains('lib/l10n/')) continue;
      final text = f.readAsStringSync();
      if (RegExp(r'Color\(0x|Colors\.[a-z]').hasMatch(text)) offenders.add(p);
    }
    expect(offenders, isEmpty);
  });

  test('kProvisionalSeed is gone', () {
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              f.readAsStringSync().contains('kProvisionalSeed'),
        );
    expect(hits, isEmpty);
  });
}
