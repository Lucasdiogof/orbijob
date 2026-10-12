# Política de frescor das vagas (12/10/2026)

Uma vaga só aparece no app se `status = 'open'` **e** `last_checked_at` tem menos de 72 h (`worker/src/freshness.ts`, `app` aplica o mesmo corte).
`last_checked_at` só anda quando **a própria fonte** confirma a vaga. Ausência de evidência nunca fecha uma vaga; uma consulta que falhou nunca a confirma.

## Os seis estados

| Estado | Como é representado | Quem decide |
|---|---|---|
| Comprovadamente aberta | `open` + `last_checked_at` < 72 h | a fonte (status endpoint ou presença no feed completo/janela) |
| Ainda não revalidada | `open` + `last_checked_at` ≥ 72 h (**oculta** no app) | derivado; `ops.freshness_report()` conta |
| Desconhecida | `unknown` | `ops.expire_unseen_jobs`, quando nada prova que sumiu (ver abaixo); oculta; **recupera-se**: 200 do `/ad/{id}` (Supabase) ou nova listagem no feed (descoberta) a devolvem a `open`, com o texto |
| Comprovadamente encerrada | `closed` | a fonte: 404/410, `removed`, status "closed", ou sumiço de um feed **completo** |
| Removida da fonte | `closed` (mesmo caso; a retenção compacta em 14 d e apaga em 90 d se ninguém a referencia). `unknown`: compacta só aos **30 d** (antes, 14 d) e apaga aos 90 d se ninguém a referencia | idem |
| Verificação falhou | nada muda (`open` segue com a data antiga e a passada termina `partial`/`failed`) | 403, 429, 5xx, timeout, resposta ilegível, feed parcial |

Sem coluna nova: "tipo da última verificação" é o próprio `sync_runs` (`scope` = `discover` | `revalidate`) e "próxima tentativa" é a ordem da revalidação (a menos verificada primeiro).

## Por fonte

| Fonte | Descoberta | Como a vaga é reconfirmada | Como encerra | Quando vira `unknown` |
|---|---|---|---|---|
| Jobicy | 4x/dia (Actions) | **status endpoint** (100 ids/chamada), Supabase Cron 4x/dia + Actions de contingência | `closed` só por resposta "closed" | nunca (não expira por ausência) |
| Platsbanken (`jobtech`) | 4x/dia: faixas prioritárias + 1.200 mais novas | **`/ad/{id}`** (200 publicada, 404/410 encerrada, `removed`, janela de publicação vencida há > 36 h), do menos recentemente verificado para o mais recente. **Principal: Supabase Cron** (`ops.jobtech_revalidate_start/collect`, 02/08/14/20 :07 UTC, 600 por passada, inclui as `unknown`, que voltam a `open` se ainda publicadas). Contingência: `sources-revalidate.yml` (GitHub, 04/10/16/22 :47, até 3.000 por passada; só `open`) | 404/410/`removed`/janela vencida | `unseen > 7 d` (a revalidação não alcançou): **nunca fecha por ausência** |
| Arbeitnow | 4x/dia, **8 páginas** (≈ 1.250 anúncios, ≈ 9 dias) a 1 req/4 s | só a **presença** na janela; **não há endpoint por id** nem por slug na API (a página HTML está atrás do Cloudflare e os termos só cobrem a API: não é consultada) | sumiço **dentro** da janela lida (> 7 d) → `closed` | fora da janela (publicada antes da vaga mais antiga que a última passada `ok` viu) e > 7 d sem ver → `unknown` |
| Taiwan Jobs (`twjobs`) | 2 gatilhos/dia (extract diário às 01:00 de Taiwan) | presença no extract (1.000 registros) e o prazo `STOP_DATE` (vencido = não importa) | — | ausência do extract > 7 d → `unknown`, **nunca `closed`** (é um extract, não o cadastro completo) |
| Jobs.co.nz (`jobsconz`) | 4 gatilhos/dia (GitHub) | **`/api/v1/jobs/{id}`**: 200 vale até o `expires_at` do próprio anúncio; **404 "No live listing" = encerrada**. **Supabase Cron** (`ops.jobsconz_revalidate_*`, migration 15) a cada 3 h, 100 por passada (limite 120/min sem chave) | 404/410 ou `expires_at` vencido | `unseen > 7 d` (revalidação não alcançou) |
| Remote OK | 2x/dia | presença no feed (ele lista **tudo** que está aberto) | sumiço do feed > 7 d | nunca |
| Remotive | 1x/dia | presença no feed (lista tudo) | sumiço do feed > 7 d | nunca |

