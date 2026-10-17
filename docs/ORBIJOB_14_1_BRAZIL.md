# OrbiJob 14.1 — Operação Brasil (2026-10-17)

Rodada delimitada: cobertura de vagas no Brasil, com atenção a Flutter/Dart/mobile e fisioterapia pélvica, sem alterar o caráter global do app. Evidências de fontes: [SOURCES_14_0.md](SOURCES_14_0.md) (rodada anterior) e as tabelas abaixo. Estado do produto: [ORBIJOB_MASTER_CHECKLIST.md](ORBIJOB_MASTER_CHECKLIST.md).

## 1. Linha de base (medida antes de qualquer mudança, chave pública, mesma visibilidade do app)
Scripts de leitura: `scripts/brazil-baseline.mjs`, `scripts/brazil-links-check.mjs`. 20 fontes habilitadas (Calgary publicada pelo dono, 55 vagas).

| | Valor |
|---|---|
| Vagas visíveis no total | 27.047 |
| **Visíveis com país Brasil (sediadas no país)** | **13** (jobicy 12, getonboard 1; 12 remotas sem cidade, 1 híbrida "Brasília, São Paulo") |
| Remotas de fora que aceitam candidatos do Brasil, **com evidência explícita** na própria vaga | **109**: 9 dizem Brasil (`BR`), 59 dizem LATAM, 41 são "Anywhere/Worldwide" remoto (jobicy 90, remoteok 10, remotive 9). Uma vaga que só diz "remote" não entra |
| Flutter/Dart **no título** (Brasil + elegíveis) | **0** |
| Flutter/Dart só na descrição (elegíveis) | 3 (Remotive/Lemon.io, vagas de full-stack/dados que citam Flutter entre muitas tecnologias) |
| "Mobile" no título (elegíveis) | 2 |
| Flutter no título no catálogo inteiro (qualquer país) | 5: 3 do Get on Board (sem país, remotas, sem elegibilidade informada), 1 Arbeitnow (NL), 1 Get on Board (CL, híbrida) |
| Fisioterapia no título, Brasil | 0 (no catálogo inteiro há ≈ 290 vagas de fisioterapia: Suécia, Reino Unido, Alemanha…) |
| **Fisioterapia pélvica explícita (título ou descrição) no catálogo inteiro** | **0** |
| Duplicadas no conjunto brasileiro | 0 por URL, 0 por título+empresa |
| Links inválidos (122 links brasileiros e elegíveis, 1 GET cada) | 5 respondem 404 (4,1 %): 4 do Jobicy conferidas há 2–3 dias (dentro da janela de 72 h; a próxima revalidação as retira) e 1 do Remotive que a fonte ainda lista mas cuja página saiu do ar; 0 bloqueios |
| Encerradas | por construção só são visíveis vagas confirmadas na fonte nas últimas 72 h |

Não há meta numérica inventada nem vaga simulada: o número que existe é o da tabela.

