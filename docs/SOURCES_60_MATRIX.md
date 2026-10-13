# Matriz das 60 fontes candidatas (verificada em 12/10/2026)

Classes: **PERSIST** (armazenar e exibir autorizados) · **FEDERATED** (consulta/exibição, sem persistência comprovada) · **LINK_ONLY** · **PENDING** (faltam provas, credencial ou resposta de terceiro) · **BLOCKED** (termos/custo impedem). "Lida" = a página de termos/API foi lida nesta ou na sessão anterior (12/10); "não lida" = decisão por falta de endpoint público e **não** por leitura completa dos termos; será reavaliada na próxima rodada.
Detalhes e evidências das fontes integradas: `docs/SOURCES_MATRIX.md`. Frescor de cada uma: `docs/FRESHNESS_POLICY.md`.

| # | Fonte | Região | Classe | Estado e motivo | Vagas importadas |
|---|---|---|---|---|---:|
| 1 | Himalayas | global | FEDERATED (em tese) | termos proíbem espelhar/copiar (lida 12/10); sem busca federada construída e sem permissão escrita | 0 |
| 2 | Open Jobs CC0 | global | PENDING | CC0 declarado, sem conta; **export de 05/10 (7 dias): sem como dar verificação honesta de 72 h**; retomar com `head` ≤ 3 dias (hyparquet com Range já provado em `join.parquet`) | 0 |
| 3 | Dev Global Jobs | global | PENDING | API pública sem chave; "redistribuição comercial exige permissão escrita"; pedir permissão | 0 |
| 4 | Career Nest | global | PENDING | documentação não lida a fundo | 0 |
| 5 | RemNavi | remoto/tech | BLOCKED | CC BY 4.0, mas reagrega WWR/Himalayas/Remotive/Remote OK/ATS: proveniência proibida e duplicada | 0 |
| 6 | freehire | global | PENDING | repositório não avaliado | 0 |
| 7 | Job Opportunities API | global | PENDING | documentação não avaliada | 0 |
| 8 | Jobicy | remoto | **PERSIST — integrada** | revalidação por status endpoint (Supabase Cron + Actions) | 848 |
| 9 | Arbeitnow | Europa | **PERSIST — integrada** | janela de 8 páginas; sem endpoint por id; fora da janela → `unknown` | 600 |
| 10 | Remote OK | remoto | **PERSIST — integrada** | feed completo; ausência > 7 d → `closed` | 100 |
| 11 | Remotive | remoto | **PERSIST — integrada** | feed completo; 1–2x/dia | 18 |
| 12 | Platsbanken / JobTech (SE) | Europa | **PERSIST — integrada** | CC0; `/ad/{id}`; revalidação no Supabase | 593 |
| 13 | NAV Arbeidsplassen (NO) | Europa | PENDING | termos permitem republicar; **token de produção por e-mail à NAV** (ação do dono) | 0 |
| 14 | France Travail (FR) | Europa | PENDING | acesso restrito, pedido por formulário em francetravail.io; 10 chamadas/s | 0 |
| 15 | Bundesagentur Jobsuche (DE) | Europa | PENDING | API documentada pela comunidade; sem termos oficiais de reuso | 0 |
| 16 | VDAB (BE) | Europa | PENDING | portal de desenvolvedor exige cadastro (página devolveu 403 a leitura automatizada; não contornado) | 0 |
| 17 | Job Market Finland (FI) | Europa | PENDING | retirada de anúncios só para organização com credencial do KEHA | 0 |
| 18 | Jobnet (DK) | Europa | PENDING | sem API pública localizada | 0 |
| 19 | Job-Room (CH) | Europa | PENDING | API sob aprovação do RAV; não lida | 0 |
| 20 | UWV (NL) | Europa | LINK_ONLY | sem API oficial; bloqueia IP fora dos Países Baixos | 0 |
| 21 | Ordem dos Fisioterapeutas (PT) | Europa | LINK_ONLY | bolsa de emprego sem API; termos não lidos; prioridade de fisioterapia: solicitar acordo | 0 |
| 22 | IEFP (PT) | Europa | PENDING | sem API pública localizada | 0 |
| 23 | Empléate (ES) | Europa | PENDING | sem API pública localizada | 0 |
| 24 | NHS Jobs (UK) | Europa | LINK_ONLY | feeds só para parceiros | 0 |
| 25 | HealthJobsUK | Europa | LINK_ONLY | sem API pública | 0 |
| 26 | HSE (IE) | Europa | LINK_ONLY | sem API pública | 0 |
| 27 | publicjobs.ie | Europa | LINK_ONLY | sem API pública | 0 |
| 28 | Find a Job (UK) | Europa | PENDING | API do DWP sob cadastro; não lida | 0 |
| 29 | AMS (AT) | Europa | PENDING | sem API pública localizada | 0 |
| 30 | ANPAL (IT) | Europa | PENDING | sem API pública localizada | 0 |
| 31 | EURES | Europa | LINK_ONLY | dados só para parceiros nacionais | 0 |
| 32 | CSP Careers (UK) | Europa | LINK_ONLY | termos §3.2/4.3/4.4 proíbem copiar (lidos 12/10) | 0 |
| 33 | Taiwan Open Government Jobs | Ásia | **PERSIST — integrada** | OGDL v1.0, atribuição obrigatória; extract diário de 1.000 | 960 |
| 34 | Jobs.co.nz | **Oceania** | **PERSIST — integrada** | API pública, `/jobs/{id}` 404 = encerrada, `expires_at`; 120 req/min | 301 |
| 35 | MyCareersFuture (SG) | Ásia | PENDING | sem termos oficiais de API localizados | 0 |
| 36 | NCS (IN) | Ásia | PENDING | sem API pública localizada | 0 |
| 37 | WorkNet (KR) | Ásia | PENDING | API de dados abertos exige chave; não avaliada | 0 |
| 38 | Hello Work (JP) | Ásia | LINK_ONLY | sem API pública | 0 |
| 39 | IES Hong Kong | Ásia | PENDING | dados abertos HK não avaliados | 0 |
| 40 | JobStreet | Ásia | LINK_ONLY | portal comercial (SEEK), scraping proibido | 0 |
| 41 | Workforce Australia | Oceania | PENDING | sem API pública localizada | 0 |
| 42 | APSJobs | Oceania | PENDING | a página não carregou para leitura automatizada; sem feed localizado | 0 |
| 43 | Australian Health | Oceania | LINK_ONLY | página institucional | 0 |
| 44 | jobs.govt.nz | Oceania | PENDING | sem RSS/API/termos localizados na página inicial | 0 |
| 45 | Health New Zealand | Oceania | LINK_ONLY | página de carreiras | 0 |
| 46 | Careers NZ | Oceania | LINK_ONLY | orientação de carreira, não vagas | 0 |
| 47 | South African Government Jobs | África | PENDING | circulares em PDF; sem API | 0 |
| 48 | DPSA Vacancy Circular | África | PENDING | PDFs quinzenais; extração e licença não avaliadas | 0 |
| 49 | PSC Kenya | África | PENDING | sem API | 0 |
| 50 | Kenya Public Service | África | PENDING | sem API | 0 |
| 51 | Federal Civil Service (NG) | África | PENDING | portal de recrutamento, sem API | 0 |
| 52 | PNet | África | LINK_ONLY | portal comercial | 0 |
| 53 | BrighterMonday | África | LINK_ONLY | portal comercial | 0 |
| 54 | Jobberman | África | LINK_ONLY | portal comercial | 0 |
| 55 | USAJOBS | América do Norte | PENDING | chave gratuita por cadastro (ação do dono) | 0 |
| 56 | Job Bank Canada | América do Norte | PENDING | dados abertos mensais (vagas passadas): servem à estatística, não ao catálogo ativo | 0 |
| 57 | Greenhouse | ATS | PENDING | API de quadro de vagas pública por empregador; direito é do empregador; só com autorização por empresa | 0 |
| 58 | Lever | ATS | PENDING | idem | 0 |
| 59 | Ashby | ATS | PENDING | idem | 0 |
| 60 | SmartRecruiters | ATS | PENDING | idem | 0 |

