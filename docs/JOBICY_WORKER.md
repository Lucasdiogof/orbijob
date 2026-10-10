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

## Concorrência: a decisão é do banco, atômica

**O problema.** Um Worker roda em muitos isolados, em muitos lugares. A [documentação de Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/) **não** descreve garantia de entrega exatamente-uma-vez nem diz o que acontece com execuções sobrepostas. Uma variável global só protegeria o mesmo isolado.

**O primeiro desenho não bastava.** Era "ler, inserir uma linha `running` com id aleatório, reler e ceder se houver uma mais antiga" (depois com uma pausa e uma segunda leitura). Cada passo é uma requisição em outra conexão, uma linha recém-inserida não é visível a todos os leitores ao mesmo tempo, e a ordem entre rivais por relógio/id é decidida *depois* do fato. Uma pausa só torna a falha mais rara, nunca impossível, e o resultado dependia da versão do PostgREST (a v14.18 e a v16.4 se comportaram de modos diferentes). **Não se usa mais.** O CI mede os dois desenhos no mesmo PostgREST real a cada execução do job `worker-postgrest` (anotações "Lease legacy" e "Lease atomic", de `test/live/lease-stress.test.ts`).

**O desenho atual.** O id de uma execução **não é aleatório**: é derivado de `(fonte, janela de 1 hora)` (UUID v5-like, SHA-256). `sync_runs.id` é `PRIMARY KEY`, então, entre quantas execuções tentarem começar na mesma janela, **o PostgreSQL deixa exatamente uma inserção passar** e recusa as demais com violação de unicidade (HTTP 409 pelo PostgREST). A decisão acontece dentro do banco, em um único comando, **sem depender de pausa, de relógio, de visibilidade entre conexões nem da versão do PostgREST**. Quem perde não grava nada: não há linha para limpar.

Antes da reivindicação, duas conferências baratas evitam tentativas inúteis e dão o motivo nos logs:
1. existe execução `running` com menos de 20 min? → pula (cobre uma execução longa que atravessa a virada da hora);
2. existe execução terminada há menos de 60 min? → pula (regra da fonte: uma passada por hora; também absorve entrega duplicada do cron, e uma falha também conta, para não martelar uma fonte que acabou de nos recusar).

Uma linha `running` com mais de 20 min é uma execução que caiu: é fechada como `stale_lock`. Nenhuma migration é necessária: o `id` é fornecido pelo cliente e a migration 6 já dá `insert/update/select` ao `service_role`.

### O que é e o que não é garantido

| Garantido (pelo PostgreSQL) | Não garantido |
|---|---|
| no máximo **uma** execução reivindica uma mesma fonte em uma mesma janela de 1 h, por mais instâncias, conexões ou entregas duplicadas que existam | que o cron seja entregue **exatamente uma vez** (a Cloudflare não promete isso; entregas duplicadas são **absorvidas**, não evitadas) |
| quem perde a corrida não escreve nada nem chama a fonte | que duas execuções nunca se sobreponham no tempo **entre janelas diferentes**: uma execução que começa às 11:58 e ainda roda às 12:00 é protegida pela conferência 1 (`running`), que é leitura e não é atômica |
| uma execução que caiu não bloqueia a fonte para sempre (TTL de 20 min) | retry na mesma hora de uma execução que caiu: a janela dela continua usada; a próxima tentativa é na hora seguinte (com cron de 6 h, na próxima entrega) |

**Por que o resto é inofensivo:** toda gravação do catálogo é `upsert` por chave única e nenhuma vaga é fechada sem a resposta `closed` da própria fonte. Uma passada a mais custa uma requisição a mais ao Jobicy, não corrompe dados.

### Política de janelas e de recuperação

**Janela.** É a hora UTC cheia: `floor(agora / 1 h)`, alinhada à época (12:00:00.000 a 12:59:59.999 é uma janela). O id da execução é derivado de `(fonte, janela)`. A pergunta "terminou alguma execução na última hora?" olha o intervalo **fechado dos dois lados**, `(agora − 1 h, agora]`: uma linha datada **depois** de "agora" (relógio de outra instância um pouco adiantado, backup restaurado, dado de teste) **não** conta como "a última hora". Esse limite superior faltava no primeiro desenho e era a causa dos cinco testes que falharam no CI (ver abaixo).

| Situação | O que fica no banco | Nova tentativa |
|---|---|---|
| **Sucesso** | linha `ok` | só depois de 60 min (no cron de 6 h, na próxima entrega). Dentro da hora: `too_soon` ou recusa pela chave |
| **Falha total** (429, 5xx, timeout ao falar com a fonte) | linha `failed` com a classe (`http_429`, `timeout`…) e nada fechado | **retry na mesma hora é proibido de propósito**: uma falha também conta como passada, para não martelar uma fonte que acabou de nos recusar. As tentativas com recuo (*backoff*) acontecem **dentro** da mesma passada. Próxima tentativa: a janela seguinte |
| **Falha parcial** | linha `partial`, o que foi gravado fica, **nada é fechado** | igual à falha |
| **Prazo interno de 12 min** | linha `partial`, `error_class = deadline` | igual à falha |
| **Queda do Worker** (limite da plataforma, reinício, deploy no meio) | a linha fica `running` | a partir de **20 min** ela é *stale*: a próxima execução que começar a lê e a fecha como `failed / stale_lock`. A janela da execução que caiu continua usada pela chave: a nova tentativa é na **janela seguinte** (no cron de 6 h, a próxima entrega) |
| **Credencial recusada / banco inalcançável** | nada (a execução nem começou) | a próxima entrega do cron; nenhuma janela foi ocupada |
| **Entrega duplicada do cron** | nada novo | pulada (`running`, `too_soon` ou `lost_race`), registrada em log |

