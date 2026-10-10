# Flutter × catálogo de vagas (Fase 5.3)

Estado: **implementado e testado localmente (mocks e fixtures); não validado contra o Supabase hospedado**, porque o catálogo hospedado está vazio e esta fase não grava nada lá. Enquanto não houver vagas ingeridas, a tela Explorar mostra "sem vagas" ou "sem fonte integrada" (conforme existir ou não uma fonte autorizada), nunca vagas inventadas.

Relação com o PR #50 (ingestão Jobicy no Worker): **nenhuma dependência de código**. O Flutter só lê `public.jobs`/`public.job_sources`. O que o PR #50 grava (`jobs.source_id`, `geo_restrictions`, `description` em texto, `original_url`…) é o que esta fase sabe ler. Detalhes do lado do Worker: `docs/JOBICY_INGESTION.md`, que chega com o PR #50.

## Arquitetura

```
SearchPage (Explorar) ─ SearchCubit ─ SearchRepository (interface, domain)
   filtros: SearchFiltersPanel         ├─ SupabaseJobCatalogRepository   ← app com configuração Supabase
   favoritos: FavoritesCubit           ├─ NoSourceSearchRepository       ← app sem configuração ("sem fonte integrada")
                                       └─ PreviewSearchRepository        ← só previews/testes (dados ilustrativos)
```

* `core/di/injector.dart`: sem repositório injetado, o app com Supabase registra `SupabaseJobCatalogRepository(client)` (mesmo padrão dos outros repositórios); sem configuração, a busca usa `NoSourceSearchRepository`. Previews e testes continuam trocando o repositório.
* Chave: **publishable** do cliente Supabase existente. Nenhuma `service_role`; `app_config.dart` continua rejeitando chaves secretas na inicialização.
* Modelos reaproveitados: `JobPosting`, `ScoredJob`, `SearchResult`. Acrescentados `JobPosting.geoRestrictions` e `JobPosting.description` (opcionais), `SearchResult.hasMore`/`consumed` e `JobFilters`.

## O que a consulta faz (`supabase_job_catalog_repository.dart`)

| Ponto | Implementação |
|---|---|
| Fonte autorizada | `select … job_sources!inner(…)` + `job_sources.can_redistribute = true` + `job_sources.status in (READY, CONDITIONAL)`. É a mesma regra da política RLS `jobs_read`, repetida no cliente como segunda camada. Linhas de fonte não autorizada que chegassem mesmo assim são descartadas no mapeamento |
| Vagas ativas | `status = 'open'`; linhas `closed`/`unknown` são descartadas também no mapeamento |
| Texto | `or=(search.wfts(simple).<termo>,title.ilike.*<termo>*)`: coluna `search` gerada (título, empresa, descrição) **ou** trecho do título (índice trigrama). O termo é sanitizado (só letras, dígitos, espaço, `+`, `#`, `-`), então o texto do usuário não consegue alterar a estrutura do filtro |
| Modalidade | `work_mode in (remote, hybrid, onsite)` |
| Data | `published_at >= agora − N dias` (1, 7 ou 30) |
| Salário | "só com salário": exige valor, moeda e período |
| País | `country = X` **ou** `X` em `geo_restrictions` **ou** vaga remota sem país e sem restrição ("de qualquer lugar"). Regiões (EMEA, Europe) **não** são expandidas em países, logo não casam |
| Ordem | `published_at desc nulls last, id desc` (o `id` desempata, então páginas não se sobrepõem) |
| Paginação | `range(offset, offset + limite)`: pede uma linha a mais para saber se existe próxima página. `consumed` conta as linhas do servidor (inclusive as descartadas por inválidas) e é o que avança o `offset` |
| Catálogo vazio | se a primeira página vem vazia, consulta `job_sources`: sem fonte autorizada → "sem fonte integrada"; com fonte → "nenhuma vaga" |

**Filtros que não existem de propósito:** profissão (a coluna `isco08` está vazia nas fontes atuais) e faixa salarial numérica (valores em moedas e períodos diferentes não são comparáveis). Oferecer esses filtros seria prometer algo que o schema não responde.