**Integradas hoje: 7 fontes (5 anteriores + Taiwan Jobs + Jobs.co.nz).** Pendências que dependem do proprietário: token NAV (e-mail à NAV), chave USAJOBS, formulário France Travail, permissão de Dev Global Jobs e Himalayas, credencial KEHA (Finlândia), chave do Jooble/Adzuna.
Próxima rodada de fontes (depois da etapa visual): reavaliar Open Jobs CC0 (frescor), ler os termos das fontes marcadas "não lida", e construir a busca federada para as FEDERATED.

## Atualização 6.0 (13/10/2026) — fontes avaliadas além das 60

Detalhes, evidências e licenças em `docs/SOURCES_6_0.md`.

| # | Fonte | Região | Classe | Estado | Vagas armazenadas |
|---|---|---|---|---|---:|
| 61 | Teaching Vacancies (DfE, Inglaterra) | Europa | **PERSIST — integrada, aguardando publicação** | OGL v3.0 declarada nos termos da API; feed completo lido a cada passada; teto 2.000 | 700 |
| 62 | NYC Jobs (NYC Open Data) | América do Norte | **PERSIST — integrada, aguardando publicação** | dados abertos da cidade; só postagens External; link `cityjobs.nyc.gov/job/{id}` | 800 |
| 63 | Get on Board | América Latina | **PERSIST (condicional) — integrada, aguardando publicação** | API pública documentada; nenhum termo concede ou nega o armazenamento: decisão do dono (pedido de confirmação sugerido) | 600 |
| 64 | Landing.jobs | Europa | BLOCKED | `robots.txt`: `Disallow: /api/` | 0 |
| 65 | Trampos.co | América Latina (BR) | BLOCKED | termos §2.5 proíbem robôs/scripts/cópia | 0 |
| 66 | MyCareersFuture | Ásia (SG) | BLOCKED | termos §5/§16: sem reprodução sem permissão escrita | 0 |
| 67 | Torre | América Latina | BLOCKED | API comercial com créditos; `robots.txt` `Disallow: /api/` | 0 |
| 68 | Latvia NVA "Vakances" (data.gov.lv, CC0) | Europa | PENDING (candidata) | sem nome do empregador nem descrição; só setor público | 0 |
| 69 | City of Calgary Careers (dados abertos) | América do Norte | PENDING (candidata) | 61 vagas, só título/área/prazo/link | 0 |
| 70 | Karriere.NRW (Open.NRW) | Europa (DE) | **PERSIST — integrada, aguardando publicação** | dl-by-de/2.0; lista completa em 1 requisição; contatos nunca lidos; inclui vagas de formação | 931 |
| 71 | Groupe BPCE (dados abertos do empregador) | Europa (FR + exterior) | **PERSIST — integrada, aguardando publicação** | Licence Ouverte 2.0 e convite explícito do produtor; sem data de publicação (honesto) | 1.000 |
| 72 | Le Forem (Valônia) | Europa (BE) | PENDING (decisão do dono) | CC BY-SA 4.0, sem descrição, quase só interinas | 0 |
| 73 | Infrabel (CC0) | Europa (BE) | PENDING | só metadados, sem link da vaga | 0 |

Reavaliadas em 13/10: Open Jobs CC0 (head ainda 05/10: segue PENDING por frescor), Bundesagentur (403 a toda requisição deste ambiente: PENDING).