### Casos sem mecanismo confiável (documentados, não escondidos)
* **Arbeitnow, vaga mais velha que a janela:** não há como saber se segue aberta. Ela deixa de ser carimbada, o app a oculta em 72 h, e depois de 7 d vira `unknown` (nunca `closed`). Se voltar ao feed antes disso, é carimbada de novo.
* **Platsbanken, vaga que a revalidação não alcança** (fonte fora do ar por > 7 d): `unknown`, não `closed`.
* **Remote OK / Remotive:** a ausência de um feed *completo* é a evidência; se a leitura falhar, nada é julgado (a expiração exige uma passada `ok` nas últimas 36 h).
* **Duplicatas entre fontes** (mesma empresa/cargo/local em fontes distintas): hoje 2 pares em 1.788; a descoberta só deduplica dentro da fonte. Não se elimina nada só por título + empresa.

## Agendador do GitHub: o que se mediu em 12/10/2026
Das execuções agendadas esperadas entre 05:00 e 16:30 UTC, o GitHub **iniciou** apenas Jobicy discover 11:19 (previsto 09:47), Remote OK 13:30 (previsto 08:xx/05:41), Remotive 16:10 e Platsbanken revalidate 16:10 (previsto 12:47); **não iniciou** Arbeitnow 08:23 e 14:23, Platsbanken 09:31 e 15:31. Por isso: (a) a revalidação da Platsbanken passou para o Supabase Cron (que não descarta); (b) a descoberta ganhou uma segunda série de gatilhos deslocados (a lease torna a repetição inofensiva e uma passada < 1 h depois da anterior recua verde com `skipped (too_soon)`); (c) o watchdog alerta `*_schedule_missed` quando nada agendado roda em 14 h.

## Automações (estado conferido no banco e no GitHub em 12/10/2026)

| Automação | Fonte | Frequência (UTC) | Limites | Responsável por revalidar |
|---|---|---|---|---|
| `jobicy-revalidate-start/collect` (Supabase Cron) | Jobicy | 00/06/12/18 :17 (+ coleta :19–:44) | status endpoint, sem chave | sim: Jobicy |
| `jobicy-revalidate.yml` (Actions) | Jobicy | 00/06/12/18 :17 | contingência da anterior; lease 1/h | Jobicy |
| `jobicy-discover.yml` | Jobicy | 03/09/15/21 :47 | 200 novas/passada, teto 4.000 | — |
| `sources-discover.yml` (11 cron) | Taiwan Jobs 01/19 :43 e 07 :16 · Jobs.co.nz 03/09/15/21 :05 · Arbeitnow 02/08/14/20 :23 e 05/11/17/23 :37 · Remote OK 05/17 :41 e 08/20 :27 · Remotive 06 :53 e 10/22 :51 · Platsbanken 03/09/15/21 :31 e 00/06/12/18 :13 | por fonte | Arbeitnow 300 novas/passada, teto 1.500; Platsbanken 600, teto 3.500; lease 1/h por fonte | — |
| `jobsconz-revalidate-start/collect` (Supabase Cron, migration 15) | Jobs.co.nz | 01/04/07/10/13/16/19/22 :37 (+ coleta :41/:45/:52) | 100 `/api/v1/jobs/{id}` por passada | **Jobs.co.nz** |
| `jobtech-revalidate-start/collect` (Supabase Cron, migration 13) | Platsbanken | 02/08/14/20 :07 (+ coleta :10/:14/:20/:35) | 600 `/ad/{id}` por passada, a menos verificada primeiro; pg_net; lease por (fonte, hora) | **Platsbanken (principal)** |
| `sources-revalidate.yml` | Platsbanken | 04/10/16/22 :47 | contingência: até 3.000 `/ad/{id}`/passada (4 conexões, ~12 req/s medido); mesma lease | Platsbanken (reserva) |
| `sources-expire-unseen` (Supabase Cron) | Arbeitnow, Remote OK, Remotive | 04:12 | 500/lote | — |
| `jobtech-expire-unseen` (Supabase Cron) | Platsbanken e Jobs.co.nz | 04:22 | 500/lote | — (rede de segurança: só gera `unknown`) |
| `jobicy-retention` (Supabase Cron) | todas | 04:37 | compacta `closed`/`unknown` > 14 d, apaga > 90 d sem vínculo; **nunca toca `open`** | — |
| `ops-cron-history-purge` | — | 03:07 | histórico do cron | — |
| `jobicy-watchdog.yml` | todas | 05:43 e 17:43 | issue de alerta; falha o job se crítico | — |

Duas execuções da mesma fonte na mesma hora não coexistem: o id da lease é (fonte, hora) e a descoberta e a revalidação da Platsbanken ficam ≥ 2 h separadas.

## Como medir
* `select * from ops.freshness_report();` (somente leitura; só o dono do banco): verificadas, ocultas por frescor, desconhecidas e encerradas por fonte.
* Watchdog: valida o prazo de 72 h sobre as fontes verificadas uma a uma (Jobicy e Platsbanken) e vigia as execuções agendadas de cada workflow.
* Reverter a migration 12: `supabase/rollback/20261019000000_freshness_policy.down.sql` (não altera nenhuma vaga).
