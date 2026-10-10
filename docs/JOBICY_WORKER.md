# Worker Cloudflare de sincronização do Jobicy

Estado: **implementado e testado localmente e no CI; não publicado.** Nenhum deploy, segredo, Cron Trigger ou escrita no Supabase hospedado foi feito. O catálogo hospedado continua vazio e a migration 6 continua não aplicada.

Arquivos: `worker/src/index.ts` (entrada), `worker/src/scheduled.ts` (orquestração), `worker/src/lease.ts` (bloqueio entre instâncias), `worker/src/env.ts` (configuração), `worker/src/log.ts` (logs), `worker/wrangler.toml`.

## Entrada e fluxo

`scheduled` é a **única** porta de entrada; `fetch` responde 404 a tudo, e o `wrangler.toml` desliga `workers.dev` e as URLs de preview, então o Worker não tem endereço público.

```
cron ─► loadConfig ──(inválida)──► log config_invalid + falha visível, nenhuma requisição
          │
          ▼
       acquireLease (sync_runs)  ──(401/403)──► supabase_auth_failed, falha, Jobicy NÃO é chamado
          │                      ──(rede/5xx)─► supabase_unreachable (com retry), falha
          │                      ──(outro vivo / cedo demais / perdeu a corrida)──► skipped (não é erro)
          ▼
       runSync(jobicy, deadline 12 min, no máximo N páginas)
          ├─ falha total  ─► status failed  ─► a invocação FALHA (aparece como erro no painel)
          ├─ falha parcial ─► status partial ─► a invocação termina; nada é fechado
          └─ completa ─► só então fecha o que o Jobicy responde "closed"
          ▼
       a linha da lease vira o registro final da execução (ok | partial | failed)
```

**Falha total × parcial:** total = nada foi gravado (a primeira página falhou, ou o banco recusou). Parcial = algo foi gravado antes do problema. Em ambos os casos **nenhuma vaga é fechada**: o fechamento só roda depois de uma passada completa e só para o que a fonte confirma como `closed` (`unknown` e `active` ficam abertas).

**`waitUntil`:** não é usado de propósito. A sincronização é aguardada dentro do handler para que uma falha seja atribuída à invocação; `waitUntil` só a esconderia.

## Concorrência: variável global não resolve

Um Worker roda em muitos isolados, em muitos lugares. A [documentação de Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/) **não** descreve garantia de entrega exatamente-uma-vez nem diz o que acontece com execuções sobrepostas. Uma flag no módulo só protegeria o mesmo isolado. Por isso o bloqueio é feito no banco, **com tabelas que já existem** (`sync_runs.status` já aceita `running`, e a migration 6 já concede `select/insert/update` ao `service_role`), sem nenhuma alteração de schema:

1. Existe execução `running` com menos de 20 min? → **pula**.
2. Existe execução terminada há menos de 60 min? → **pula** (regra da fonte: no máximo uma passada por hora; também absorve entrega duplicada do cron).
3. Insere a própria linha `running`, relê, e se existir uma **mais antiga** (desempate por id) → **cede** e fecha a própria linha como `lost_lease`. **A releitura é feita duas vezes, com 1 s de pausa entre elas:** uma linha recém-inserida não aparece instantaneamente para outro leitor, então uma única conferência pode não ver um rival mais antigo. Teste que prova isso: `lease.test.ts` ("a segunda conferência pega um rival invisível na primeira" e o controle sem pausa, que o deixa passar).
4. Linha `running` mais velha que 20 min = execução que caiu → fechada como `stale_lock`.

**É uma lease otimista, não um mutex.** Testes: 3 invocações simultâneas resultam em exatamente 1 sincronizando e 2 cedendo, em memória (`lease.test.ts`, `scheduled.test.ts`) e contra um PostgREST real no CI (`worker/test/live/postgrest.contract.test.ts`, job `worker-postgrest`). Limite honesto: duas instâncias inserindo no mesmo instante com relógios defasados poderiam ambas prosseguir. Isso **não corrompe nada** (toda gravação é `upsert` por chave única; fechar exige a evidência da fonte; uma vaga reaberta por engano é refechada na passada seguinte) e o custo é uma passada a mais no Jobicy. Para uma garantia estrita existem duas saídas, **ambas fora desta fase**:

| Opção | Custo | Quando |
|---|---|---|
| Índice único parcial `sync_runs (source_id) where status = 'running'` | migration (altera o banco: autorização separada) | se a duplicidade ocorrer na prática |
| Durable Object por fonte | binding + migration de DO no `wrangler.toml` | se houver várias fontes disparadas em paralelo |

## Limites da plataforma (Cloudflare, páginas oficiais lidas em 2026-10-10)

| Limite | Plano gratuito | Plano pago | Consequência aqui |
|---|---|---|---|
| CPU por invocação de Cron | **10 ms** | 15 min (intervalo ≥ 1 h) | uma passada interpreta respostas de ~1 MB: **o plano gratuito não serve** (CPU real não medida) |
| Subrequests por invocação | **50** | 10.000 | uma passada faz dezenas de chamadas (páginas do feed + gravações + status): **o gratuito estoura** |
| Duração (relógio) | 15 min | 15 min | o Worker se limita a 12 min (`RUN_BUDGET_MS`) e termina como `partial` (`deadline`) |
| Memória | 128 MB | 128 MB | uma página (≤ 100 vagas) é gravada e descartada; só ids ficam em memória |
| Triggers de cron por conta | 5 | 250 | usa 1 |
| Log por invocação | 256 KB | 256 KB | logs só com contagens |

