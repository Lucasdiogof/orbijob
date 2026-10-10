# Descoberta incremental de vagas novas do Jobicy

> **Estado: implementada e testada, DESLIGADA em produção.** Nada é importado até o proprietário autorizar (seção 7). O merge deste PR não liga nada:
> o agendamento depende da variável `JOBICY_DISCOVERY_ENABLED = true`, que não existe, e a execução manual exige uma frase de confirmação.

## 1. Separação de responsabilidades
| Trabalho | O que faz | Onde roda | Escreve em `jobs` |
|---|---|---|---|
| **Revalidação** (já ativa) | pergunta o status das vagas **já gravadas**; fecha as encerradas, carimba as ativas | Supabase Cron (principal) + GitHub Actions (contingência) | só `status` e `last_checked_at` de vagas `open` |
| **Descoberta** (esta proposta) | lê o feed do Jobicy e **insere vagas que ainda não existem** | GitHub Actions `jobicy-discover.yml` | **somente INSERT**; nunca atualiza, fecha, reabre nem apaga |

As duas compartilham a lease do banco (uma passada por hora por fonte, mais o `running`/`too_soon` da seção 4), então nunca consultam o Jobicy ao mesmo tempo.

## 2. Por que GitHub Actions (e não Supabase Cron, Worker ou Edge Function)
| Opção | Avaliação |
|---|---|
| **Supabase Cron + SQL (como a revalidação)** | Sem credencial e sem serviço externo, mas a descoberta precisa de toda a normalização que hoje está em TypeScript e testada com payloads reais (HTML → texto, regiões/países, salário plausível, fingerprint, URL canônica, dedupe). Portar para SQL cria uma segunda implementação que diverge. A revalidação coube em SQL porque a decisão dela é minúscula; esta não. Também traria páginas grandes (descrições em HTML) para dentro do `pg_net`. **Descartada.** |
| **Edge Function do Supabase** | Reaproveitaria o TypeScript, mas a chave que a plataforma injeta por padrão é a `service_role` legada exposta em 10/10. **Descartada.** |
| **Cloudflare Worker** | Os cinco cron triggers gratuitos da conta estão ocupados e o plano pago não está autorizado. **Descartada.** |
| **GitHub Actions (escolhida)** | Reaproveita `runSync`, o conector, a lease, o store e o runner (`discover-local.mjs` é irmão de `revalidate-local.mjs`). Gratuito em repositório público. O agendador do GitHub atrasa (≈3 h nas primeiras execuções, `docs/GITHUB_SCHEDULE_DIAGNOSTIC.md`), mas **a descoberta tolera isso**: o feed cobre 7 dias, então perder execuções por dias só adia a entrada de vagas, não perde nenhuma. É o contrário da revalidação, cujo prazo é de 72 h e por isso ficou no Supabase. |

O custo da escolha é uma credencial: a chave `sb_secret_` do environment `jobicy-revalidation` (a mesma da contingência de revalidação, sem passo manual novo). Ela tem só os privilégios da migration 7: lê o catálogo, **insere** e atualiza `jobs`, escreve `sync_runs`; **não apaga**, não toca em `job_sources` nem em dados de usuário (prova em `worker/test/discovery-db.test.ts`).

