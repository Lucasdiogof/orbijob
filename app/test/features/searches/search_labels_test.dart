import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/searches/domain/saved_search.dart';
import 'package:orbijob/features/searches/domain/search_spec.dart';
import 'package:orbijob/features/searches/presentation/search_labels.dart';
import 'package:orbijob/l10n/app_localizations_en.dart';
import 'package:orbijob/l10n/app_localizations_pt.dart';

void main() {
  final en = AppLocalizationsEn();
  final pt = AppLocalizationsPt();

  group('describeSpec', () {
    test('busca vazia não tem partes', () {
      expect(describeSpec(const SearchSpec(), en, 'en'), isEmpty);
    });

    test('começa pelo texto digitado, na ordem de leitura', () {
      final parts = describeSpec(
        SearchSpec(
          term: 'enfermeira',
          countryCode: 'BR',
          filters: const JobFilters(workModes: {WorkMode.remote}),
        ),
        pt,
        'pt',
      );
      expect(parts.first, 'enfermeira');
      expect(parts, hasLength(3));
    });

    test(
      'o país vira nome no idioma pedido; código desconhecido fica como está',
      () {
        final br = describeSpec(const SearchSpec(countryCode: 'BR'), en, 'en');
        expect(br.single, isNot('BR'));
        final pt0 = describeSpec(const SearchSpec(countryCode: 'BR'), pt, 'pt');
        expect(pt0.single, isNot(br.single));
      },
    );

    test('modo "não informado" nunca aparece como filtro', () {
      final parts = describeSpec(
        const SearchSpec(
          filters: JobFilters(workModes: {WorkMode.unspecified}),
        ),
        en,
        'en',
      );
      expect(parts, isEmpty);
    });

    test('vários modos aparecem na ordem do enum', () {
      final parts = describeSpec(
        const SearchSpec(
          filters: JobFilters(workModes: {WorkMode.onsite, WorkMode.remote}),
        ),
        en,
        'en',
      );
      expect(parts, hasLength(2));
      final remote = describeSpec(
        const SearchSpec(filters: JobFilters(workModes: {WorkMode.remote})),
        en,
        'en',
      ).single;
      expect(parts.first, remote);
    });

    test('sete dias tem texto próprio; outros prazos usam o número', () {
      final seven = describeSpec(
        const SearchSpec(filters: JobFilters(publishedWithinDays: 7)),
        en,
        'en',
      ).single;
      expect(seven, en.filterPublished7);
      final thirty = describeSpec(
        const SearchSpec(filters: JobFilters(publishedWithinDays: 30)),
        en,
        'en',
      ).single;
      expect(thirty, en.ssSpecDays(30));
      expect(thirty, contains('30'));
    });

    test('só com salário entra como parte', () {
      final parts = describeSpec(
        const SearchSpec(filters: JobFilters(onlyWithSalary: true)),
        en,
        'en',
      );
      expect(parts.single, en.filterWithSalary);
    });

    test('área aparece quando escolhida', () {
      final parts = describeSpec(
        const SearchSpec(filters: JobFilters(area: JobArea.health)),
        en,
        'en',
      );
      expect(parts, hasLength(1));
      expect(parts.single.trim(), isNotEmpty);
    });
  });

  group('defaultSearchName', () {
    test('sem partes, é "All jobs" no idioma', () {
      expect(defaultSearchName(const SearchSpec(), en, 'en'), en.ssAllJobs);
      expect(defaultSearchName(const SearchSpec(), pt, 'pt'), pt.ssAllJobs);
    });

    test('junta no máximo 3 partes com " · "', () {
      final name = defaultSearchName(
        SearchSpec(
          term: 'dev',
          countryCode: 'BR',
          filters: const JobFilters(
            area: JobArea.health,
            workModes: {WorkMode.remote},
            onlyWithSalary: true,
          ),
        ),
        en,
        'en',
      );
      expect(name.split(' · '), hasLength(3));
      expect(name, startsWith('dev'));
    });

    test('nome longo é cortado em 80 caracteres sem espaço sobrando', () {
      final name = defaultSearchName(SearchSpec(term: 'a' * 200), en, 'en');
      expect(name.length, lessThanOrEqualTo(80));
      expect(name, isNot(endsWith(' ')));
    });
  });

  group('savedSearchTitle e frequência', () {
    test('usa o nome dado pela pessoa; sem nome, gera um', () {
      const named = SavedSearch(id: '1', query: {}, name: 'Vagas de casa');
      expect(savedSearchTitle(named, en, 'en'), 'Vagas de casa');
      const unnamed = SavedSearch(id: '2', query: {});
      expect(savedSearchTitle(unnamed, en, 'en'), en.ssAllJobs);
    });

    test('cada frequência tem texto próprio nos dois idiomas', () {
      for (final l in [en, pt]) {
        final labels = {
          for (final f in AlertFrequency.values) frequencyLabel(f, l),
        };
        expect(labels, hasLength(AlertFrequency.values.length));
      }
      expect(frequencyLabel(AlertFrequency.daily, en), en.ssFreqDaily);
    });
  });
}
