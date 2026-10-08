# OrbiJob — fontes globais de vagas: pesquisa, classificação e evidências

Status: **Fase 0, 2026-10-08.** Documento vivo. Tabela completa gerada em [`SOURCES_TABLE.md`](SOURCES_TABLE.md); matriz país × fonte em [`COVERAGE_MATRIX.md`](COVERAGE_MATRIX.md) e `data/coverage-matrix.csv`.

## 1. Resumo honesto
- **Nenhuma fonte está `READY`.** `READY` exige: licença/termos que autorizem armazenar e exibir, gratuidade, e **teste real passando**. O ambiente desta fase bloqueou (proxy de egress, HTTP 403/EGRESS_BLOCKED) praticamente todos os hosts de vagas e de documentação oficial (himalayas.app, jobicy.com, developers.greenhouse.io, developers.ashbyhq.com, developer.usajobs.gov, developer.adzuna.com e os endpoints das APIs). Só foi possível ler `github.com/lever/postings-api` e `github.com/remotive-com/remote-jobs-api` em texto primário, além de buscas web (resumos).
- Endpoint público **não** é autorização para republicar. Onde os termos não foram lidos, o status é `RESEARCH` ou `CONDITIONAL`, nunca `READY`.
- **Portais com API fechada para busca por terceiros** (Indeed, ZipRecruiter, LinkedIn, SEEK/JobStreet/JobsDB para busca) ficam como **busca externa** (deep link), sem scraping.
- Fontes ATS (Lever/Greenhouse/Ashby) funcionam **por empresa**, sem busca transversal. Elas cobrem sobretudo tecnologia/escritórios — **pouco úteis para pedreiro, pintor, motorista**. Para ofícios e saúde, as melhores apostas são **serviços públicos de emprego** (France Travail, Job Bank, USAJOBS) e agregadores com chave gratuita (Adzuna) — todos `CONDITIONAL`.

## 2. Classificação usada
`READY` (autorizada, gratuita, validada) · `CONDITIONAL` (depende de licença/chave/autorização/validação) · `EXTERNAL_ONLY` (só link para o portal) · `BLOCKED` (proibida/incompatível) · `RESEARCH` (não comprovada).
Decisões do proprietário aplicadas: EURES = `EXTERNAL_ONLY`; SEEK/JobStreet/JobsDB = `CONDITIONAL` (e, pela evidência, sem API de busca → não construir); Jooble não é fonte principal (`RESEARCH`).

## 3. Fontes por região (resumo)
| Região | Melhor candidato gratuito/oficial | Observação |
|---|---|---|
| América do Norte | USAJOBS (US, chave grátis), Job Bank Canada (CSV mensal), Adzuna (US/CA/MX) | Indeed/ZipRecruiter: externo |
| América do Sul/Central | Adzuna (BR/MX); Gupy, Catho, InfoJobs BR, Computrabajo, Bumeran | portais BR/LatAm: `RESEARCH` |
| Europa | France Travail (FR), Adzuna (GB/DE/FR/ES/IT/NL/PL/AT/BE/CH), Reed (GB), Bundesagentur (DE, sem API oficial) | EURES: externo |
| África | nenhuma API confirmada; Adzuna (ZA) | Jobberman, BrighterMonday, PNet, Careers24, MyJobMag, Fuzu, WUZZUF, Rekrute: `RESEARCH`, externo por padrão |
| Oriente Médio | nenhuma confirmada | Bayt, GulfTalent, Naukrigulf: `RESEARCH`, externo |
| Ásia | Adzuna (IN/SG) | JobStreet/JobsDB: parceiro SEEK; Naukri, Rikunabi, Mynavi, Wantedly, Saramin, JobKorea, 104, Glints, Boss Zhipin, MyCareersFuture: `RESEARCH` |
| Oceania | Adzuna (AU/NZ) | SEEK parceiro; Workforce Australia só estatística; Jora, Trade Me: `RESEARCH` |
| Remoto global | Remotive (restrições), Himalayas/Jobicy (`RESEARCH`), ATS por empresa | |

## 4. Critérios de aceite — resultado real (2026-10-08)
Executado `node scripts/acceptance.mjs` (evidência: `docs/evidence/acceptance-2026-10-08.json`).

| Busca | Resultado | Motivo | Alternativa externa |
|---|---|---|---|
| Flutter Developer — EUA | **NÃO EXECUTADA com fonte real** | rede bloqueada (403 do proxy); USAJOBS/Adzuna sem chave | us.indeed.com, LinkedIn |
| Fisioterapeuta pélvica — Alemanha | idem | idem; Bundesagentur `RESEARCH` | de.indeed.com |
| Pedreiro — Portugal | idem | **nenhuma fonte candidata cobre PT** além de ATS/remoto | pt.indeed.com (+ IEFP: pesquisar) |
| Pintor residencial — Austrália | idem | Adzuna AU `CONDITIONAL` (sem chave) | au.indeed.com, SEEK |
| Enfermeiro — Canadá | idem | Job Bank é CSV mensal; Adzuna CA sem chave | ca.indeed.com, Job Bank |
| Eletricista — África do Sul | idem | só Adzuna ZA (sem chave) | za.indeed.com |
| Professor — Singapura | idem | Adzuna SG (sem chave); MyCareersFuture `RESEARCH` | sg.indeed.com |
| Motorista — Emirados | idem | **nenhuma fonte candidata** | ae.indeed.com, Bayt |

**Nenhum resultado foi fabricado.** O app exibe "sem fonte integrada" + busca externa nesses casos (comportamento já implementado e testado em `SearchCubit`). Para rodar de verdade: execute o script numa máquina com internet e com `USAJOBS_KEY`, `USAJOBS_EMAIL`, `ADZUNA_APP_ID`, `ADZUNA_APP_KEY`; anexe o JSON em `docs/evidence/` e só então promova fontes a `READY`.

## 5. Estratégia de atualização
Por fonte: sincronização incremental (cursor/`updated_since` quando existir; senão, varredura periódica respeitando limites); retry com backoff; um `RateLimiter` por conector (`worker/src/http.ts`); vaga só é marcada `closed` quando há **snapshot completo** da fonte (`shouldMarkClosed`); desaparecer de feed "recentes" não encerra a vaga. Frequência inicial: ≤ limites publicados (ex.: Remotive ≤ 4/dia; Adzuna ≤ 250/dia).

## 6. Riscos
Termos mudam sem aviso; cobertura de ofícios é baixa em APIs gratuitas; ATS por empresa exige curadoria de slugs; atribuição obrigatória (Adzuna, Remotive) afeta UI; dados pessoais em vagas (contatos) devem ser descartados (France Travail exclui contatos); cobertura "mundial" **não** pode ser prometida.

## 7. Próximos passos
1. Obter chaves gratuitas (USAJOBS, Adzuna, France Travail) — **ação humana/aprovação**.
2. Rodar `scripts/acceptance.mjs` com internet; arquivar evidências.
3. Ler termos oficiais dos `RESEARCH`/`CONDITIONAL` (Himalayas, Jobicy, Greenhouse, Ashby, Reed, Adzuna caching) e registrar.
4. Investigar serviços públicos de emprego: IEFP (PT), SAPS/ZA, MyCareersFuture (SG), Bayt (AE), Job Bank (CA) etc.
5. Implementar apenas conectores promovidos a `READY`.
