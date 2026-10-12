# ORBIJOB 2.0 — REFATORAÇÃO COMPLETA DE UX/UI, DESIGN SYSTEM E EXPERIÊNCIA PROFISSIONAL

> Prompt guardado em 2026-10-12 a pedido do proprietário, para execução **depois** da consolidação do catálogo. Não executar antes. Texto integral abaixo.

Você é um Principal Flutter Engineer, Senior Product Designer e especialista em UX/UI para produtos SaaS e plataformas de recrutamento.
Sua missão é executar uma refatoração visual e funcional abrangente do OrbiJob, transformando o aplicativo atual em um produto corporativo moderno, sofisticado, responsivo, intuitivo e visualmente consistente.
Não quero um facelift superficial.
Quero uma reconstrução cuidadosa da experiência, mantendo as funcionalidades e os dados reais que já existem.

## 0. REPOSITÓRIO E AUTORIZAÇÃO
Repositório: https://github.com/Lucasdiogof/orbijob
Supabase: `rpmlfxwebnlxnwadyvle`
Stack: Flutter / Dart; Android; iOS; Web; Supabase; Cloudflare Worker; GitHub Actions; Internacionalização PT-BR, EN e ES.

O proprietário autoriza: refatorar todas as telas; criar e substituir widgets; reorganizar a arquitetura de apresentação; criar design system completo; modificar navegação e layouts; implementar animações; melhorar a gestão do perfil; melhorar a experiência de currículos; refatorar filtros e resultados de busca; trabalhar diretamente na main; fazer commits e push sem PR; executar testes e gerar builds; trabalhar autonomamente até concluir as etapas.

Não modifique o projeto Supabase errado. Confirme o project ref antes de qualquer operação.
Não altere tabelas, RLS ou APIs sem necessidade real.
Nenhum serviço pago está autorizado.

## 1. DIAGNÓSTICO VISUAL — PROBLEMAS ATUAIS
O proprietário forneceu seis capturas reais da interface Android. Use essas imagens como referência obrigatória do que deve ser melhorado.

**Home:** cabeçalho extremamente simples; logo pequena e sem valorização; título principal grande, mas sem composição visual; campo de pesquisa genérico; categorias representadas por dezenas de chips com bordas; chips ocupam espaço demais; visual repetitivo; pouca hierarquia visual; aparência semelhante a uma tela de testes; falta uma apresentação profissional das vagas; não há sensação de produto premium.

**Explore:** busca e filtros visualmente desorganizados; categorias em rolagem horizontal pouco elegante; especialidades aparecem como mais uma linha de chips; elementos horizontais são cortados sem indicação suficiente; botão Filters desproporcional; excesso de bordas; cards de vagas com tipografia pouco refinada; muitos textos sem hierarquia clara; informações da vaga poderiam ser organizadas melhor; falta separação visual adequada entre filtros, resultados e conteúdo.

**Favoritos e candidaturas:** estados bloqueados por autenticação pouco trabalhados; mensagens genéricas; ilustrações extremamente simples; muito espaço desperdiçado; falta contexto sobre o benefício de entrar na conta; falta uma ação de criação de conta bem posicionada.

**Perfil:** repetição de avisos de login; seção profissional ocupada por um estado vazio enorme; configurações misturadas ao perfil profissional; layout vertical excessivamente espaçado; não existe composição profissional que valorize os dados do candidato.

**Idioma:** o texto "Português" quebra em duas linhas de forma ruim. O controle não se adapta à largura disponível. Inaceitável num aplicativo em três idiomas.

**Identidade geral:** excesso de outlines; uso pouco estratégico da cor roxa; ícones genéricos e sem unidade visual; falta de componentes de marca; tipografia pouco consistente; espaçamentos sem ritmo visual; pouco refinamento em transições e estados; ausência de microinterações; menu inferior muito simples; componentes visualmente ultrapassados.

Não resolva isso apenas alterando BorderRadius, Padding e ColorScheme. Reestruture o produto visualmente.

## 2. OBJETIVO DE DESIGN
Aparência de uma plataforma profissional de recrutamento global. Referências conceituais: LinkedIn Jobs, Linear, Notion, Arc, plataformas SaaS corporativas contemporâneas, interfaces de recrutamento premium. Não copie layouts, marcas ou componentes proprietários; extraia apenas princípios de qualidade.

Personalidade: confiança, profissionalismo, clareza, tecnologia, organização, modernidade, eficiência, segurança, sofisticação.

