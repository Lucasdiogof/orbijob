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
      'Se o endereço tiver conta, um código de 6 dígitos foi enviado.';

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
  String get authErrorCodeInvalid =>
      'Código incorreto ou expirado. Confira o e-mail ou peça um novo código.';

  @override
  String get authRecoveryTitle => 'Redefinir senha';

  @override
  String get authRecoverySubtitle =>
      'Informe seu e-mail e enviaremos um código de 6 dígitos.';

  @override
  String get authRecoverySendCode => 'Enviar código';

  @override
  String authRecoveryEnterCode(String email) {
    return 'Digite o código de 6 dígitos enviado para $email.';
  }

  @override
  String get authRecoveryCodeLabel => 'Código de 6 dígitos';

  @override
  String get authRecoveryCodeShort => 'Digite os 6 dígitos';

  @override
  String get authRecoveryVerify => 'Continuar';

  @override
  String get authRecoveryResend => 'Enviar novo código';

  @override
  String authRecoveryResendIn(int seconds) {
    return 'Enviar novo código em ${seconds}s';
  }

  @override
  String get authRecoveryChangeEmail => 'Usar outro e-mail';

  @override
  String get authCancelRecovery => 'Cancelar';

  @override
  String get commonLoading => 'Carregando';

  @override
  String get filtersButton => 'Filtros';

  @override
  String filtersButtonCount(int count) {
    return 'Filtros ($count)';
  }

  @override
  String get filtersClear => 'Limpar filtros';

  @override
  String get filterWorkMode => 'Modalidade';

  @override
  String get filterPublished => 'Publicada';

  @override
  String get filterPublished1 => 'Últimas 24 horas';

  @override
  String get filterPublished7 => 'Últimos 7 dias';

  @override
  String get filterPublished30 => 'Últimos 30 dias';

  @override
  String get filterWithSalary => 'Só com salário';

  @override
  String get filterCountry => 'País (do seu perfil)';

  @override
  String get filterContinent => 'Região';

  @override
  String get homeRegionsTitle => 'Explorar por região';

  @override
  String get continentEurope => 'Europa';

  @override
  String get continentOceania => 'Oceania';

  @override
  String get continentAsia => 'Ásia';

  @override
  String get continentAfrica => 'África';

  @override
  String get continentNorthAmerica => 'América do Norte';

  @override
  String get continentSouthAmerica => 'América do Sul';

  @override
  String get browseLatest => 'Ver vagas recentes';

  @override
  String get loadMore => 'Mostrar mais';

  @override
  String get loadMoreFailed => 'Não foi possível carregar mais vagas.';

  @override
  String resultsShown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrando $count vagas',
      one: 'Mostrando 1 vaga',
    );
    return '$_temp0';
  }

  @override
  String get emptyFiltersBody =>
      'Nenhuma vaga com esses filtros. Tente remover algum.';

  @override
  String get openOriginalListing => 'Abrir anúncio original';

  @override
  String eligibleIn(String places) {
    return 'Aberta a candidatos em: $places';
  }

  @override
  String get jobDescriptionTitle => 'Descrição';

  @override
  String get locationAnywhere => 'Qualquer lugar';

  @override
  String get eligibleAnywhere =>
      'Aberta a candidatos de qualquer lugar, segundo a fonte';

  @override
  String get eligibilityUnknown =>
      'Elegibilidade geográfica não informada pela fonte';

  @override
  String get eligibilityCheckOriginal =>
      'Confira a elegibilidade no anúncio original antes de se candidatar.';

  @override
  String salaryFrom(String amount) {
    return 'A partir de $amount';
  }

  @override
  String salaryUpTo(String amount) {
    return 'Até $amount';
  }

  @override
  String get areaData => 'Dados e IA';

  @override
  String get areaDesign => 'Design';

  @override
  String get areaProduct => 'Produto e projetos';

  @override
  String get areaSales => 'Vendas';

  @override
  String get areaMarketing => 'Marketing e conteúdo';

  @override
  String get areaSupport => 'Atendimento e suporte';

  @override
  String get areaFinance => 'Finanças e jurídico';

  @override
  String get areaPeople => 'Pessoas e operações';

  @override
  String get areaHospitality => 'Hotelaria e turismo';

  @override
  String get areaPublic => 'Setor público e terceiro setor';

  @override
  String get areaAll => 'Todas as áreas';

  @override
  String get notConfiguredTitle => 'Esta versão não está conectada ao OrbiJob';

  @override
  String get notConfiguredBody =>
      'O app foi iniciado sem a configuração do servidor (SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY). Desenvolvedores: execute com --dart-define-from-file.';

  @override
  String get homeLatestTitle => 'Vagas recentes';

  @override
  String get homeLatestSeeAll => 'Ver todas';

  @override
  String get homeLatestEmpty =>
      'Não há vagas para mostrar agora. Tente novamente mais tarde.';

  @override
  String get specPhysiotherapy => 'Fisioterapia';

  @override
  String get specPelvicPhysio => 'Fisioterapia pélvica';

  @override
  String get specNursing => 'Enfermagem';

  @override
  String get specMedicine => 'Medicina';

  @override
  String get specPsychology => 'Psicologia';

  @override
  String get specOccupationalTherapy => 'Terapia ocupacional';

  @override
  String get specNutrition => 'Nutrição';

  @override
  String get specDentistry => 'Odontologia';

  @override
  String get specPharmacy => 'Farmácia';

  @override
  String get specSpeechTherapy => 'Fonoaudiologia';

  @override
  String get specRadiology => 'Radiologia';

  @override
  String get specHospitalManagement => 'Gestão hospitalar';

  @override
  String get specAll => 'Toda a saúde';

  @override
  String get portalsButton => 'Portais especializados';

  @override
  String get portalsTitle => 'Procure em portais especializados';

  @override
  String get portalsNote =>
      'Links externos. Esses portais não permitem copiar as vagas, por isso elas não fazem parte do catálogo do OrbiJob: o link abre o próprio portal.';

  @override
  String get specialtyEmpty =>
      'Nenhuma vaga aberta desta especialidade no catálogo agora. Veja os portais especializados abaixo.';

  @override
  String get gateCreateAccount => 'Criar conta';

  @override
  String get gateKeepExploring => 'Continuar explorando vagas';

  @override
  String get gateFavoritesTitle =>
      'Suas melhores oportunidades, em um só lugar.';

  @override
  String get gateFavoritesBody =>
      'Salve as vagas que chamam sua atenção e volte a elas quando quiser.';

  @override
  String get gateFavorites1 => 'Salve vagas de qualquer país e profissão';

  @override
  String get gateFavorites2 => 'Encontre-as de novo em qualquer dispositivo';

  @override
  String get gateFavorites3 => 'Veja de relance se a vaga continua aberta';

  @override
  String get gateApplicationsTitle =>
      'Acompanhe cada etapa da sua próxima oportunidade.';

  @override
  String get gateApplicationsBody =>
      'Um painel simples dos processos em que você está, do interesse à oferta.';

  @override
  String get gateApplications1 => 'Registre onde e quando se candidatou';

  @override
  String get gateApplications2 => 'Mova cada processo pelas suas etapas';

  @override
  String get gateApplications3 => 'Guarde notas e datas importantes';

  @override
  String get gateResumesTitle =>
      'Tenha seu currículo pronto quando encontrar a vaga certa.';

  @override
  String get gateResumesBody =>
      'Seus arquivos ficam privados na sua conta e nunca são compartilhados sem você.';

  @override
  String get gateResumes1 => 'Envie currículos em PDF e guarde várias versões';

  @override
  String get gateResumes2 => 'Escolha qual é o seu currículo principal';

  @override
  String get gateResumes3 => 'Abra ou substitua um arquivo quando precisar';

  @override
  String get gateProfileTitle => 'Seu perfil profissional, sempre à mão.';

  @override
  String get gateProfileBody =>
      'Diga quem você é profissionalmente, em qualquer profissão e país.';

  @override
  String get gateProfile1 =>
      'Apresente sua experiência, formação e habilidades';

  @override
  String get gateProfile2 => 'Reaproveite seus dados ao se candidatar';

  @override
  String get gateProfile3 => 'Defina as modalidades e os países que prefere';

  @override
  String get gateSavedSearchesTitle => 'Guarde as buscas que importam.';

  @override
  String get gateSavedSearchesBody =>
      'Salve uma busca uma vez e repita com um toque.';

  @override
  String get gateSavedSearches1 => 'As buscas ficam na sua conta';

  @override
  String get gateSavedSearches2 => 'Reabra-as a partir do Início';

  @override
  String get gateSavedSearches3 => 'Remova quando quiser';

  @override
  String get homeHeadline => 'Encontre sua próxima oportunidade';

  @override
  String get homeGreetingMorning => 'Bom dia';

  @override
  String get homeGreetingAfternoon => 'Boa tarde';

  @override
  String get homeGreetingEvening => 'Boa noite';

  @override
  String get homeRemoteTitle => 'Vagas remotas';

  @override
  String get homeContinueTitle => 'Continue de onde parou';

  @override
  String get homeQuickLast7 => 'Novas da semana';

  @override
  String get areasPageTitle => 'Áreas profissionais';

  @override
  String get areasPageBody =>
      'Escolha uma área para ver as vagas abertas. Só aparecem áreas com vagas agora.';

  @override
  String areaJobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vagas',
      one: '1 vaga',
    );
    return '$_temp0';
  }

  @override
  String get filtersTitle => 'Filtros';

  @override
  String get filtersApply => 'Ver resultados';

  @override
  String get filtersReset => 'Limpar tudo';

  @override
  String get filterArea => 'Área profissional';

  @override
  String get filterAreaChip => 'Área';

  @override
  String get filterSalary => 'Salário';

  @override
  String get filterRegionAny => 'Qualquer lugar do mundo';

  @override
  String get filterCountryAny => 'Qualquer país';

  @override
  String get filterAreaAny => 'Todas as áreas';

  @override
  String get areaPickerTitle => 'Escolha uma área';

  @override
  String get areaPickerSpecialties => 'Especialidades';

  @override
  String get sortNewest => 'Mais recentes primeiro';

  @override
  String get exploreOpenFilters => 'Abrir filtros';

  @override
  String exploreFiltersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filtros ativos',
      one: '1 filtro ativo',
    );
    return '$_temp0';
  }

  @override
  String get authSignInHeadline => 'Que bom ter você de volta';

  @override
  String get authSignInSubtitle =>
      'Entre para ver seus favoritos, candidaturas e currículos.';

  @override
  String get authSignUpHeadline => 'Crie sua conta no OrbiJob';

  @override
  String get authSignUpSubtitle =>
      'Grátis. Salve vagas, acompanhe candidaturas e guarde seus currículos em um só lugar.';

  @override
  String get authShowPassword => 'Mostrar senha';

  @override
  String get authHidePassword => 'Ocultar senha';

  @override
  String get authBrowseWithoutAccount => 'Continuar sem conta';

  @override
  String get authNewPasswordSubtitle =>
      'Escolha uma nova senha com pelo menos 8 caracteres.';

  @override
  String get profileHubProfessionalSub =>
      'Cargo, competências, experiência e formação';

  @override
  String get profileHubResumesSub => 'Seus PDFs, com um currículo principal';

  @override
  String get profileHubPreferences => 'Preferências';

  @override
  String get profileHubPreferencesSub => 'Países de interesse e buscas salvas';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get profileHubSettingsSub => 'Idioma e aparência';

  @override
  String get privacyTitle => 'Privacidade';

  @override
  String get profileHubPrivacySub => 'Como seus dados são tratados';

  @override
  String get privacyIntro => 'O que o OrbiJob guarda e o que ele nunca faz.';

  @override
  String get privacyKeepsTitle => 'O que fica guardado';

  @override
  String get privacyKeeps1 => 'Seu e-mail e a sessão de acesso.';

  @override
  String get privacyKeeps2 =>
      'Seu perfil profissional, favoritos, candidaturas e preferências, legíveis só por você.';

  @override
  String get privacyKeeps3 =>
      'Currículos numa área privada da sua conta, abertos só por links temporários.';

  @override
  String get privacyNeverTitle => 'O que o OrbiJob nunca faz';

  @override
  String get privacyNever1 =>
      'Nunca se candidata por você: toda candidatura acontece no anúncio original.';

  @override
  String get privacyNever2 =>
      'Nunca compartilha seu currículo ou perfil com empresas ou outros usuários.';

  @override
  String get privacyNever3 => 'Nunca vende seus dados.';

  @override
  String profileCompletenessTitle(int percent) {
    return 'Perfil $percent% completo';
  }

  @override
  String get profileCompletenessHint =>
      'Um perfil completo ajuda a estimar sua compatibilidade com cada vaga. Falta:';

  @override
  String get profileCompletenessDone => 'Tudo o que o app usa está preenchido.';

  @override
  String get profileMissingHeadline => 'Cargo';

  @override
  String get profileMissingLocation => 'Localização';

  @override
  String get profileMissingSkills => 'Competências';

  @override
  String get profileMissingSummary => 'Resumo';

  @override
  String get profileMissingExperience => 'Experiência';

  @override
  String get profileMissingEducation => 'Formação';

  @override
  String get profileMissingResume => 'Currículo';

  @override
  String get resumePrimary => 'Principal';

  @override
  String get resumeSetPrimary => 'Definir como principal';

  @override
  String get resumePrimarySet => 'Currículo principal atualizado';

  @override
  String get resumeReplace => 'Substituir arquivo';

  @override
  String get resumeReplaceTitle => 'Substituir este currículo?';

  @override
  String get resumeReplaceBody =>
      'Escolha o novo PDF. Ele é enviado primeiro; só depois o arquivo antigo é removido da sua conta.';

  @override
  String get resumeReplaced => 'Currículo substituído';

  @override
  String get resumeMoreActions => 'Mais ações';

  @override
  String get resumeChooseFile => 'Escolher PDF';

  @override
  String get languageChooseHint => 'O app muda na hora.';

  @override
  String get formDiscardTitle => 'Descartar alterações?';

  @override
  String get formDiscardBody => 'O que você digitou será perdido.';

  @override
  String get formDiscard => 'Descartar';

  @override
  String get formKeepEditing => 'Continuar editando';

  @override
  String get commonSaved => 'Salvo';

  @override
  String get formFixErrors => 'Confira os campos destacados.';

  @override
  String get profileFieldEmail => 'E-mail de contato';

  @override
  String get profileFieldPhone => 'Telefone';

  @override
  String get profileEmailInvalid => 'Informe um e-mail válido';

  @override
  String get resumeSuggestAction => 'Preencher meu perfil com este currículo';

  @override
  String get resumeImportStart => 'Começar por um currículo em PDF';

  @override
  String get resumeImportTitle => 'Revise as sugestões';

  @override
  String get resumeImportIntro =>
      'O texto foi lido neste aparelho; o arquivo não foi enviado a lugar nenhum. Confira cada item e corrija o que estiver errado. Nada é salvo até você aplicar, e o que você já tem só é substituído onde você marcar.';

  @override
  String get resumeImportReading => 'Lendo o currículo…';

  @override
  String get resumeImportNoText =>
      'Este PDF não tem texto selecionável (parece um documento escaneado ou uma foto). O OrbiJob não lê imagens, então preencha seu perfil manualmente.';

  @override
  String get resumeImportEncrypted =>
      'Este PDF é protegido por senha, então o texto não pode ser lido.';

  @override
  String get resumeImportUnreadable =>
      'Não foi possível ler o texto deste PDF (fontes incomuns ou arquivo danificado).';

  @override
  String get resumeImportNothing =>
      'O texto foi lido, mas nenhum dado de perfil pôde ser reconhecido.';

  @override
  String get resumeImportDownloadFailed =>
      'Não foi possível abrir o arquivo para lê-lo.';

  @override
  String get resumeImportSectionIdentity => 'Identidade e contato';

  @override
  String get resumeImportSectionSkills => 'Competências';

  @override
  String get resumeImportSectionLanguages => 'Idiomas';

  @override
  String get resumeImportSectionExperience => 'Experiência';

  @override
  String get resumeImportSectionEducation => 'Formação';

  @override
  String resumeImportReplaces(String value) {
    return 'Substitui: $value';
  }

  @override
  String get resumeImportAlready => 'Já está no seu perfil';

  @override
  String get resumeImportNeedsFields =>
      'Preencha o cargo e a empresa para incluir esta entrada.';

  @override
  String get resumeImportNeedsInstitution =>
      'Preencha a instituição para incluir esta entrada.';

  @override
  String get resumeImportNeedsName =>
      'Um perfil precisa de um nome: marque e preencha o nome.';

  @override
  String resumeImportApply(int count) {
    return 'Aplicar $count selecionados';
  }

  @override
  String get resumeImportApplied => 'Perfil atualizado com seu currículo';

  @override
  String get resumeImportOfferTitle =>
      'Preencher seu perfil com este currículo?';

  @override
  String get resumeImportOfferBody =>
      'O OrbiJob pode ler o texto neste aparelho e sugerir dados. Você revisa tudo antes de qualquer coisa ser salva.';

  @override
  String get resumeImportOfferYes => 'Ver sugestões';

  @override
  String get resumeImportOfferNo => 'Agora não';

  @override
  String get resumeImportPresent => 'atual';

  @override
  String resumeImportDates(String from, String to) {
    return '$from – $to';
  }

  @override
  String get kitButton => 'Preparar minha candidatura';

  @override
  String get kitTitle => 'Kit de candidatura';

  @override
  String get kitIntro =>
      'O OrbiJob nunca preenche nem envia formulários em outros sites. Copie o que precisar do seu perfil, abra o anúncio original e cole lá.';

  @override
  String get kitSignIn => 'Entre para usar os dados do seu perfil.';

  @override
  String get kitEmpty =>
      'Seu perfil ainda não tem dados para copiar. Preencha-o ou comece por um currículo em PDF.';

  @override
  String kitCopy(String field) {
    return 'Copiar $field';
  }

  @override
  String kitCopied(String field) {
    return '$field copiado';
  }

  @override
  String get kitCopyAll => 'Copiar tudo';

  @override
  String get kitAllCopied => 'Dados do perfil copiados';

  @override
  String get kitLocation => 'Localização';

  @override
  String get kitLinks => 'Links';

  @override
  String get kitLastJob => 'Experiência mais recente';

  @override
  String get kitLastEducation => 'Formação mais recente';

  @override
  String get kitMainResume => 'Abrir meu currículo principal';

  @override
  String get kitMainResumeHint => 'Baixe pelo link para anexá-lo no anúncio.';

  @override
  String get kitTrack => 'Já me candidatei: acompanhar';

  @override
  String get kitTrackConfirmTitle => 'Acompanhar esta candidatura?';

  @override
  String get kitTrackConfirmBody =>
      'Ela entra em Candidaturas como Inscrito, com a data de hoje. O OrbiJob não consegue verificar se você realmente se candidatou.';

  @override
  String get kitTracked => 'Adicionada às suas candidaturas';

  @override
  String get kitNoListing => 'Esta vaga não tem anúncio original para abrir.';

  @override
  String get browserClose => 'Fechar';

  @override
  String get browserBack => 'Voltar';

  @override
  String get browserForward => 'Avançar';

  @override
  String get browserReload => 'Recarregar';

  @override
  String get browserMore => 'Mais opções';

  @override
  String get browserShare => 'Compartilhar link';

  @override
  String get browserCopyLink => 'Copiar link';

  @override
  String get browserLinkCopied => 'Link copiado';

  @override
  String get browserOpenExternal => 'Abrir no navegador';

  @override
  String get browserSecure => 'Conexão HTTPS';

  @override
  String get browserNotSecure => 'Não segura (HTTP)';

  @override
  String get browserSecureHint =>
      'HTTPS criptografa a conexão. O OrbiJob não verifica quem mantém o site nem o que ele pede de você.';

  @override
  String get browserErrorTitle => 'Não foi possível carregar a página';

  @override
  String get browserErrorBody =>
      'Confira sua conexão e tente de novo. Se o site não funcionar aqui (login, bloqueios, captcha), abra no navegador.';

  @override
  String get browserErrorTls =>
      'O certificado de segurança do site não é confiável, então a página não foi aberta.';

  @override
  String get browserBlockedLink => 'Um link foi bloqueado por segurança.';

  @override
  String get browserDownloadExternal =>
      'Arquivos são baixados pelo navegador: abrindo lá.';

  @override
  String get browserExternalOnly =>
      'Este link só pode ser aberto no navegador.';

  @override
  String get browserOpeningExternal => 'Abrindo no navegador…';

  @override
  String get browserDidYouApply => 'Você se candidatou?';

  @override
  String get browserCannotOpenExternal => 'Não foi possível abrir o navegador.';

  @override
  String get browserLanguageNotice =>
      'A página original pode estar em outro idioma. O OrbiJob não traduz outros sites.';

  @override
  String get translationAuto => 'Tradução automática';

  @override
  String translationNote(String language) {
    return 'Traduzido do $language automaticamente. Pode conter erros.';
  }

  @override
  String get translationShowOriginal => 'Ver original';

  @override
  String get translationShowTranslation => 'Ver tradução';

  @override
  String get translationLoading => 'Traduzindo…';

  @override
  String get translationNeedsTitle => 'Traduzir esta vaga?';

  @override
  String translationNeedsBody(int mb) {
    return 'O OrbiJob traduz no seu aparelho, então o que você lê fica nele. Na primeira vez, são baixados dados de idioma de cerca de $mb MB.';
  }

  @override
  String get translationNeedsBodyWeb =>
      'Seu navegador traduz neste aparelho, então o que você lê fica nele. Ele pode baixar dados de idioma antes.';

  @override
  String get translationDownload => 'Baixar e traduzir';

  @override
  String get translationDownloading => 'Baixando dados de idioma…';

  @override
  String translationUnsupported(String language) {
    return 'A tradução automática do $language não está disponível neste aparelho. Mostrando o original.';
  }

  @override
  String get translationFailed =>
      'Não foi possível traduzir esta vaga. Mostrando o original.';

  @override
  String get translationPartialCut =>
      'Só a primeira parte foi traduzida; o resto está no original.';

  @override
  String get translationPartialLines =>
      'Algumas linhas ficam no original para que números, códigos e nomes continuem exatos.';

  @override
  String translationOriginalLabel(String language) {
    return 'Texto original ($language)';
  }

  @override
  String get translationSettingsTitle => 'Tradução';

  @override
  String get translationSettingsSwitch => 'Traduzir vagas para o meu idioma';

  @override
  String get translationSettingsBody =>
      'Usa a tradução embutida neste aparelho: os títulos são traduzidos quando os dados do idioma já estão nele, e o texto completo quando você pede. O original está sempre a um toque.';

  @override
  String get translationClearCache => 'Limpar traduções salvas';

  @override
  String get translationCacheCleared => 'Traduções salvas apagadas';

  @override
  String get translationTitleOriginalHint => 'Título traduzido';

  @override
  String get ssTitle => 'Pesquisas salvas';

  @override
  String get ssSubtitle =>
      'Reabra uma pesquisa com um toque e escolha quais avisam sobre vagas novas.';

  @override
  String get ssEmptyTitle => 'Nenhuma pesquisa salva ainda';

  @override
  String get ssEmptyBody =>
      'Pesquise ou filtre em Explorar e toque em “Salvar pesquisa”. Você pode ativar alertas para ela.';

  @override
  String get ssGoExplore => 'Ir para Explorar';

  @override
  String get ssSaveAction => 'Salvar pesquisa';

  @override
  String get ssMine => 'Minhas pesquisas';

  @override
  String get ssSaveSheetTitle => 'Salvar esta pesquisa';

  @override
  String get ssEditSheetTitle => 'Editar pesquisa salva';

  @override
  String get ssNameLabel => 'Nome';

  @override
  String get ssNameHint => 'ex.: Enfermeiro na Alemanha';

  @override
  String get ssNameRequired => 'Dê um nome à pesquisa.';

  @override
  String ssNameTooLong(int max) {
    return 'Use no máximo $max caracteres.';
  }

  @override
  String get ssAlertsLabel => 'Avisar sobre vagas novas';

  @override
  String get ssAlertsHelp =>
      'Uma notificação aparece no OrbiJob quando uma vaga nova combina. Só vagas abertas e verificadas recentemente são avisadas.';

  @override
  String get ssFrequencyLabel => 'Com que frequência verificar';

  @override
  String get ssFreqInstant => 'A cada hora';

  @override
  String get ssFreqDaily => 'Uma vez por dia';

  @override
  String get ssFreqWeekly => 'Uma vez por semana';

  @override
  String get ssAlertsOn => 'Alertas ativos';

  @override
  String get ssAlertsOff => 'Alertas desativados';

  @override
  String ssAlertsToggle(String name) {
    return 'Alertas de $name';
  }

  @override
  String get ssSaved => 'Pesquisa salva';

  @override
  String get ssUpdated => 'Pesquisa atualizada';

  @override
  String get ssRemoved => 'Pesquisa excluída';

  @override
  String get ssDuplicated => 'Cópia criada';

  @override
  String get ssOpen => 'Abrir em Explorar';

  @override
  String get ssRename => 'Renomear';

  @override
  String get ssDuplicate => 'Duplicar';

  @override
  String get ssEdit => 'Editar';

  @override
  String get ssDelete => 'Excluir';

  @override
  String ssMenu(String name) {
    return 'Ações de $name';
  }

  @override
  String get ssDeleteTitle => 'Excluir esta pesquisa?';

  @override
  String get ssDeleteBody =>
      'Os alertas dela param. As notificações já recebidas continuam.';

  @override
  String ssCopyName(String name) {
    return '$name (cópia)';
  }

  @override
  String get ssDefaultName => 'Pesquisa';

  @override
  String get ssAllJobs => 'Todas as vagas';

  @override
  String ssSpecDays(int days) {
    return 'Últimos $days dias';
  }

  @override
  String ssAlertsLimit(int max) {
    return 'Você pode ter até $max pesquisas com alertas. Desative uma antes.';
  }

  @override
  String get ssSignedOutNote =>
      'Entre na conta para guardar pesquisas e receber alertas.';

  @override
  String get homeSavedTitle => 'Pesquisas salvas';

  @override
  String get homeSavedAll => 'Ver todas';

  @override
  String get ntTitle => 'Notificações';

  @override
  String get ntBell => 'Notificações';

  @override
  String ntBellUnread(int count) {
    return 'Notificações, $count não lidas';
  }

  @override
  String get ntEmptyTitle => 'Nada de novo por enquanto';

  @override
  String get ntEmptyBody =>
      'Quando uma vaga nova combinar com uma pesquisa salva com alertas, ela aparece aqui. As vagas novas são verificadas mais ou menos a cada hora.';

  @override
  String get ntEmptyNoAlerts =>
      'Você não tem pesquisa salva com alertas ativos.';

  @override
  String get ntManageSearches => 'Gerenciar pesquisas salvas';

  @override
  String get ntMarkAllRead => 'Marcar todas como lidas';

  @override
  String get ntClearAll => 'Limpar tudo';

  @override
  String get ntClearTitle => 'Limpar todas as notificações?';

  @override
  String get ntClearBody =>
      'Elas somem desta lista. As vagas não são afetadas.';

  @override
  String get ntDismiss => 'Remover da lista';

  @override
  String get ntUnread => 'Não lida';

  @override
  String ntFromSearches(String names) {
    return 'Combina com: $names';
  }

  @override
  String ntFromSearchesMore(String names, int count) {
    return 'Combina com: $names e mais $count';
  }

  @override
  String ntFound(String when) {
    return 'Encontrada $when';
  }

  @override
  String get ntJobUnavailable =>
      'Esta vaga não está mais no catálogo. Você ainda pode tentar o anúncio original.';

  @override
  String get ntSettingsTitle => 'Alertas';

  @override
  String get ntEnabled => 'Receber alertas';

  @override
  String get ntEnabledHelp =>
      'Das suas pesquisas salvas. Vagas encontradas com isto desligado não são enviadas depois.';

  @override
  String get ntPushNote =>
      'Alertas e lembretes sempre chegam aqui. No Android também chegam como notificação push depois que você permitir; no iPhone e no navegador o push ainda não está ativado.';

  @override
  String get ntSignedOut =>
      'Entre na conta para receber alertas de vagas novas.';

  @override
  String get ntLoadFailed => 'Não foi possível carregar as notificações.';

  @override
  String get ssUseCurrent => 'Substituir pela pesquisa atual do Explorar';

  @override
  String get agoJustNow => 'agora há pouco';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count minutos',
      one: 'há 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count horas',
      one: 'há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String get agoYesterday => 'ontem';

  @override
  String agoDays(int count) {
    return 'há $count dias';
  }

  @override
  String jobMoreActions(String title) {
    return 'Mais ações para $title';
  }

  @override
  String get hdHide => 'Ocultar esta vaga';

  @override
  String get hdHidden => 'Vaga ocultada';

  @override
  String get hdUndo => 'Desfazer';

  @override
  String get hdRestore => 'Restaurar';

  @override
  String get hdRestored => 'Vaga restaurada';

  @override
  String get hdTitle => 'Vagas ocultas';

  @override
  String get hdSubtitle =>
      'Vagas ocultas não aparecem na busca, nas recomendações nem nos alertas. Restaure uma para vê-la de novo.';

  @override
  String get hdEmptyTitle => 'Nenhuma vaga oculta';

  @override
  String get hdEmptyBody =>
      'Abra o menu de uma vaga e escolha “Ocultar esta vaga” para não vê-la mais.';

  @override
  String hdCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vagas ocultas',
      one: '1 vaga oculta',
    );
    return '$_temp0';
  }

  @override
  String get hdProfileSub => 'Vagas que você escolheu não ver mais';

  @override
  String get hdOpenListing => 'Abrir anúncio';

  @override
  String get hdSeeHidden => 'Ver vagas ocultas';

  @override
  String get hdFilteredNote => 'Algumas vagas desta página estão ocultas.';

  @override
  String get profileHubSavedSearches => 'Pesquisas salvas e alertas';

  @override
  String get profileHubSavedSearchesSub =>
      'Pesquisas que você guarda e as que avisam você';

  @override
  String get rsTitle => 'Histórico de pesquisas';

  @override
  String get rsSwitch => 'Lembrar minhas pesquisas recentes';

  @override
  String get rsBody =>
      'Apenas as palavras que você pesquisa, guardadas neste dispositivo e nunca enviadas ao servidor. Desativar também apaga as que já estão guardadas.';

  @override
  String get rsClear => 'Limpar histórico de pesquisas';

  @override
  String get rsCleared => 'Histórico de pesquisas apagado';

  @override
  String get rsRecent => 'Pesquisas recentes';

  @override
  String get rcTitle => 'Recomendadas para você';

  @override
  String get rcSubtitle =>
      'Combinadas com o seu perfil neste dispositivo: profissão, competências, local, modalidade e idioma.';

  @override
  String get rcSeeAll => 'Ver todas';

  @override
  String get rcEmptyTitle => 'Nada combina agora';

  @override
  String get rcEmptyBody =>
      'Nenhuma vaga aberta combina com o seu perfil no momento. Salve uma pesquisa com alertas para saber das novas.';

  @override
  String get rcNeedProfileTitle => 'Conte o que você faz';

  @override
  String get rcNeedProfileBody =>
      'Adicione ao perfil sua profissão, onde quer trabalhar e como, e o OrbiJob ordena as vagas para você. Vale para qualquer profissão.';

  @override
  String get rcNeedProfileAction => 'Completar meu perfil';

  @override
  String get rcSignInBody =>
      'Entre na conta e preencha seu perfil para receber recomendações.';

  @override
  String get rcThinNote =>
      'Seu perfil tem pouca informação, então estas combinações são amplas. Adicione sua profissão para melhorar.';

  @override
  String get rcFitStrong => 'Combina muito';

  @override
  String get rcFitGood => 'Combina bem';

  @override
  String get rcFitPossible => 'Pode interessar';

  @override
  String get rcWhy => 'Por que esta vaga?';

  @override
  String get rcWhyTitle => 'Por que você vê esta vaga';

  @override
  String get rcMatches => 'O que combina';

  @override
  String get rcCheck => 'Vale conferir';

  @override
  String get rcDisclaimer =>
      'O OrbiJob compara o texto do anúncio com o seu perfil. Não verifica vistos, autorizações de trabalho, registro profissional nem certificações: confirme os requisitos no anúncio.';

  @override
  String rcScore(int score) {
    return 'Pontuação $score de 100';
  }

  @override
  String rcSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count critérios avaliados',
      one: '1 critério avaliado',
    );
    return '$_temp0';
  }

  @override
  String rcReasonProfessionExact(String profession) {
    return 'O título menciona sua profissão: $profession';
  }

  @override
  String rcReasonProfessionClose(String profession) {
    return 'Próxima da sua profissão: $profession';
  }

  @override
  String rcReasonProfessionSynonym(String profession) {
    return 'Mesma profissão em outro idioma: $profession';
  }

  @override
  String rcReasonSameField(String area) {
    return 'Mesma área profissional: $area';
  }

  @override
  String rcReasonSkills(String skills) {
    return 'Menciona suas competências: $skills';
  }

  @override
  String rcReasonCountryInterest(String country) {
    return 'Em $country, um dos seus países de interesse';
  }

  @override
  String rcReasonCountryResidence(String country) {
    return 'Em $country, onde você mora';
  }

  @override
  String rcReasonRemoteEligible(String country) {
    return 'Remota e aberta a candidatos de $country';
  }

  @override
  String get rcReasonRemoteAnywhere =>
      'Remota, aberta a candidatos de qualquer lugar';

  @override
  String rcReasonCity(String city) {
    return 'Em $city';
  }

  @override
  String rcReasonWorkMode(String mode) {
    return '$mode, como você prefere';
  }

  @override
  String rcReasonLanguage(String language) {
    return 'Escrita em $language, um idioma do seu perfil';
  }

  @override
  String get rcCaveatLocation => 'O anúncio não diz onde fica a vaga.';

  @override
  String rcCaveatLanguage(String language) {
    return 'Escrita em $language, que seu perfil não lista.';
  }

  @override
  String rcCaveatEligibility(String places) {
    return 'O anúncio restringe quem pode se candidatar: $places. Confira se você atende.';
  }

  @override
  String get rcCaveatMode =>
      'O anúncio não diz se é remota, híbrida ou presencial.';

  @override
  String get pfMustTitle => 'Exigências para as recomendações';

  @override
  String get pfMustHelp =>
      'Ative o que uma vaga precisa ter para ser recomendada a você. O resto é só preferência: sobe a vaga na lista mas nunca a esconde. Um anúncio que não informa nunca é escondido.';

  @override
  String get pfMustWorkMode => 'Só a minha modalidade';

  @override
  String get pfMustCountry => 'Só os meus países';

  @override
  String get pfMustLanguage => 'Só os meus idiomas';

  @override
  String get applicationStageInterested => 'Interessado';

  @override
  String get applicationStageHired => 'Contratado';

  @override
  String get apPipelineAll => 'Todas';

  @override
  String get apStageHint =>
      'Você decide a etapa. O OrbiJob nunca contata o empregador e nunca presume que você se candidatou.';

  @override
  String get apAgendaTitle => 'Próximos compromissos';

  @override
  String get apAgendaInterview => 'Entrevista';

  @override
  String get apAgendaFollowUp => 'Acompanhamento';

  @override
  String get apOverdue => 'Atrasado';

  @override
  String get apAgendaOverdueHint =>
      'A data passou. Atualize a etapa ou defina uma nova data.';

  @override
  String get apDatesTitle => 'Datas';

  @override
  String get apInterviewLabel => 'Entrevista (data e hora)';

  @override
  String get apFollowUpLabel => 'Acompanhar em';

  @override
  String get apDateNone => 'Não definida';

  @override
  String get apDatePick => 'Escolher';

  @override
  String get apDateClear => 'Limpar';

  @override
  String get apDatesSaved => 'Data salva';

  @override
  String get apTrackInterest => 'Acompanhar esta vaga';

  @override
  String get apTrackedInterest =>
      'Adicionada às suas candidaturas como “interessado”. Nada foi enviado.';

  @override
  String get apAlreadyTracked => 'Esta vaga já está nas suas candidaturas.';

  @override
  String apNextDate(String kind, String date) {
    return '$kind: $date';
  }

  @override
  String apPipelineCount(String stage, int count) {
    return '$stage ($count)';
  }

  @override
  String get apFilteredEmpty => 'Nenhuma candidatura nesta etapa.';

  @override
  String get shShare => 'Compartilhar esta vaga';

  @override
  String get shCopied =>
      'Link copiado. O compartilhamento não está disponível aqui.';

  @override
  String get shNoLink => 'Esta vaga não tem link para compartilhar.';

  @override
  String get cpAdd => 'Adicionar à comparação';

  @override
  String get cpRemove => 'Remover da comparação';

  @override
  String cpFull(int max) {
    return 'Você pode comparar até $max vagas. Remova uma antes.';
  }

  @override
  String get cpAdded => 'Adicionada à comparação';

  @override
  String cpBar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vagas escolhidas',
      one: '1 vaga escolhida',
    );
    return '$_temp0';
  }

  @override
  String get cpCompare => 'Comparar';

  @override
  String get cpClear => 'Limpar';

  @override
  String get cpTitle => 'Comparar vagas';

  @override
  String get cpNeedTwo =>
      'Escolha ao menos duas vagas para compará-las. Use o menu de uma vaga e escolha “Adicionar à comparação”.';

  @override
  String get cpHint =>
      'Só aparece o que cada anúncio informa. Nada é estimado nem preenchido: “Não informado” significa que o anúncio não diz.';

  @override
  String get cpNotStated => 'Não informado';

  @override
  String get cpRowCompany => 'Empresa';

  @override
  String get cpRowPlace => 'Local';

  @override
  String get cpRowMode => 'Modalidade';

  @override
  String get cpRowContract => 'Contrato';

  @override
  String get cpRowSalary => 'Salário';

  @override
  String get cpRowPublished => 'Publicada';

  @override
  String get cpRowSource => 'Fonte';

  @override
  String get cpRowLanguage => 'Idioma do anúncio';

  @override
  String get cpRowEligibility => 'Quem pode se candidatar';

  @override
  String get cpEligibilityAnywhere => 'De qualquer lugar (conforme a fonte)';

  @override
  String cpEligibilityRestricted(String places) {
    return 'Restrito a: $places';
  }

  @override
  String get cpSalaryNote =>
      'Os salários usam moedas ou períodos diferentes e aparecem como informados, sem conversão.';

  @override
  String get cpOpenListing => 'Abrir o anúncio';

  @override
  String cpRemoveOne(String title) {
    return 'Remover $title da comparação';
  }

  @override
  String get ntReminderInterview => 'Entrevista nas próximas 24 horas';

  @override
  String get ntReminderFollowUp => 'Dia de dar retorno nesta candidatura';

  @override
  String get cpRowSkills => 'Habilidades listadas';

  @override
  String get ntKindNewJob => 'Nova vaga';

  @override
  String get ntKindInterview => 'Entrevista';

  @override
  String get ntKindFollowUp => 'Retorno';

  @override
  String get searchSuggestTitle => 'Tente em vez disso';

  @override
  String get searchSuggestHint =>
      'Profissões mais amplas ou com grafia parecida. São só sugestões: os resultados são o que o catálogo tem.';

  @override
  String get pdTitle => 'Seus dados';

  @override
  String get pdIntro =>
      'Leve uma cópia de tudo o que o app guarda sobre você ou apague sua conta de vez.';

  @override
  String get pdSignInHint =>
      'Entre na sua conta para exportar ou excluir seus dados.';

  @override
  String get pdExportTitle => 'Exportar meus dados';

  @override
  String get pdExportBody =>
      'Um ZIP com seu perfil, favoritos, buscas salvas, candidaturas, anotações e os PDFs de currículo que você enviou. Senhas e tokens de notificação nunca são incluídos.';

  @override
  String get pdExportAction => 'Exportar meus dados';

  @override
  String get pdExportWorking => 'Preparando sua exportação…';

  @override
  String get pdExportDone => 'Exportação criada. Salve onde preferir.';

  @override
  String pdExportMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count arquivos de currículo não puderam ser incluídos; eles constam no arquivo de dados.',
      one: '1 arquivo de currículo não pôde ser incluído; ele consta no arquivo de dados.',
    );
    return '$_temp0';
  }

  @override
  String get pdExportFailed =>
      'Não foi possível preparar a exportação. Verifique a conexão e tente de novo.';

  @override
  String get pdDeleteTitle => 'Excluir minha conta';

  @override
  String get pdDeleteBody =>
      'Exclui de forma permanente sua conta e tudo o que está ligado a ela. Isso não pode ser desfeito.';

  @override
  String get pdDeleteWhatTitle => 'O que é excluído';

  @override
  String get pdDelete1 =>
      'Seu perfil, experiências, formação, competências e idiomas';

  @override
  String get pdDelete2 => 'Os PDFs de currículo que você enviou';

  @override
  String get pdDelete3 => 'Favoritos, vagas ocultas, buscas salvas e alertas';

  @override
  String get pdDelete4 => 'Candidaturas, anotações, lembretes e notificações';

  @override
  String get pdDelete5 => 'O registro de notificações push dos seus aparelhos';

  @override
  String get pdDeleteKeeps =>
      'As vagas são públicas e continuam no catálogo. Se quiser uma cópia dos seus dados, exporte antes.';

  @override
  String get pdDeletePassword => 'Senha atual';

  @override
  String get pdDeleteConfirmCheck => 'Entendo que isso não pode ser desfeito';

  @override
  String get pdDeleteAction => 'Excluir permanentemente';

  @override
  String get pdDeleteWrongPassword =>
      'Essa senha não está correta. Nada foi excluído.';

  @override
  String get pdDeleteFailed =>
      'Não foi possível excluir a conta agora. Nada foi perdido; tente novamente em instantes.';

  @override
  String get pdDeleted => 'Sua conta foi excluída';

  @override
  String get pdLinkPrivacy => 'Política de privacidade';

  @override
  String get pdLinkTerms => 'Termos de uso';

  @override
  String get pdLinkDeletion => 'Exclusão de conta e dados';

  @override
  String get pdDeletedBody =>
      'Sua conta e todos os dados ligados a ela foram excluídos de forma permanente. Você será desconectado neste aparelho.';

  @override
  String get pdDeletedAction => 'OK';
}