### Validação de cada linha (`jobFromCatalogRow`)
Vaga só aparece se tiver fonte autorizada, status aberto, id da fonte, id externo, título e **link http(s) válido** (`javascript:`, `data:`, caminho relativo e lixo são rejeitados). Link de candidatura inválido vira `null`. Salário só é montado se valor, moeda (3 letras maiúsculas) e período forem válidos e `min ≤ max`; senão nada é mostrado. Empresa pode ser vazia (algumas fontes omitem) e não é inventada. Restrições geográficas (códigos, regiões, nomes como a fonte escreveu) são preservadas.

## Experiência (Explorar)

* Estados: carregando (esqueleto), **vazio** (com ou sem filtros), **sem fonte integrada**, **erro com "Tentar de novo"** (repete a mesma busca e filtros), sucesso.
* **Ver vagas recentes**: lista as mais novas sem digitar nada.
* **Filtros** (botão com contagem, painel recolhível, chips): modalidade, publicação, "só com salário" e, se o perfil tiver países de interesse, país. Um país ativo continua visível e removível mesmo se a conta não o listar (troca de conta). Vazio sob filtros oferece "Limpar filtros".
* **Mostrar mais**: carregamento incremental por botão. O cabeçalho diz "Mostrando N vagas" enquanto existir próxima página e só vira "N resultados" quando a lista está completa: **nenhum total do catálogo é inventado**. Falha ao carregar mais mantém o que já estava e oferece repetir. Uma resposta atrasada de uma busca anterior é descartada.
* Cartão: título, empresa (omitida se vazia), local ou, para remota sem local, a elegibilidade (`CA, US`), modalidade, salário (só se válido), data e **"Fonte: Jobicy"**.
* Detalhe: descrição em texto simples, "Aberta a candidatos em: …", fonte e botão **Abrir anúncio original** (URL canônica da fonte; se não abrir, mensagem em vez de silêncio).
* PT/EN/ES: 17 textos novos nos três `.arb`, com teste de paridade já existente.

## Favoritos

Reaproveitam `FavoritesCubit` e `SupabaseFavoritesRepository`: a chave é `fonte:id` (`jobicy:154956`), gravada por `upsert` em `(user_id, job_key)` (sem duplicar). O snapshot guarda fonte, link, local, salário, data e `geoRestrictions`, **sem a descrição**: a tabela limita o snapshot a 16 KB e a descrição pode ser maior. Corrigido nesta fase: uma vaga **sem nome de empresa** era descartada ao ser relida dos favoritos; agora é preservada. Favoritos continuam por usuário (RLS); a troca de conta A→B recria os Cubits e B não vê nada de A.

## Testes (mocks e fixtures, nenhum remoto)

| Arquivo | O que cobre |
|---|---|
| `test/supabase/job_catalog_test.dart` (33) | forma exata da consulta, chave publishable, ordem, offset/limite, sanitização do texto, cada filtro, paginação, catálogo vazio × sem fonte, fonte não autorizada, vagas fechadas, links inválidos, dados incompletos, salário inconsistente, erros HTTP |
| `test/features/search_catalog_cubit_test.dart` (16) | paginação, offset com linhas puladas, duplicadas entre páginas, toque duplo, falha ao carregar mais, filtros, ordem de respostas, retry, vazio/sem fonte |
| `test/features/search_catalog_ui_test.dart` (17) | cartão (fonte, salário, elegibilidade), ver recentes, mostrar mais, filtros, vazio sob filtros, erro com retry, detalhe e link (abre/não abre), favoritos e reabertura, **troca de conta**, PT/ES, tela estreita com texto grande |
| `test/supabase/catalog_favorites_test.dart` (9) | snapshot de vaga do catálogo, limite de 16 KB, upsert sem duplicar, releitura, empresa vazia, remoção escopada, sem sessão |

Rodam: `flutter analyze` (sem problemas), `dart format` (sem alterações), `flutter test` (340), `flutter build web --release --no-web-resources-cdn`, e no Worker `npm run typecheck` + `npm test` (58 na `main`; a política `jobs_read` é exercitada em `worker/test/rls.test.ts` com Postgres real em memória).

