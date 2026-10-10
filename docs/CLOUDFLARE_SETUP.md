# OrbiJob — Worker de ingestão no Cloudflare (preparação, sem deploy)

## Auditoria do estado atual (`worker/`)
| Item | Estado |
|---|---|
| Conectores | `lever` (normalização + paginação, testado com fixture sintética). Greenhouse/Ashby/USAJOBS/Adzuna/France Travail: **não implementados** |
| Normalização | tipo `NormalizedJob` (`types.ts`), ocupações ISCO-08 multilíngues (`occupations.ts`) |
| Deduplicação | fingerprint + URL canônica (`dedupe.ts`); `shouldMarkClosed` só age após varredura completa |
| Retry / erros | `withRetry` (backoff com jitter, `Retry-After`, só 429/5xx). **Corrigido nesta fase:** o conector lançava `Error` genérico, então um 404 era repetido como erro de rede; agora `getJson` lança `HttpError`, tem timeout de 15 s e lê `Retry-After` |
| Rate limiting | `RateLimiter` em memória: **insuficiente em Workers** (isolados efêmeros/múltiplos). Para produção usar Durable Object (ou KV com janela) por fonte |
| Ponto de entrada | **existe desde a Fase 5.5** (`worker/src/index.ts`, `worker/wrangler.toml`, tipo `Env` em `worker/src/env.ts`), ainda **não publicado**. Ver [`JOBICY_WORKER.md`](JOBICY_WORKER.md) |
| Segredos | nenhum no repositório (gitleaks no CI) |

## Quando a primeira fonte for validada (ordem sugerida)
1. `worker/wrangler.toml` (exemplo, ajuste os nomes):
   ```toml
   name = "orbijob-ingest"
   main = "src/index.ts"
   compatibility_date = "2026-10-01"
   [triggers]
   crons = ["17 */6 * * *"]
   ```
2. `src/index.ts` com `scheduled()` que, para cada fonte `READY` e escopo: reserva slot do limitador (Durable Object) → `withRetry(getJson…)` → normaliza → `dedupe` → upsert em lote no Supabase (REST, service role) → grava `sync_runs` (contagens, nunca payload) → `shouldMarkClosed` só após paginação completa.
3. Variáveis/segredos: `wrangler secret put SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, e a chave da fonte (`ADZUNA_APP_ID`, `ADZUNA_APP_KEY` ou `USAJOBS_KEY`/`USAJOBS_EMAIL`). Nunca em `[vars]` nem no app.
4. Segurança de integração: endpoint de ingestão sem rota pública (apenas cron/`scheduled`); se houver HTTP de administração, exigir token e Cloudflare Access; respeitar atribuição e limites de cada fonte.
5. Teste local: `wrangler dev --local` e `/cdn-cgi/handler/scheduled` (automatizado em `worker/scripts/e2e-workerd.mjs`); só então `wrangler deploy` (não feito).
