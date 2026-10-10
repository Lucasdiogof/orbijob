# Jobicy: sincronização automática e validade das vagas (Etapa H)

Estado de partida: 299 vagas publicadas (`can_redistribute = true`), Worker implementado e **não implantado**, nenhum cron. Esta etapa
é só código local e testes; nada foi implantado, contratado nem escrito no banco.

## 1. Auditoria do Worker (o que já funciona)

| Item | Situação |
|---|---|
| Paginação e limites | cursor opaco, 100 por página, ritmo de 1 req/s, teto `SYNC_MAX_PAGES` (padrão 40; o feed de 7 dias tem ~7 páginas), cursor expirado (HTTP 400) reinicia **uma vez** |
| Deduplicação | `Deduper` por URL canônica/impressão digital + upsert por `(source_id, external_id)`; reprocessar não duplica |
| Falhas HTTP/timeout | retry com espera exponencial, `Retry-After` respeitado, classe de erro registrada; falha **nunca** fecha vaga |
| Execuções simultâneas | lease atômica por chave primária (1 vencedor garantido em PostgREST real); 1 passada por hora |
| Reexecução | idempotente (testado); vaga fechada que volta ao feed é reaberta |
| Logs | só contagens e classes de erro; sem conteúdo de vaga, URL ou chave (testado) |
| Limites do Jobicy | no máximo 1 passada/hora (6 h no cron); páginas em sequência |
| Vagas removidas/desconhecidas | ausência do feed **não** fecha; o endpoint de status decide: `closed` fecha, `active` confirma, `unknown` ou sem resposta não muda nada |
| Currículos/candidaturas/favoritos | o Worker só usa as tabelas `jobs`, `job_sources` e `sync_runs`, e **nunca** `DELETE` (testado) |

## 2. O que faltava e foi implementado nesta etapa

**Lacuna:** uma vaga que saiu do feed de 7 dias e continuava ativa na fonte nunca recebia nova data de verificação, e a interface
mostrava como aberta qualquer vaga `open`, por mais antiga que fosse a última confirmação. Sem Worker rodando, as 299 vagas
ficariam "abertas" para sempre.

1. **`confirmOpen`** (`worker/src/store/supabase.ts`): quando o endpoint de status responde `active`, só `last_checked_at` é movido.
   Vagas vistas no feed já tinham a data movida pelo upsert.
2. **Revalidação por lote** (`worker/src/sync.ts`): cada lote de 100 aplica o que provou (fecha as `closed`, confirma as `active`)
   antes do próximo; uma falha num lote posterior **não** desfaz o anterior. Contadores novos `confirmed` e `unverified` no log
   (não há coluna na `sync_runs`).
3. **Estados de verificação** (`worker/src/freshness.ts`): `fresh` (≤ 12 h), `aging` (≤ 72 h), `expired` (> 72 h), `unverified`
   (sem data). Com o cron de 6 h, 12 h cobre uma passada perdida e 72 h cobre um fim de semana de falhas.
4. **Interface**: o catálogo do app só pede vagas com `last_checked_at` dentro de 72 h
   (`SupabaseJobCatalogRepository.maxVerificationAge`). Vaga vencida **some da lista** e **volta sozinha** assim que uma verificação a
   confirma; nada é apagado nem fechado só por vencer. O contrato com PostgREST real cobre isso (vaga 12 do seed).

> **Consequência importante:** as 299 vagas foram verificadas em 2026-10-10 (≈ 04:58 UTC, gravação; checagem de status às 06:57).
> **Sem o Worker rodando, elas deixam de aparecer no app em 2026-10-13 ≈ 05:00 UTC.** É o comportamento desejado (não afirmar
> validade que ninguém garante), mas liga a implantação do Worker a um prazo.

### Proteção equivalente no banco (migration proposta, NÃO criada nem aplicada)
O filtro acima vale para o app. Qualquer outro cliente que leia `jobs` com a chave pública ainda vê vagas vencidas. Se quisermos
impor no banco, a política `jobs_read` receberia `and jobs.last_checked_at > now() - interval '72 hours'`. Fica documentada como
proposta; só com autorização e nova migration.

## 3. Frequência recomendada
**A cada 6 horas** (`0 */6 * * *`, já em `wrangler.toml`). O Jobicy pede no máximo 1 passada/hora e diz que algumas por dia bastam;
o feed cobre 7 dias; 4 passadas/dia dão 12 tentativas dentro da janela de 72 h. Mais frequente não traz vaga nova relevante e só
gasta cota.

