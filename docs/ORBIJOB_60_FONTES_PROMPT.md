# ORBIJOB — OPERAÇÃO GLOBAL: 60 FONTES, INTEGRAÇÃO REAL E AUTOMAÇÃO

> Guardado em 2026-10-12. Ordem combinada com o proprietário: (1) consolidação/freshness do catálogo (em andamento) → (2) **este prompt (60 fontes)** → (3) OrbiJob 2.0 visual (`docs/ORBIJOB_2_0_PROMPT.md`).

Você é o engenheiro principal responsável pela expansão e consolidação do catálogo mundial de vagas do OrbiJob.
Repositório: https://github.com/Lucasdiogof/orbijob · Supabase: `rpmlfxwebnlxnwadyvle`

## 0. MISSÃO E AUTORIZAÇÃO
Trabalhar autonomamente: investigar, implementar, testar, importar vagas e publicar direto na `main`, sem PR. Objetivo: o maior número viável de fontes gratuitas, confiáveis e legalmente utilizáveis. NÃO ficar só pesquisando: transformar fontes aprovadas em conectores funcionando, com vagas reais no app. Não parar na primeira fonte.

Restrições absolutas: infraestrutura 100% gratuita; não contratar serviços; não desabilitar RLS; não expor secrets; não contornar CAPTCHA, bloqueios ou autenticação; HTTP 200 não é permissão de redistribuição; não apagar dados de usuários; sem alterações destrutivas sem autorização específica; não ultrapassar quotas; sem force push; não modificar o projeto Supabase errado.

## 1. CONCEITO
Agregador global de TODAS as profissões (tecnologia, saúde, educação, engenharia, administração, finanças, comércio, vendas, marketing, design, indústria, construção, transporte, logística, hotelaria, turismo, agronegócio, serviços, setor público, outras). Prioridades especiais de esforço (não exclusividade): Flutter/Mobile internacional; Fisioterapia/Fisioterapia Pélvica (inclusive vagas presenciais). Ordem geográfica: Europa, Oceania, Ásia, África, América do Norte, América Latina e Brasil; sem excluir países.

## 2. ESTADO ATUAL (histórico — conferir banco e GitHub antes)
Cinco fontes: Jobicy, Arbeitnow, Remote OK, Remotive, Platsbanken/JobTech. 1.788 vagas (Platsbanken 600, Jobicy 771, Arbeitnow 300, Remote OK 99, Remotive 18); banco ~43 MB; revalidação, retenção e descoberta incremental implementadas; ~39 mil anúncios na origem sueca. Não trabalhar no redesign nesta sessão.

## 3. INVESTIGAR AS 60 FONTES (candidatas, não autorizadas; registrar evidências)
**Grupo A — APIs globais/bases estruturadas:** 1 Himalayas https://himalayas.app/docs/remote-jobs-api · 2 Open Jobs CC0 https://backend.dehnbostele.workers.dev/data/ · 3 Dev Global Jobs https://devglobaljobs.com/developers · 4 Career Nest https://careernest.cloud/api-docs · 5 RemNavi https://remnavi.com/api/ · 6 freehire https://github.com/strelov1/freehire · 7 Job Opportunities API https://jobopportunitiesapi.org/docs/overview · 8 Jobicy · 9 Arbeitnow · 10 Remote OK · 11 Remotive · 12 Platsbanken/JobTech https://jobtechdev.se/ (8–12 já integradas; não reimplementar).

**Grupo B — Europa:** 13 NAV Arbeidsplassen https://arbeidsplassen.nav.no/vilkar-api · 14 France Travail https://www.data.gouv.fr/dataservices/api-offres-demploi · 15 Bundesagentur Jobsuche https://github.com/bundesAPI/jobsuche-api · 16 VDAB Bélgica https://developer.vdab.be/ · 17 Job Market Finland https://tyomarkkinatori.fi/en/instructions-and-support/interfaces/interfaces-for-job-postings · 18 Jobnet Dinamarca https://jobnet.dk/ · 19 Job-Room Suíça https://www.job-room.ch/ · 20 UWV Países Baixos https://www.uwv.nl/ · 21 Ordem dos Fisioterapeutas Portugal https://portalbolsadeemprego.ordemdosfisioterapeutas.pt/Public/Offers · 22 IEFP Portugal https://www.iefp.pt/ · 23 Empléate Espanha https://www.empleate.gob.es/ · 24 NHS Jobs https://www.jobs.nhs.uk/ · 25 HealthJobsUK https://www.healthjobsuk.com/ · 26 HSE Irlanda https://about.hse.ie/jobs/ · 27 publicjobs.ie https://www.publicjobs.ie/ · 28 Find a Job UK https://www.gov.uk/find-a-job · 29 AMS Áustria https://www.ams.at/ · 30 ANPAL Itália https://www.anpal.gov.it/ · 31 EURES https://ec.europa.eu/eures/ · 32 CSP Careers https://www.csp.org.uk/careers-jobs

