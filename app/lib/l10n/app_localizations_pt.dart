// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'OrbiJob';

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

  @override
  String get navHome => 'Início';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navApplications => 'Candidaturas';

  @override
  String get profile => 'Perfil';

  @override
  String get homeTitle => 'Bem-vindo ao OrbiJob';

  @override
  String get homeBody =>
      'Suas compatibilidades e atividade recente aparecerão aqui quando as fontes de vagas estiverem conectadas.';

  @override
  String get favoritesTitle => 'Nenhum favorito ainda';

  @override
  String get favoritesBody => 'As vagas salvas aparecerão aqui.';

  @override
  String get applicationsTitle => 'Nenhuma candidatura registrada';

  @override
  String get applicationsBody =>
      'Acompanhe onde se candidatou, entrevistas e propostas. O status é atualizado manualmente.';

  @override
  String get profileSoon => 'Perfil, currículo e experiências chegam em breve.';
}
