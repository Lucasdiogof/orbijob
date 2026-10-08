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
  String get navHome => 'Início';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navApplications => 'Candidaturas';

  @override
  String get navMain => 'Navegação principal';

  @override
  String get profile => 'Perfil';

  @override
  String get back => 'Voltar';

  @override
  String get homeTitle => 'O que você procura?';

  @override
  String get homeSearchHint => 'Qualquer profissão ou país';

  @override
  String get homeAreasTitle => 'Explorar por área';

  @override
  String get areaTechnology => 'Tecnologia';

  @override
  String get areaHealth => 'Saúde';

  @override
  String get areaConstruction => 'Construção';

  @override
  String get areaEducation => 'Educação';

  @override
  String get areaServices => 'Serviços';

  @override
  String get areaIndustry => 'Indústria';

  @override
  String get areaTransport => 'Transporte';

  @override
  String get homeForYouTitle => 'Para você';

  @override
  String get homeForYouEmptyTitle => 'Nenhuma compatibilidade ainda';

  @override
  String get homeForYouEmptyBody =>
      'As compatibilidades aparecem aqui quando houver fontes de vagas conectadas e seu perfil estiver preenchido.';

  @override
  String get homeApplicationsTitle => 'Candidaturas';

  @override
  String get homeApplicationsEmptyTitle => 'Nenhuma candidatura registrada';

  @override
  String get homeApplicationsEmptyBody =>
      'Acompanhe onde se candidatou, entrevistas e propostas.';

  @override
  String get searchHint =>
      'Qualquer profissão, ex.: eletricista, enfermeiro, desenvolvedor Flutter';

  @override
  String get searchLabel => 'Pesquisar vagas';

  @override
  String get searchClear => 'Limpar pesquisa';

  @override
  String get exploreIdleTitle => 'Pesquise qualquer profissão';

  @override
  String get exploreIdleBody =>
      'Digite uma profissão ou escolha uma área. Os resultados vêm somente de fontes aprovadas.';

  @override
  String get searching => 'Pesquisando…';

  @override
  String get emptyTitle => 'Nenhuma vaga encontrada';

  @override
  String get emptyBody => 'Tente outra profissão ou uma busca mais ampla.';

  @override
  String get noSourceTitle => 'Nenhuma fonte integrada para esta busca';

  @override
  String get noSourceBody =>
      'Ainda não temos fonte autorizada para este país e profissão. Tente os portais de vagas originais.';

  @override
  String get errorTitle => 'Algo deu errado';

  @override
  String get errorBody =>
      'Não foi possível carregar os resultados. Verifique a conexão e tente novamente.';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get favoritesTitle => 'Nenhum favorito ainda';

  @override
  String get favoritesBody => 'As vagas salvas aparecem aqui.';

  @override
  String get applicationsTitle => 'Nenhuma candidatura registrada';

  @override
  String get applicationsBody =>
      'Acompanhe onde se candidatou, entrevistas e propostas. O status é atualizado manualmente.';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileEmptyTitle => 'Seu perfil profissional chega em breve';

  @override
  String get profileEmptyBody =>
      'Currículo, experiências e preferências ficarão aqui.';

  @override
  String get appearanceTitle => 'Aparência';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get workModeRemote => 'Remoto';

  @override
  String get workModeHybrid => 'Híbrido';

  @override
  String get workModeOnsite => 'Presencial';

  @override
  String get compatibilityLabel => 'Compatibilidade';

  @override
  String compatibilityValue(int score) {
    return 'Compatibilidade $score de 100';
  }

  @override
  String get confidenceLabel => 'Confiança';

  @override
  String get confidenceHigh => 'Confiança alta';

  @override
  String get confidenceMedium => 'Confiança média';

  @override
  String get confidenceLow => 'Confiança baixa';

  @override
  String confidenceSemantic(String level) {
    return 'Confiança da análise: $level';
  }

  @override
  String get scoreExplainer =>
      'Compatibilidade e confiança são medidas separadas.';

  @override
  String sourceLabel(String name) {
    return 'Fonte: $name';
  }

  @override
  String get favoriteAdd => 'Salvar vaga';

  @override
  String get favoriteRemove => 'Remover dos favoritos';

  @override
  String get perHour => '/h';

  @override
  String get perDay => '/dia';

  @override
  String get perWeek => '/semana';

  @override
  String get perMonth => '/mês';

  @override
  String get perYear => '/ano';

  @override
  String get publishedToday => 'Publicada hoje';

  @override
  String get publishedYesterday => 'Publicada ontem';

  @override
  String publishedDaysAgo(int count) {
    return 'Publicada há $count dias';
  }

  @override
  String publishedWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Publicada há $count semanas',
      one: 'Publicada há 1 semana',
    );
    return '$_temp0';
  }

  @override
  String publishedMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Publicada há $count meses',
      one: 'Publicada há 1 mês',
    );
    return '$_temp0';
  }

  @override
  String get jobDetailTitle => 'Detalhes da vaga';

  @override
  String get openOfficialApplication => 'Abrir candidatura oficial';

  @override
  String get selectJobHint => 'Selecione uma vaga para ver os detalhes.';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
    );
    return '$_temp0';
  }

  @override
  String get previewBanner =>
      'PRÉVIA · DADOS ILUSTRATIVOS, NÃO SÃO VAGAS REAIS';

  @override
  String get previewAction => 'Somente prévia: esta ação não está disponível.';
}
