# Fontes prioritárias — ficha técnica

Ver classificação e evidências em [`GLOBAL_SOURCES.md`](GLOBAL_SOURCES.md). Mapeamento do pedido original → taxonomia atual: APPROVED não existe mais; fontes prioritárias estão `CONDITIONAL` ou `RESEARCH` até validação ao vivo.

| Campo | Himalayas | Jobicy | Greenhouse | Lever | Ashby | Remotive | USAJOBS | Adzuna |
|---|---|---|---|---|---|---|---|---|
| Docs | himalayas.app/docs | jobicy.com/api/v2/remote-jobs | developers.greenhouse.io/job-board.html | github.com/lever/postings-api | developers.ashbyhq.com | github.com/remotive-com/remote-jobs-api | developer.usajobs.gov | developer.adzuna.com |
| Países | global (remoto) | global (remoto) | global (por empresa) | global (por empresa; host EU separado) | global (por empresa) | global (remoto) | EUA | 19 (a verificar) |
| Profissões | tech/conhecimento | remoto, várias | todas que a empresa publique | idem | idem | remoto | federais (todas) | todas |
| Integração | REST | REST | REST `boards-api.greenhouse.io/v1/boards/{token}/jobs` | REST `api.lever.co/v0/postings/{site}` | REST `api.ashbyhq.com/posting-api/job-board/{name}` | REST | REST `data.usajobs.gov/api/search` | REST |
| Auth | não reportada | não | não (GET) | não (GET) | não | não | chave + User-Agent | app_id/app_key |
| Limites | não encontrado | count ≤ 100 | não documentado | apply 2/s | não documentado | ≤4 fetch/dia, ≤2 req/min | 500 linhas/pág., 10k/consulta | 25/min, 250/dia, 1k/sem, 2,5k/mês |
| Termos | **não lidos** | **não lidos** | não lidos | sem ToS de API | não lidos | atribuição + link; sem repasse a terceiros; sem coleta de e-mail; atraso 24h | não lidos | rótulo "Jobs by Adzuna"; uso comercial além de publicar exige consentimento |
| Redistribuição | desconhecida | desconhecida | por empregador | por empregador | por empregador | restrita | desconhecida | restrita |
| Paginação | n/d | `count` | lista completa (`content=true` p/ descrição) | `skip`/`limit` | resposta única | `limit` | página/linhas | `/search/{page}` |
| Atualização | n/d | n/d | snapshot completo | snapshot completo | snapshot (só publicadas) | atraso 24h | n/d | n/d |
| Salário | n/d | quando informado | `pay_transparency` no endpoint de vaga | `salaryRange` | `includeCompensation=true` | campo `salary` (texto) | faixa | estimado/ informado |
| Link de candidatura | n/d | URL da vaga | sim | `applyUrl` | sim | `url` | URI | `redirect_url` |
| Risco de manutenção | médio | médio | baixo | baixo | médio | médio | baixo | médio |
| **Status** | RESEARCH | RESEARCH | CONDITIONAL | CONDITIONAL | CONDITIONAL | CONDITIONAL | CONDITIONAL | CONDITIONAL |

"n/d" = não obtido (fonte inacessível nesta fase). Células sobre Greenhouse/Ashby/Himalayas/Jobicy/USAJOBS/Adzuna vêm de resumos de terceiros, exceto limites e atribuição do Adzuna (texto dos termos via busca) — **reverificar nos originais**.

## Contrato de conector
`worker/src/types.ts` (`NormalizedJob`, `Connector`, `FetchPage`). Regras: `fetchPage(cursor, scope)` é idempotente; `isFullSnapshot` só é `true` ao fim de varredura completa; campos desconhecidos são `null`, nunca inventados; cada conector declara `minIntervalMs` derivado dos limites publicados. Implementado nesta fase: contrato + normalizador Lever + testes com fixture **sintética** (rotulada), deduplicação, retry/backoff, rate limiter. Não há conector de produção habilitado.
