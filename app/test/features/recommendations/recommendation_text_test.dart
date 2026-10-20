import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/recommendations/domain/recommendation.dart';
import 'package:orbijob/features/recommendations/presentation/recommendation_text.dart';
import 'package:orbijob/l10n/app_localizations_en.dart';
import 'package:orbijob/l10n/app_localizations_pt.dart';

void main() {
  final en = AppLocalizationsEn();
  final pt = AppLocalizationsPt();

  group('reasonText', () {
    test('toda razão vira um texto não vazio nos dois idiomas', () {
      for (final l in [en, pt]) {
        for (final kind in ReasonKind.values) {
          final text = reasonText(
            Reason(kind, text: 'BR', items: const ['Excel', 'SQL'], number: 3),
            l,
            l.localeName,
          );
          expect(
            text.trim(),
            isNotEmpty,
            reason: '${kind.name} em ${l.localeName}',
          );
        }
      }
    });

    test('profissão exata cita a profissão', () {
      final t = reasonText(
        const Reason(ReasonKind.professionExact, text: 'Enfermeira'),
        pt,
        'pt',
      );
      expect(t, contains('Enfermeira'));
    });

    test('habilidades são listadas separadas por vírgula', () {
      final t = reasonText(
        const Reason(ReasonKind.skills, items: ['Excel', 'SQL']),
        en,
        'en',
      );
      expect(t, contains('Excel, SQL'));
    });

    test('país vira nome no idioma; código desconhecido fica cru', () {
      final known = reasonText(
        const Reason(ReasonKind.countryOfInterest, text: 'BR'),
        en,
        'en',
      );
      expect(known, isNot(contains('BR')));
      final unknown = reasonText(
        const Reason(ReasonKind.countryOfInterest, text: 'ZZ'),
        en,
        'en',
      );
      expect(unknown, contains('ZZ'));
    });

    test('publicação recente: hoje, ontem e há N dias', () {
      String r(int? n) =>
          reasonText(Reason(ReasonKind.recent, number: n), en, 'en');
      expect(r(0), en.publishedToday);
      expect(r(null), en.publishedToday);
      expect(r(-2), en.publishedToday);
      expect(r(1), en.publishedYesterday);
      expect(r(5), en.publishedDaysAgo(5));
      expect(r(5), contains('5'));
    });

    test('área desconhecida cai em serviços, sem quebrar', () {
      final t = reasonText(
        const Reason(ReasonKind.sameField, text: 'area_que_nao_existe'),
        en,
        'en',
      );
      expect(t.trim(), isNotEmpty);
    });

    test('modo de trabalho desconhecido vira "não informado"', () {
      final t = reasonText(
        const Reason(ReasonKind.workMode, text: 'xyz'),
        en,
        'en',
      );
      expect(t.trim(), isNotEmpty);
    });

    test('remoto de qualquer lugar não precisa de texto', () {
      expect(
        reasonText(const Reason(ReasonKind.remoteAnywhere), en, 'en'),
        en.rcReasonRemoteAnywhere,
      );
    });
  });

  group('caveatText', () {
    test('todo aviso vira texto nos dois idiomas', () {
      for (final l in [en, pt]) {
        for (final kind in CaveatKind.values) {
          final text = caveatText(
            Caveat(kind, text: 'de', items: const ['US', 'CA']),
            l,
            l.localeName,
          );
          expect(text.trim(), isNotEmpty, reason: kind.name);
        }
      }
    });

    test('restrição de elegibilidade lista os países pelo nome', () {
      final t = caveatText(
        const Caveat(CaveatKind.eligibilityRestricted, items: ['BR', 'EMEA']),
        en,
        'en',
      );
      expect(t, contains('EMEA'));
      expect(t, isNot(contains('BR,')));
    });

    test('idioma diferente cita o idioma pelo nome nativo', () {
      final t = caveatText(
        const Caveat(CaveatKind.languageDiffers, text: 'de'),
        en,
        'en',
      );
      expect(t, contains('Deutsch'));
    });
  });

  group('fitLabel', () {
    test('cada nível tem um rótulo diferente', () {
      for (final l in [en, pt]) {
        expect({
          for (final f in Fit.values) fitLabel(f, l),
        }, hasLength(Fit.values.length));
      }
      expect(fitLabel(Fit.strong, en), en.rcFitStrong);
    });
  });
}