## 2. Pesquisa de fontes brasileiras — o que foi lido e decidido
| Candidato | O que foi comprovado | Decisão |
|---|---|---|
| **SINE-ES** — Agências do Trabalhador do Espírito Santo (SETADES), conjunto "Vagas das agências estaduais do trabalhador" em dados.es.gov.br | CKAN, licença **Creative Commons Atribuição**, 11 CSVs reescritos toda madrugada, oito colunas idênticas; 356 linhas, 2.131 postos; **dados atuais**. Sem nome do empregador, sem link por vaga, descrição = texto padrão da ocupação (CBO) | **INTEGRADA, não publicada** (§3) |
| Prefeitura de BH — "Vagas ofertadas PBH" (Sine BH, CC BY) | Planilhas **trimestrais** (jul–set/2026 etc.), sem como saber se a vaga ainda está aberta, sem link | NÃO integrada (sem frescor verificável) |
| Governo de Goiás — "Concursos e Processos Seletivos" (SEAD) | Estatísticas de certames (inscritos, aprovados), não vagas | NÃO integrada |
| Recife — "Postos do Sistema Público de Emprego" | Endereços dos postos | NÃO integrada |
| dados.gov.br (catálogo federal, MTE) | A API responde **401**: exige chave de API (login gov.br) | **Dependência do dono** (§8); busca na web não achou conjunto de vagas individuais do SINE/Emprega Brasil |
| Emprega Brasil / SINE nacional | Vagas só no portal (login gov.br) | Sem dado aberto localizado |
| EBSERH / HU Brasil (hospitais universitários federais) | Contratação por **concurso público** (a EBSERH já usou a especialidade "Fisioterapia na Saúde da Mulher" em 2023 e 2025); página oficial de concursos existe; **não há edital de 2026 localizado**; sem feed | **Link externo** na lista de portais de fisioterapia do app (página oficial `gov.br/hubrasil`) |
| Gupy (portal e páginas de vagas das empresas) | `robots.txt` permissivo, mas **sem licença de armazenamento/republicação** nem API documentada; o endpoint que o portal usa devolveu 404 e não foi forçado | NÃO integrada; pedido de parceria no §8 |
| Remotar | Termos de uso proíbem "mecanismos, software ou scripts", "Robot/Crawler", reprodução dos conteúdos | BLOQUEADA |
| Coodesh | Termos: proíbem "bots, scripts ou meios automatizados" sem autorização prévia | BLOQUEADA |
| GeekHunter | Termos proíbem copiar/extrair; `robots.txt` bloqueia crawlers de IA | BLOQUEADA |
| Programathor, Solides, Vagas.com, Catho, InfoJobs BR, BNE | Termos ilegíveis sem navegador (404/403) ou sem licença; `robots.txt` restritivos (Catho 32 regras, InfoJobs 66) | NÃO integradas (sem permissão comprovada) |
| Trampos.co | Termos (§2.5) proíbem robôs e cópia | BLOQUEADA (já era, 6.0) |
| Quadros comunitários no GitHub (`frontendbr`, `backend-br`, `androiddevbr`, `flutterbr`/vagas) | MIT cobre o repositório, não as issues dos terceiros; **0 issues abertas citam Flutter** em frontendbr, backend-br e androiddevbr; flutterbr tem 1, parada desde 2022 | NÃO integrados (volume nulo e licença das issues não é do repositório) |
| Open Jobs CC0 (export de ~7,6 milhões de vagas) | O serviço **foi encerrado em 10/10/2026**; o último export é de 05/10 (sem frescor honesto) | Descartado |
| Greenhouse / Lever / Ashby / SmartRecruiters / Gupy por empregador | Acesso público não comprova direito de armazenar/republicar; o direito é do empregador | Só com autorização por empresa (rascunho em `docs/EMPLOYER_FEED_PERMISSION.md`, nada enviado) |

