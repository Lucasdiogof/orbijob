# Jobicy — integração de vagas (Fase 5.2)

Estado: **implementado e testado localmente; não implantado**. Nada foi gravado no Supabase hospedado, nenhuma migration foi aplicada, nenhum segredo foi configurado, nenhum Worker foi publicado.

Regras da fonte lidas em texto primário em 2026-10-09: [README oficial](https://github.com/Jobicy/remote-jobs-api) (seções Remote Jobs API, Production Recommendations, Fair Use, License) e [OpenAPI](https://jobicy.com/api/openapi.json). Um payload real de referência está em `worker/test/fixtures/jobicy-feed.sanitized.json`.

## O que a fonte garante (e o que isso exige de nós)

| Ponto | Texto oficial | Como o código respeita |
|---|---|---|
| Endpoint | `GET https://jobicy.com/api/v2/remote-jobs`, sem chave | `connectors/jobicy.ts` |
| Janela | só vagas publicadas nos **últimos 7 dias**; "sua ausência no feed não indica fechamento" | `isFullSnapshot` é sempre `false`; fechamento só pelo endpoint de status |
| Paginação | `count` 1–200; `nextCursor` opaco, válido 24 h; ordem por data desc; cursor expirado ou alterado → HTTP 400, recomeçar | 100 por página; cursor repassado sem alteração; `runSync` recomeça **uma vez** em 400 |
| Frequência | "não iniciar novas passadas de sincronização mais de uma vez por hora" | a passada é do agendador (≤ 1/h). Dentro da passada, 1 req/s entre páginas é **escolha nossa** (a fonte não publica cota) |
| Identificador | `id` inteiro; "deduplicar por `id`" | `external_id = String(id)`; único por `(source_id, external_id)` |
| Link canônico | "preservar a URL canônica do Jobicy"; botões de candidatura vão para a URL do feed | `original_url = apply_url = url`; só aceita `https` em `jobicy.com` |
| Atribuição | creditar o Jobicy com link direto; não apresentar como vaga própria | `job_sources.attribution`; a UI deve mostrar a fonte e o link |
| Descrição | HTML: "sanitizar antes de exibir" | reduzida a texto simples (`text.ts`); HTML nunca é guardado |
| Expiração | endpoint `GET /api/v2/remote-jobs/status?ids=` (≤ 100): `active`, `closed`, `unknown`; "`unknown` não confirma fechamento" | `active→open`, `closed→closed`, `unknown` não altera a vaga |
| Uso / retenção | "pode usar em seus produtos sem pedir permissão individual"; "cache onde apropriado"; "armazenar por `id`" | persistência permitida, com a fonte e a URL preservadas |
| Dados vs. código | MIT vale para o repositório; **não** transfere a propriedade das vagas, logos ou conteúdo de empregadores | logos **não** são armazenados |

**Limite da leitura:** o texto de uso é o "Fair Use" do README, não um contrato. Para grande volume ou uso diferente do normal, a própria fonte manda falar com ela. Publicar o Jobicy (`can_redistribute = true`) é uma **decisão do dono**, apoiada nesse texto e tomada só depois de revisar os registros gravados; a linha nasce com `false`.

## Arquitetura

```
agendador (Cron, ≤ 1×/h)  ──►  runSync(connector, store, scope)           worker/src/sync.ts
                                 │  RateLimiter + withRetry (429/5xx, Retry-After)   worker/src/http.ts
                                 ├─► connector.fetchPage(cursor)            worker/src/connectors/jobicy.ts
                                 │      getJson (timeout 15 s) → normalizeJobicy (valida + normaliza)
                                 │          geo.ts (países/regiões)  text.ts (HTML → texto)
                                 ├─► Deduper (id, URL canônica, impressão digital)   worker/src/dedupe.ts
                                 ├─► store.upsertJobs (por página)          worker/src/store/supabase.ts
                                 └─► fim da passada COMPLETA: closeStale → checkStatuses (lotes de 100) → markClosed
                                     store.recordRun  → public.sync_runs (só contagens)
```

Para uma nova fonte basta um `Connector` (`fetchPage`, `minIntervalMs`, opcionalmente `checkStatuses`) e a regra de licença dela. O pipeline não muda.

### Campos normalizados (Jobicy → `NormalizedJob` → coluna de `jobs`)

| Jobicy | Normalizado | Observação |
|---|---|---|
| `id` | `externalId` | inteiro positivo; senão a vaga é rejeitada |
| `jobTitle` | `title` | entidades decodificadas; vazio → rejeitada |
| `companyName` | `company` | pode ser `''` (a fonte admite); nunca inventada |
| `url` | `originalUrl`, `applyUrl`, `canonical_url` | `https` + `jobicy.com`, senão rejeitada |
| `jobDescription` (HTML) | `description` (texto) | cai para `jobExcerpt` se vazia |
| `jobType[]` | `contractType` | valores unidos por `, ` |
| `jobGeo` | `country`, `geoRestrictions` | país só quando é **um** país e nada mais; regiões (`EMEA`, `Europe`, `APAC`, `LATAM`) ficam como região; nomes desconhecidos ficam como escritos; `Anywhere` = sem restrição |
| `salaryMin/Max/Currency/Period` | salário | só com **moeda ISO e período reconhecido**; `min > max` ou campo faltando → nenhum salário |
| `pubDate` | `publishedAt` | data inválida → `null` |
| (fixo) | `workMode = 'remote'` | o endpoint é só de vagas remotas |
| — | `city`, `language`, `skills`, `requirements` | `null`/vazio: a fonte não informa |
| `jobIndustry`, `jobLevel`, `companyLogo` | **descartados** | sem coluna; logo não é armazenado |

## Dependências de implantação

1. **Migration 6** (`20261013000000_service_role_grants.sql`): **aplicada e auditada** em 2026-10-10 (15 grants para o `service_role`, nada além). Os testes (`jobicy-schema.test.ts`) provam que o conjunto de permissões dela basta para este fluxo.
2. **Linha da fonte** (`jobs.source_id` é chave estrangeira): **criada em 2026-10-10 em estado NÃO publicado**: `status = 'CONDITIONAL'`, `can_redistribute = false`. É o único estado inicial permitido:
   ```sql
   insert into public.job_sources (id, status, attribution, can_redistribute)
   values ('jobicy', 'CONDITIONAL', 'Remote jobs via Jobicy (https://jobicy.com)', false);
   ```
   (`insert` simples, sem `on conflict`: se a linha existir, o comando falha em vez de sobrescrever.) A política `jobs_read` só deixa o app ler vagas de fontes com `can_redistribute = true` e status `READY`/`CONDITIONAL`; com `false`, **nenhuma** vaga do Jobicy é visível ao app, mesmo depois da ingestão.
   **Publicar é uma operação separada**, só depois de conferir os registros gravados e com autorização do dono: `scripts/supabase/ops/publish_jobicy.sql`. Esse arquivo se recusa a rodar sem a trava `orbijob.publish_jobicy`, sem uma passada `ok` em `sync_runs`, sem vagas, com URL fora de `jobicy.com` etc. `scripts/supabase/no_premature_publish.test.mjs` (CI) falha se qualquer outro arquivo do repositório ligar `can_redistribute`.
3. **Segredo** do Worker (`SUPABASE_SERVICE_ROLE_KEY` e a URL do projeto). Só no Worker ou no processo local da primeira ingestão, nunca no Flutter, nunca no chat. Use uma chave `sb_secret_…` **nova e exclusiva** (a chave legada `service_role` foi exposta em 2026-10-10 e deve ser desativada: ver `FIRST_INGESTION_RUNBOOK.md`, passo 0).
4. **Worker + agendador:** ponto de entrada (`scheduled`) que monta `jobicyConnector(fetch)` + `SupabaseJobStore` e chama `runSync`. **Cron no máximo de hora em hora.** O plano gratuito do Workers dá 10 ms de CPU por chamada (provavelmente insuficiente para interpretar páginas de ~1 MB; não medido); o plano pago (US$ 5/mês) dá 30 s por padrão.
5. **Flutter:** hoje `NoSourceSearchRepository`. Falta um repositório que leia `jobs` (com filtros, e `geo_restrictions` para a elegibilidade de vagas remotas) e mostre a atribuição. As telas e os cartões existentes já exibem os campos; `JobPosting` ainda não traz `geoRestrictions` nem a descrição.

## O que foi testado

* `worker/test/jobicy.test.ts` — normalização com payloads **reais** sanitizados, localização ambígua, salários incompletos, URLs inválidas, HTML hostil, paginação, status.
* `worker/test/sync.test.ts` — passada completa, idempotência, duplicados, vagas inválidas, vaga removida/expirada, 429 com `Retry-After`, 500, timeout, 404, cursor expirado, limite de páginas, falha ao gravar, logs sem conteúdo.
* `worker/test/jobicy-schema.test.ts` — as linhas contra o **schema real** (PGlite, migrations 1, 2 e 6): constraints, upsert repetido, permissões do `service_role`, leitura por `anon`.
* `worker/test/store.test.ts` — contrato das requisições PostgREST, sem rede; chave e corpo da resposta nunca vazam em erros.
* `worker/test/live/jobicy.live.test.ts` — **chamada real somente leitura**, desligada por padrão (`JOBICY_LIVE=1`). Executada uma vez em 2026-10-09: 100 vagas reais, 0 rejeitadas, status coerente.

## Auditoria final (Fase 5.4)

* **Defeito corrigido (reproduzido por teste):** em uma fonte com vários escopos sob o mesmo `source_id` (um quadro por empresa, como o Lever), a passada completa de um escopo fechava as vagas abertas dos outros, porque "ausente do snapshot" era tratado como encerrada. O Jobicy nunca foi afetado (só fecha o que a própria fonte responde `closed`), mas o pipeline é reutilizável. Agora a ausência em snapshot só fecha vagas se quem chama declara `snapshotCoversSource: true` (padrão `false`). Teste: `worker/test/sync-scope.test.ts`.
* **Endurecimento do `SupabaseJobStore`:** recusa URL que não seja `https` (e `http` só para `localhost`), ou com credenciais embutidas, porque a chave `service_role` vai em todas as requisições; e divide as gravações por tamanho (≈ 400 mil caracteres de JSON por requisição, no máximo 100 linhas), para que cem descrições longas não virem um corpo gigante.
* **Compatibilidade com as chaves novas do Supabase (defeito corrigido):** o `SupabaseJobStore` enviava a chave também em `Authorization: Bearer`. A [documentação do Supabase](https://supabase.com/docs/guides/api/api-keys) manda enviar as chaves `sb_publishable_…`/`sb_secret_…` **apenas** em `apikey`, porque não são JWT e qualquer verificação como JWT falha. Agora `Authorization` só é enviado quando a chave é um JWT (chave `service_role` clássica, ou PostgREST direto nos testes). Não foi possível testar contra o gateway hospedado (nenhuma chave secreta foi usada); o teste prova o formato dos cabeçalhos.
* **Teste de contrato com PostgREST real** (`worker/test/live/postgrest.contract.test.ts`, job de CI `worker-postgrest`, PostgREST v14.18 e v16.4, Postgres 17, schema das 6 migrations, JWT HS256 assinado de verdade): `runSync` + `SupabaseJobStore` gravam as 10 vagas da fixture, registram o `sync_runs`, repetem sem duplicar, fecham só o que a fonte diz `closed` (PATCH real), não fecham nada quando o feed cai, e o `service_role` **não** lê dados de usuário nem apaga fontes. Isso prova também que o conjunto de permissões da migration 6 basta para este fluxo.
* **Deduplicação medida em dados reais:** em 100 vagas reais do Jobicy, 0 descartadas por "empresa + título + país". Risco residual: duas vagas distintas com a mesma empresa, título e país nulo seriam tratadas como a mesma.

## Limitações conhecidas

* Conteúdo: sobretudo tecnologia e escritório, inglês, só remoto, só a última semana. Sem ofícios, sem Brasil/Portugal. A cobertura "mundial" não pode ser prometida.
* Dados de `jobIndustry` e `jobLevel` não são guardados (sem coluna); poderiam alimentar filtros numa fase futura, com migration revisada.
* A deduplicação entre fontes (`job_clusters`) ainda não é preenchida: `jobs.fingerprint` e `canonical_url` já são gravados, mas `cluster_id` fica vazio.
* Vagas que a fonte devolve como `unknown` e que saíram do feed permanecem `open` até a fonte dizer `closed`. Uma política de idade máxima exigiria decisão de produto.
* O limite de 30 lotes de status por passada (3.000 ids) evita rajadas; o excedente espera a próxima passada.
