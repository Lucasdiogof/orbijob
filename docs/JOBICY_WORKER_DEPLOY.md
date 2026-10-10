# Implantar o Worker do Jobicy em modo `revalidate` (procedimento; NADA aqui foi executado)

Conferido em 2026-10-10. Tudo marcado **[verificado]** foi lido da conta/da documentação nesta data; tudo marcado
**[não verificável]** não foi confirmado e não deve ser tratado como fato.

## 1. Estado real da Cloudflare

| Item | Situação |
|---|---|
| Conta vinculada | **[verificado]** o `wrangler` está logado (OAuth) numa conta ("Lucasdiogo1234@gmail.com's Account") com escopos de leitura de conta e escrita de Workers |
| Workers existentes | **[verificado]** 6, de outros projetos: `aura`, `bragantino-app`, `goias-app`, `la-pelve`, `lucksrei-site`, `vilanova-app` |
| `orbijob-jobicy-sync` existe? | **[verificado]** **não** (a API responde "This Worker does not exist", código 10007) |
| Crons já na conta | **[verificado]** 5: `goias-app` (3: 11:00, 17:00, 23:00 UTC) e `bragantino-app` (2: 14:00, 20:00 UTC). Nenhum no OrbiJob |
| Secrets do OrbiJob | **[verificado]** inexistentes (o Worker não existe) |
| **Workers Paid está ativo?** | **[não verificável]** o token não tem escopo de cobrança (a consulta de assinatura retorna erro de autenticação) e `usage_model: standard` é o valor de qualquer conta, paga ou gratuita. **Precisa da sua confirmação no painel** |

**Pista importante (documentação oficial lida hoje):** no plano **gratuito** o limite é de **5 Cron Triggers por conta** (no pago, 250).
A conta já tem 5. Se ela for gratuita, o `wrangler deploy` do OrbiJob (o 6º cron) **será recusado**; se for paga, passa. Ou seja, um
deploy que falha por limite de cron indica plano gratuito. Isso não substitui a conferência no painel.

### Limites e custo (documentação oficial da Cloudflare, lida em 2026-10-10)
| | Gratuito | **Pago (Workers Paid)** | Uso do OrbiJob |
|---|---|---|---|
| CPU por Cron Trigger | 10 ms | **15 min** (intervalo ≥ 1 h) | uma passada de revalidação: leituras e 3 consultas de status; CPU real **não medida** |
| Subrequests por invocação | 50 | **10.000** | dezenas (3 lotes de status + gravações + lease) |
| Crons por conta | 5 | 250 | 1 novo |
| Preço | — | **US$ 5/mês mínimo por conta** + uso acima do incluído (10 mi requisições, 30 mi ms de CPU) | 4 passadas/dia: dentro do incluído |

**Custo esperado: o mínimo de US$ 5/mês, se a conta ainda não for paga** (se já for, custo adicional ≈ 0). Estimativa, não confirmação.

**O cron de 6 em 6 horas é adequado:** 4 execuções/dia, 1 por vez (a lease impede sobreposição), muito acima do intervalo mínimo de 1 h
do Jobicy, e cada vaga é revalidada 12 vezes dentro da janela de 72 h do app.

## 2. Configuração final recomendada (`worker/wrangler.toml`, já na `main`)
* `name = "orbijob-jobicy-sync"`, `main = "src/index.ts"`, sem endereço público (`workers_dev = false`, `preview_urls = false`, sem rotas).
* **Um** cron: `0 */6 * * *` (00, 06, 12, 18 UTC).
* `[vars] SYNC_MODE = "revalidate"` (única variável). **Nenhum** `SYNC_MAX_NEW_JOBS`, nada de modo `full`.
* Logs (`[observability] enabled = true`): só contagens, classes de erro e o modo (testado: sem chave, sem texto de vaga, sem URL).
* Sem bindings (KV, D1, R2, filas, Durable Objects, serviços).
* Secrets (fora do arquivo): `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY`.
* Cada item acima é verificado por `worker/test/deploy-config.test.ts`; o e2e do CI roda esta configuração no workerd e exige 0 chamadas
  ao feed, 0 vagas importadas e 1 linha de `sync_runs`.

**Proteções já testadas:** lease atômica (um vencedor), 1 passada por hora entre os modos, falha de status nunca fecha vaga,
lotes anteriores permanecem, chave errada para antes de falar com o Jobicy, nenhuma tabela de usuário é tocada, o Worker nunca usa
`DELETE`, as 299 vagas existentes só têm `last_checked_at` movido (e só se a fonte confirmar) ou `status = closed` (só se a fonte confirmar).

## 3. Credencial exclusiva do Worker
**Não usar:** a chave legada `service_role` (exposta em 2026-10-10), a `orbijob_ingest_local` (usada pelos scripts locais) nem a
`default`. O Worker recebe uma chave `sb_secret_` **só dele**, `orbijob_sync_worker`, revogável sem afetar mais nada.

* **Criar a chave** (ação sua, no painel): Supabase → Project Settings → API Keys → *Secret keys* → **New secret key** → nome
  `orbijob_sync_worker`. Não copie o valor para lugar nenhum. (Alternativa: me autorizar a criá-la pela API de gerenciamento da CLI já logada.)
