import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_alternatives.dart';

/// OrbiJob 13.0: the Spanish regional employment services (Murcia, Catalonia, Castilla y León, Basque Country) write offers in Spanish and Catalan. The professions they
/// name must be found from the other languages and the other way round, without turning a specific profession into a whole field.
bool has(String term, String part) =>
    titleAlternatives(term).any((a) => a.length == 1 && a.first == part);

void main() {
  group('Spanish and Catalan professions', () {
    test('teacher: profesor <-> teacher <-> Lehrer <-> enseignant', () {
      expect(has('profesor', 'teacher'), true);
      expect(has('profesor', 'lehrer'), true);
      expect(has('teacher', 'profesor'), true);
      expect(has('enseignant', 'profesor'), true);
    });
    test('nurse: infermer (Catalan) <-> enfermero <-> nurse', () {
      expect(has('infermera', 'nurse'), true);
      expect(has('infermera', 'enfermer'), true);
      expect(has('enfermero', 'infermer'), true);
      expect(has('nurse', 'infermer'), true);
    });
    test(
      'waiting staff and cooks across Spanish, Catalan, English, German',
      () {
        expect(has('cambrer', 'waiter'), true);
        expect(has('camarero', 'cambrer'), true);
        expect(has('waiter', 'camarero'), true);
        expect(has('cuiner', 'cook'), true);
        expect(has('cocinero', 'cuiner'), true);
      },
    );
    test(
      'office work: auxiliar administrativo <-> administrative assistant <-> Sachbearbeiter, but never every administrator',
      () {
        expect(
          has('auxiliar administrativo', 'administrative assistant'),
          true,
        );
        expect(has('administrative assistant', 'administrativo'), true);
        expect(has('administrative assistant', 'sachbearbeiter'), true);
        expect(has('administratiu', 'administrative assistant'), true);
        for (final t in ['administrative assistant', 'administrativo']) {
          expect(has(t, 'administrator'), isFalse, reason: t);
          expect(has(t, 'administrativ'), isFalse, reason: t);
        }
        expect(
          titleAlternatives('administrador de sistemas'),
          isNot(contains(['administrative assistant'])),
        );
      },
    );
    test('cleaning staff', () {
      expect(has('limpiador', 'cleaner'), true);
      expect(has('cleaner', 'limpiador'), true);
      expect(has('cleaner', 'netejador'), true);
    });
    test('unrelated words are not professions', () {
      for (final t in ['administración pública', 'limpieza', 'infermeria']) {
        // a field or a place is not the profession: none of these may open the profession's other names
        final alts = titleAlternatives(t);
        expect(
          alts.any((a) => a.length == 1 && a.first == 'cleaner'),
          isFalse,
          reason: t,
        );
      }
    });
  });
}
