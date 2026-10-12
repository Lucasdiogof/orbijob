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
}
