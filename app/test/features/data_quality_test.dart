import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';
import 'package:orbijob/core/format/country_names.dart';
import 'package:orbijob/core/format/description_text.dart';
import 'package:orbijob/core/format/geo_eligibility.dart';
import 'package:orbijob/core/format/job_format.dart';
import 'package:orbijob/core/format/salary_check.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/presentation/widgets/job_card.dart';
import 'package:orbijob/features/search/presentation/widgets/job_detail_view.dart';
import 'package:orbijob/l10n/app_localizations.dart';

import '../helpers/harness.dart';

// Regression cases from the audit of the first real Jobicy ingestion (299 listings, 2026-10-10). Shapes are real, text is made up.
// The salary bounds and the description rules mirror the Worker (worker/test/data-quality.test.ts) on the same cases.

JobPosting job({
  String? country,
  List<String> geo = const [],
  double? min,
  double? max,
  String? cur = 'USD',
  SalaryPeriod? per = SalaryPeriod.year,
  String? description,
}) => JobPosting(
  source: 'jobicy',
  externalId: '152711',
  company: 'Example Co',
  title: 'Example role',
  originalUrl: 'https://jobicy.com/jobs/152711-example',
  country: country,
  geoRestrictions: geo,
  salaryMin: min,
  salaryMax: max,
  salaryCurrency: cur,
  salaryPeriod: per,
  description: description,
  sourceName: 'Jobicy',
);