Estimativa de subrequests no pior caso configurado (`SYNC_MAX_PAGES` = 40): ≤ 40 páginas do feed + ≤ ~120 gravações (até 3 por página, por tamanho) + leitura dos ids abertos + ≤ 30 lotes de status + fechamentos + 5 da lease ≈ 200, folgado para o limite de 10.000 do plano pago. **Requisito: Workers Paid (US$ 5/mês).**

**Tamanho do pacote:** 33,45 KiB (10,78 KiB comprimido), sem bindings (`wrangler deploy --dry-run`). **Runtime:** `AbortSignal.timeout`, `fetch`, `atob` e `Response` são APIs de Workers; a chamada de `fetch` usa um invólucro porque, em Workers, uma função da plataforma chamada como método de outro objeto lança `Illegal invocation` (teste em workerd falha sem o invólucro, verificado).

## Cron

`wrangler.toml`: `crons = ["0 */6 * * *"]` (a cada 6 horas, em UTC). Compatível com a regra do Jobicy (uma passada por hora; o próprio Worker também impõe os 60 min). A Cloudflare avisa que uma mudança de agenda pode levar até 15 minutos para propagar. **O cron só passa a existir quando o proprietário autorizar e fizer `wrangler deploy`.**

## Segredos e configuração

| Nome | Tipo | Conteúdo |
|---|---|---|
| `SUPABASE_URL` | segredo | `https://<ref>.supabase.co` (`https` obrigatório) |
| `SUPABASE_SERVICE_ROLE_KEY` | **segredo** | a chave secreta do projeto (`sb_secret_…`) ou o JWT `service_role` legado |
| `JOBICY_API_URL` | só testes | origem alternativa (`https://jobicy.com` ou localhost); **não definir em produção** |
| `SYNC_MAX_PAGES` | opcional | 1–100 (padrão 40) |

* Configurados com `wrangler secret put` (ferramenta oficial; o valor é digitado no terminal do proprietário, nunca em chat, nunca no Git, nunca no `wrangler.toml`).
* O Worker **recusa** chave publishable ou anon, formato desconhecido, URL não `https` e números fora de faixa, listando só o nome da variável e o motivo.
* Conforme o [guia de chaves do Supabase](https://supabase.com/docs/guides/api/api-keys): `sb_secret_…` vai **somente** em `apikey` (não é JWT); JWT clássico vai também em `Authorization`. Verificado em workerd (o stub recusa `Authorization` com `sb_secret_`).
* Nada disso vai para o Flutter, que só conhece a chave publishable.

## Logs

Uma linha JSON por evento (`sync_start`, `sync_skipped`, `sync_ok|partial|failed`, `supabase_auth_failed`, `supabase_unreachable`, `config_invalid`, …) com contagens, classe de erro e id da execução. **Nunca** conteúdo de vagas, URLs, mensagens de erro de servidores (podem ecoar linhas ou chaves) nem a chave: além de não serem enviados, qualquer segredo registrado é mascarado em toda a linha, inclusive escapado.

## Execução manual controlada (futura)

* **Não existe rota HTTP de disparo**, nem protegida: não há endpoint administrativo. É uma decisão, não uma lacuna.
* **Local, sem conta Cloudflare:** `cd worker && npx wrangler dev --local --var …` e `curl "http://127.0.0.1:8787/cdn-cgi/handler/scheduled"` (endpoint só existe no desenvolvimento local). `scripts/e2e-workerd.mjs` automatiza isso contra um Supabase/Jobicy simulado.
* **Produção (somente após autorização da primeira ingestão):** ajustar temporariamente o cron para um minuto próximo, publicar, acompanhar com `wrangler tail`, **restaurar** `0 */6 * * *`. Como o Worker impõe 60 min entre passadas, um disparo repetido não martela a fonte.

## O que foi testado

| Camada | Onde | O quê |
|---|---|---|
| Unidade | `worker/test/env.test.ts`, `lease.test.ts` | configuração (chaves, URLs, faixas), logger e máscara, lease (corrida de 3, intervalo mínimo, linha estagnada, outras fontes) |
| Orquestração | `worker/test/scheduled.test.ts` (26) | passada normal, idempotência, configuração ausente, chave publishable, credencial recusada (401/403), banco fora do ar, 429, timeout, 500 parcial, fechamento só com prova, prazo, limite de páginas, concorrência, entrega duplicada, execução caída, logs sem segredo |
| Entrada | `worker/test/entry.test.ts` | `fetch` = 404, `scheduled` falha visível só quando deve |
| Banco/PostgREST reais | `worker/test/live/postgrest.contract.test.ts` (CI `worker-postgrest`, v14.18 e v16.4) | handler completo, **3 invocações simultâneas contra o banco real**, entrega repetida, execução caída, credencial forjada |
| Runtime real | `worker/scripts/e2e-workerd.mjs` (CI `worker`, e `worker-postgrest` contra PostgREST) | o handler executa de verdade em **workerd**: passada completa, 2ª entrega pulada, credencial no cabeçalho certo, sem `Illegal invocation`, sem segredo nos logs |
| Configuração | `wrangler deploy --dry-run` (CI) | `wrangler.toml` e pacote válidos, sem deploy |

Controle negativo feito à mão: passando o `fetch` cru em vez do invólucro, o teste em workerd falha (HTTP 500, nada gravado).

## Limitações

* Plano pago obrigatório (acima). CPU e subrequests reais de uma passada em produção ainda não foram medidos.
* Lease otimista (acima).
* Só a fonte Jobicy: o `index.ts` não escolhe fontes; adicionar outra exige código e autorização.
* Vagas `unknown` que saíram do feed permanecem abertas até a fonte dizer `closed`.
* Sem alertas: a falha total aparece como invocação com erro no painel (Observability está ligada), mas ninguém é avisado automaticamente.