Evite: visual infantil; gradientes exagerados; glassmorphism em toda a interface; roxo saturado em áreas enormes; sombras pesadas; cards gigantes; excesso de chips; animações decorativas desnecessárias; elementos que parecem placeholders; telas com grandes vazios inexplicados. A interface deve parecer um produto comercial maduro.

## 3. IDENTIDADE VISUAL — ORBIJOB
Preserve o reconhecimento da marca, especialmente o conceito orbital do símbolo. Evolua o design sem trocar arbitrariamente o logotipo existente.

**Paleta inicial sugerida (pontos de partida, não ordem; ajustar para WCAG, contraste e identidade; sem preto/branco puro indiscriminado)**

LIGHT: Background #F7F8FC · Surface #FFFFFF · Primary text #111827 · Secondary text #667085 · Primary brand #5B4CF6 · Hover/pressed #4837D8 · Subtle brand #EEECFF · Border #E5E7EB · Success #16866B · Warning #B7791F · Error #D64550

DARK: Background #0D111B · Surface #151B28 · Elevated surface #1D2535 · Primary text #F5F7FC · Secondary text #A7B0C2 · Primary brand #A298FF · Subtle brand #292447 · Border #30394B · Success #44C4A1 · Warning #E4B45A · Error #FF727D

**Tipografia:** investigar as fontes já incluídas; escolher família moderna, excelente em mobile, com suporte confiável a PT, EN e ES. Definir Display, Heading large/medium/small, Body, Body emphasis, Label, Caption, Metadata, com escalas consistentes. Evitar títulos enormes que empurram conteúdo para fora da tela.

**Espaçamento:** escala 4/8 pontos para telas, seções, cards, listas, inputs, botões, barra de navegação, bottom sheets, dialogs.

**Componentes:** biblioteca reutilizável OrbiJob — OrbiAppShell, OrbiTopBar, OrbiNavigationBar, OrbiSearchField, OrbiJobCard, OrbiFilterChip, OrbiFilterSheet, OrbiSectionHeader, OrbiPrimaryButton, OrbiSecondaryButton, OrbiTextField, OrbiEmptyState, OrbiAuthGate, OrbiLoadingIndicator, OrbiSkeleton, OrbiProfileCard, OrbiResumeCard, OrbiStatCard, OrbiStatusBadge, OrbiSnackbar, OrbiDialog. Não criar componentes redundantes se já existem equivalentes que possam ser evoluídos. Sem widgets isolados com estilos hardcoded.

## 4. REFATORAÇÃO COMPLETA DA NAVEGAÇÃO
**Bottom Navigation** (hoje Home | Explore | Favorites | Applications): ícones consistentes; estado ativo claro; label bem dimensionada; transições discretas; área de toque confortável; SafeArea; fundo harmonizado aos temas; separação visual sutil; comportamento correto com teclado aberto. Avaliar indicador ativo em cápsula ou destaque discreto. Não usar uma linha roxa solta no topo como único indicador.

**Navegação contextual:** Perfil, Currículos, Configurações, Login/cadastro, Detalhes da vaga, Histórico de candidaturas, Preferências, Pesquisas salvas. Não colocar tudo na bottom bar.

**Tablet e desktop:** NavigationRail ou sidebar profissional; Web não deve parecer um telefone esticado; largura máxima de conteúdo; layout em colunas quando útil; menu lateral; área de resultados; painel de detalhes; responsividade real.

## 5. HOME — RECONSTRUÇÃO TOTAL
Dashboard profissional de oportunidades. Composição: (1) cabeçalho valorizando a marca e acesso ao perfil; (2) saudação contextual discreta; (3) busca global em destaque; (4) acesso rápido aos filtros; (5) vagas recentes; (6) explorar por áreas; (7) explorar por localização; (8) vagas remotas; (9) recomendações baseadas nas preferências, quando existirem dados; (10) continuação das atividades recentes, quando autenticado. Priorizar o útil; não gerar tela excessivamente longa.

**Categorias:** abandonar dezenas de chips outline; grade de categorias; ícones em superfícies discretas; nome da área; número de vagas real; hierarquia consistente; cards compactos com toque confortável; tela dedicada para ver todas; categoria não é etiqueta de formulário.

**Vagas recentes:** cards compactos e premium com cargo, empresa, localização, modalidade, salário quando disponível, data, origem, favoritar, acesso aos detalhes. Dados reais; sem contagens ou recomendações inventadas.

## 6. EXPLORE — EXPERIÊNCIA DE BUSCA PREMIUM
Uma das telas mais importantes. Estrutura: search bar moderna com foco e limpeza; filtros rápidos horizontais; botão de filtros avançados com contador; ordenação; contagem de resultados; lista; paginação ou carregamento progressivo; empty e error states.

