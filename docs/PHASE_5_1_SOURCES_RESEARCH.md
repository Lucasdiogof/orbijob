# OrbiJob — Fase 5.1: pesquisa de fontes reais de vagas

Data: **2026-10-09**. Escopo: somente pesquisa. Nenhum código, migration, commit, deploy ou escrita no Supabase foi feito.
Este arquivo está **sem commit** (arquivo novo na árvore de trabalho) a pedido da fase.

Substitui, onde houver conflito, o levantamento de 2026-10-08 ([`GLOBAL_SOURCES.md`](GLOBAL_SOURCES.md), [`SOURCES_TABLE.md`](SOURCES_TABLE.md)), que foi feito **com a rede bloqueada** e se apoiou em resumos de terceiros. Nesta rodada li os termos em texto primário e chamei as APIs abertas de verdade.

## Correções da Fase 5.2 (2026-10-09, mais recentes que o restante deste arquivo)

**1. USAJOBS: a divergência apontada não se reproduz hoje, mas a conclusão ficou mais cautelosa.**
* Baixei as duas páginas no mesmo dia: [`/guides/terms-of-service`](https://developer.usajobs.gov/guides/terms-of-service) e [`/apirequest/index`](https://developer.usajobs.gov/apirequest/index). A página de solicitação **embute** o bloco "USAJOBS API Terms of Service" com as mesmas 12 seções. Comparei sentença por sentença: **idênticas**, exceto o rótulo de um botão ("Close") e espaçamento. Não há cláusula mais restritiva na página de solicitação. A cláusula de licença (seção 2, "Public Data… may be copied, stored, reformatted, adapted, analyzed, published, redistributed, and used for lawful commercial or noncommercial purposes. Prior OPM approval is not required") está nas duas.
* Hipóteses para a divergência vista antes, **não confirmadas**: leitura de uma versão anterior ou em cache; ou leitura de um resumo. Os próprios termos dizem que o OPM pode atualizar o texto e avisar por e-mail, e que o uso continuado conta como aceite.
* Pontos que **limitam** a leitura de "autorização irrestrita": (a) o "Public Data" **exclui** conteúdo marcado com restrição legal ou de terceiros; (b) a seção 4 incorpora "applicable policies identified on the USAJOBS Developer site", que não li; (c) o formulário de chave pede ao solicitante descrever o uso (255 caracteres) e exige aceitar os termos: **o aceite no cadastro é o ato que vincula**; (d) o OPM não garante dado completo ou atual e **o consumidor responde por conferir com o anúncio oficial** (seção 10); (e) não pode sugerir endosso nem usar selos do governo (seção 2).
* **Reclassificação:** de "autorização expressa" para **CONFIRMADO NO TEXTO ATUAL; RECONFIRMAR NO ACEITE**. Antes de gravar vagas do USAJOBS, o dono deve ler o texto exibido no momento do cadastro e arquivar uma cópia. Impressão digital do corpo normalizado dos termos lidos hoje (SHA-256, 16 primeiros caracteres): `5421235eff6a300d`; se mudar, o texto mudou.
* Continuo **sem** ter testado a API real (exige chave).

**2. Jobicy: agora conferido no texto primário.** O [README oficial](https://github.com/Jobicy/remote-jobs-api) e o [OpenAPI](https://jobicy.com/api/openapi.json) foram lidos integralmente nesta fase (a seção 3.3 abaixo vinha de resumo). Confirmado:
* Endpoint `GET https://jobicy.com/api/v2/remote-jobs`, sem chave; `count` 1–200; cursor opaco válido 24 h; HTTP 400 em cursor expirado ou alterado.
* Feed = **somente os últimos 7 dias**; "uma vaga que sai da janela pode continuar aberta"; status em lote (≤ 100 ids): `active`, `closed`, `unknown` ("`unknown` não confirma fechamento").
* **Frequência:** "não iniciar novas passadas automáticas de sincronização mais de uma vez por hora". Não há cota por requisição publicada (a pausa de 1 s entre páginas é escolha do adaptador).
* **Fair Use:** pode usar em produtos sem pedir permissão individual; manter o Jobicy como fonte e a URL canônica; não apresentar como vagas próprias; não criar redes de spam nem bases enganosas; volume alto → contatar. Licença MIT só do código do repositório, **não** dos anúncios.
* **Armazenar é permitido e esperado:** "Cache responses where appropriate" e "Store jobs by `id` to avoid duplicates".
* `jobGeo` é texto humano separado por vírgulas, "não é um array de códigos ISO"; `companyLogo` pode ser `false`; HTML da descrição deve ser sanitizado.
* Classificação mantida: **CONFIRMADO EM DOCUMENTAÇÃO OFICIAL** para consulta, armazenamento por id e exibição com crédito. **Limite:** é um texto de uso justo, não um contrato; vale a regra "volume fora do normal → falar com a fonte".

**3. Adzuna: nada mudou, e continua sem base para persistência.** Termos relidos em texto bruto ([ToS](https://developer.adzuna.com/docs/terms_of_service)): limites padrão 25/min, 250/dia, 1.000/semana, 2.500/mês; rótulo "Adzuna" ≥ 116×23 px com link; uso comercial além de publicar anúncios exige 14 dias de teste e consentimento escrito; ao encerrar, remover todo dado obtido. **Silêncio sobre cache e armazenamento.** Não foi implementado nada do Adzuna.

**4. Auditoria do schema (migrations 1, 2 e 6, sem criar nada).** `jobs` cobre tudo que o Jobicy fornece, sem coluna nova. Pontos:
* `jobs_read` (RLS) libera ao app só vagas de fontes com `can_redistribute = true` e status `READY` ou `CONDITIONAL`; `job_clusters` só aparece para vagas legíveis; `sync_runs` não tem política de cliente.
* Grants dos clientes: só `select` em `job_sources`, `jobs` e `job_clusters`. O `service_role` **não** tem privilégio de tabela sem a migration 6 (confirmado por teste no schema real); com ela, tem exatamente `select/insert/update` em `job_sources`, `select/insert/update/delete` em `jobs` e `job_clusters`, `select/insert/update` em `sync_runs`, e `select` em `resumes`.
* Índices existentes servem ao uso: `unique (source_id, external_id)`, `jobs_source_idx`, `jobs_fingerprint_idx`, `jobs_canonical_idx`, `jobs_country_idx`, GIN de busca e trigrama no título.
* Lacunas que **não** exigem migration agora: sem coluna de prazo de candidatura (o Jobicy não tem prazo; USAJOBS terá), sem indicação de salário estimado (o Jobicy não estima), `cluster_id` vazio.
* **Dependência de implantação:** a linha da fonte em `job_sources` e a migration 6 (ver [`JOBICY_INGESTION.md`](JOBICY_INGESTION.md)).

**5. Achado do lado Flutter:** o app usa `NoSourceSearchRepository`; **não existe repositório que leia `jobs`**. Isso, e não as telas, é o que falta para uma vaga aparecer no app.

## 0. Como ler as classificações

| Rótulo | Significa |
|---|---|
| **CONFIRMADO EM DOCUMENTAÇÃO OFICIAL** | Li o texto oficial (termos, documentação ou o aviso legal da própria resposta da API) |
| **DEPENDE DE AUTORIZAÇÃO** | O texto oficial exige contrato, consentimento escrito, aprovação ou deixa o ponto ambíguo de forma que só o provedor resolve |
| **NÃO CONFIRMADO** | Não encontrei o texto oficial, ou ele não cobre o ponto. Não é permissão |
| **INCOMPATÍVEL** | Os dados ou os termos não servem para listar vagas no app |

Três permissões diferentes, que nunca devem ser confundidas: **(C)** consultar a API, **(A)** armazenar/cachear os dados, **(R)** republicar/exibir em app próprio e monetizar. Ter (C) não dá (A) nem (R).

Limite do método: a leitura das páginas foi feita por um extrator automático. Para as cláusulas que decidem o ranking (USAJOBS, Adzuna, Arbeitnow) conferi o **texto bruto** das páginas de termos com `curl`. Para o resto, o resumo do extrator vale como indicação e está marcado quando não foi conferido no bruto.

---

## 1. Resultado em uma tela

* **Três fontes comprovadamente utilizáveis agora**, no sentido de "li o texto oficial e chamei a API": **USAJOBS** (termos claríssimos, mas a chamada exige chave que não tenho), **Jobicy** (termos e chamada confirmados, sem chave) e **Adzuna** (termos lidos, cobertura ampla, mas exige chave e a regra de armazenamento é omissa).
* **O maior risco do produto não é técnico, é de cobertura:** não encontrei **nenhuma fonte aberta** para **Brasil** (exceto Adzuna `br`, que exige chave) e para **Portugal**. Ofícios (pedreiro, motorista, pintor) só aparecem em serviços públicos de emprego e no Adzuna.
* **O esquema atual do banco tem uma trava que muda o desenho:** a política RLS `jobs_read` só deixa o app ler vagas de fontes com `can_redistribute = true`. Para fontes cuja regra de armazenamento é omissa (Adzuna), o desenho seguro é **consulta sob demanda via Worker**, sem gravar em `jobs` até haver autorização por escrito (seção 5).
* **Recomendação:** MVP = **USAJOBS**; complementares = **Adzuna** (cobertura) e **Jobicy** (remoto global, com checagem de vaga fechada); expansão = Suécia (JobSearch), ATS por empresa e France Travail. Detalhes na seção 8.

---

## 2. Fontes investigadas

Legenda das colunas de permissão: C = consultar, A = armazenar, R = republicar/exibir em app comercial.

| Fonte | C | A | R | Chave | Países | Profissões | Classificação geral |
|---|---|---|---|---|---|---|---|
| **USAJOBS** | sim | **sim** | **sim**, uso comercial permitido | grátis | EUA (federal) | todas | **CONFIRMADO EM DOCUMENTAÇÃO OFICIAL** |
| **Jobicy** | sim | não dito (cache pedido) | **sim**, "produtos" permitidos com crédito | não | global (remoto) | várias | **CONFIRMADO EM DOCUMENTAÇÃO OFICIAL** |
| **Adzuna** | sim | **omisso** | sim para "publicar anúncios", com rótulo | sim | 19 (não oficial) | todas | **DEPENDE DE AUTORIZAÇÃO** (armazenamento) |
| **Himalayas** | sim | não dito | link obrigatório; resto omisso | não | global (remoto) | tecnologia e conhecimento | **NÃO CONFIRMADO** (termos não achados) |
| **Remotive** | sim | restrito | só com link e crédito; 24 h de atraso | não | global (remoto) | várias | **CONFIRMADO**, mas com **17 vagas** hoje |
| **Remote OK** | sim | não dito | link com follow + crédito; sem logo | não | global (remoto) | várias | CONFIRMADO só o aviso; uso comercial **NÃO CONFIRMADO** |
| **Arbeitnow** | sim | contraditório | contraditório | não | Alemanha (maioria) | várias | **DEPENDE DE AUTORIZAÇÃO** |
| **The Muse** | sim | implícito ("exibir") | exibir com link | sim (grátis) | EUA e outros | várias | **DEPENDE DE AUTORIZAÇÃO** |
| **Greenhouse Job Board** | sim | por empregador | por empregador | não (GET) | por empresa | todas | **NÃO CONFIRMADO** (sem termos) |
| **Lever Postings** | sim | "podem ser raspadas por terceiros" | por empregador | não (GET) | por empresa | todas | CONFIRMADO só a nota; **NÃO CONFIRMADO** o resto |
| **Ashby** | sim | por empregador | por empregador | não | por empresa | todas | **NÃO CONFIRMADO** (sem termos) |
| **Suécia JobSearch** | sim | "dados abertos" | "dados abertos" | não | SE | todas | licença **NÃO CONFIRMADA** no texto oficial |
| **France Travail** | sim | licença exigida | licença exigida | OAuth2 | FR | todas | **DEPENDE DE AUTORIZAÇÃO** |
| **Job Bank (Canadá)** | sim (CSV) | OGL-Canadá | OGL-Canadá | não | CA | todas | **INCOMPATÍVEL** para listar vagas (só estatística) |
| **Reed** | sim | omisso | omisso | grátis | GB | todas | **NÃO CONFIRMADO** |
| **Jooble** | só com chave | omisso | termos proíbem robôs no site | sob pedido | global | todas | **DEPENDE DE AUTORIZAÇÃO** |
| **Careerjet** | só com chave | omisso | API de afiliado | sim | muitos | todas | **NÃO CONFIRMADO** |
| **InfoJobs (ES)** | sim, com cadastro | não lido | não lido | sim | ES | todas | **NÃO CONFIRMADO** |
| **Bundesagentur (DE)** | sim (não oficial) | sem termos | sem termos | cabeçalho público | DE | todas | **NÃO CONFIRMADO**; a própria doc diz que não há API oficial |
| **EURES** | só portal | restrito | restrito | n/a | 31 | todas | **INCOMPATÍVEL** para API (link externo) |
| **SINE / Emprega Brasil, Gupy, IEFP (PT)** | — | — | — | — | BR, PT | todas | **NÃO CONFIRMADO**: nenhuma API pública achada |

---

## 3. Documentação oficial e termos (evidência por fonte)

### 3.1 USAJOBS — melhor clareza jurídica
* Doc: [Search API](https://developer.usajobs.gov/api-reference/get-api-search), [Termos](https://developer.usajobs.gov/guides/terms-of-service), [Rate limiting](https://developer.usajobs.gov/guides/rate-limiting).
* **Termos (texto bruto conferido, seção 2; ver a nota de divergência no topo):** o dado público "may be copied, stored, reformatted, adapted, analyzed, published, redistributed, and used for lawful commercial or noncommercial purposes. Prior OPM approval is not required." O registro da API rege o **acesso**, não o reuso do dado.
* Atribuição **não é obrigatória**, apenas incentivada (nomear USAJOBS, linkar o anúncio oficial, data de coleta). Proibido: apresentar dado modificado como oficial, sugerir endosso do OPM, usar selos, afirmar falsamente que a candidatura foi enviada.
* Frescor: o OPM **não garante** dado atual; o consumidor responde por conferir com o anúncio oficial (seção 10). Os termos **não exigem** remover vagas fechadas.
* Limites: 500 linhas por página, 10.000 por consulta; o OPM pode impor cotas sem aviso. Valor numérico de requisições por minuto: **NÃO CONFIRMADO**.
* Campos (doc): `MatchedObjectId` (id estável), `PositionURI`, `ApplyURI`, `PositionRemuneration` (mín/máx/período), `PositionLocation`, `ApplicationCloseDate`, `JobCategory`, `PositionSchedule`, `UserArea.Details`. Atualização: consulta de vagas abertas.
* **Teste HTTP:** sem chave → `401` (esperado). **Não consegui testar o formato real** porque exige chave grátis, e esta fase proíbe pedir credenciais.

### 3.2 Adzuna — cobertura ampla, regra de armazenamento omissa
* Doc: [Visão geral](https://developer.adzuna.com/overview), [Busca](https://developer.adzuna.com/docs/search), [Termos](https://developer.adzuna.com/docs/terms_of_service).
* **Termos (texto bruto conferido):** usos permitidos = publicar anúncios, publicar estimativas "Jobsworth", pesquisa pessoal/acadêmica. Rótulo **"Adzuna" ≥ 116×23 px com link** em cada anúncio. Limites padrão **25/min, 250/dia, 1.000/semana, 2.500/mês**; aumento pode ser pedido para quem publica anúncios.
* "Qualquer outro uso" comercial exige **14 dias de teste** só para validar cobertura, sem usar o dado "no formato original" nem em agregados (contagens, salários médios) em trabalho contínuo sem consentimento escrito.
* **Silêncio sobre cache/armazenamento.** Ao encerrar o contrato, é preciso "remover imediatamente" todo dado obtido do Adzuna **das páginas** do site. Isso é a única regra de retenção.
* Resposta (doc): `id`, `redirect_url`, `salary_min/max`, `salary_is_predicted`, `category`, `location`, `created`, `contract_type`, `title`, `company`, lat/long. **Só um trecho da descrição** ("snipped").
* Países: a documentação **não lista**. Fontes não oficiais convergem em 19 (US, GB, AU, DE, FR, IN, CA, NZ, ZA, PL, NL, IT, ES, AT, BE, BR, MX, SG, CH): **NÃO CONFIRMADO** oficialmente. Veja [SDK](https://cdn.jsdelivr.net/npm/adzuna-sdk@0.1.2/README.md) e [Apify](https://apify.com/thirdwatch/adzuna-jobs-scraper) como indícios, não como prova.
* **Teste HTTP:** sem chave → `400`. Formato real **não testado** (exige `app_id`/`app_key`).

### 3.3 Jobicy — melhor equilíbrio entre termos e acesso aberto
* Doc: [API e feed](https://jobicy.com/jobs-rss-feed) e, na Fase 5.2, o [README oficial](https://github.com/Jobicy/remote-jobs-api) lido por inteiro (ver "Correções da Fase 5.2" no topo). O aviso na própria resposta da API (crédito com link direto e botões de candidatura levando à URL original) também foi lido diretamente.
* Termos de uso justo: listagens podem ser usadas em "produtos, newsletters, ferramentas de pesquisa e produtos de IA" **sem permissão individual** para integrações normais; exige **crédito e link** para a fonte, manter a URL canônica do Jobicy e **não apresentar as vagas como suas**. O aviso na própria resposta pede também que os botões de candidatura levem à URL original do feed.
* Janela de **7 dias** e **atraso de 3 h**. Sincronização automática "no máximo 1 vez por hora". Sem cota publicada; 429 → esperar. Existe endpoint em lote `/api/v2/remote-jobs/status` (até **100 ids** por chamada) que diz `active`, `closed` ou `unknown`: **resolve expiração**.
* API comercial paga (Bearer, **US$ 0,01 por vaga nova** com URL direta do ATS) é opcional.

### 3.4 Remotive, Remote OK, Himalayas
* **Remotive** ([aviso legal na resposta](https://remotive.com/api/remote-jobs) e [repositório](https://github.com/remotive-com/remote-jobs-api)): máx. **4 consultas/dia**, >2/min bloqueia; **atraso de 24 h**; **proibido** enviar as vagas a terceiros como Jooble, Neuvoo, Google Jobs, LinkedIn Jobs; proibido usar para coletar e-mails; link para a vaga **e** menção ao Remotive. API privada paga a partir de US$ 5k/mês (texto do aviso).
* **Remote OK** (aviso na resposta de [remoteok.com/api](https://remoteok.com/api)): link com **follow** de volta e menção à fonte; **não usar o logo**. Termos completos: **NÃO CONFIRMADO**.
* **Himalayas** ([documentação](https://himalayas.app/docs/remote-jobs-api)): sem chave; `limit` máx. **20** na listagem; dado atualizado a cada **24 h**; **link visível para himalayas.app e menção** se exibir; 429 sob limite não publicado. **Nenhum termo** sobre armazenar, uso comercial ou espelho: o texto cita "espelho completo do feed" sem dizer se é permitido. Tratar como **NÃO CONFIRMADO**; o contato oficial é `hi@himalayas.app`.

### 3.5 Arbeitnow — termos se contradizem
* Doc: [API](https://www.arbeitnow.com/api/job-board-api), [Termos](https://www.arbeitnow.com/terms) (bruto conferido).
* A **seção 11** (API) só exige um link de volta e diz que a permissão pode ser revogada a qualquer momento.
* A **seção 2** (uso do site) permite uso "pessoal, não comercial, transitório" e **proíbe** uso comercial, exibição pública, cópia e "espelhar" em outro servidor. Não está claro se a seção 2 vale para o conteúdo da API.
* A própria resposta diz: "free public API… please do not abuse… linking back… you agree to the terms of service present on Arbeitnow.com". Isso remete aos termos que contêm a proibição.
* Veredito: **DEPENDE DE AUTORIZAÇÃO**. Perguntar ao autor por escrito antes de qualquer uso.

### 3.6 The Muse
* Doc: [API v2](https://www.themuse.com/developers/api/v2), [Termos](https://www.themuse.com/developers/api/v2/terms).
* Chave grátis: **3.600 req/h** com chave, **500/h** sem. Cabeçalhos `X-RateLimit-*` confirmados em teste.
* Termos: licença limitada, revogável, **link obrigatório** para o The Muse; **proíbe raspagem**, sublicenciar, clonar o conteúdo e usar o nome/logo; no encerramento é preciso **destruir cópias**. **Uso comercial não é nem permitido nem proibido** de forma expressa. Armazenamento só implícito ("o necessário para formatar e exibir").

### 3.7 ATS por empresa (Greenhouse, Lever, Ashby)
* **Greenhouse** ([docs](https://docs.greenhouse.io/job-board.html)): "Job Board data is publicly available", GET sem autenticação; `content=true` traz descrição; `pay_transparency=true` (vaga individual) traz faixa salarial. Sem termos de reuso e sem limite documentado. Estabilidade do `id`: **NÃO CONFIRMADO**.
* **Lever** ([README](https://github.com/lever/postings-api)): "Published postings are public and may be scraped by third parties". `applyUrl`, `workplaceType`, `country`, `salaryRange`. Limite só para POST de candidatura (2/s).
* **Ashby** ([docs](https://developers.ashbyhq.com/docs/public-job-posting-api)): `includeCompensation=true`; `isListed`, `workplaceType`, `applyUrl`. Sem termos nem limites.
* Todas exigem **curadoria de um slug por empresa**. Cobertura é por empregador, sem busca transversal. A decisão de republicar é **do empregador**, não do ATS: **NÃO CONFIRMADO**.

### 3.8 Serviços públicos de emprego
* **Suécia, JobSearch/JobStream** ([JobSearch](https://jobtechdev.se/en/components/jobsearch), [JobStream](https://www.jobtechdev.se/en/docs/apis/jobstream/)): descritas como **dado aberto** de uma unidade do serviço público de emprego. JobStream existe para quem quer uma cópia completa com eventos de publicação/remoção (resolve expiração). **Não achei o texto da licença** (não confirmei CC0; a alegação vem só de listagens de terceiros no Apify). Tratar a licença como **NÃO CONFIRMADA** até ler a página oficial de termos. O site `jobtechdev.se` não resolveu por DNS a partir desta máquina; a API sim.
* **France Travail** ([francetravail.io](https://francetravail.io)): fontes secundárias dizem conta grátis (OAuth2) + **contrato de licença de reuso**; contatos do empregador excluídos sem consentimento; teto de ~1.150 resultados por busca é só relato de terceiro. Página oficial só renderiza com JavaScript. **DEPENDE DE AUTORIZAÇÃO**.
* **Job Bank Canadá** ([conjunto de dados](https://open.canada.ca/data/dataset/ea639e28-c0fc-48bf-b5dd-b8899bd43072)): licença **Open Government Licence – Canada** (campo `license_title` da API CKAN, confirmado). Mas o CSV mensal tem 65 colunas **sem descrição, sem empresa e sem URL de candidatura** (cabeçalho lido por `Range`). É dado estatístico, **INCOMPATÍVEL** para listar vagas. Útil no máximo para um link externo.
* **Alemanha, Bundesagentur**: a documentação comunitária ([bundesAPI/jobsuche-api](https://github.com/bundesAPI/jobsuche-api)) afirma que a agência **não oferece API oficial**; a chave é um cabeçalho compartilhado. Sem termos. **NÃO CONFIRMADO**.
* **Noruega (NAV)**: o feed público antigo foi **descontinuado em 2024**, segundo o [catálogo oficial](https://data.norge.no/en/datasets/62409bc8-680d-3f70-98bf-d2f2beebaa50/api-navs-stillingsdatabase) (licença CC BY 4.0 nesse registro). Serviço atual existe, sem endpoint confirmado por mim.
* **EURES**: dado só para membros/parceiros ([Decisão 2017/1257](https://eur-lex.europa.eu/eli/dec_impl/2017/1257/oj/eng)). **INCOMPATÍVEL**; manter link externo.
* **Brasil**: não achei API pública do SINE/Emprega Brasil (só portal e painel) nem da Gupy para listar vagas (a API é de integração de clientes). **Portugal**: nada achado sobre API/dados abertos de ofertas do IEFP. Em ambos, **NÃO CONFIRMADO**.

---

## 4. Testes HTTP reais (somente leitura, 2026-10-09)

Todas as chamadas: `GET`, sem chave, uma por endpoint, `User-Agent` identificado, poucos itens, nada gravado no Supabase e nenhum conteúdo de vaga guardado. Foram feitas **duas** chamadas ao Remotive, abaixo do limite de 4/dia por uso real.

| Endpoint | HTTP | Observado |
|---|---|---|
| `remotive.com/api/remote-jobs?limit=3` | 200 | **17 vagas** no total (`total-job-count: 17`), `limit` ignorado; ids estáveis; `url` própria; salário em texto; `Cache-Control: no-store` |
| `remotive.com/api/remote-jobs/categories` | 200 | 30 categorias (`id`, `name`, `slug`) |
| `arbeitnow.com/api/job-board-api` | 200 | **325 vagas** numa página (2,4 MB); paginação `?page=` com `links.next`; `X-RateLimit-Limit: 50`; `Cache-Control: max-age=432000`; 32 de 325 remotas; campos `slug`, `title`, `company_name`, `location`, `remote`, `tags`, `job_types`, `created_at`, `url` |
| `jobicy.com/api/v2/remote-jobs?count=3` | 200 | `nextCursor`, `hasMore`, `lastUpdate`; campos `id`, `jobTitle`, `companyName`, `jobGeo`, `jobIndustry`, `jobType`, `jobLevel`, `salaryMin/Max/Currency/Period`, `url`, `pubDate` |
| `himalayas.app/jobs/api?limit=3` | 200 | `totalCount: 118.459` (valor informado pela API, não verificado); `nextCursor`; `guid`, `expiryDate`, `locationRestrictions`, `minSalary/maxSalary`, `currency`, `applicationLink`; `s-maxage=7200` |
| `remoteok.com/api` | 200 | 100 itens; primeiro item é o aviso legal |
| `themuse.com/api/public/jobs?page=1` | 200 | `total: 415.019`, 20 por página, 20.751 páginas; `X-Ratelimit-Limit: 500`; `locations`, `levels`, `refs.landing_page` |
| `boards-api.greenhouse.io/v1/boards/gitlab/jobs` | 200 | 218 vagas (154 KB sem descrição, ~700 B/vaga); `id`, `internal_job_id`, `absolute_url`, `first_published`, `updated_at`, `language`, `location.name`, `application_deadline` |
| `api.lever.co/v0/postings/leverdemo?limit=3` | 200 | `id` (uuid), `applyUrl`, `hostedUrl`, `country`, `workplaceType`, `salaryRange`, `createdAt`; `ETag` |
| `api.ashbyhq.com/posting-api/job-board/Ashby?includeCompensation=true` | 200 | 68 vagas, 2,2 MB (descrições HTML e texto); `id`, `jobUrl`, `applyUrl`, `isRemote`, `workplaceType`, `employmentType`, `publishedAt`, `compensation`; `Cache-Control: max-age=60` |
| `jobsearch.api.jobtechdev.se/search?q=nurse&limit=2` | 200 | `total`, `hits[]` com `id`, `headline`, `webpage_url`, `application_deadline`, `publication_date`, `removed`, `removed_date`, `workplace_address`, `occupation`, `salary_type`, `working_hours_type`; **sem chave**. Uma primeira tentativa com acento no `q` retornou 400 |
| `open.canada.ca/.../package_show` e CSV (`Range`) | 200 / 206 | licença OGL-Canadá; CSV UTF-16 tabulado de 65 colunas **sem descrição nem URL** |
| `api.adzuna.com/.../jobs/gb/search/1` | 400 | exige chave |
| `data.usajobs.gov/api/Search` | 401 | exige chave |

Não testei por falta de credenciais (e a fase proíbe pedi-las): Adzuna, USAJOBS, France Travail, Reed, Jooble, Careerjet, InfoJobs. Para eles o formato real continua **NÃO TESTADO**.

---

## 5. Arquitetura futura e encaixe no schema atual

Examinei [`20261008000000_init.sql`](../supabase/migrations/20261008000000_init.sql) e o contrato [`worker/src/types.ts`](../worker/src/types.ts). **Não proponho migration agora.** Os pontos abaixo são o que a Fase 5.2 precisa decidir.

### 5.1 O que o schema já cobre bem
`jobs` tem `source_id`, `external_id` (único por fonte), `company`, `title`, `description`, `country`, `city`, `language`, `work_mode`, `contract_type`, salário (mín, máx, moeda, período), `published_at`, `last_checked_at`, `original_url`, `apply_url`, `status` (`open`/`closed`/`unknown`), `geo_restrictions`, `fingerprint`, `canonical_url`, `isco08`. `job_sources` tem `attribution` e `can_redistribute`. `sync_runs` registra contagens sem carga útil.

### 5.2 Lacunas e tensões, em ordem de impacto
1. **RLS × licença:** `jobs_read` só libera vagas de fontes com `can_redistribute = true` e status `READY`/`CONDITIONAL`. Fontes com armazenamento **omisso** (Adzuna) ou **contraditório** (Arbeitnow) não devem ter `can_redistribute = true`. Resultado: ou o app consulta essas fontes **sob demanda pelo Worker, sem gravar**, ou se obtém autorização escrita primeiro. Recomendo o primeiro enquanto a resposta não vem.
2. **Expiração:** não há coluna de prazo de candidatura. Várias fontes trazem esse dado: USAJOBS `ApplicationCloseDate`, Himalayas `expiryDate`, Greenhouse `application_deadline`, Suécia `application_deadline`/`removed_date`. Candidato a coluna `expires_at` (anulável). **Só proponho; não é migration.**
3. **Salário previsto:** Adzuna marca `salary_is_predicted`. O schema não distingue salário informado de estimado; exibir estimativa como se fosse da vaga seria enganoso. Candidato a um indicador.
4. **Descrição parcial:** Adzuna entrega só um trecho. O app deve tratar `description` como possivelmente truncada e priorizar `original_url`/`apply_url`.
5. **Atribuição por vaga:** `job_sources.attribution` guarda um texto, mas Adzuna exige **rótulo com imagem ≥ 116×23 px e link**, Remotive/Jobicy/Himalayas/Remote OK exigem **link para a vaga na origem**. A UI precisa receber fonte + link por vaga (o `original_url` já ajuda).
6. **Unicidade de `external_id`:** todas as fontes testadas têm identificador próprio (`MatchedObjectId`, `id`, `slug`, `guid`, uuid). Arbeitnow usa `slug`, que pode mudar se o título mudar: validar.
7. **Dado pessoal:** Suécia e France Travail podem trazer telefone/e-mail do empregador (visto no campo `employer` do teste sueco). Descartar contatos no normalizador; `sync_runs` já não guarda carga útil.

### 5.3 Contrato comum e adaptadores
O `NormalizedJob` existente já espelha o schema. Cada fonte vira um `Connector` (`fetchPage(cursor, scope)`, `minIntervalMs`), como o conector Lever já escrito. Regras que o levantamento reforça:
* **Snapshot completo** só quando a fonte lista todas as abertas (Greenhouse, Lever, Ashby, Suécia/JobStream). Para Jobicy (janela de 7 dias) e Himalayas, ausência **não** significa fechada: usar o endpoint de status do Jobicy e `expiryDate`.
* **Dedup:** `fingerprint` + `canonical_url`. O mesmo emprego aparece em ATS e agregadores (Jobicy aponta para a própria página); preferir a URL do empregador quando houver.
* **Normalização:** país por ISO alfa-2 (Lever já dá `country`; Greenhouse/Jobicy dão texto livre → mapear); modalidade (`workplaceType`, `remote`, `isRemote`); moeda/período (Jobicy `yearly`, Himalayas `annual`, USAJOBS `Per Year` → `year`).
* **Rate limit:** limiter por conector com `minIntervalMs` = limite publicado (Adzuna 25/min ⇒ ≥ 2,4 s; Jobicy ≤ 1/h por varredura; Remotive ≤ 4/dia; Himalayas 1 vez/dia; The Muse 3.600/h). Backoff exponencial com `Retry-After` quando existir; 429 nunca é repetido de imediato.
* **Observabilidade:** `sync_runs` por execução (contagens, `http_errors`, `error_class`).

---

## 6. Custo de operação (somente dados oficiais; sem estimativa de tráfego)

| Item | Gratuito | Pago |
|---|---|---|
| [Cloudflare Workers](https://developers.cloudflare.com/workers/platform/pricing/) | 100.000 req/dia; **10 ms de CPU por invocação** | US$ 5/mês mínimo; 10 M req e 30 M ms de CPU incluídos; CPU até 5 min por invocação (padrão 30 s); cron/filas até 15 min; extras US$ 0,30 por milhão de req |
| [Supabase](https://supabase.com/pricing) | US$ 0; 500 MB de banco; 5 GB de egress; **projeto pausado após 1 semana de inatividade** | Pro a partir de US$ 25/mês; 8 GB de disco; 250 GB de egress |
| APIs das fontes | USAJOBS, Jobicy, Himalayas, Remotive, Suécia, Greenhouse/Lever/Ashby: US$ 0. Adzuna, The Muse: chave grátis | Jobicy comercial US$ 0,01 por vaga nova (opcional); Remotive privada a partir de US$ 5k/mês (não recomendado) |

Leituras que decorrem dos números oficiais e das medições deste relatório (aritmética, não previsão):
* **O plano gratuito do Workers dificilmente serve para ingestão:** 10 ms de CPU por invocação, e as respostas medidas têm de 154 KB a 2,4 MB de JSON. Interpretar um JSON de 2 MB provavelmente excede 10 ms (**não medi**). Para um cron de sincronização, o plano pago de US$ 5 é o piso realista.
* **Armazenar descrição completa pesa:** nas amostras, o JSON bruto por vaga foi de ~0,7 KB (Greenhouse sem descrição), ~7 KB (Arbeitnow, Himalayas), ~10 KB (Remotive), ~13 KB (Jobicy) e ~32 KB (Ashby, com HTML e texto duplicados). Se a descrição for guardada inteira, 500 MB comportam **dezenas de milhares** de vagas, e não centenas de milhares. Guardar só campos normalizados e um trecho da descrição reduz isso, e para o Adzuna o trecho já é o que a fonte entrega.
* **Pausa por inatividade:** no plano gratuito do Supabase, um app sem uso por uma semana pausa. Um cron do Worker tende a manter o projeto ativo, mas **não confirmei** como o Supabase conta a atividade.

---

## 7. Ranking

Notas de 0 a 5 (5 = melhor), com base apenas no que verifiquei. "Legal" mede a clareza de **armazenar e exibir**. "Credencial" 5 = nenhuma.

| Fonte | Legal | Cobertura geo | Cobertura profissional | Integração | Qualidade | Atualização | Custo | Credencial | Sustentabilidade | **Total /45** |
|---|---|---|---|---|---|---|---|---|---|---|
| **USAJOBS** | 5 | 1 | 5 | 4 | 4 | 4 | 5 | 3 | 5 | **36** |
| **Jobicy** | 4 | 3 | 3 | 5 | 4 | 4 | 5 | 5 | 3 | **36** |
| **Adzuna** | 2 | 4 | 5 | 4 | 3 | 4 | 4 | 3 | 4 | **33** |
| Suécia JobSearch | 3 | 1 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **39** *(licença a confirmar)* |
| Himalayas | 2 | 3 | 2 | 5 | 4 | 3 | 5 | 5 | 3 | **32** |
| Greenhouse/Lever/Ashby | 2 | 3 | 3 | 4 | 5 | 5 | 5 | 5 | 3 | **35** *(exige curadoria de slugs)* |
| The Muse | 3 | 2 | 3 | 4 | 4 | 3 | 4 | 3 | 3 | **29** |
| Remotive | 3 | 3 | 3 | 4 | 3 | 2 | 5 | 5 | 2 | **30** *(17 vagas hoje)* |
| France Travail | 2 | 1 | 5 | 3 | 4 | 4 | 4 | 2 | 4 | **29** |
| Arbeitnow | 1 | 1 | 3 | 4 | 3 | 5 | 5 | 5 | 2 | **29** |

A Suécia pontua mais por ser técnica e legalmente favorável, mas cobre **um país** e a licença não foi lida no texto oficial; por isso não é o MVP de um app que promete vários países. O ranking não substitui a decisão de produto: **quanto vale cobrir poucos países com segurança jurídica total versus muitos com o risco do armazenamento omisso**.

---

## 8. Recomendação

### MVP: **USAJOBS**
Única fonte em que li, em texto oficial, permissão expressa para **copiar, armazenar, redistribuir e usar comercialmente**, sem atribuição obrigatória e sem aprovação prévia. Cobre todas as profissões, traz faixa salarial, `ApplyURI` e data de encerramento (resolve a expiração). Tem identificador estável. **Limites:** só vagas federais dos EUA; exige **chave grátis** (que a fase proíbe pedir); formato real **ainda não testado** por esse motivo. Serve para validar de ponta a ponta o ciclo busca → favorito → candidatura manual com **vagas reais** e risco jurídico mínimo.

### Complementares
1. **Adzuna** (cobertura: 19 países não oficiais, inclui Brasil e ofícios). Só **consulta sob demanda via Worker**, com o rótulo exigido, **sem gravar em `jobs`**, até receber **autorização escrita** sobre armazenamento. Pedir também aumento do limite de 250/dia, porque o padrão é baixo para um catálogo.
2. **Jobicy** (remoto global). Permite uso em produtos com crédito e link, tem endpoint de status que resolve vagas fechadas e não exige chave. Janela de 7 dias, no máximo 1 varredura/hora.

### Expansão futura (depois de confirmar o que falta)
* **Suécia JobSearch/JobStream**: confirmar a licença no texto oficial; excelente para dado completo com remoções.
* **ATS por empresa** (Greenhouse, Lever, Ashby): bom para tecnologia e escritórios; exige lista curada de empresas e confirmação de que o empregador aceita a republicação.
* **France Travail**: depende de assinar a licença.
* **Himalayas**, **The Muse**: só após resposta por escrito sobre armazenamento/uso comercial.
* **Reed, InfoJobs, Jooble, Careerjet**: ler os termos depois de obter chave.

### A evitar ou manter só como link externo
* **Arbeitnow**: termos contraditórios, perguntar antes.
* **Remotive**: pouco volume hoje (17) e restrições pesadas; só vale se o volume voltar.
* **Job Bank (Canadá)**: dado estatístico, sem descrição nem URL; busca externa.
* **EURES**: dado restrito a membros; link externo.
* **Indeed, LinkedIn, ZipRecruiter, SEEK**: não reverifiquei nesta rodada; o levantamento anterior os marcou como `EXTERNAL_ONLY`, e raspagem não autorizada continua fora de cogitação.
* **Bundesagentur (DE)**: API não oficial; só com confirmação do órgão.

### Lacunas honestas
Brasil e Portugal **não têm fonte aberta confirmada**. Para o Brasil, o único caminho concreto hoje é Adzuna `br`, sujeito a chave. Prometer cobertura "mundial" no app seria incorreto.

---

## 9. Próximas etapas (aguardam sua autorização para iniciar a Fase 5.2)

1. **Você** pede as chaves grátis (USAJOBS, Adzuna) e guarda como segredo do Worker; **eu não peço nem recebo credenciais no chat**.
2. **Eu** envio um e-mail-modelo ao Adzuna perguntando por escrito: (a) armazenamento/cache dos resultados, (b) aumento de limite, (c) uso no app móvel. O mesmo para Arbeitnow e Himalayas, se quiser avançar.
3. Com as chaves: rodar os testes HTTP restantes (USAJOBS, Adzuna) e arquivar a evidência em `docs/evidence/`.
4. Fase 5.2 (somente após aval): conector USAJOBS + Jobicy com testes de fixtures reais anonimizadas, regras de expiração, limiter e `sync_runs`; **sem** aplicar a sexta migration e **sem** deploy até você autorizar cada um.
5. Decisão de produto pendente: para fontes sem permissão de armazenar, aceitar a **busca sob demanda** (sem catálogo local, sem favoritos persistentes dessas vagas) ou esperar autorização.

## 10. Itens que este relatório não afirma
* Cotas numéricas do USAJOBS, da Himalayas e do Arbeitnow além do que está citado.
* Lista oficial de países do Adzuna.
* Licença do JobSearch sueco e texto contratual do France Travail.
* Quantidade de vagas realmente úteis por país: os números de totais (Himalayas 118.459, The Muse 415.019) são **informados pelas APIs**, não auditados, e podem incluir vagas antigas.