**Grupo C — Ásia e Oceania:** 33 Taiwan Open Government Jobs https://data.gov.tw/en/datasets/44062 · 34 Jobs.co.nz API https://jobs.co.nz/api · 35 MyCareersFuture https://www.mycareersfuture.gov.sg/ · 36 National Career Service Índia https://www.ncs.gov.in/ · 37 WorkNet Coreia https://www.work.go.kr/ · 38 Hello Work Japão https://www.hellowork.mhlw.go.jp/ · 39 Interactive Employment Service Hong Kong https://www2.jobs.gov.hk/ · 40 JobStreet https://www.jobstreet.com/ · 41 Workforce Australia https://www.workforceaustralia.gov.au/ · 42 APSJobs https://www.apsjobs.gov.au/ · 43 Australian Health https://www.health.gov.au/ · 44 jobs.govt.nz https://www.jobs.govt.nz/ · 45 Health New Zealand https://www.healthnz.govt.nz/careers · 46 Careers NZ https://www.careers.govt.nz/

**Grupo D — África:** 47 South African Government Jobs https://www.gov.za/jobs · 48 DPSA Vacancy Circular https://www.dpsa.gov.za/newsroom/psvc/ · 49 PSC Kenya https://www.psckjobs.go.ke/ · 50 Kenya Public Service https://www.publicservice.go.ke/ · 51 Federal Civil Service Nigeria https://recruitment.fedcivilservice.gov.ng/ · 52 PNet https://www.pnet.co.za/ · 53 BrighterMonday https://www.brightermonday.co.ke/ · 54 Jobberman https://www.jobberman.com/

**Grupo E — América e ATS:** 55 USAJOBS https://developer.usajobs.gov/ · 56 Job Bank Canada https://www.jobbank.gc.ca/network · 57 Greenhouse https://developers.greenhouse.io/job-board.html · 58 Lever https://github.com/lever/postings-api · 59 Ashby https://developers.ashbyhq.com/ · 60 SmartRecruiters https://developers.smartrecruiters.com/

Investigar também fontes novas descobertas; sem limite artificial às 60.

## 4. PRIORIZAÇÃO
**Lote 1:** NAV Noruega, Taiwan Jobs Open Data, Himalayas, Open Jobs CC0. **Lote 2:** Jobs.co.nz, Dev Global Jobs, RemNavi, fontes públicas da África do Sul. **Lote 3:** outras governamentais europeias/asiáticas, ATS com acesso e reutilização autorizados, novos feeds. Prioridade não é autorização: se exigir cadastro/token/aprovação, documentar a pendência e avançar.

## 5. AUDITORIA OBRIGATÓRIA POR FONTE
API/feed oficial; endpoint de listagem; endpoint de detalhes; paginação; atualização incremental; status da vaga; data de publicação; data de encerramento; países; profissões; formato; autenticação; quotas gratuitas; licença vigente; permissão de coleta, armazenamento e redistribuição; atribuição; regras de atualização/remoção; compatibilidade com uso comercial; qualidade dos identificadores; integridade das URLs; taxa de duplicação; viabilidade no plano gratuito.

Classificar: **PERSIST** (armazenar e exibir autorizados) · **FEDERATED** (consulta/exibição autorizadas, persistência não comprovada/proibida) · **LINK_ONLY** · **PENDING** (faltam provas) · **BLOCKED** (termos, custo ou controles impedem). Guardar URL da evidência e data. Nunca PERSIST só porque o endpoint é acessível.

## 6. CONECTORES
Para cada PERSIST: adapter independente aproveitando a arquitetura atual; paginação; normalizar títulos/empresas; preservar descrições originais limpando HTML inseguro; normalizar localização; modalidade; salário quando informado; preservar restrições geográficas; deduplicar por ID e URL canônica; verificar se continua aberta; tratar encerradas; retries; rate limiting; timeouts; checkpoints; leases; limites de lote; tetos por fonte; logs estruturados; testes automatizados; monitoramento. Sem arquivo gigante; sem replicar arquitetura; sem serviço pago.

## 7. DATASETS MASSIVOS (Open Jobs CC0)
NÃO baixar/armazenar o dataset completo. Investigar: arquivos particionados; partição por país; filtros por data; consulta seletiva por profissão; Parquet/NDJSON; streaming; arquivos incrementais; metadados de atualização; identificadores de origem; proveniência e licença por subconjunto. Começar com amostras pequenas; avaliar freshness e duplicação; importar só anúncios recentes, verificáveis e de boa qualidade; manter cobertura multiprofissional.

