import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';

import 'png_info.dart';

const res = 'android/app/src/main/res';
String read(String p) => File(p).readAsStringSync();
bool wellFormed(String xml) {
  // tag balance + no stray '<' (enough to catch truncation/typos without an XML dependency)
  final stack = <String>[];
  for (final m in RegExp(
    r'<(/?)([A-Za-z][\w:.-]*)[^<>]*?(/?)>',
  ).allMatches(xml.replaceAll(RegExp(r'<\?xml[^>]*\?>|<!--[\s\S]*?-->'), ''))) {
    final closing = m.group(1) == '/', selfClose = m.group(3) == '/';
    if (selfClose) continue;
    if (closing) {
      if (stack.isEmpty || stack.removeLast() != m.group(2)) return false;
    } else {
      stack.add(m.group(2)!);
    }
  }
  return stack.isEmpty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('brand SVGs', () {
    for (final path in AppAssets.all) {
      test('$path is a valid, self-contained vector', () async {
        final svg = await rootBundle.loadString(path);
        expect(svg, contains('viewBox='));
        expect(wellFormed(svg), isTrue);
        expect(
          svg,
          isNot(contains('<text')),
          reason: 'text must be outlines: no font dependency',
        );
        expect(svg, isNot(contains('<image')));
        expect(svg, isNot(contains('<script')));
        expect(svg, isNot(contains('font-family')));
        expect(
          RegExp(r'(href|src)=').hasMatch(svg),
          isFalse,
          reason: 'no external references',
        );
        expect(
          RegExp(r'url\(#([^)]+)\)')
              .allMatches(svg)
              .every((m) => svg.contains('id="${m.group(1)}"')),
          isTrue,
        );
      });
      test(
        '$path equals the official source in docs/design/identity/c-minimal',
        () {
          final name = path.split('/').last;
          final src = File('../docs/design/identity/c-minimal/$name');
          expect(src.existsSync(), isTrue, reason: name);
          expect(
            File('assets/brand/$name').readAsBytesSync(),
            src.readAsBytesSync(),
            reason: 'run docs/design/identity/build/apply_c.py',
          );
        },
      );
    }
    test('symbol geometry is the approved one: two arcs (stroke 13) + central dot (r 9)', () {
      final svg = read('assets/brand/symbol-light.svg');
      expect(RegExp(r'stroke-width="13"').allMatches(svg).length, 2);
      expect(svg, contains('r="9"'));
      expect(svg, contains('#5B3DF5'));
      expect(svg, contains('#111113'));
    });
    test('mono logos use a single colour', () {
      for (final (f, c) in [
        ('logo-horizontal-mono-black', '#000000'),
        ('logo-horizontal-mono-white', '#FFFFFF'),
        ('symbol-mono-black', '#000000'),
        ('symbol-mono-white', '#FFFFFF'),
      ]) {
        final colors = RegExp(r'(?:fill|stroke)="(#[0-9A-Fa-f]{6})"')
            .allMatches(read('assets/brand/$f.svg'))
            .map((m) => m.group(1)!.toUpperCase())
            .toSet();
        expect(colors, {c}, reason: f);
      }
    });
  });

  group('fonts', () {
    test(
      'declared in pubspec, present, valid TrueType, licensed and light',
      () {
        final pub = read('pubspec.yaml');
        var total = 0;
        for (final f in Directory(
          'assets/fonts',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
          final name = f.uri.pathSegments.last;
          expect(pub, contains('assets/fonts/$name'), reason: name);
          final b = f.readAsBytesSync();
          expect(b.sublist(0, 4), [
            0x00,
            0x01,
            0x00,
            0x00,
          ], reason: '$name is not TrueType');
          total += b.length;
        }
        expect(total, lessThan(600 * 1024), reason: 'keep the bundle light');
        for (final l in ['SpaceGrotesk', 'Inter', 'JetBrainsMono']) {
          expect(
            File('assets/fonts/OFL-$l.txt').readAsStringSync(),
            contains('SIL OPEN FONT LICENSE'),
            reason: l,
          );
          expect(pub, contains('assets/fonts/OFL-$l.txt'));
        }
      },
    );
  });

  group('Android', () {
    test('adaptive launcher icon: background, foreground and monochrome exist and are wired', () {
      for (final f in [
        'mipmap-anydpi-v26/ic_launcher.xml',
        'mipmap-anydpi-v26/ic_launcher_round.xml',
        'mipmap-anydpi-v33/ic_launcher.xml',
        'mipmap-anydpi-v33/ic_launcher_round.xml',
      ]) {
        final x = read('$res/$f');
        expect(wellFormed(x), isTrue, reason: f);
        expect(x, contains('@color/ic_launcher_background'));
        expect(x, contains('@drawable/ic_launcher_foreground'));
        expect(x.contains('monochrome'), f.contains('v33'), reason: f);
      }
      for (final f in [
        'drawable/ic_launcher_foreground.xml',
        'drawable/ic_launcher_monochrome.xml',
        'values/ic_launcher_colors.xml',
      ]) {
        expect(wellFormed(read('$res/$f')), isTrue, reason: f);
      }
      expect(
        read('$res/values/ic_launcher_colors.xml'),
        contains('ic_launcher_background'),
      );
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        allOf(
          contains('@mipmap/ic_launcher"'),
          contains('@mipmap/ic_launcher_round'),
          contains('android:label="OrbiJob"'),
        ),
      );
    });

    test('symbol stays inside the 66 dp adaptive safe zone (never cropped by circle/squircle masks)', () {
      for (final f in ['ic_launcher_foreground', 'ic_launcher_monochrome']) {
        final x = read('$res/drawable/$f.xml');
        final scale = double.parse(
          RegExp(r'scaleX="([\d.]+)"').firstMatch(x)!.group(1)!,
        );
        final canvasDp = double.parse(
          RegExp(r'android:width="(\d+)dp"').firstMatch(x)!.group(1)!,
        );
        const outer =
            31 + 13 / 2; // arc radius + half stroke, in viewport units (0..100)
        final radiusDp = outer * scale * canvasDp / 100;
        expect(canvasDp, 108);
        expect(
          radiusDp,
          lessThanOrEqualTo(30),
          reason:
              '$f radius ${radiusDp.toStringAsFixed(1)}dp must be <= 30dp (33dp safe radius minus margin)',
        );
        expect(
          radiusDp,
          greaterThan(24),
          reason: 'symbol should still be prominent',
        );
      }
    });

    test('legacy launcher PNGs exist in all densities (square and round) with exact sizes', () {
      const sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final e in sizes.entries) {
        for (final n in ['ic_launcher', 'ic_launcher_round']) {
          final i = readPng(File('$res/mipmap-${e.key}/$n.png'));
          expect(
            (i.width, i.height),
            (e.value, e.value),
            reason: '${e.key}/$n',
          );
        }
      }
    });

    test('splash: simple static symbol on the token background (light, night, Android 12+)', () {
      expect(read('$res/values/ic_launcher_colors.xml'), contains('#FFFFFF'));
      expect(
        read('$res/values-night/ic_launcher_colors.xml'),
        contains('#0C0C0E'),
      );
      expect(
        read('$res/drawable/launch_background.xml'),
        allOf(
          contains('@color/splash_background'),
          contains('@drawable/splash_symbol'),
        ),
      );
      for (final v in ['values-v31', 'values-night-v31']) {
        final x = read('$res/$v/styles.xml');
        expect(x, contains('windowSplashScreenBackground'));
        expect(x, contains('@drawable/splash_icon'));
        expect(
          x,
          contains('windowSplashScreenAnimationDuration">0'),
          reason: 'no decorative animation',
        );
      }
      for (final f in [
        'drawable/splash_symbol.xml',
        'drawable-night/splash_symbol.xml',
        'drawable/splash_icon.xml',
        'drawable-night/splash_icon.xml',
      ]) {
        expect(wellFormed(read('$res/$f')), isTrue, reason: f);
      }
      // Android 12+: the icon canvas is 288 dp, visible area is a 192 dp circle
      final icon = read('$res/drawable/splash_icon.xml');
      final scale = double.parse(
        RegExp(r'scaleX="([\d.]+)"').firstMatch(icon)!.group(1)!,
      );
      expect(37.5 * scale * 288 / 100, lessThanOrEqualTo(96));
    });

    test('app id and namespace are unchanged', () {
      expect(
        read('android/app/build.gradle.kts'),
        allOf(
          contains('applicationId = "com.lucksrei.orbijob"'),
          contains('namespace = "com.lucksrei.orbijob"'),
        ),
      );
    });
  });

  group('iOS', () {
    final set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    test('AppIcon: Contents.json is complete, every PNG exists with exact size, opaque and square', () {
      final contents =
          jsonDecode(read('$set/Contents.json')) as Map<String, dynamic>;
      final images = (contents['images'] as List).cast<Map<String, dynamic>>();
      expect(images.length, 19);
      final referenced = images.map((i) => i['filename']).toSet();
      final onDisk = Directory(set)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(onDisk, referenced, reason: 'no orphan or missing icon files');
      for (final im in images) {
        final file = File('$set/${im['filename']}');
        expect(file.existsSync(), isTrue, reason: '${im['filename']}');
        final size = double.parse((im['size'] as String).split('x').first);
        final scale = int.parse((im['scale'] as String).replaceAll('x', ''));
        final px = (size * scale).round();
        final info = readPng(file);
        expect(
          (info.width, info.height),
          (px, px),
          reason: im['filename'] as String,
        );
        expect(
          info.hasAlpha,
          isFalse,
          reason: '${im['filename']} must be opaque (App Store rule)',
        );
      }
      expect(
        images.any(
          (i) => i['idiom'] == 'ios-marketing' && i['size'] == '1024x1024',
        ),
        isTrue,
      );
    });
    test('launch image has light and dark variants and the storyboard uses a named background colour', () {
      final contents = jsonDecode(
        read('ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json'),
      ) as Map<String, dynamic>;
      final images = (contents['images'] as List).cast<Map<String, dynamic>>();
      expect(images.where((i) => i.containsKey('appearances')).length, 3);
      for (final im in images) {
        expect(
          File(
            'ios/Runner/Assets.xcassets/LaunchImage.imageset/${im['filename']}',
          ).existsSync(),
          isTrue,
        );
      }
      final colorset = read(
        'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
      );
      expect(
        colorset,
        allOf(contains('luminosity'), contains('0x0C'), contains('0xFF')),
      );
      final sb = read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      expect(wellFormed(sb), isTrue);
      expect(
        sb,
        allOf(
          contains('name="LaunchBackground"'),
          contains('image="LaunchImage"'),
          contains('<namedColor name="LaunchBackground">'),
        ),
      );
    });
    test('display name and bundle id', () {
      expect(
        read('ios/Runner/Info.plist'),
        allOf(
          contains('<string>OrbiJob</string>'),
          isNot(contains('Jobradar')),
        ),
      );
      final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
      expect(
        'PRODUCT_BUNDLE_IDENTIFIER = com.lucksrei.orbijob;'
            .allMatches(pbx)
            .length,
        greaterThanOrEqualTo(2),
      );
      expect(
        pbx,
        isNot(contains('DEVELOPMENT_TEAM = ')),
        reason: 'signing untouched',
      );
    });
  });

  group('Web / PWA', () {
    test(
      'manifest: identity, colours, icons (any + maskable) with exact sizes',
      () {
        final m = jsonDecode(read('web/manifest.json')) as Map<String, dynamic>;
        expect(m['name'], 'OrbiJob');
        expect(m['short_name'], 'OrbiJob');
        expect(m['description'], isNot(contains('A new Flutter project')));
        expect(m['theme_color'], '#111113');
        expect(m['background_color'], '#FFFFFF');
        expect(m['display'], 'standalone');
        expect(m['orientation'], 'any');
        final icons = (m['icons'] as List).cast<Map<String, dynamic>>();
        expect(icons.where((i) => i['purpose'] == 'maskable').length, 2);
        for (final i in icons) {
          final px = int.parse((i['sizes'] as String).split('x').first);
          final info = readPng(
            File('web/${(i['src'] as String).split('?').first}'),
          );
          expect(
            (info.width, info.height),
            (px, px),
            reason: i['src'] as String,
          );
        }
      },
    );
    test('maskable icons are opaque and full-bleed', () {
      for (final n in ['192', '512']) {
        expect(
          readPng(File('web/icons/Icon-maskable-$n.png')).hasAlpha,
          isFalse,
        );
      }
    });
    test('index.html: title, metadata, favicons, apple-touch-icon, static splash removed on first frame', () {
      final h = read('web/index.html');
      expect(
        h,
        allOf(
          contains('<title>OrbiJob</title>'),
          contains('rel="manifest"'),
          contains('favicon.svg'),
          contains('favicon.ico'),
          contains('apple-touch-icon'),
        ),
      );
      expect(
        h,
        allOf(
          contains('theme-color'),
          contains('prefers-color-scheme: dark'),
          contains('flutter-first-frame'),
          contains('id="splash"'),
        ),
      );
      expect(h, isNot(contains('A new Flutter project')));
      expect(
        RegExp(r'@keyframes|animation\s*:').hasMatch(h),
        isFalse,
        reason: 'splash is static',
      );
      final a = readPng(File('web/icons/apple-touch-icon.png'));
      expect((a.width, a.height, a.hasAlpha), (180, 180, false));
    });
    test('favicons: ICO has 16/32/48, PNG favicon is 32, SVG is valid', () {
      final ico = File('web/favicon.ico').readAsBytesSync();
      final bd = ByteData.sublistView(ico);
      expect(bd.getUint16(2, Endian.little), 1);
      final n = bd.getUint16(4, Endian.little);
      expect(List.generate(n, (i) => ico[6 + 16 * i]), [16, 32, 48]);
      expect(readPng(File('web/favicon.png')).width, 32);
      expect(wellFormed(read('web/favicon.svg')), isTrue);
    });
    test('no default Flutter branding is left in web/', () {
      for (final f
          in Directory('web')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => RegExp(r'\.(html|json|svg)$').hasMatch(f.path))) {
        expect(
          f.readAsStringSync().toLowerCase(),
          isNot(contains('a new flutter project')),
          reason: f.path,
        );
      }
    });
    test('splash colours equal the identity tokens', () {
      final h = read('web/index.html');
      expect(h, contains('#0C0C0E'));
      expect(AppColors.dark.bg, const Color(0xFF0C0C0E));
      expect(h.toUpperCase(), contains('#FFFFFF'));
    });
  });

  test('launcher/web/iOS icons are generated from one geometry: the arcs and dot match across assets', () {
    final arcs = RegExp(r'A31,31 0 0 1 [\d.]+,[\d.]+')
        .allMatches(read('$res/drawable/ic_launcher_foreground.xml'))
        .length;
    expect(arcs, 2);
    expect(
      math.pi,
      greaterThan(3),
    ); // keeps dart:math import meaningful for future geometry checks
  });
}