* **Permissões mínimas:** uma chave secreta do Supabase tem o papel `service_role`, e o que ela alcança é decidido pelos *grants* do
  banco (migration 6): `jobs` (select, insert, update, delete), `job_sources` e `sync_runs` (select, insert, update), `resumes` (select).
  Dados de usuário ficam **fechados**. O modo `revalidate` só precisa de: `select`+`update` em `jobs`, `select`+`insert`+`update` em
  `sync_runs`. O `delete` em `jobs` não é usado pelo Worker e é o único privilégio "a mais": uma chave vazada poderia apagar vagas
  (e, por `on delete cascade`, favoritos). **Endurecimento proposto (NÃO criado nem aplicado):** migration que revoga `delete` em
  `jobs`/`job_clusters` do `service_role`. Só com sua autorização.
* **Teste de autenticação sem alterar dados** (só `GET`): `node worker/scripts/worker-key-check.mjs --from-cli`. Reprova se a chave
  não for `sb_secret_`, se for a legada/da ingestão/`default`, se não ler `job_sources`/`jobs`/`sync_runs`, ou se conseguir ler
  **qualquer** tabela de usuário. A chave só existe na memória do processo (testado: nunca aparece na saída, em argumento ou arquivo).

## 4. Checklist de implantação (reproduzível; só com sua autorização)
Antes de tudo: **prazo** (primeira vaga expira em **2026-10-13 07:32 UTC**) e **hora**: evite as 00/06/12/18 UTC (a primeira execução do cron).

- [ ] **1. Confirmar Workers Paid** (você): Cloudflare → Workers & Pages → Plans (ou Billing). Se for gratuito, a contratação é sua.
- [ ] **2. Criar a chave `orbijob_sync_worker`** (você, painel) e validar: `node worker/scripts/worker-key-check.mjs --from-cli` → `APROVADA`.
- [ ] **3. Deploy** (modo revalidate já no arquivo): `cd worker && npx wrangler deploy`. A saída deve listar o schedule `0 */6 * * *`
  e a variável `SYNC_MODE ("revalidate")`. Se recusar por limite de cron, o plano é gratuito: pare.
- [ ] **4. Secrets** (stdin, a chave nunca aparece): `node worker/scripts/worker-secrets.mjs --from-cli` (ensaio, não envia) e depois
  `node worker/scripts/worker-secrets.mjs --from-cli --apply --yes`. Conferir: `npx wrangler secret list --name orbijob-jobicy-sync`
  (deve mostrar os 2 nomes, nunca valores). Se o cron disparar antes dos secrets, o Worker só registra `config_invalid`; nada é gravado.
- [ ] **5. Confirmar que o cron está ativo:** `npx wrangler deployments list --name orbijob-jobicy-sync` e a lista de schedules do Worker
  (painel: Worker → Settings → Triggers → Cron Triggers: `0 */6 * * *`).
- [ ] **6. Acompanhar a primeira execução** (próxima 00/06/12/18 UTC): `npx wrangler tail orbijob-jobicy-sync --format json`
  (eventos `sync_start` com `"mode":"revalidate"` e `sync_ok`). Sem tail, o painel (Workers Logs) mostra o mesmo.
- [ ] **7. Nenhuma vaga nova:** `select count(*) from jobs;` deve continuar **299**; `select status, scope, fetched, upserted, closed from sync_runs order by started_at desc limit 1;`
  deve ser `ok`, `revalidate`, `0`, `0`, `0` (ou o número de fechadas confirmadas).
- [ ] **8. Validade renovada:** `select min(last_checked_at), max(last_checked_at) from jobs where status='open';` — o mínimo deve ser
  posterior ao início da execução. (A cada 6 h o mínimo anda; a janela de 72 h passa a ser renovada sozinha.)
- [ ] **9. Desativar rápido, se algo estiver errado** (do mais leve ao mais completo):
  1. `npx wrangler secret delete SUPABASE_SERVICE_ROLE_KEY --name orbijob-jobicy-sync` (o Worker passa a falhar na configuração e **não grava nada**);
  2. `npx wrangler delete --name orbijob-jobicy-sync` (remove o Worker e o cron; ou painel: Settings → Triggers → apagar o cron);
  3. revogar `orbijob_sync_worker` no painel do Supabase;
  4. se alguma vaga estiver errada no catálogo: `update public.job_sources set can_redistribute = false where id = 'jobicy';`.
  Nada disso apaga vagas nem dados de usuário.

## 5. Ações que dependem de você
1. Confirmar/contratar o Workers Paid (cobrança).
2. Criar a chave `orbijob_sync_worker` no painel do Supabase (ou me autorizar a criá-la).
3. Autorizar o deploy e o envio dos secrets (passos 3 e 4).
4. (Opcional) autorizar a migration de endurecimento que revoga `delete` do `service_role` em `jobs`/`job_clusters`.
5. Ampliar o catálogo (`SYNC_MODE=full`) é uma etapa **separada**, depois de a revalidação estar rodando.

## 6. Pendências técnicas
* CPU real da passada no Cloudflare não medida (esperado muito abaixo do limite; a primeira execução mostra no painel).
* Sem alerta automático de falha repetida; o sinal é `sync_runs` e o prazo de 72 h do app.
* O Worker ainda não foi exercitado contra o gateway hospedado com a chave `sb_secret_` própria (o teste de autenticação acima cobre a leitura; a primeira execução cobre a escrita).
* A lease continua sem token de fencing (ver `JOBICY_WORKER.md`).
