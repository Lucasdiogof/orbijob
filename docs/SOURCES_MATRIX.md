# Matriz de fontes de vagas (verificada em 2026-10-12)

> **Como ler:** só entram no catálogo armazenado as fontes cuja regra de uso foi lida **no texto primário** e permite exibir as vagas com atribuição e link de volta.
> "API acessível" não é licença. Evidência = o que foi realmente lido/medido nesta data; "pesquisa anterior" = `docs/SOURCES_TABLE.md` / `docs/PHASE_5_1_SOURCES_RESEARCH.md`, não relida hoje.
> Decisões: **INTEGRAR** (vagas armazenadas, com atribuição), **LINK/EXTERNA** (só link para o portal original), **NÃO INTEGRAR** (motivo registrado), **BLOQUEADA** (depende de conta/chave que só o proprietário pode criar).

## Integradas (armazenadas, com adapter, testes e execução real)

| Fonte | Endpoint oficial | Cobertura / profissões | Observado em 12/10 | Frequência | Chave | Limite | Licença e atribuição | Verificar vaga aberta | Decisão |
|---|---|---|---|---|---|---|---|---|---|
| **Jobicy** | `jobicy.com/api/v2/remote-jobs` (+ `/status`) | remoto global; todas as áreas, tecnologia predomina | feed 773 vagas / 7 dias | a cada passada | não | 1 passada/hora (README) | README "Fair Use": manter a fonte e a URL do anúncio; descrição em HTML sanitizada | **sim** (endpoint de status, até 100 ids) | **INTEGRADA** (699 vagas) |
| **Arbeitnow** | `arbeitnow.com/api/job-board-api?page=N` | Alemanha/Europa, presencial e remoto; **todas as áreas** (saúde, jurídico, ofícios, estudantes, tecnologia); vagas vindas de Greenhouse, SmartRecruiters, Join.com, Teamtailor, Recruitee, Comeet | 325 vagas na página 1, ≥ 18 páginas (≈ 2.100); o Cloudflare deles **desafiou a leitura rápida na página 19** | atualiza de hora em hora; ordenada por `created_at` | não | não documentado; desafio anti-bot em rajada | Termos §11 (API): "link back to Arbeitnow.com"; revogável. A resposta traz: "link back appreciated; ao usar a API você aceita os termos". Sem cláusula de armazenamento | não há: **estar no feed = aberta**; some do feed → expira em 7 dias | **INTEGRADA** (poucas páginas, ritmo de 1 req/4 s, para no primeiro desafio) |
| **Remote OK** | `remoteok.com/api` | remoto global; tecnologia, marketing, vendas, saúde, educação | 99 vagas (585 KB) | contínua | não | não documentado | aviso legal no feed: link de volta (follow) e crédito "Remote OK" como fonte; logo proibida sem permissão | não: estar no feed = aberta | **INTEGRADA** (sem logo; link da própria página Remote OK) |
| **Remotive** | `remotive.com/api/remote-jobs` | remoto global, 9 categorias (software, dados, IA, design, marketing, vendas, redação, TI) | 18 vagas (a API pública traz poucas) | atraso de 24 h; "no máximo 4 vezes ao dia" | não | > 2 req/min bloqueia | README: link de volta + citar Remotive, **senão encerram o acesso**; não enviar a terceiros (Jooble, Google Jobs, LinkedIn); não usar para captar cadastros/e-mails | não: estar no feed = aberta | **INTEGRADA** (1x/dia). Risco aceito e registrado: o app tem cadastro de usuário, mas a vaga não é usada para captar cadastro (a leitura do catálogo é pública) |

## Pesquisadas e NÃO integradas

