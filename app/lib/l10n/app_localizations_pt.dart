// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'JobRadar';

  @override
  String get searchHint =>
      'Qualquer profissão, ex.: eletricista, enfermeiro, desenvolvedor Flutter';

  @override
  String get emptyTitle => 'Pesquise qualquer profissão';

  @override
  String get emptyBody =>
      'Nenhuma fonte de vagas está conectada ainda. Os resultados mostrarão apenas dados reais de fontes aprovadas.';

  @override
  String get loading => 'Pesquisando…';

  @override
  String get errorTitle => 'Algo deu errado';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get noSourceTitle => 'Nenhuma fonte integrada para esta busca';

  @override
  String get noSourceBody => 'Tente os portais originais.';
}
