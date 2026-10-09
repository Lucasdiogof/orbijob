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

  @override
  String jobLanguageSemantic(String code) {
    return 'Idioma da vaga: $code';
  }

  @override
  String originalLanguageNote(String code) {
    return 'Exibida no idioma original ($code). Cargos, nomes de empresas e descrições não são traduzidos.';
  }

  @override
  String get recentSearchesTitle => 'Pesquisas recentes';

  @override
  String get recentSearchesClear => 'Limpar pesquisas recentes';

  @override
  String get interestCountriesTitle => 'Países de interesse';

  @override
  String get interestCountriesEmptyTitle => 'Nenhum país escolhido ainda';

  @override
  String get interestCountriesEmptyBody =>
      'Adicione países no seu perfil para direcioná-los.';

  @override
  String get applicationStageApplied => 'Inscrito';

  @override
  String get applicationStageScreening => 'Triagem';

  @override
  String get applicationStageInterview => 'Entrevista';

  @override
  String get applicationStageOffer => 'Proposta';

  @override
  String get applicationStageRejected => 'Rejeitada';

  @override
  String get applicationStageWithdrawn => 'Retirada';

  @override
  String get applicationStageClosed => 'Encerrada';

  @override
  String get accountTitle => 'Conta';

  @override
  String get accountUnavailableTitle =>
      'Contas não estão ativadas nesta versão';

  @override
  String get accountUnavailableBody =>
      'Tudo funciona neste aparelho sem entrar. A sincronização chega quando o serviço for conectado.';

  @override
  String accountSignedInAs(String email) {
    return 'Conectado como $email';
  }

  @override
  String get accountSignedInNoEmail => 'Conectado';

  @override
  String get accountSignedOutBody =>
      'Entre para manter seu perfil, favoritos e candidaturas na sua conta.';

  @override
  String get accountSignIn => 'Entrar';

  @override
  String get accountSignOut => 'Sair';

  @override
  String get authSignInTitle => 'Entrar';

  @override
  String get authSignUpTitle => 'Criar conta';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Senha';

  @override
  String get authSignInAction => 'Entrar';

  @override
  String get authSignUpAction => 'Criar conta';

  @override
  String get authSwitchToSignUp => 'Ainda não tem conta? Crie uma';

  @override
  String get authSwitchToSignIn => 'Já tem conta? Entre';

  @override
  String get authForgotPassword => 'Esqueci a senha';

  @override
  String get authEmailInvalid => 'Informe um e-mail válido';

  @override
  String get authPasswordShort => 'Use pelo menos 8 caracteres';

  @override
  String get authConfirmationSent =>
      'Confira seu e-mail para confirmar a conta e depois entre.';

  @override
  String get authResetSent =>
      'Se o endereço tiver conta, um link de redefinição foi enviado.';

  @override
  String get authErrorInvalidCredentials => 'E-mail ou senha incorretos.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirme seu e-mail primeiro. Veja sua caixa de entrada.';

  @override
  String get authErrorEmailTaken =>
      'Este e-mail já está cadastrado. Tente entrar.';

  @override
  String get authErrorInvalidEmail => 'Este endereço de e-mail não é válido.';

  @override
  String get authErrorWeakPassword =>
      'Senha fraca demais. Use uma mais longa e incomum.';

  @override
  String get authErrorRateLimited =>
      'Muitas tentativas. Aguarde alguns minutos e tente de novo.';

  @override
  String get authErrorNetwork =>
      'Sem conexão. Verifique a internet e tente de novo.';

  @override
  String get authErrorUnavailable => 'O serviço está indisponível no momento.';

  @override
  String get authErrorUnknown => 'Algo deu errado. Tente novamente.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonAdd => 'Adicionar';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonOptional => 'Opcional';

  @override
  String get commonRequired => 'Campo obrigatório';

  @override
  String get commonDeleteConfirmBody => 'Esta ação não pode ser desfeita.';

  @override
  String get fieldStartDate => 'Data de início';

  @override
  String get fieldEndDate => 'Data de término';

  @override
  String get dateChoose => 'Escolher data';

  @override
  String get dateClear => 'Limpar data';

  @override
  String tooLongError(int max) {
    return 'Muito longo (máximo de $max caracteres)';
  }

  @override
  String get dataLoadErrorTitle => 'Não foi possível carregar seus dados';

  @override
  String get dataSignInTitle => 'Entre para continuar';

  @override
  String get dataFailureNotConfigured =>
      'Esta versão do app não está conectada a um serviço de contas, então nada pode ser salvo aqui.';

  @override
  String get dataFailureSignedOut =>
      'Seus dados ficam na sua conta. Entre para ver e alterar.';

  @override
  String get dataFailureSessionExpired =>
      'Sua sessão terminou. Entre novamente para continuar.';

  @override
  String get dataFailureNetwork =>
      'Sem conexão. Verifique a internet e tente novamente.';

  @override
  String get dataFailureDenied =>
      'O servidor não permitiu esta ação para a sua conta.';

  @override
  String get dataFailureQuota =>
      'Você atingiu o limite para este tipo de item. Remova um para adicionar outro.';

  @override
  String get dataFailureDuplicate => 'Isto já existe.';

  @override
  String get dataFailureInvalid =>
      'Algum dado não é válido. Confira os campos e tente novamente.';

  @override
  String get dataFailureTooLarge => 'O arquivo é maior que 5 MB.';

  @override
  String get dataFailureNotPdf => 'Só são aceitos arquivos PDF.';

  @override
  String get dataFailureEmptyFile => 'O arquivo está vazio.';

  @override
  String get dataFailureNotFound =>
      'Este item não existe mais. Atualize e tente novamente.';

  @override
  String get dataFailureUnavailable =>
      'O serviço está indisponível agora. Tente novamente mais tarde.';

  @override
  String get dataFailureUnknown => 'Algo deu errado. Tente novamente.';

  @override
  String get applicationsAdd => 'Adicionar candidatura';

  @override
  String get applicationsDisclaimer =>
      'O OrbiJob nunca envia candidaturas. Aqui você registra as que enviou por conta própria.';

  @override
  String get applicationNewTitle => 'Nova candidatura';

  @override
  String get applicationDetailTitle => 'Candidatura';

  @override
  String get applicationCompany => 'Empresa';

  @override
  String get applicationJobTitle => 'Cargo da vaga';

  @override
  String get applicationLink => 'Link da vaga';

  @override
  String get applicationLinkInvalid => 'Informe um link começando com https://';

  @override
  String get applicationChannel => 'Onde se candidatou';

  @override
  String get applicationStageLabel => 'Etapa';

  @override
  String get applicationAppliedOn => 'Candidatura em';

  @override
  String get applicationNote => 'Observações';

  @override
  String get applicationSaveNote => 'Salvar observações';

  @override
  String get applicationOpenLink => 'Abrir vaga';

  @override
  String get applicationLinkCannotOpen => 'Não foi possível abrir o link.';

  @override
  String get applicationHistory => 'Histórico';

  @override
  String get applicationHistoryEmpty =>
      'Nenhuma mudança de etapa registrada ainda.';

  @override
  String get applicationDeleteTitle => 'Excluir esta candidatura?';

  @override
  String get applicationNoDate => 'Data não informada';

  @override
  String homeApplicationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count candidaturas acompanhadas',
      one: '1 candidatura acompanhada',
    );
    return '$_temp0';
  }

  @override
  String get profileSectionProfessional => 'Perfil profissional';

  @override
  String get profileCreateTitle => 'Crie seu perfil profissional';

  @override
  String get profileCreateBody =>
      'Diga quem você é profissionalmente. Qualquer profissão é bem-vinda.';

  @override
  String get profileCreateAction => 'Criar perfil';

  @override
  String get profileEditAction => 'Editar perfil';

  @override
  String get profileFieldName => 'Nome profissional';

  @override
  String get profileFieldHeadline => 'Cargo ou profissão';

  @override
  String get profileFieldSummary => 'Resumo';

  @override
  String get profileFieldCountry => 'País de residência (código de 2 letras)';

  @override
  String get profileFieldCity => 'Cidade';

  @override
  String get profileFieldWorkMode => 'Modalidade de trabalho desejada';

  @override
  String get profileWorkModeAny => 'Sem preferência';

  @override
  String get profileFieldSkills => 'Competências';

  @override
  String get profileSkillAdd => 'Adicionar competência';

  @override
  String profileSkillRemove(String name) {
    return 'Remover competência $name';
  }

  @override
  String get profileSkillsLimit => 'Até 200 competências.';

  @override
  String get profileCountryInvalid =>
      'Use um código de 2 letras, por exemplo BR';

  @override
  String get profileSaved => 'Perfil salvo';

  @override
  String get profileNeedsProfile =>
      'Crie seu perfil primeiro para adicionar isto.';

  @override
  String get profileSignInBody =>
      'Entre para criar e manter seu perfil profissional.';

  @override
  String get experienceSection => 'Experiência profissional';

  @override
  String get experienceAdd => 'Adicionar experiência';

  @override
  String get experienceNewTitle => 'Nova experiência';

  @override
  String get experienceEditTitle => 'Editar experiência';

  @override
  String get experienceCompany => 'Empresa';

  @override
  String get experienceRole => 'Cargo';

  @override
  String get experienceCurrent => 'Trabalho aqui atualmente';

  @override
  String get experienceDescription => 'Descrição';

  @override
  String get experiencePresent => 'Atual';

  @override
  String get experienceEmpty => 'Nenhuma experiência adicionada ainda.';

  @override
  String get experienceDatesInvalid =>
      'A data de término não pode ser anterior à de início';

  @override
  String get experienceCurrentNeedsStart =>
      'Escolha a data de início para um trabalho atual';

  @override
  String get experienceDeleteTitle => 'Excluir esta experiência?';

  @override
  String get educationSection => 'Formação acadêmica';

  @override
  String get educationAdd => 'Adicionar formação';

  @override
  String get educationNewTitle => 'Nova formação';

  @override
  String get educationEditTitle => 'Editar formação';

  @override
  String get educationInstitution => 'Instituição';

  @override
  String get educationDegree => 'Grau (se houver)';

  @override
  String get educationField => 'Curso ou área de estudo';

  @override
  String get educationEmpty => 'Nenhuma formação adicionada. É opcional.';

  @override
  String get educationDeleteTitle => 'Excluir esta formação?';

  @override
  String get resumesSection => 'Currículos';

  @override
  String get resumesBody =>
      'Somente PDF, até 5 MB cada, até 10 arquivos. Guardados de forma privada na sua conta.';

  @override
  String get resumesUpload => 'Enviar PDF';

  @override
  String get resumesUploading => 'Enviando…';

  @override
  String get resumesEmpty => 'Nenhum currículo enviado ainda.';

  @override
  String resumeItem(String date) {
    return 'Currículo de $date';
  }

  @override
  String get resumeOpen => 'Abrir';

  @override
  String get resumeUploaded => 'Currículo enviado';

  @override
  String get resumeDeleteTitle => 'Excluir este currículo?';

  @override
  String get resumeDeleteBody => 'O arquivo é removido da sua conta.';

  @override
  String get preferencesSection => 'Preferências de busca';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSystem => 'Idioma do aparelho';

  @override
  String get languagePt => 'Português';

  @override
  String get languageEn => 'English';

  @override
  String get languageEs => 'Español';

  @override
  String get preferencesLocalOnly =>
      'Entre para manter estas escolhas na sua conta. Até lá, valem só neste aparelho.';

  @override
  String get countriesTitle => 'Países de interesse';

  @override
  String get countriesHint => 'Adicionar país (código de 2 letras)';

  @override
  String get countriesEmpty => 'Nenhum país escolhido.';

  @override
  String get countriesInvalid =>
      'Use um código de 2 letras que ainda não esteja na lista, por exemplo DE';

  @override
  String countriesRemove(String code) {
    return 'Remover país $code';
  }

  @override
  String get savedSearchesTitle => 'Pesquisas salvas';

  @override
  String get savedSearchesNote => 'Guardadas na sua conta.';

  @override
  String get recentSearchesNote =>
      'As pesquisas recentes ficam neste aparelho.';

  @override
  String get savedSearchSave => 'Salvar esta pesquisa';

  @override
  String get savedSearchSaved => 'Pesquisa salva';

  @override
  String savedSearchRemove(String term) {
    return 'Remover pesquisa salva $term';
  }

  @override
  String get authNewPasswordTitle => 'Escolha uma nova senha';

  @override
  String get authNewPasswordLabel => 'Nova senha';

  @override
  String get authNewPasswordAction => 'Salvar nova senha';

  @override
  String get authPasswordChanged => 'Senha atualizada.';

  @override
  String get authSessionExpired => 'Sua sessão terminou. Entre novamente.';

  @override
  String get authErrorLinkInvalid =>
      'Este link expirou ou já foi usado. Solicite um novo.';

  @override
  String get authErrorSamePassword => 'Escolha uma senha diferente da atual.';

  @override
  String get authCancelRecovery => 'Cancelar';

  @override
  String get commonLoading => 'Carregando';
}