## 4. Cloudflare: requisitos e custo
Valores oficiais conferidos em `docs/JOBICY_WORKER.md` (leitura da documentação da Cloudflare em 2026-10-09):
* **Plano Workers Paid é obrigatório** (US$ 5/mês, mínimo da conta). No gratuito, o Cron tem 10 ms de CPU e 50 subrequests por
  invocação, abaixo de uma passada. No pago: até 15 min de CPU (intervalo ≥ 1 h), 10.000 subrequests, 15 min de relógio (o Worker se
  limita a 12 min).
* **Uso estimado por passada:** ~7 páginas do feed + gravações (≤ 3 por página) + leitura dos ids abertos + lotes de status
  (299 vagas = 3 lotes) + lease: **dezenas de subrequests**, bem abaixo de 10.000. Num ensaio local, a passada de 7 páginas usou
  ~0,4 s de CPU de Node (inclui a inicialização do Node; CPU real no Worker **não medida**).
* **Custo adicional:** 4 passadas/dia ficam longe dos 10 milhões de requisições e 30 milhões de ms de CPU incluídos no plano pago.
  Custo esperado: **só o mínimo de US$ 5/mês**. Supabase: tráfego desprezível.
* **Secrets (2):** `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY`. Recomendado: uma chave `sb_secret_…` **exclusiva do Worker**
  (nunca a legada `service_role` exposta em 2026-10-10 e nunca a da ingestão local).
* **Permissões mínimas no banco:** as da migration 6 (já aplicada): `select/insert/update` em `job_sources` e `sync_runs`;
  `select/insert/update/delete` em `jobs`. O Worker não usa `delete` em nenhum lugar.
* **Rollback do Worker:** `wrangler delete` (ou remover o cron) para a sincronização; `can_redistribute=false` esconde o catálogo na
  hora; secrets são removíveis com `wrangler secret delete`.

## 5. Plano de implantação (nada executado)
Sequência detalhada em "Compatibilidade com as 299 vagas e sequência segura" (seção 5b). Resumo:
1. Merge do PR #57.
2. Revalidação local única das 299 (`scripts/revalidate-local.mjs`), com autorização.
3. Workers Paid + chave `sb_secret_` exclusiva do Worker (autorizações do dono) e deploy com o cron `0 */6 * * *` **em `revalidate`**
   (fixado no `wrangler.toml`); observar a primeira execução (`wrangler tail`) e conferir `sync_runs`.
4. Critérios de sucesso: `sync_runs.status = 'ok'`, `closed + confirmed + unverified` coerentes, nenhuma vaga fechada sem `closed` da
   fonte, nenhuma vaga nova, sem erro 401/403.
5. Expansão do catálogo (`SYNC_MODE=full`, `SYNC_MAX_NEW_JOBS` pequeno) só depois, em um commit revisado e com autorização.
6. Rollback: `wrangler delete`/remover cron; `can_redistribute=false` se algo exposto estiver errado.

## 5b. Dois modos explícitos (PR #57)

| | **A. Revalidação** (`SYNC_MODE=revalidate`) | **B. Sincronização completa** (`SYNC_MODE=full`) |
|---|---|---|
| Lê o feed do Jobicy | **não** | sim (páginas, ritmo de 1 req/s) |
| Grava vaga nova | **nunca** | sim (upsert), limitável por `SYNC_MAX_NEW_JOBS` |
| Consulta o endpoint de status | sim, só das vagas abertas já gravadas | sim, só das que saíram do feed |
| Fecha | só as que a fonte responde `closed` | idem |
| Move `last_checked_at` | só das que a fonte responde `active` | das vistas no feed e das `active` |
| Falha do status | run `failed` (nada alterado) ou `partial` (lotes anteriores ficam) | idem (`partial`) |
| `job_sources`, `can_redistribute`, tabelas de usuário | nunca tocados | nunca tocados |

* **O modo é explícito.** `wrangler.toml` fixa `SYNC_MODE = "revalidate"` em `[vars]`; um teste e um e2e no CI garantem que o que vai
  para produção importa **nada**. Para ampliar o catálogo é preciso editar essa linha para `full` em um commit revisado. Valor
  inválido é erro de configuração antes de qualquer requisição. Sem a variável (testes, ensaios locais) o padrão é `full`, por
  compatibilidade; a configuração implantada nunca depende desse padrão.
