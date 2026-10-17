import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_alternatives.dart';

/// OrbiJob 14.0, second round: Brazilian Portuguese trade names measured on the public catalogue (0 results for most before the groups existed).
bool has(String term, String part) =>
    titleAlternatives(term).any((a) => a.length == 1 && a.first == part);

void main() {
  test('nursing assistants are their own profession, not nurses', () {
    expect(has('auxiliar de enfermagem', 'nursing assistant'), true);
    expect(has('técnico de enfermagem', 'pflegehelfer'), true);
    expect(has('nursing assistant', 'undersköterska'), true);
    expect(has('auxiliar de enfermagem', 'nurse'), isFalse);
    expect(has('enfermeiro', 'nurse'), true);
  });
  test('butcher, kitchen assistant, delivery, seamstress, elderly care', () {
    expect(has('açougueiro', 'metzger'), true);
    expect(has('auxiliar de cozinha', 'küchenhilfe'), true);
    expect(has('entregador', 'delivery driver'), true);
    expect(has('delivery driver', 'repartidor'), true);
    expect(has('delivery driver', 'motorista'), isFalse);
    expect(has('costureira', 'seamstress'), true);
    expect(has('cuidador de idosos', 'care worker'), true);
  });
  test('production, machines, shops, maintenance', () {
    expect(has('auxiliar de produção', 'production operator'), true);
    expect(has('operador de máquinas', 'maschinenführer'), true);
    expect(has('balconista', 'shop assistant'), true);
    expect(has('técnico de manutenção', 'wartungstechniker'), true);
  });
  test(
    'a plural of a word of the name is not a qualifier: "gerente de projetos"',
    () {
      expect(has('gerente de projetos', 'project manager'), true);
      for (final a in titleAlternatives('gerente de projetos')) {
        expect(a.contains('projetos'), isFalse, reason: '$a');
      }
    },
  );
}