**Filtros rápidos:** localização; remoto/híbrido/presencial; data; área profissional; salário se disponível. Não mostrar 20 filtros como chips permanentes.

**Filtros avançados:** em mobile, modal bottom sheet com drag handle, título, fechar, seções agrupadas, checkboxes/segmented controls/campos apropriados, contagem, limpar tudo, aplicar, rodapé fixo, scroll interno, suporte a teclado, temas claro/escuro. Em tablet/desktop, sidebar de filtros. Nada de formulário gigante sobre a lista.

**Profissões e especialidades:** navegação hierárquica (Saúde → Fisioterapia → Fisioterapia Pélvica; Tecnologia → Desenvolvimento Mobile → Flutter), preservando a busca global para qualquer profissão. Sem chips empilhados para todo tipo de categoria.

**Cards de vagas:** redesenhar. Prioridade visual: cargo, empresa, localização, modalidade, remuneração, data, fonte. Secundário com tipografia/cor adequadas; sem repetir metadados; títulos longos tratados; badges discretos, não coleção de pílulas chamativas.

## 7. DETALHES DA VAGA
Cargo e empresa; localização; modalidade; contrato; salário; publicação; origem; status; descrição organizada; requisitos; responsabilidades (quando separáveis de forma confiável); restrição geográfica; idioma (quando informado); link oficial; favoritar; registrar candidatura. CTA principal "Ver vaga original" ou "Candidatar-se", fixo inferior quando apropriado, respeitando SafeArea. Nunca dizer que o OrbiJob enviou candidatura quando apenas abriu o site externo.

## 8. LOGIN, CADASTRO E ESTADOS DE AUTENTICAÇÃO
Experiência moderna, convidativa e contextual. **Auth Gate** ao tentar favoritar, ver favoritos, registrar candidatura, abrir perfil privado, salvar pesquisa, gerenciar currículo — estados contextuais, não uma tela enorme com cadeado genérico. Exemplos: Favoritos "Suas melhores oportunidades, em um só lugar."; Candidaturas "Acompanhe cada etapa da sua próxima oportunidade."; Currículos "Tenha seu currículo pronto quando encontrar a vaga certa." Cada estado: ilustração vetorial/composição de marca discreta; benefício; CTA login; CTA cadastro; caminho para continuar explorando; sem duplicação de textos.

Redesenhar: Login, Criar conta, Recuperar senha, Verificação de e-mail, Erros de autenticação, Estados de carregamento. Sem login social sem backend configurado. Manter segurança e autenticação existentes.

## 9. PERFIL PROFISSIONAL — RECONSTRUÇÃO COMPLETA
Ferramenta profissional de carreira. Separar: Minha conta; Meu perfil profissional; Meus currículos; Preferências de vagas; Configurações; Privacidade e segurança. Aparência e Idioma não ficam misturados com experiências.

Dashboard (autenticado): nome; cargo/título; localização; resumo; indicador de completude; experiências; formação; habilidades; idiomas; currículos; preferências profissionais. Só campos realmente implementados, ou criar suporte persistente se necessário e autorizado. Edição por seção, formulários bonitos, estados de salvamento, validação, mensagens claras; sem formulário interminável. Completude baseada em campos reais, sem percentuais inventados e sem gamificação desnecessária.

## 10. GESTÃO DE CURRÍCULOS
Adicionar; selecionar PDF; ver nome e tamanho; data do upload; definir principal; abrir/baixar o próprio arquivo; excluir; substituir versão; múltiplos currículos respeitando limites existentes. Não expor arquivos privados; respeitar Storage, RLS e permissões.

**Extração de informações:** investigar preencher o perfil a partir de PDF. Primeira abordagem: extração local ou backend seguro; sem serviços pagos; sem enviar PDFs a terceiros desconhecidos; mostrar campos sugeridos; usuário confirma antes de salvar. Não inventar experiências nem qualificações; não alterar dados existentes sem confirmação.

## 11. PRÉ-PREENCHIMENTO DE CANDIDATURAS
Investigar o código e a viabilidade real em Android, iOS e Web. Objetivo: usar informações do perfil, reaproveitar currículo, preencher campos compatíveis de formulários externos, reduzir trabalho repetitivo.

Segurança obrigatória: ação explícita do usuário; nunca enviar candidaturas automaticamente; não responder perguntas subjetivas ou legais sem confirmação; não inventar experiência, salário, idioma ou autorização de trabalho; não preencher consentimentos automaticamente; não contornar CAPTCHA; não automatizar em sites que proíbem; não armazenar senhas de portais; não executar JavaScript arbitrário de fontes não confiáveis.