Future<AppLocalizations> loc(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadBrandFonts();
  });

  group('1. salary', () {
    test('kinds: range, exact, from, up to, unknown, suspicious', () {
      expect(salaryKind(job(min: 120000, max: 145000)), SalaryKind.range);
      expect(salaryKind(job(min: 150000, max: 150000)), SalaryKind.exact);
      expect(salaryKind(job(min: 90000)), SalaryKind.from);
      expect(salaryKind(job(max: 110000)), SalaryKind.upTo);
      expect(salaryKind(job()), SalaryKind.unknown);
      expect(salaryKind(job(min: 90000, cur: null)), SalaryKind.unknown);
      expect(salaryKind(job(min: 90000, per: null)), SalaryKind.unknown);
    });

    test('Jobicy 152711 (USD 168-220 per year) is suspicious and HIDDEN, never shown as 168,000', () async {
      final j = job(min: 168, max: 220);
      expect(salaryKind(j), SalaryKind.suspicious);
      for (final code in ['en', 'pt', 'es']) {
        expect(formatSalary(j, await loc(code)), isNull);
      }
    });

    test('bounds match the Worker (same boundary cases)', () {
      SalaryKind k(double? a, double? b, SalaryPeriod p) =>
          salaryKind(job(min: a, max: b, per: p));
      expect(k(1000, null, SalaryPeriod.year), SalaryKind.from);
      expect(k(999, null, SalaryPeriod.year), SalaryKind.suspicious);
      expect(k(null, 10000, SalaryPeriod.hour), SalaryKind.upTo);
      expect(k(null, 10001, SalaryPeriod.hour), SalaryKind.suspicious);
      expect(k(100, 2000, SalaryPeriod.month), SalaryKind.range);
      expect(k(100, 2001, SalaryPeriod.month), SalaryKind.suspicious);
      expect(k(9, 3, SalaryPeriod.month), SalaryKind.suspicious);
      expect(k(0, null, SalaryPeriod.year), SalaryKind.suspicious);
    });

    test('one-sided salaries read "From" / "Up to" in PT, EN and ES and keep currency and period', () async {
      final en = await loc('en');
      final pt = await loc('pt');
      final es = await loc('es');
      expect(
        formatSalary(job(min: 90000), en),
        allOf(startsWith('From '), contains('90,000'), endsWith('/year')),
      );
      expect(
        formatSalary(job(max: 110000), en),
        allOf(startsWith('Up to '), contains('110,000')),
      );
      expect(formatSalary(job(min: 90000), pt), startsWith('A partir de '));
      expect(formatSalary(job(max: 110000), pt), startsWith('Até '));
      expect(formatSalary(job(min: 90000), es), startsWith('Desde '));
      expect(formatSalary(job(max: 110000), es), startsWith('Hasta '));
      expect(
        formatSalary(job(min: 60, max: 70, per: SalaryPeriod.hour), en),
        allOf(contains('60–70'), endsWith('/h')),
      );
      expect(
        formatSalary(job(min: 120000, max: 145000), en),
        contains('120,000–145,000'),
      );
      expect(
        formatSalary(job(min: 150000, max: 150000), en),
        isNot(contains('–')),
      );
    });
  });

  group('2. geographic eligibility', () {
    GeoEligibility g(JobPosting j, [String lang = 'en']) =>
        geoEligibility(j, lang);

    test('absent location is UNKNOWN and needs a check, it is not global', () {
      final e = g(job());
      expect(e.kind, GeoKind.unknown);
      expect(e.needsCheck, isTrue);
    });
    test('explicit Anywhere is its own kind and needs no warning', () {
      final e = g(job(geo: ['Anywhere']));
      expect(e.kind, GeoKind.anywhere);
      expect(e.needsCheck, isFalse);
    });
    test('one country, several countries: named, no warning', () {
      final one = g(job(country: 'US', geo: ['US']), 'pt');
      expect(one.kind, GeoKind.country);
      expect(one.places, ['Estados Unidos']);
      expect(one.needsCheck, isFalse);
      final many = g(job(geo: ['CA', 'US']), 'es');
      expect(many.kind, GeoKind.countries);
      expect(many.places, ['Canadá', 'Estados Unidos']);
      expect(many.needsCheck, isFalse);
    });
    test('regions stay regions (never expanded) and ask for a check', () {
      for (final r in ['EMEA', 'LATAM', 'APAC']) {
        final e = g(job(geo: [r]));
        expect(e.kind, GeoKind.region);
        expect(e.places, [r]);
        expect(e.needsCheck, isTrue);
      }
      expect(g(job(geo: ['Europe']), 'pt').places, ['Europa']);
      final mixed = g(job(geo: ['CA', 'US', 'APAC', 'EMEA', 'LATAM']));
      expect(mixed.kind, GeoKind.mixed);
      expect(mixed.places, [
        'Canada',
        'United States',
        'APAC',
        'EMEA',
        'LATAM',
      ]);
      expect(mixed.needsCheck, isTrue);
    });
    test('names the app does not recognise are shown as written and ask for a check', () {
      final e = g(job(geo: ['US', 'Atlantis']));
      expect(e.places, ['United States', 'Atlantis']);
      expect(e.needsCheck, isTrue);
    });
    test('Anywhere together with places is ambiguous', () {
      final e = g(job(geo: ['Anywhere', 'US']));
      expect((e.kind, e.needsCheck), (GeoKind.mixed, true));
    });
    test('a record with only the single country (no list) is that country', () {
      expect(g(job(country: 'DE')).kind, GeoKind.country);
    });
  });

  group('3. descriptions', () {
    test(
      'Markdown residue, CR, zero-width characters and double-encoded entities',
      () {
        expect(
          tidyMarkdown(
            '**UK Employee-specific benefits**\n\n***CURRENTLY ONLY HIRING FOR UK***\n\n______________\n\n* May vary by country\n* Second',
          ),
          'UK Employee-specific benefits\n\nCURRENTLY ONLY HIRING FOR UK\n\n- May vary by country\n- Second',
        );
        expect(
          tidyMarkdown('GD is **committed** to __equal__ opportunity'),
          'GD is committed to equal opportunity',
        );
        expect(tidyMarkdown('**UK Employee benefits'), 'UK Employee benefits');
        expect(
          tidyMarkdown(
            'Salary* depends on location. Use snake_case_names and a*b*c.',
          ),
          'Salary* depends on location. Use snake_case_names and a*b*c.',
        );
        expect(
          tidyMarkdown(
            'See [our policy](https://example.com/p) now\n\n## Benefits',
          ),
          'See our policy (https://example.com/p) now\n\nBenefits',
        );
        expect(cleanDescriptionText('a\r\n\r\n\r\n\r\nb​'), 'a\n\nb');
        expect(
          cleanDescriptionText('Fish &amp;amp; chips &amp;quot;x&amp;quot;'),
          'Fish & chips "x"',
        );
        expect(
          cleanDescriptionText('&amp;lt;b&amp;gt; stays text'),
          '&lt;b&gt; stays text',
        );
      },
    );
    test(
      'role-based addresses stay, personal ones are masked, free-mail always',
      () {
        for (final a in [
          'careers@example.com',
          'accommodations@example.com',
          'candidate_accommodations@example.com',
          'hr.support@example.com',
          'recruiting@example.com',
          'talent@example.com',
          'jobs@example.com',
          'askpeople@example.com',
          'reasonable-accommodations@example.com',
        ]) {
          expect(isRoleAddress(a), isTrue, reason: a);
        }
        for (final a in [
          'jane.doe@example.com',
          'jdoe@example.com',
          'jane.doe84@example.com',
          'careers@gmail.com',
          'hr@hotmail.com',
        ]) {
          expect(isRoleAddress(a), isFalse, reason: a);
        }
        expect(
          maskPersonalEmails(
            'Questions? Ask jane.doe@example.com or careers@example.com.',
          ),
          'Questions? Ask $maskedEmail or careers@example.com.',
        );
      },
    );
  });

  group('4. country names', () {
    test('US, CA, DE in PT, EN and ES', () {
      expect(countryName('US', 'pt'), 'Estados Unidos');
      expect(countryName('US', 'en'), 'United States');
      expect(countryName('US', 'es'), 'Estados Unidos');
      expect(countryName('CA', 'pt'), 'Canadá');
      expect(countryName('CA', 'en'), 'Canada');
      expect(countryName('CA', 'es'), 'Canadá');
      expect(countryName('DE', 'pt'), 'Alemanha');
      expect(countryName('DE', 'en'), 'Germany');
      expect(countryName('DE', 'es'), 'Alemania');
    });
    test('unknown codes and regions are not turned into countries', () {
      expect(countryName('ZZ', 'en'), isNull);
      expect(countryName('EMEA', 'en'), isNull);
      expect(countryName('USA', 'en'), isNull);
      expect(regionName('EMEA', 'pt'), 'EMEA');
      expect(regionName('Atlantis', 'en'), isNull);
    });
    test('every country the Worker maps has a name in all three languages', () {
      const workerCodes =
          'AR AU AT BE BR BG CA CN CR HR CY CZ DK EE FI FR DE GR HK HU IE IL IT JP LV LT MY MX NL NZ NO PH PL PT RO RS SG SK SI KR ES SE CH TH TR AE GB UA US VN';
      for (final c in workerCodes.split(' ')) {
        for (final lang in ['en', 'pt', 'es']) {
          expect(countryName(c, lang), isNotNull, reason: '$c/$lang');
        }
      }
    });
    test(
      'placeLabel shows the localized country, the list, Anywhere, or nothing',
      () async {
        final pt = await loc('pt');
        expect(
          placeLabel(job(country: 'US', geo: ['US']), pt),
          'Estados Unidos',
        );
        expect(
          placeLabel(job(geo: ['CA', 'US']), pt),
          'Canadá, Estados Unidos',
        );
        expect(placeLabel(job(geo: ['Anywhere']), pt), 'Qualquer lugar');
        expect(placeLabel(job(geo: ['EMEA']), pt), 'EMEA');
        expect(placeLabel(job(), pt), isNull);
      },
    );
  });

  group('screens: PT/EN/ES, light and dark, narrow width, long names, large text', () {
    Widget host(Widget child, String lang, Brightness b, double width) =>
        MaterialApp(
          theme: b == Brightness.light ? AppTheme.light() : AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(lang),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        );

    final scenarios = <(String, JobPosting, List<String>)>[
      (
        'pt',
        job(
          country: 'AE',
          geo: ['AE'],
          min: 90000,
          description: '**About us**\n\nApply: careers@example.com or jane.doe@example.com',
        ),
        ['Emirados Árabes Unidos', 'A partir de'],
      ),
      (
        'en',
        job(geo: ['EMEA'], max: 110000, description: '* one\n* two'),
        ['Up to', 'Check eligibility on the original listing before applying.'],
      ),
      (
        'es',
        job(geo: ['CA', 'US', 'LATAM'], min: 168, max: 220),
        [
          'Canadá, Estados Unidos, LATAM',
          'Verifica la elegibilidad en el anuncio original antes de postularte.',
        ],
      ),
      (
        'pt',
        job(),
        [
          'Elegibilidade geográfica não informada pela fonte',
          'Confira a elegibilidade no anúncio original antes de se candidatar.',
        ],
      ),
    ];

    for (final b in [Brightness.light, Brightness.dark]) {
      for (final (lang, j, expected) in scenarios) {
        testWidgets('detail ($lang, ${b.name}, 280 px, text x2)', (t) async {
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.platformDispatcher.clearAllTestValues);
          t.view.physicalSize = const Size(280, 1600);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(
            host(
              JobDetailView(
                scored: ScoredJob(j),
                now: DateTime.utc(2026, 10, 10),
              ),
              lang,
              b,
              280,
            ),
          );
          expect(t.takeException(), isNull, reason: 'no overflow');
          final all = t
              .widgetList<Text>(find.byType(Text))
              .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
              .join('\n');
          for (final e in expected) {
            expect(all, contains(e));
          }
          expect(
            all,
            isNot(contains('168')),
            reason: 'suspicious salary hidden',
          );
          expect(all, isNot(contains('**')));
          expect(all, isNot(contains('jane.doe@')));
          if (j.description != null && j.description!.contains('careers@')) {
            expect(all, contains('careers@example.com'));
          }
        });
      }
    }

    testWidgets(
      'card: long country name does not overflow at 280 px, text x2',
      (t) async {
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.platformDispatcher.clearAllTestValues);
        await t.pumpWidget(
          host(
            JobCard(
              scored: ScoredJob(job(geo: ['AE', 'DO', 'CZ'], max: 110000)),
            ),
            'pt',
            Brightness.dark,
            280,
          ),
        );
        expect(t.takeException(), isNull);
        expect(find.textContaining('Emirados Árabes Unidos'), findsOneWidget);
      },
    );
  });
}