## 3. Fonte integrada: SINE-ES (`sinees`) — armazenada, **não publicada**
* Conector `worker/src/connectors/sinees.ts`, testes com amostras reais (`worker/test/sinees.test.ts`, 11 casos + fixtures dos CSVs reais), agendamento diário 09:20 UTC, linha da fonte `CONDITIONAL`, `can_redistribute=false`.
* Passada real (workflow, 17/10): 331 linhas lidas, **309 vagas armazenadas**, 9 agências (Anchieta 5, Nova Venécia 41, Cachoeiro de Itapemirim 45, Linhares 23, São Mateus 67, Aracruz 43, Cariacica 61, Barra de São Francisco 23, Guarapari 13); 309 URLs distintas.
* Fica de fora, com motivo: 10 linhas sem código de vaga (Colatina publica o **código da ocupação** CBO, como `7170-20`, no lugar do código da vaga; 1 linha em branco em São Mateus), e 25 linhas de Marataízes sem atualização há mais de 21 dias.
* **Nada inventado**: empresa vazia (a atribuição diz "The SINE does not name the employer"), sem data de publicação (a data do arquivo é "atualizada em", mostrada na descrição), sem salário, sem modalidade. Quantidade em branco conta como 1 vaga (regra que a própria SETADES declara na página).
* **Link**: a página oficial da SETADES que lista essas vagas por agência (`https://setades.es.gov.br/vagas-de-empregos`, um visualizador do mesmo conjunto); `#/vaga/<código>` só mantém a URL distinta (o catálogo deduplica por URL canônica e descarta fragmentos, exceto os do tipo rota — descoberto na primeira simulação, em que 318 das 331 vagas colapsaram numa só; corrigido e testado). O candidato se apresenta na Agência do Trabalhador citada na vaga.
* **Decisão do dono antes de publicar** (o arquivo explica no cabeçalho): sem nome de empresa e sem link individual, o valor da vaga é menor que o de um anúncio completo. Publicar traz 309 vagas de ocupações comuns (auxiliar de produção, açougueiro, ajudante de carga, vendedor, auxiliar administrativo…) para um estado onde o catálogo hoje tem 0. Arquivo: `_aplicar/2026-10-17_14_1_brasil/01_publicar_sinees.sql` (trava ensaiada em transação revertida: passa; `can_redistribute` continua falso).
* Depois de publicar: Brasil visível passa de 13 para 322.

## 4. Flutter / Dart / Mobile — o que a pesquisa mostra
* **Catálogo**: 5 vagas com Flutter no título no mundo todo, 0 no Brasil, 0 elegíveis a brasileiros no título. Não há vaga Flutter "brasileira" licenciada para armazenar.
* **Onde elas estão** (e por que não entram): Gupy, LinkedIn, Remotar, Coodesh, GeekHunter, Programathor, Vagas.com, Indeed, páginas de carreira dos empregadores. Todas fecharam a porta a robôs nos termos ou não têm licença de republicação (§2). Os quadros comunitários abertos no GitHub têm zero Flutter hoje.
* Não se copiou nenhuma vaga dessas páginas e nenhuma foi cadastrada à mão.
* **Caminhos de autorização**: (1) pedido de parceria/feed à Gupy (rascunho §8); (2) pedido à Remotar/Coodesh (mesmo modelo); (3) empregadores brasileiros de tecnologia com página de carreira que aceitem ser listados (rascunho existente de 13.0); (4) as fontes remotas globais que já alimentam o catálogo (Jobicy, Remote OK, Remotive, Get on Board) continuam trazendo as raras vagas Flutter elegíveis, com a elegibilidade explícita preservada.
* Vagas de React Native, Kotlin ou Swift **não** são tratadas como Flutter: "Flutter" só vale quando está no título (ou, para o modo amplo da busca, no texto), e "mobile" continua um qualificador obrigatório separado.

## 5. Fisioterapia pélvica
* **0 vagas com especialidade pélvica explícita** no catálogo inteiro (título ou descrição), 0 no Brasil. As ≈ 290 vagas de fisioterapia do catálogo são gerais ou de outras áreas; nenhuma é apresentada como pélvica. A busca preserva a distinção (§6).
* O app já separa os três níveis pedidos: filtro de especialidade (pélvica explícita) × fisioterapia geral × outras, e a lista de **portais externos** (links, nunca vagas armazenadas: Indeed Brasil "fisioterapia pélvica", PCI Concursos, CREFITO-5, Herman & Wallace, APTA Pelvic Health, CSP). Nesta rodada entrou o link oficial dos **hospitais universitários federais** (`gov.br/hubrasil`, concursos e seleções), que já ofereceram a especialidade "Fisioterapia na Saúde da Mulher".
* Onde estão as vagas reais (e a barreira): hospitais e maternidades com ATS próprio, clínicas especializadas, concursos da EBSERH, portais de classe (CREFITO). Todos "todos os direitos reservados" ou sem licença (ver `docs/SOURCES_MATRIX.md`). Sem permissão por escrito não entram.
* Não se confunde com ginecologista, enfermagem obstétrica, pilates ou educação física: os testes novos garantem que "Ginecologista" e "Enfermeira Obstetra" não casam com nenhuma alternativa de uma busca pélvica ou de saúde da mulher.