* **Expansão controlada.** `SYNC_MAX_NEW_JOBS=N` (só `full`) limita quantas vagas **ainda não gravadas** entram por passada; as
  já gravadas continuam sendo atualizadas e as demais ficam para a passada seguinte (o log traz `skippedNew`). `0` não adiciona nada.
  Se os ids gravados não puderem ser lidos, nada é adicionado. Além disso `SYNC_MAX_PAGES=1` limita a ~100 vagas mais novas.
  Como a fonte está publicada, **toda vaga importada fica pública na hora**: por isso a expansão é uma decisão separada e gradual
  (por exemplo `SYNC_MAX_NEW_JOBS=50` na primeira passada completa).
* **Regras do Jobicy preservadas:** no máximo 1 passada por hora (a lease vale entre os dois modos: uma revalidação logo após
  uma sincronização completa é adiada), páginas em sequência, status em lotes de 100, nenhum 4xx/5xx tratado como encerramento.

### Como executar SOMENTE a revalidação
* **Local, uma vez (antes de qualquer deploy):** `node worker/scripts/revalidate-local.mjs preflight` (só leitura) e depois
  `node worker/scripts/revalidate-local.mjs run --yes`. Usa o mesmo código do Worker em modo `revalidate` (fixo no script), a chave
  `sb_secret_` exclusiva lida da CLI logada só na memória, e **reprova** se o conjunto de vagas mudar, se aparecer transição
  diferente de `open → closed`, se o número de fechadas divergir do informado ou se a fonte mudar. Ensaiado em processo real contra
  um servidor local de mentira (`worker/test/revalidate-runner.test.ts`).
* **Em produção:** o cron do Worker implantado já roda em `revalidate` (valor fixado no `wrangler.toml`).

### Compatibilidade com as 299 vagas e sequência segura
As 299 foram gravadas em 2026-10-10 ≈ 04:58 UTC; com a janela de 72 h elas **somem do app em 2026-10-13 ≈ 05:00 UTC** se nada as
revalidar. A janela **não** foi ampliada. Sequência recomendada:
1. Merge do PR #57 (nada muda no banco).
2. **Revalidação local única** (acima), com sua autorização: confirma as 299 (estão `active`), move as datas e empurra o vencimento
   72 h adiante. Pode ser repetida manualmente enquanto o Worker não existe.
3. Plano Workers Paid + chave exclusiva do Worker (suas autorizações) → deploy com o cron em `revalidate`: a validade passa a ser
   renovada a cada 6 h.
4. Só então, e separadamente, ampliar o catálogo: commit alterando `SYNC_MODE` para `full` com `SYNC_MAX_NEW_JOBS` pequeno.
5. **Adiar o filtro no app** (alternativa, se a ordem acima atrasar): o build aceita `--dart-define=JOB_MAX_VERIFICATION_HOURS=0`,
   que **desliga** o filtro de 72 h; qualquer outro valor é ignorado e continua 72. É um interruptor temporário de build, não uma
   janela maior: remova-o assim que a revalidação estiver operacional.

### Revisão de segurança (resumo)
* **Concorrência/lease:** igual à passada completa (chave primária atômica; TTL 20 min > orçamento 12 min > teto da plataforma 15 min).
  Uma execução antiga que gravasse depois de uma nova só pode: mover `last_checked_at` (idempotente) ou fechar uma vaga que a fonte
  ainda diga `closed` (se ela voltou ao feed, a próxima passada completa a reabre). Sem fencing token; não há risco de duplicata.
* **Falhas parciais:** o que cada lote provou fica gravado; falha do status → `failed`/`partial`, nunca fechamento.
* **Timeout/limites de API:** timeout vira classe `timeout`; 429 respeita `Retry-After`; 100 ids por consulta, ritmo de 1 req/s.
* **Autenticação:** chave errada para na lease, antes de qualquer pedido ao Jobicy (testado); a chave JWT legada é recusada.
* **Logs:** só contagens, classes de erro e o modo; nunca chave, URL de vaga ou texto.
* **Rollback sem apagar nada:** `wrangler delete`/remover o cron; `can_redistribute=false` esconde o catálogo; o Worker nunca usa
  `DELETE` (favoritos têm `on delete cascade` para `jobs`, então apagar vagas apagaria favoritos: testado).

## 6. Riscos restantes
* CPU real no Cloudflare não medida; sem alerta de falha repetida (o único sinal é `sync_runs` e o prazo de 72 h do app).
* O gateway hospedado com chave `sb_secret_` pelo Worker ainda não foi exercitado (a ingestão local usou a CLI).
* Um processo antigo depois do TTL da lease continua sem token de fencing (ver `JOBICY_WORKER.md`).
* O limite de 3.000 ids por passada no status é muito acima do catálogo atual; ordenar os mais antigos primeiro só importa se o
  catálogo crescer.