UX: se permitido e possível, fluxo de revisão mostrando campos identificados, dados sugeridos, campos não preenchidos, confirmação. Se incompatível com o site, explicar e permitir copiar dados do perfil. Não prometer preenchimento automático universal.

## 12. FAVORITOS
Autenticado: lista de salvas; busca; filtros; ordenação; remoção; abrir detalhes; status da vaga. Não autenticado: estado contextual bonito, login/cadastro, benefícios, voltar a explorar. Preservar registros existentes.

## 13. CANDIDATURAS
Painel de acompanhamento de carreira: lista; filtros por estágio; status; datas; empresa; cargo; notas; detalhes; histórico se existir suporte real. Etapas possíveis: Interesse, Candidatura enviada, Triagem, Entrevista, Oferta, Contratado, Encerrado. Não forçar mudanças no modelo sem avaliar compatibilidade e migração. Pipeline visual funcional em telas pequenas.

## 14. LOADING E ANIMAÇÃO DA LOGO
Identidade de loading própria. Conceito: pequeno elemento orbital gira ao redor do núcleo da marca (órbita suave, rotação parcial, pulso sutil, transição discreta, movimento contínuo e profissional; sem exageros). Investigar os assets existentes. Preferir animação vetorial nativa (AnimationController, CustomPainter, Transform, Tween, Curves); Lottie/Rive só se fizer sentido e sem peso/custo. Funciona em light e dark. Usos: carregamento inicial; vagas; atualização de filtros; upload de currículo; salvamento de perfil; sincronização visível. Não bloquear a tela inteira quando skeleton ou indicador local for melhor. Respeitar acessibilidade e movimento reduzido. Splash elegante e curta, sem atrasar a inicialização.

## 15. MICROINTERAÇÕES
Discretas, para: trocas de abas; seleção de filtros; abertura de bottom sheets; expansão de seções; favoritar; carregamento; estados vazios; sucesso de upload; transição para detalhes. Curtas, sem animar tudo ao mesmo tempo, sem jank em celulares intermediários.

## 16. INTERNACIONALIZAÇÃO COMPLETA
PT-BR, EN, ES. 100% das novas interfaces traduzidas; nenhuma string hardcoded. Revisar Home, Explore, Filtros, Categorias, Profissões, Especialidades, Login, Cadastro, Perfil, Currículos, Candidaturas, Favoritos, Configurações, Loading, Erros, Empty states, Snackbars, Diálogos, datas e números.

**Problema obrigatório:** o seletor de idioma quebra "Português". Redesenhar (lista, modal, dropdown responsivo ou radio list); não usar segmented control quando os nomes não cabem. Testar textos longos nas três línguas e font scaling de acessibilidade; sem tamanhos fixos que gerem overflow.

## 17. TEMA CLARO E ESCURO
Escuro tão bem trabalhado quanto o claro. Tokens semânticos: background, surface, elevated surface, text primary/secondary, border, divider, primary/secondary action, input, disabled, loading, error, success, warning, navigation, cards. Todos os widgets novos consomem tokens. Validar estados normal, pressed, hover, focus, disabled, selected. Tema System respeita o SO; alternância atualiza toda a interface.

## 18. RESPONSIVIDADE
Testar no mínimo: Android compacto, médio, grande; iPhone compacto e moderno; tablet; Web desktop. Breakpoints reais; sem overflows; SafeArea, teclado, Dynamic Type, navegação, modais, scroll, orientação, resizing. Não esconder bugs reduzindo fonte.

## 19. ACESSIBILIDADE
Contraste; Semantics; alvos de toque adequados; labels; navegação por teclado; focus; screen readers; estados acessíveis; reduced motion; font scaling; não depender só de cor.

## 20. ARQUITETURA E QUALIDADE
Preservar Clean Architecture e padrões existentes. Sem widgets monolíticos de milhares de linhas. Separar design system e funcionalidades. Reutilizar Cubits/BLoCs quando apropriado. Evitar rebuilds desnecessários. Preservar paginação, filtros, busca, autenticação e persistência. Não alterar a coleta de vagas sem necessidade. Não mudar contratos públicos sem testes.