## 8. TESTAR ANTES DE IMPORTAR
Consulta somente leitura → validação de licença → amostra de 20–50 anúncios → verificação de campos → duplicatas → preview de importação → estimativa de armazenamento → testes do conector → testes de segurança e RLS → importação real controlada. Importações reais não destrutivas de fontes aprovadas, dentro dos limites gratuitos, estão autorizadas após as validações (sem aprovação por lote pequeno). Nunca importar fonte PENDING ou BLOCKED. Sem migrações destrutivas sem autorização específica.

## 9. BUSCA FEDERADA
Para FEDERATED, avaliar busca sob demanda no backend: consultar catálogo persistido + fontes externas autorizadas; normalizar; deduplicar; identificar proveniência; filtros compatíveis; proteger quotas; cache só se permitido; resultados parciais quando uma fonte falhar. Nada de tokens no Flutter; não gastar quota vitalícia em agendamentos; suportar todas as profissões.

## 10. COBERTURA
Medir vagas por continente, país, sem país, remotas/presenciais/híbridas, por área, fisioterapia, fisioterapia pélvica, Flutter/Mobile. Pélvica e Flutter com mais esforço de investigação/qualidade, sem limitar as demais.

## 11. REVALIDAÇÃO E EXPIRAÇÃO
Por fonte: frequência de descoberta; método de revalidação; como saber se encerrou; o que fazer quando a vaga sai da janela de paginação; diferenciar encerrada de falha HTTP; feed parcial; quando ocultar registro desatualizado; quando compactar; quando excluir respeitando vínculos. Nunca atualizar `last_checked_at` sem confirmação real. Não fechar por timeout, 403, 429 ou leitura incompleta. Preservar favoritos e candidaturas.

## 12. AUTOMAÇÃO
GitHub Actions, Supabase Cron, Cloudflare Worker existente se apropriado; respeitar quotas, capacidade, rate limits, leases, intervalos mínimos, horários existentes, tetos por fonte e global, armazenamento, monitoramento. Sem custo. Nenhuma rotina sem recuperação e observabilidade.

## 13. VALIDAR NO APP
Fonte só está integrada quando o Flutter a consulta pela chave pública: RLS; `can_redistribute`; status da fonte; vagas abertas; freshness; títulos e empresas; países; links originais; atribuição; filtros e busca. Sem mudanças visuais.

## 14. GITHUB E TESTES
Fluxo: atualizar main → inspecionar → uma integração → testes → commit → push → CI → corrigir → próxima. Sem force push, sem sobrescrever outras sessões, sem referência a IA nos commits, sem credenciais. Testes de Worker, SQL e Flutter relevantes.

## 15. DOCUMENTAÇÃO
Matriz global das 60 candidatas + outras encontradas, com: fonte, URL, países, profissões, formato, API, autenticação, quota, licença, permissão de persistência, de exibição, atribuição, frequência, estado, motivo, vagas efetivamente importadas, data da verificação, evidências. Documentar também: arquitetura dos conectores; como executar preview; importação; ativar Cron; desativar fonte; investigar falha; medir quota e armazenamento.

## 16. RELATÓRIO FINAL
1 Estado inicial · 2 Estado final · 3 Fontes pesquisadas · 4 Aprovadas · 5 Rejeitadas e motivos · 6 Conectores implementados · 7 Vagas importadas por fonte · 8 Total de abertas · 9 Empresas · 10 Países e continentes · 11 Profissões · 12 Flutter · 13 Fisioterapia · 14 Fisioterapia pélvica · 15 Novos agendamentos · 16 Revalidação e expiração · 17 Consumo Supabase · 18 Testes · 19 Commits · 20 CI · 21 Pendências do proprietário. Não declarar integrada fonte que só tem conector; não declarar importadas vagas só vistas em preview; não confundir armazenado com federado.

## 17. EXECUÇÃO AUTÔNOMA
Se a NAV exigir token, documentar e avançar para Taiwan; se Taiwan estiver acessível, validar e integrar; se Himalayas estiver liberada, validar e integrar; se Open Jobs for grande demais, usar um subconjunto; se uma fonte falhar por licença/bloqueio/custo, passar à próxima. Continuar enquanto a sessão estiver disponível. COMEÇAR PELA AUDITORIA DE PRODUÇÃO E PELO LOTE 1: NAV, TAIWAN, HIMALAYAS E OPEN JOBS CC0.
