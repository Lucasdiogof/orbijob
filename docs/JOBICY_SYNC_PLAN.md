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
1. Merge deste PR (a validade de 72 h vai junto com o app).
2. Autorização do dono: assinar Workers Paid (custo) e criar a chave `sb_secret_` exclusiva do Worker.
3. Antes do deploy, um ensaio local `wrangler dev --test-scheduled` com a mesma chave (ele grava no banco hospedado, importa as
   ~690 vagas restantes do feed de 7 dias, que **ficam públicas na hora** porque a fonte está publicada, e exercita o status).
4. Deploy com o cron `0 */6 * * *`; observar a primeira execução (`wrangler tail`) e conferir `sync_runs`.
5. Critérios de sucesso: `sync_runs.status = 'ok'`, `confirmed + closed + unverified` coerentes, nenhuma vaga fechada sem `closed` da
   fonte, vagas visíveis no app, sem erro 401/403.
6. Rollback: `wrangler delete`/remover cron; `can_redistribute=false` se algo exposto estiver errado.

## 6. Riscos restantes
* CPU real no Cloudflare não medida; sem alerta de falha repetida (o único sinal é `sync_runs` e o prazo de 72 h do app).
* O gateway hospedado com chave `sb_secret_` pelo Worker ainda não foi exercitado (a ingestão local usou a CLI).
* Um processo antigo depois do TTL da lease continua sem token de fencing (ver `JOBICY_WORKER.md`).
* O limite de 3.000 ids por passada no status é muito acima do catálogo atual; ordenar os mais antigos primeiro só importa se o
  catálogo crescer.