| Fonte | O que foi lido | Por que não integrar agora | O que destrava |
|---|---|---|---|
| **Himalayas** (`himalayas.app/jobs/api`) | API gratuita, sem chave, 20/página, dados a cada 24 h, atribuição visível pedida. **Termos do site (cláusulas 2, 29, 30, 46, 93):** proíbem espelhar, copiar, republicar, "data mining"; "Himalayas is not a storage service"; reuso só com consentimento escrito | armazenar = espelhar | e-mail a `hi@himalayas.app` pedindo permissão de armazenar e exibir |
| **The Muse** (`themuse.com/api/public/jobs`) | 413.875 vagas, 20/página, **todas as áreas**, EUA. API v2 exige **registro para qualquer uso além de teste**; termos: exibir é permitido com link de volta, mas "may not clone Muse Content", sem scraping, nome/logo proibidos | clonar 413 mil vagas viola o termo; precisa de chave (conta) | chave criada pelo proprietário + arquitetura de consulta ao vivo (sem armazenar), ou autorização escrita (`api@themuse.com`) |
| **Adzuna** | pesquisa anterior: BR, MX, AR, e outros 15 países; app_id/app_key; "Jobs by Adzuna" obrigatório; 250 chamadas/dia | **BLOQUEADA**: exige cadastro (conta) | proprietário se cadastra em developer.adzuna.com e fornece as chaves como secret |
| **Jooble** | pesquisa anterior: chave sob solicitação; possível limite total | **BLOQUEADA** (chave) | pedido de chave pelo proprietário |
| **USAJOBS** | pesquisa anterior: chave gratuita + e-mail no `User-Agent`; 500 linhas/página | **BLOQUEADA** (chave); só EUA, setor público | chave pelo proprietário |
| **Reed.co.uk**, **France Travail** | pesquisa anterior: Reino Unido / França; chave ou OAuth após registro | **BLOQUEADAS** (conta) | registro pelo proprietário |
| **Job Bank Canada (dados abertos)** | CSV mensal sob Open Government Licence – Canada; campos NOC/NAICS | arquivos mensais de **vagas passadas**, sem como saber se ainda estão abertas | só serve a estatística (cobertura por profissão), não a catálogo ativo |
| **Greenhouse, Lever, Ashby, SmartRecruiters, Workable** (APIs públicas de quadro de vagas por empresa) | endpoints públicos por empresa; feitos para a página de carreiras do próprio empregador; sem termo de agregação | direito de redistribuir é de cada empregador; precisaria de lista de empresas e permissão | Arbeitnow já agrega parte dessas vagas com licença de API; lista curada + autorização por empregador |
| **Bundesagentur für Arbeit (Jobsuche)** | pesquisa anterior: API interna documentada pela comunidade, sem termos oficiais | sem licença | consulta formal à agência |
| **EURES, NHS Jobs, SEEK / JobStreet / JobsDB, Indeed, ZipRecruiter, LinkedIn** | pesquisa anterior: dados só para parceiros, sem API de busca, ou scraping proibido | EXTERNA: o app pode oferecer busca externa, nunca copiar | acordo de parceria |
| **Brasil / América Latina** (Gupy, Catho, InfoJobs BR, Vagas.com, Computrabajo, SINE/Emprega Brasil) | busca de hoje: **nenhuma API pública oficial de vagas** encontrada; os dados do SINE são acessíveis só por chamamento público com termo e certificado digital | sem fonte legal aberta | Adzuna/Jooble com chave (cobrem BR e MX) ou parceria; enquanto isso o Brasil aparece pelas vagas remotas abertas a LATAM/Brasil das fontes acima |

## Cobertura real do catálogo (o que a matriz entrega hoje)
* **Remoto global** (Jobicy, Remote OK, Remotive): predominantemente tecnologia, vendas, marketing e suporte; 54 de 699 vagas do Jobicy são utilizáveis do Brasil (país BR ou restrição BR/LATAM/Worldwide).
* **Presencial e híbrido, múltiplas profissões**: só a **Arbeitnow** (Alemanha/Europa, em alemão e inglês). Não há fonte gratuita legal aberta para Brasil, Ásia ou África: essa lacuna é documentada, não escondida.
* Países com vaga hoje: 31 (Jobicy) + a Alemanha e vizinhos (Arbeitnow, cidade sem país: o país **não é inferido**).