## 3. Regras (cada uma tem teste)
* **Endpoint oficial apenas:** `GET https://jobicy.com/api/v2/remote-jobs?count=100` (cursor, mais novo primeiro) e `.../status?ids=` (≤100 ids). Sem scraping, sem CAPTCHA, sem outro host (o conector rejeita URLs fora de `jobicy.com`). Uma passada por hora, páginas em sequência a 1 req/s.
* **Atribuição e link:** a fonte continua `jobicy`/`CONDITIONAL` com "Remote jobs via Jobicy"; `original_url` e `apply_url` são a URL do Jobicy; nada é apresentado como vaga própria.
* **Identificação estável:** `(source_id, external_id)` único; `external_id` é o id numérico do Jobicy (só `^[1-9][0-9]{0,15}$`).
* **Não reimporta:** antes de inserir, lista tudo que já está gravado (qualquer status). Id conhecido → ignorado (`ja_conhecidas`). Duplicata por fingerprint/URL de uma vaga **viva** → ignorada (`duplicadas`); uma vaga **fechada** não esconde um novo anúncio da mesma empresa e título.
* **Idempotente e à prova de corrida:** o insert é `INSERT ... ON CONFLICT (source_id, external_id) DO NOTHING` (`Prefer: resolution=ignore-duplicates`). Se outro escritor inserir o mesmo id no meio da passada, a linha dele fica intacta e a passada conta como já conhecida. Rodar duas vezes não muda nada (teste de snapshot byte a byte).
* **Não sobrescreve nada:** não há `UPDATE` nem `merge-duplicates` neste modo (testes: nenhum PATCH, toda escrita pede `ignore-duplicates`; mutação trocando para `merge-duplicates` reprova vários testes). Vaga existente com dados melhores que o feed não é tocada.
* **Não importa encerradas:** antes do insert, cada lote de candidatas passa pelo endpoint de status; só entra quem responde `active`. `closed`, `unknown` e sem resposta ficam de fora (`inativas`) e são perguntadas de novo na passada seguinte. Falha do endpoint de status → nenhuma vaga daquela página entra.
* **Falhas:** HTTP 4xx/5xx, timeout e JSON malformado encerram a passada como `failed`/`partial` (páginas já inseridas ficam; nada é fechado nem alterado); cursor expirado (HTTP 400) reinicia a travessia uma vez; registros inválidos são rejeitados e contados sem parar a passada; sem conseguir listar o que já existe, **não insere nada**.
* **Limites:** `SYNC_MAX_NEW_JOBS` (padrão **200** por passada, o resto fica para a próxima) e `SYNC_MAX_CATALOGUE` (padrão **4000** vagas gravadas; ao atingir, a passada termina `partial` com `error_class = catalogue_full`, código de saída 7 e um alerta próprio). Orçamento de 3 min por passada; corte duro de 4 min.
* **Privilégios:** `INSERT` em `jobs` e escrita em `sync_runs` com a chave da migration 7. A fonte não é publicada nem escondida pela descoberta; uma vaga nova fica visível no app assim que entra, porque a fonte já está publicada (`can_redistribute = true`): por isso o modo é opt-in.

## 4. Execução e concorrência
* `.github/workflows/jobicy-discover.yml`: **03:47, 09:47, 15:47, 21:47 UTC** (três horas depois da revalidação das 00:17/06:17/12:17/18:17). `concurrency` impede duas execuções da própria descoberta; a lease do banco impede coincidir com a revalidação.
* Se o GitHub atrasar a descoberta para dentro de 60 min de uma revalidação, uma das duas termina `skipped (too_soon)`/`running`. Atenção: a função SQL da revalidação (`ops.jobicy_revalidate_start`) também recua se **qualquer** passada da fonte (inclusive uma descoberta) terminou há menos de 60 min; o custo é uma janela de revalidação perdida (a próxima é 6 h depois, e o app tolera 72 h). A distância de 3 h entre as agendas torna isso raro.
* Runner: `worker/scripts/discover-local.mjs` com `preflight` (somente leitura), `preview` (**simulação**: lê o feed e o status, calcula o que seria inserido, **não grava nada**, recusa-se se houve passada na última hora) e `run --yes` (uma passada real + verificação antes/depois: vagas existentes idênticas, novas = informadas, fonte inalterada, uma linha em `sync_runs`; qualquer diferença sai com código 1).
* Aceita **somente** `ORBIJOB_SUPABASE_SECRET` (`sb_secret_`); recusa a chave JWT legada; não consulta a chave de ingestão local.

## 5. Logs e métricas
Cada passada grava uma linha em `sync_runs` (`scope = 'discover'`) e imprime no resumo do Actions:
`metricas: lidas=… importadas=… ja_conhecidas=… duplicadas=… inativas=… rejeitadas=… adiadas_pelo_limite=… atualizadas=0 fechadas=0 paginas=…`

| Métrica | Onde fica |
|---|---|
| descobertas (lidas no feed) | `sync_runs.fetched` |
| importadas | `sync_runs.upserted` |
| ignoradas (já conhecidas + duplicadas) | `sync_runs.duplicates` |
| fechadas | `sync_runs.closed` (sempre 0 aqui) |
| erros HTTP / classe | `sync_runs.http_errors`, `error_class` |
| rejeitadas, inativas, adiadas pelo limite, atualizadas (sempre 0) | log estruturado e resumo do Actions (sem coluna nova: **nenhuma migration é necessária**) |

Os logs têm só contagens e classes de erro, nunca descrição de vaga, URL de usuário ou chave (teste).