**Contrato com PostgREST real (CI, job `catalog-postgrest`):** o teste `test/supabase/catalog_contract_test.dart` registra as requisições exatas que o repositório envia em 16 buscas (arquivo `test/supabase/catalog_requests.golden.json`, comparado a cada `flutter test`). O job de CI reproduz essas mesmas requisições, sem alterá-las, contra um **PostgREST real (v14.18 e v16.4)** sobre o schema real das 6 migrations, com uma semente que inclui vagas fechadas e fontes não autorizadas (`supabase/tests/09_catalog_seed.sql`, `scripts/supabase/catalog_postgrest_contract.mjs`). Prova, fora de mocks: o PostgREST aceita todas as consultas (inclusive dois parâmetros `or` na mesma URL, combinados com E, `cs.{X}`, `eq.{}`, `wfts(simple)` e o filtro no recurso embutido com `!inner`); devolve as linhas esperadas e na ordem esperada; **nunca** devolve vaga fechada nem de fonte não autorizada; e os tipos JSON são os que o app lê (numéricos como número, `geo_restrictions` como lista de texto, `published_at` ISO, `job_sources` como objeto). Se as consultas mudarem de propósito, regenere com `UPDATE_GOLDEN=1 flutter test test/supabase/catalog_contract_test.dart` e ajuste as expectativas do script.

**Limite desse teste:** roda como o papel `anon` (sem login). A política vale também para `authenticated`; isso não foi exercitado com JWT de usuário neste job. A versão do PostgREST do projeto hospedado não pôde ser lida (o endpoint raiz exige chave secreta), por isso são testadas duas versões atuais.

**Única verificação real contra o Supabase hospedado (somente leitura, 2026-10-09):** o app Web de desenvolvimento, com a configuração local do dono e a chave publishable, foi aberto no navegador embutido e duas buscas de texto foram feitas no catálogo hospedado, sem login. Resultado: **"Nenhuma fonte integrada para esta busca"**, isto é, a consulta a `jobs` voltou vazia, a consulta a `job_sources` não achou fonte autorizada, e nenhuma das duas foi negada (uma negação apareceria como "Algo deu errado"). Isso confirma que a leitura anônima funciona e que o estado vazio é o honesto. **Não prova nada sobre vagas reais**, porque não existe nenhuma no catálogo. Nada foi gravado. (A ferramenta de rede do navegador não listou as chamadas ao Supabase, então a prova é a tela, não o log de requisições.)

**O que NÃO foi testado:** exibição de vagas reais vindas do Supabase hospedado (o catálogo está vazio); nenhum teste em Android/iOS; a política RLS nunca é exercitada pelo código Flutter (o cliente fake não a aplica), só pelos testes do Worker.

## Dependências para ver vagas em produção (nada disto foi feito)

1. PR #50 integrado e a **ingestão autorizada e publicada** (migration 6, linha `jobicy` em `job_sources` criada com `can_redistribute = false` e só depois **publicada** por `scripts/supabase/ops/publish_jobicy.sql`, segredo do Worker, cron).
2. Vagas gravadas no catálogo hospedado.
3. Um teste remoto com conta descartável depois da primeira ingestão: abrir Explorar → "Ver vagas recentes" → ver "Fonte: Jobicy" → salvar uma vaga → reabrir o app → conferir em Favoritos → abrir o anúncio original.

## Limitações
* **Buscas salvas não guardam filtros:** "Salvar busca" grava só o termo; ao reabrir uma busca salva os filtros (modalidade, data, salário, país) não voltam.
* **Ordenação global sem índice dedicado:** a lista "mais recentes" ordena por `published_at desc, id desc` entre todas as vagas abertas; existe índice `(country, published_at desc)`, mas não um só por data. Com poucos milhares de vagas não é problema; se o catálogo crescer muito, um índice parcial para vagas abertas exigiria uma migration revisada. Não medido.

* Profissão e faixa salarial numérica não são filtráveis (ver acima).
* País: casa país da vaga, elegibilidade explícita e "qualquer lugar"; não casa regiões.
* Paginação por `offset`: se o catálogo muda entre duas páginas, uma vaga pode se deslocar; a lista mostra cada vaga uma vez, mas pode pular uma que mudou de posição.
* Busca de texto usa a configuração `simple` (sem radicais): "engineer" e "engineers" são palavras diferentes; o trecho do título cobre parte disso.
* Os códigos de país aparecem como códigos (`US`, `CA`), sem nome por extenso.
* `JobPosting.description` não persiste em favoritos/candidaturas: ao abrir um favorito, o texto completo está no anúncio original.
