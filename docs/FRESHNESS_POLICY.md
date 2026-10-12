# Política de frescor das vagas (12/10/2026)

Uma vaga só aparece no app se `status = 'open'` **e** `last_checked_at` tem menos de 72 h (`worker/src/freshness.ts`, `app` aplica o mesmo corte).
`last_checked_at` só anda quando **a própria fonte** confirma a vaga. Ausência de evidência nunca fecha uma vaga; uma consulta que falhou nunca a confirma.

## Os seis estados

| Estado | Como é representado | Quem decide |
|---|---|---|
| Comprovadamente aberta | `open` + `last_checked_at` < 72 h | a fonte (status endpoint ou presença no feed completo/janela) |
| Ainda não revalidada | `open` + `last_checked_at` ≥ 72 h (**oculta** no app) | derivado; `ops.freshness_report()` conta |
| Desconhecida | `unknown` | `ops.expire_unseen_jobs`, quando nada prova que sumiu (ver abaixo); oculta |
| Comprovadamente encerrada | `closed` | a fonte: 404/410, `removed`, status "closed", ou sumiço de um feed **completo** |
| Removida da fonte | `closed` (mesmo caso; a retenção compacta em 14 d e apaga em 90 d se ninguém a referencia) | idem |
| Verificação falhou | nada muda (`open` segue com a data antiga e a passada termina `partial`/`failed`) | 403, 429, 5xx, timeout, resposta ilegível, feed parcial |

Sem coluna nova: "tipo da última verificação" é o próprio `sync_runs` (`scope` = `discover` | `revalidate`) e "próxima tentativa" é a ordem da revalidação (a menos verificada primeiro).

## Por fonte

| Fonte | Descoberta | Como a vaga é reconfirmada | Como encerra | Quando vira `unknown` |
|---|---|---|---|---|
| Jobicy | 4x/dia (Actions) | **status endpoint** (100 ids/chamada), Supabase Cron 4x/dia + Actions de contingência | `closed` só por resposta "closed" | nunca (não expira por ausência) |
| Platsbanken (`jobtech`) | 4x/dia: faixas prioritárias + 1.200 mais novas | **`/ad/{id}`** (200 publicada, 404/410 encerrada, `removed`, janela de publicação vencida há > 36 h), do menos recentemente verificado para o mais recente, até 3.000 por passada, 4x/dia (`sources-revalidate.yml`) | 404/410/`removed`/janela vencida | `unseen > 7 d` (a revalidação não alcançou): **nunca fecha por ausência** |
| Arbeitnow | 4x/dia, **8 páginas** (≈ 1.250 anúncios, ≈ 9 dias) a 1 req/4 s | só a **presença** na janela; **não há endpoint por id** nem por slug na API (a página HTML está atrás do Cloudflare e os termos só cobrem a API: não é consultada) | sumiço **dentro** da janela lida (> 7 d) → `closed` | fora da janela (publicada antes da vaga mais antiga que a última passada `ok` viu) e > 7 d sem ver → `unknown` |
| Remote OK | 2x/dia | presença no feed (ele lista **tudo** que está aberto) | sumiço do feed > 7 d | nunca |
| Remotive | 1x/dia | presença no feed (lista tudo) | sumiço do feed > 7 d | nunca |

### Casos sem mecanismo confiável (documentados, não escondidos)
* **Arbeitnow, vaga mais velha que a janela:** não há como saber se segue aberta. Ela deixa de ser carimbada, o app a oculta em 72 h, e depois de 7 d vira `unknown` (nunca `closed`). Se voltar ao feed antes disso, é carimbada de novo.
* **Platsbanken, vaga que a revalidação não alcança** (fonte fora do ar por > 7 d): `unknown`, não `closed`.
* **Remote OK / Remotive:** a ausência de um feed *completo* é a evidência; se a leitura falhar, nada é julgado (a expiração exige uma passada `ok` nas últimas 36 h).
* **Duplicatas entre fontes** (mesma empresa/cargo/local em fontes distintas): hoje 2 pares em 1.788; a descoberta só deduplica dentro da fonte. Não se elimina nada só por título + empresa.

## Automações (estado conferido no banco e no GitHub em 12/10/2026)

| Automação | Fonte | Frequência (UTC) | Limites | Responsável por revalidar |
|---|---|---|---|---|
| `jobicy-revalidate-start/collect` (Supabase Cron) | Jobicy | 00/06/12/18 :17 (+ coleta :19–:44) | status endpoint, sem chave | sim: Jobicy |
| `jobicy-revalidate.yml` (Actions) | Jobicy | 00/06/12/18 :17 | contingência da anterior; lease 1/h | Jobicy |
| `jobicy-discover.yml` | Jobicy | 03/09/15/21 :47 | 200 novas/passada, teto 4.000 | — |
| `sources-discover.yml` (4 cron) | Arbeitnow 02/08/14/20 :23 · Remote OK 05/17 :41 · Remotive 06 :53 · Platsbanken 03/09/15/21 :31 | por fonte | Arbeitnow 300 novas/passada, teto 1.500; Platsbanken 600, teto 3.500; lease 1/h por fonte | — |
| `sources-revalidate.yml` | Platsbanken | 00/06/12/18 :47 | até 3.000 `/ad/{id}`/passada (4 conexões, ~7 req/s, 9 min); lease compartilhada com a descoberta da mesma fonte | Platsbanken |
| `sources-expire-unseen` (Supabase Cron) | Arbeitnow, Remote OK, Remotive | 04:12 | 500/lote | — |
| `jobtech-expire-unseen` (Supabase Cron) | Platsbanken | 04:22 | 500/lote | — (rede de segurança: só gera `unknown`) |
| `jobicy-retention` (Supabase Cron) | todas | 04:37 | compacta `closed`/`unknown` > 14 d, apaga > 90 d sem vínculo; **nunca toca `open`** | — |
| `ops-cron-history-purge` | — | 03:07 | histórico do cron | — |
| `jobicy-watchdog.yml` | todas | 05:43 e 17:43 | issue de alerta; falha o job se crítico | — |

Duas execuções da mesma fonte na mesma hora não coexistem: o id da lease é (fonte, hora) e a descoberta e a revalidação da Platsbanken ficam ≥ 2 h separadas.

## Como medir
* `select * from ops.freshness_report();` (somente leitura; só o dono do banco): verificadas, ocultas por frescor, desconhecidas e encerradas por fonte.
* Watchdog: valida o prazo de 72 h sobre as fontes verificadas uma a uma (Jobicy e Platsbanken) e vigia as execuções agendadas de cada workflow.
* Reverter a migration 12: `supabase/rollback/20261019000000_freshness_policy.down.sql` (não altera nenhuma vaga).