**Como uma lease *stale* é identificada:** pela **idade** da linha `running` (`agora − started_at ≥ 20 min`), nunca por um relógio de quem a criou. **Como evitar uma execução presa para sempre:** a idade é avaliada a cada novo início, então uma linha esquecida em `running` nunca bloqueia a fonte por mais de 20 min; ela só continua listada como `running` até a próxima execução limpá-la (efeito apenas cosmético).

**Risco: um processo antigo continuar trabalhando depois de a lease expirar.** Com esta chave única, a lease não tem um "token de fencing": se uma execução pudesse viver mais que o TTL, outra poderia começar e as duas escreveriam. Aqui isso **não pode acontecer na plataforma**: o prazo da própria passada é de 12 min (`RUN_BUDGET_MS`) e a Cloudflare limita um cron a **15 min** de relógio, ambos **menores que o TTL de 20 min**. Se o TTL algum dia ficasse menor que o tempo máximo de uma execução (ou se a plataforma mudasse o limite), seria preciso um *fencing token* (um número que cresce a cada lease e que toda gravação confere, rejeitando o antigo), ou uma operação transacional no banco (por exemplo, uma função SQL que reivindica e grava com verificação). Isso exigiria uma migration e **não foi feito**. Mesmo no pior caso, as gravações são `upsert` por chave única e fechar vaga exige a resposta `closed` da fonte, então uma execução zumbi não corrompe o catálogo.

**Garantia estrita opcional (migration, NÃO aplicada, a ser aprovada à parte):** um índice único parcial faria o banco recusar duas linhas `running` da mesma fonte em qualquer momento, inclusive entre janelas:

```sql
create unique index sync_runs_one_running_per_source on public.sync_runs (source_id) where status = 'running';
```

Só vale a pena se a medição em produção mostrar execuções cruzando a virada da hora. A alternativa seria um Durable Object por fonte (binding e migration de DO no `wrangler.toml`).

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
| Unidade | `worker/test/env.test.ts`, `lease.test.ts` | configuração (chaves, URLs, faixas), logger e máscara; lease: id da janela, 2/3/10 simultâneos, **propriedade com 150 rodadas aleatórias de 2 a 10 concorrentes**, intervalo mínimo, falha e recuperação, execução caída |
| Orquestração | `worker/test/scheduled.test.ts` (26) | passada normal, idempotência, configuração ausente, chave publishable, credencial recusada (401/403), banco fora do ar, 429, timeout, 500 parcial, fechamento só com prova, prazo, limite de páginas, concorrência, entrega duplicada, execução caída, logs sem segredo |
| Entrada | `worker/test/entry.test.ts` | `fetch` = 404, `scheduled` falha visível só quando deve |
| Banco/PostgREST reais | `worker/test/live/postgrest.contract.test.ts` e `lease-stress.test.ts` (CI `worker-postgrest`, v14.18 e v16.4) | o 409 do banco para um id repetido; **2, 3 e 10 invocações simultâneas contra o banco real, com asserção estrita (1 vencedora, 1 linha, nada em `running`)**; entrega repetida; execução caída e retry na mesma hora; falha e recuperação na hora seguinte; passada parcial que não fecha nada; credencial forjada; **estresse de 20 rodadas × 10 concorrentes, desenho antigo × atual** |
| Runtime real | `worker/scripts/e2e-workerd.mjs` (CI `worker`, e `worker-postgrest` contra PostgREST) | o handler executa de verdade em **workerd**: passada completa, 2ª entrega pulada, credencial no cabeçalho certo, sem `Illegal invocation`, sem segredo nos logs |
| Configuração | `wrangler deploy --dry-run` (CI) | `wrangler.toml` e pacote válidos, sem deploy |

Controle negativo feito à mão: passando o `fetch` cru em vez do invólucro, o teste em workerd falha (HTTP 500, nada gravado).

## Limitações

* Plano pago obrigatório (acima). CPU e subrequests reais de uma passada em produção ainda não foram medidos.
* Lease otimista (acima).
* Só a fonte Jobicy: o `index.ts` não escolhe fontes; adicionar outra exige código e autorização.
* Vagas `unknown` que saíram do feed permanecem abertas até a fonte dizer `closed`.
* Sem alertas: a falha total aparece como invocação com erro no painel (Observability está ligada), mas ninguém é avisado automaticamente.