## 6. Busca em PT-BR: medido antes e depois
Benchmark `scripts/search-benchmark.queries.br.json` (26 consultas) na API pública, mais `search-timing.mjs` (tempo da página que o app pede, sem contagem exata). Commits `eb98272` e `2c8bc52`.

| Antes → depois | |
|---|---|
| `programador dart` | 0 alternativas → 8 (dart exigido em todas) |
| `desenvolvedor de aplicativos` | exigia "aplicativos" no título (0 resultados) → nomes inteiros (app developer, Appentwickler, apputvecklare, desarrollador de aplicaciones…): 3 |
| `desenvolvedor flutter` | frase adjacente só: não achava "Desenvolvedor(a) Flutter" nem "Flutter Senior Developer" → também a conjunção das palavras digitadas; `flutter developer` 1 → 4 |
| `fisioterapeuta pélvica` / `pelvic floor physiotherapist` | 0 resultados (honesto: não há vaga); a conjunção das palavras digitadas passou a casar "Pelvic Health Physiotherapist" também para quem escreve "pelvic floor" |
| `programador` | sem equivalentes → programmer / developer / desenvolvedor / Entwickler |
| Consultas antigas (74 + 70 + 38) | apenas as que dependem desses grupos mudaram; total de resultados da série principal 24.465 → 24.304 (catálogo mudou), sem queda por consulta |
* **Precisão preservada** (testes `app/test/search/brazil_search_test.dart`): toda alternativa de uma busca pélvica é "pélvica **e** fisioterapia" (nunca "toda fisioterapia"); uma busca Flutter nunca oferece "developer" sozinho; "mobile" continua exigido em "desenvolvedor/engenheiro mobile"; "floor" não vira qualificador de "pelvic floor".
* **Paridade Flutter ↔ SQL** (alertas e buscas salvas): golden `worker/test/fixtures/v3-specs.golden.json` regenerado, 11 casos passam no Dart e no Worker; golden das requisições ao PostgREST regenerado (`catalog_requests.golden.json`), revalidado no CI `catalog-postgrest`.
* **Desempenho**: pior caso 1,3–1,8 s (fisioterapia pélvica, 28 alternativas) em 209 consultas, nenhuma acima de 3 s nem com falha; a contagem exata da mesma consulta estoura o `statement_timeout` (o benchmark agora registra `-1` em vez de falhar). O limite de alternativas continua 40.
* Limites documentados, **não** alterados: o qualificador acentuado "sênior" não casa com "Senior" em inglês (dois grupos de qualificadores diluiriam a precisão); termos sem acento digitados contra títulos acentuados dependem das alternativas (`medico` abre o grupo de `médico`, mas uma palavra fora de grupo, como `reabilitacao`, não é normalizada no banco — exigiria `unaccent` nas colunas e paridade no SQL dos alertas); "reabilitação perineal" não tem equivalente porque isso dobraria o produto cruzado fisioterapia × pélvica acima do limite e o catálogo tem 0 vagas.