## 6. Estimativas (medidas em 2026-10-10)
**Feed público:** 715 vagas em 8 páginas (publicadas de 04/10 a 10/10, ≈100 por dia). Das 715, as **299 gravadas** estão todas no feed; **416 ainda não estão gravadas**.

| Item | Estimativa |
|---|---|
| Chamadas ao Jobicy por passada | 8 do feed + 1 a 3 de status ≈ **10 a 12** (4 passadas/dia ≈ 40–50/dia), 1 req/s |
| Chamadas ao Supabase por passada | lease (3–4) + listagem do que existe (1 por 1000 vagas) + inserts (1 por 100) ≈ **10 a 20** (≈ 80/dia). O que pesa no plano gratuito é armazenamento e transferência (poucas centenas de KB por passada); o volume de requisições é desprezível. Confira os limites vigentes no painel do Supabase |
| GitHub Actions | ~1–2 min por execução × 4/dia ≈ 240 min/mês; gratuito e sem franquia em repositório público |
| Catch-up inicial | 416 novas com teto de 200/passada = 3 passadas (≈ 12–18 h) |
| Regime estável | ≈ 100 vagas novas por dia ≈ 25 por passada |
| **Armazenamento** | **≈ 38 KB por vaga** (medido: 11 MB para 299 vagas, com os índices de busca). Banco hoje: 24 MB de 500 MB. ≈ 100 vagas/dia ≈ **3,9 MB/dia** |

**Risco que a descoberta cria e que precisa de decisão:** sem remoção, o catálogo cresce ≈ 3,9 MB/dia e o teto de 4000 vagas (≈ 152 MB) seria atingido em **≈ 33 dias**, e os 500 MB do plano gratuito em ≈ 4 meses. O teto `SYNC_MAX_CATALOGUE` impede que isso estoure o banco (a descoberta para e alerta), mas **uma operação contínua exige uma política de retenção** das vagas encerradas, que hoje ninguém apaga (o `service_role` não tem DELETE, de propósito). Proposta detalhada, com medições e critérios, em `docs/JOBICY_RETENTION.md` (sujeita a autorização): um job do `pg_cron` (papel do banco, fora do alcance de qualquer chave) que remove vagas `closed` há mais de N dias **que nenhuma tabela de usuário referencia** (`saved_jobs`, `viewed_jobs`, `applications`), mantendo favoritos e candidaturas; ou, alternativa menos agressiva, esvaziar `description` das encerradas antigas. Nenhuma das duas está implementada.

## 7. O que falta para ativar com segurança (nada abaixo foi feito)
1. **Autorização explícita do proprietário** para importar vagas novas em produção.
2. Merge deste PR e do PR #65 (documentação) com o CI verde.
3. **Decidir a retenção** (seção 6) e, se aprovada, um PR de migration + job de limpeza. Recomendado antes de ligar o agendamento.
4. Simulação em produção: Actions → *Jobicy discover* → *Run workflow* → `preview` (não grava nada). Conferir `seriam_importadas` (esperado ≈ 200 limitado pelo teto, de 416 novas).
5. **Uma** importação controlada: *Run workflow* → `discover` + `confirm = IMPORTAR-NOVAS-VAGAS`. Conferir a linha `verificacao: OK`, `sync_runs`, contagem de vagas e uma amostra de títulos/URLs; as 299 existentes devem permanecer idênticas.
6. Só então definir a variável de repositório `JOBICY_DISCOVERY_ENABLED = true` (liga o agendamento) e acompanhar as duas primeiras execuções agendadas.
7. Opcional: estender o monitor (`jobicy-watchdog`) para alertar se a descoberta estiver ligada e sem execução bem-sucedida há mais de 36 h; hoje o alerta é o erro do próprio workflow (e-mail do GitHub).

## 8. Desligar e desfazer
* Desligar o agendamento: apagar a variável `JOBICY_DISCOVERY_ENABLED` (ou valor ≠ `true`). Nada precisa ser desfeito no banco.
* O que já foi importado não é removido automaticamente. Para esconder tudo imediatamente: `update public.job_sources set can_redistribute = false where id = 'jobicy';` (esconde o catálogo inteiro, inclusive as 299 originais). Para remover só as importadas por uma passada, use o `sync_runs.started_at` dessa passada com `jobs.last_checked_at`/`published_at` (operação de dono do banco, com backup, sob autorização).
* Reverter o código: reverter o PR; o modo `discover` é aditivo (não altera `full` nem `revalidate`).