## Regras que valem para todas
* Atribuição em `job_sources.attribution` e link original em `original_url` (o app mostra "Fonte: …" e abre o anúncio original); sem logos de terceiros.
* Descrição reduzida a texto simples; e-mails pessoais mascarados; nada é traduzido.
* Nenhum scraping, nenhum desafio anti-bot contornado (um desafio encerra a passada como falha, sem repetir), nenhuma conta criada.
* Cada fonte nasce `CONDITIONAL` e **não publicada**; só `publish_source.sql` (com frase e verificações) publica depois de revisar a amostra.
* Teto de vagas **cheias** por fonte (`src/sources.ts`): Jobicy 4.000, Arbeitnow 1.500, Remote OK 300, Remotive 200 (total ≤ 6.000 ≈ 60–220 MB).
* Vaga que some do feed deixa de ser carimbada; o app a esconde em 72 h e `ops.expire_unseen_jobs` a fecha em 7 dias, só se a fonte teve passada `ok` nas últimas 36 h.

## Evidências lidas em 2026-10-12
README do Remotive (`github.com/remotive-com/remote-jobs-api`); termos da Arbeitnow (`arbeitnow.com/terms`, §11) e `meta.terms` da própria API; aviso legal do `remoteok.com/api`; documentação (`himalayas.app/docs/remote-jobs-api`) e termos (`himalayas.app/terms`) do Himalayas; `themuse.com/developers/api/v2` e `/terms`; busca sobre os dados abertos do Job Bank Canada e sobre APIs de vagas no Brasil. Medições: uma requisição a cada feed (Remotive 18, Remote OK 99, Arbeitnow 325 na página 1 e 18 páginas lidas antes do desafio do Cloudflare; The Muse página 0).

## Saúde e fisioterapia pélvica (pesquisado em 2026-10-12)

Nenhum portal especializado oferece API ou feed, e os termos lidos proíbem copiar as vagas para outro catálogo. Por isso **nada deles é armazenado**: o app só oferece um **link externo** para o próprio portal (Explorar → Saúde → "Portais especializados"; `app/lib/features/search/domain/specialty_portals.dart`), separado das vagas do catálogo.

| Portal | Vagas reais (12/10) | API/feed | Termos lidos | Decisão |
|---|---|---|---|---|
| Herman & Wallace Job Board | 10 vagas (17/09 a 08/10), posts de 30 dias | não | só "All Rights Reserved"; sem licença de reuso | **LINK** |
| APTA Pelvic Health Career Center (Momentive/YM Careers) | 441 vagas | não (só alerta por e-mail) | `/terms/`: "No party may aggregate, package, spider, collect, or display any of the content" sem consentimento escrito | **LINK** |
| Chartered Society of Physiotherapy (`csp.org.uk/jobs`) | sim (NHS, privado) | não | termos 3.2(4), 4.3, 4.4: proíbem copiar, extrair sistematicamente ou montar base com o conteúdo | **LINK** |
| CREFITO-5 (RS) | 68 oportunidades (jun–out/2026) | não | "todos os direitos reservados"; sem licença | **LINK** |
| CREFITO-11 (GO/DF) | mural de vagas não encontrado no site | não | — | nada a integrar |
| PCI Concursos (`/vagas/fisioterapeuta`) | sim (concursos) | não | página de termos não encontrada (404); sem licença | **LINK** |
| Indeed Brasil | sim | API só para parceiros | termos: uso pessoal; scraping e cópia permanente proibidos | **LINK** (busca pronta "fisioterapeuta em Goiânia") |
| Solutudo, demais CREFITOs, hospitais/ATS | — | — | ATS por empresa: direito é de cada empregador (ver Greenhouse/Lever acima) | não integrado |

**No catálogo armazenado (12/10):** 0 vagas de fisioterapia, 0 de fisioterapia pélvica, 0 em Goiás/Goiânia; 11 vagas com país Brasil e 18 elegíveis para candidatos do Brasil (todas remotas). O app mostra essas contagens com o valor real, inclusive zero.