## 7. Qualidade e privacidade (dados brasileiros)
* Achado real: telefones brasileiros com DDD **não eram mascarados** (`(62) 99999-9999`, `62 9 9999-9999`, `(62) 3333-4444` passavam) e o **CPF** também não. Corrigido no ponto único de armazenamento (`phones.ts`, `description.ts`, commit `9c3ad46`): celular com DDD (nove dígitos começando em 9) sempre mascarado; fixo mascarado quando há pessoa citada ou nada indica linha da empresa, **mantido** quando é central/recepção/SAC/prefeitura ("Ligue para a central: (62) 3333-4444"); CPF formatado e onze dígitos depois da palavra CPF viram `[CPF]`. Intactos: CNPJ, CBO, CEP, datas, horários, valores em R$, referências, sequência solta de onze dígitos (pode ser PIS). 7 testes novos (`worker/test/phones-br.test.ts`).
* Auditoria pública das **27.047** vagas visíveis com a regra nova: **0** ocorrências restantes → **nenhum backfill necessário** (o de privacidade da fase anterior não foi reexecutado).
* As 309 vagas do SINE-ES não têm telefone, e-mail, CPF nem nome de pessoa (varredura nos 11 CSVs: 0 padrões).

## 8. Dependências externas e rascunhos (NADA foi enviado)
1. **Chave da API do dados.gov.br** (dono): entrar com a conta gov.br em `https://dados.gov.br` → perfil → "Token/Chave de API". Com ela, procurar conjuntos de vagas do MTE/SINE e de órgãos federais; sem ela a API devolve 401.
2. **SETADES-ES** (opcional): perguntar se existe link por vaga ou por código na plataforma deles e se podem informar a empresa quando for pública. Rascunho: "Prezados, o OrbiJob (Lucksrei) exibe, com atribuição e sob a licença CC BY, as vagas do conjunto 'Vagas das agências estaduais do trabalhador'. Há uma forma de apontar cada código de vaga para uma página própria (ou parâmetro da página de vagas)? Para a agência de Colatina o campo 'código da vaga' traz o código CBO da ocupação; é possível publicar o código real da vaga? Contato: marketing@lucksrei.com".
3. **Gupy** (parceria): "O OrbiJob é um aplicativo gratuito de busca de vagas em vários países. Gostaríamos de exibir, com link de volta para a página oficial da vaga e atribuição à Gupy e à empresa, vagas públicas das empresas que autorizarem. Existe um programa de parceiros, um feed ou termos que permitam armazenar título, descrição, local e link das vagas publicadas nas páginas públicas? Não faremos coleta sem autorização. Contato: marketing@lucksrei.com".
4. **Remotar / Coodesh / GeekHunter**: mesmo texto, citando a cláusula dos termos que hoje impede (robôs/cópia) e pedindo autorização específica para exibir título + link (nada de descrição completa).
5. **Empregadores brasileiros** (tecnologia, hospitais, maternidades, redes de clínicas): modelo de `docs/EMPLOYER_FEED_PERMISSION.md`, a ser adaptado e enviado pelo dono. Nada enviado.

## 9. Testes e CI
Worker 979 passaram (+39 de rede ignorados), `tsc` limpo; Flutter 1.018 passaram (+94 ignorados), `flutter analyze` limpo; golden Dart/SQL e golden do PostgREST regenerados; CI verde nos commits `eb98272`, `1c07f73` e `a4b4679` (os posteriores estão listados no relatório final). Banco 283 MB de 500 MB, 29.504 linhas.

## 10. Conclusão objetiva
* **Possível melhorar**: busca para os termos brasileiros (programador, desenvolvedor de aplicativos, palavras digitadas em ordem diferente, pélvica sem virar toda fisioterapia), privacidade brasileira (DDD e CPF, que estavam abertos), primeira fonte brasileira real (SINE-ES, 309 vagas, aguardando a sua decisão), link oficial de concursos de hospitais universitários para fisioterapia (inclui saúde da mulher), linha de base reprodutível.
* **Ainda exige acordos ou novas fontes**: qualquer vaga Flutter brasileira (hoje 0) e qualquer vaga de fisioterapia pélvica (hoje 0 no catálogo inteiro) estão em plataformas e empregadores sem licença de republicação; o caminho é permissão escrita (§8) ou a chave do dados.gov.br para os dados federais. Sem isso, o app mostra o zero com honestidade e leva a pessoa aos portais, sem copiar nada.