## 21. ESTRATÉGIA DE IMPLEMENTAÇÃO (fases)
- **0 Inventário e auditoria:** verificar main; inspecionar telas; widgets reaproveitáveis; problemas de layout; limitações por plataforma; baseline visual; testes existentes.
- **1 Design System:** paleta light/dark; tipografia; espaçamento; componentes; tokens; estados; ícones; interações.
- **2 Shell e navegação:** top bar; bottom navigation; NavigationRail/sidebar; rotas; transições; responsividade.
- **3 Home e Explore:** dashboard; busca; categorias; filtros; cards; paginação; resultados.
- **4 Detalhes e ações:** detalhe; favoritar; abrir anúncio; registrar candidatura; sucesso/erro.
- **5 Autenticação:** login; cadastro; recuperação; auth gates; empty states.
- **6 Perfil e currículos:** perfil profissional; edição; currículos; preferências; configurações; pré-preenchimento seguro.
- **7 Favoritos e candidaturas:** salvos; pipeline; filtros; estados autenticado/não.
- **8 Animações:** logo animada; loading; skeletons; microinterações; splash.
- **9 i18n, responsividade e acessibilidade:** PT/EN/ES; light/dark; font scaling; mobile/tablet/desktop.
- **10 Auditoria final:** testes automatizados; visuais; navegação; consultas reais; builds; CI; documentação.

## 22. VALIDAÇÃO VISUAL OBRIGATÓRIA
Não basta "analyze passou". Executar builds reais e validar visualmente com screenshots do app renderizado (nada de mockups como prova). Galeria em `docs/design/orbijob-v2/`: Home light/dark; Explore light/dark; Filtros; Detalhe; Favoritos vazio; Favoritos autenticado (se houver QA); Candidaturas vazio; Perfil visitante; Perfil autenticado (se houver QA); Login; Cadastro; Currículos; Loading; Seleção de idioma; Tablet; Web. Sem contas reais de produção; usar fixtures e ambiente de teste; sem dados pessoais nas screenshots.

Comparar com as seis capturas do baseline: hierarquia melhorou? bordas excessivas sumiram? bottom navigation moderna? Home profissional? filtros elegantes? cards compactos e informativos? estados de autenticação agradáveis? perfil intuitivo? idioma não quebra? escuro tão bom quanto claro? parece produto corporativo pronto? Se não, refinar antes de declarar a fase concluída.

## 23. TESTES OBRIGATÓRIOS
Flutter tests e analyze; widgets; navegação; temas; i18n; layouts; golden quando úteis; formulários; autenticação simulada; upload simulado; integração com catálogo; builds Android e Web quando o ambiente permitir. Evitar snapshots frágeis; testes comportamentais além dos visuais; confirmar que o usuário ainda encontra e abre vagas reais.

## 24. COMMITS E AUTONOMIA
Trabalhar direto na main. Fluxo: inspecionar; atualizar a main; etapa coesa; testes relevantes; commit; push; conferir CI; corrigir; próxima etapa. Sem force push; sem sobrescrever outras sessões; sem expor chaves; sem atribuição a IA nos commits; sem screenshots com dados privados; sem mudanças destrutivas no Supabase sem autorização; sem serviços pagos.

## 25. RELATÓRIO FINAL
1 Diagnóstico inicial · 2 Design system · 3 Telas refatoradas · 4 Navegação · 5 Filtros · 6 Home · 7 Explore · 8 Cards e detalhes · 9 Estados de autenticação · 10 Perfil profissional · 11 Currículos · 12 Pré-preenchimento (ou limites) · 13 Animação da logo · 14 Loading e skeletons · 15 Temas · 16 i18n · 17 Responsividade · 18 Acessibilidade · 19 Screenshots reais com caminhos · 20 Testes e builds · 21 Commits · 22 CI · 23 Pendências técnicas · 24 O que depende de backend.

Uma tela só é concluída depois de compilar, funcionar e passar por validação visual.

## RESULTADO ESPERADO
Abrir o OrbiJob e sentir uma plataforma profissional moderna de busca de empregos: confiável, sofisticada e agradável, tanto para a primeira oportunidade quanto para profissionais experientes.

Não quero: telas genéricas; chips gigantes; campos sem refinamento; menus simples demais; layouts vazios; mensagens repetidas; overflow; traduções quebradas; loading sem identidade; perfil improvisado.

Quero: produto visualmente consistente; navegação excelente; busca fluida; filtros intuitivos; cards bonitos; loading animado com a identidade OrbiJob; autenticação elegante; perfil profissional completo; gestão de currículos intuitiva; auxílio seguro nas candidaturas; claro e escuro de primeira; PT/EN/ES bem implementados; responsivo em Android, iOS e Web.

NÃO PARAR NA PRIMEIRA TELA. Refatorar o produto inteiro, implementar, testar, validar visualmente, publicar e continuar até concluir o escopo ou encontrar bloqueio real. Começar pela auditoria visual e pelo novo design system, depois avançar autonomamente pelas fases.
