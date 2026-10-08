# Issues do OrbiJob (por área)

Fonte de verdade das issues abertas no GitHub (rótulo `area:*` + `phase:*`). Mantenha este arquivo e o GitHub alinhados; **evite duplicatas** buscando pelo título antes de criar.

| # | Área | Fase | Título |
|---|---|---|---|
| 1 | foundation | 1 | Publicar identidade escolhida e aplicar tema/ícones do app |
| 2 | foundation | 1 | Busca formal de marca "OrbiJob" (INPI/USPTO/EUIPO/WIPO), lojas e domínios |
| 3 | foundation | 1 | Definir licença do repositório (público) e adicionar LICENSE |
| 4 | foundation | 1 | Habilitar proteção de branch, Dependabot e secret scanning no GitHub |
| 5 | data-sources | 1 | Obter chaves gratuitas USAJOBS / Adzuna / France Travail |
| 6 | data-sources | 1 | Rodar `scripts/acceptance.mjs` com internet e arquivar evidência |
| 7 | data-sources | 1 | Ler e registrar termos oficiais (Himalayas, Jobicy, Greenhouse, Ashby, Reed, Adzuna-cache) |
| 8 | data-sources | 1 | Conector USAJOBS com fixtures reais |
| 9 | data-sources | 1 | Conector Adzuna com atribuição obrigatória |
| 10 | data-sources | 7 | Investigar serviços públicos por país (IEFP-PT, MyCareersFuture-SG, Bayt-AE, SAPS-ZA, Job Bank-CA, Bundesagentur-DE) |
| 11 | backend | 2 | Worker: rotas /search e /jobs/:id com cache KV |
| 12 | backend | 2 | Worker: rate limiting por IP/usuário |
| 13 | backend | 1 | Job de sincronização com `sync_runs` e métricas por conector |
| 14 | backend | 2 | Runbook de backup e recuperação |
| 15 | database | 2 | Criar projeto Supabase de staging (requer aprovação) e aplicar migração |
| 16 | database | 2 | Repetir testes de RLS no Supabase real |
| 17 | database | 2 | Validar índices de busca (tsvector/trigram) com volume real |
| 18 | flutter-ui | 3 | Login e cadastro com Supabase Auth |
| 19 | flutter-ui | 3 | Perfil (cabeçalho): currículo, experiências, formação, licenças |
| 20 | flutter-ui | 3 | Componentes: JobCard, FilterSheet, MatchBadge, StageTimeline, SourceAttribution |
| 21 | flutter-ui | 3 | Detalhe da vaga |
| 22 | search | 1 | Importar ESCO/ISCO e revisar rótulos com falantes nativos |
| 23 | search | 2 | Filtros internacionais (país, modalidade, salário, profissão, idioma) |
| 24 | search | 2 | Conectar busca ao Worker com estados loading/vazio/erro/sem-fonte |
| 25 | ranking | 4 | Motor de compatibilidade 0–100 determinístico com evidências |
| 26 | ranking | 4 | Confiança da análise separada da pontuação |
| 27 | applications | 5 | Favoritos, notas, pesquisas salvas e histórico de visualização |
| 28 | applications | 5 | Candidaturas: etapas, entrevistas, propostas, lembretes |
| 29 | autofill | 6 | `ApplicationAutofillService` mobile (InAppWebView, allowlist, sem submit) |
| 30 | autofill | 6 | Web/PWA: painel de respostas copiáveis |
| 31 | security | 2 | Sanitização de HTML de vagas e testes |
| 32 | security | 3 | Exportar e excluir dados do usuário (LGPD/GDPR) |
| 33 | qa | 1 | Rodar CI no GitHub Actions e corrigir falhas |
| 34 | qa | 3 | Testes de integração dos fluxos críticos |
| 35 | qa | 3 | Verificações de acessibilidade (contraste, leitores de tela, alvos de toque) |
| 36 | release | 8 | Ícones/splash finais Android/iOS/PWA e metadados das lojas |
| 37 | release | 8 | Material no portfólio lucksrei.com (sem alterar o site antes da aprovação) |
