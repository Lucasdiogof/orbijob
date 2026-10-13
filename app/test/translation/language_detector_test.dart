import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/translation/language_detector.dart';

List<Map<String, dynamic>> _real() => (jsonDecode(
  File('test/fixtures/jobs/real_listings.json').readAsStringSync(),
) as List).cast<Map<String, dynamic>>();

void main() {
  group('real listings from the live catalogue (the country never decides the language)', () {
    for (final j in _real()) {
      final title = j['title'] as String;
      test(
        '${j['expect']}: ${title.length > 48 ? title.substring(0, 48) : title}',
        () {
          final text = '${j['title']}\n${j['description']}';
          final d = detectLanguage(text);
          expect(d, isNotNull, reason: 'enough text to decide');
          expect(
            d!.code,
            j['expect'],
            reason: 'country=${j['country']} declared=${j['language']}',
          );
        },
      );
    }
  });

  test('Traditional Chinese is recognised as such (script hint for the translator)', () {
    final d = detectLanguage('我們誠徵門市人員，需具備服務熱忱，負責商品銷售與顧客服務，歡迎應徵');
    expect(d!.code, 'zh');
    expect(d.script, 'Hant');
    expect(detectLanguage('我们诚聘门市人员，需具备服务热忱，负责商品销售与顾客服务，欢迎应聘')!.script, 'Hans');
  });

  test('other scripts', () {
    expect(detectLanguage('ソフトウェアエンジニアを募集しています。経験者歓迎です。')!.code, 'ja');
    expect(detectLanguage('소프트웨어 엔지니어를 모집합니다. 경력자 우대합니다.')!.code, 'ko');
    expect(
      detectLanguage(
        'Мы ищем разработчика программного обеспечения в нашу команду',
      )!.code,
      'ru',
    );
  });

  test('Latin languages', () {
    expect(
      detectLanguage(
        'Wir suchen eine erfahrene Pflegefachkraft für unser Team in Hamburg, die gerne mit Menschen arbeitet',
      )!.code,
      'de',
    );
    expect(
      detectLanguage(
        'Vi söker en erfaren sjuksköterska till vårt team som vill arbeta med människor och är trygg i sin roll',
      )!.code,
      'sv',
    );
    expect(
      detectLanguage(
        'Estamos buscando un enfermero con experiencia para nuestro equipo en el hospital de la ciudad',
      )!.code,
      'es',
    );
    expect(
      detectLanguage(
        'Estamos à procura de um enfermeiro com experiência para a nossa equipa no hospital da cidade',
      )!.code,
      'pt',
    );
    expect(
      detectLanguage(
        'Nous recherchons un infirmier expérimenté pour rejoindre notre équipe à l\'hôpital de la ville',
      )!.code,
      'fr',
    );
    expect(
      detectLanguage(
        'We are looking for an experienced nurse to join our team at the city hospital and work with patients',
      )!.code,
      'en',
    );
  });

  test('too short, empty, numeric or ambiguous text is not guessed', () {
    expect(detectLanguage(''), isNull);
    expect(detectLanguage('Manager'), isNull);
    expect(detectLanguage('12345 67890 ###'), isNull);
    expect(detectLanguage('Flutter Dart Kotlin Firebase CI/CD'), isNull);
  });
}
