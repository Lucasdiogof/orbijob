# Revalidação automática do Jobicy com GitHub Actions (custo zero)

**Decisão:** sem Cloudflare Workers Paid. A revalidação roda no GitHub Actions, gratuito para repositório público com runner padrão.
O Worker e o `wrangler.toml` continuam no repositório como alternativa **não implantada** (`docs/JOBICY_WORKER_DEPLOY.md`).

> **Nada é ligado pelo merge.** O agendamento só executa depois que você definir a variável `JOBICY_REVALIDATION_ENABLED = true`
> (passo 4). Hoje não existe segredo, variável nem environment.

## 1. O que existe

| Arquivo | Função |
|---|---|
| `.github/workflows/jobicy-revalidate.yml` | a cada 6 h (`17 */6 * * *`, UTC) revalida **só as vagas já gravadas**; execução manual (`workflow_dispatch`) com `check` (somente leitura, padrão) ou `revalidate` |
| `.github/workflows/jobicy-watchdog.yml` | 2×/dia (`43 5,17 * * *`) avalia o catálogo público e as execuções, e abre/atualiza/fecha uma issue de alerta |
| `worker/scripts/revalidate-local.mjs` | o mesmo script já usado na Etapa I (código do Worker, modo `revalidate` fixo): pergunta o status ao Jobicy, renova `last_checked_at` das ativas, fecha só as `closed`, deixa `unknown`/sem resposta; confere antes/depois |
| `worker/scripts/worker-key-check.mjs` | verifica a chave **somente lendo** (lê o catálogo, é recusada nas tabelas de usuário, não é a legada nem a da ingestão local) |
| `worker/scripts/jobicy-watchdog.mjs` + `watchdog-core.mjs` | o monitor |

Garantias (cada uma tem teste em `worker/test/workflows.test.ts`, `revalidate-runner.test.ts`, `sync-modes.test.ts`, `watchdog.test.ts`):
* o workflow **não tem como** pedir o modo `full`, importar vagas, usar a chave de ingestão ou a legada: o script fixa `revalidate` e os testes
  reprovam qualquer menção a `SYNC_MODE`, `first-ingestion`, `wrangler` etc. no arquivo;
* gatilhos só `schedule` e `workflow_dispatch` (nunca `push` nem `pull_request`: código de PR não roda com o segredo);
* permissões `contents: read`; ações fixadas por SHA; Node 22; `npm ci --ignore-scripts` **sem** o segredo;
* um único segredo, entregue só aos passos que o usam, dentro do environment `jobicy-revalidation`; mascarado; sem artefatos, sem `set -x`;
* `concurrency` (nunca duas ao mesmo tempo) **e** a lease do banco (1 passada por hora; uma segunda é adiada, não duplicada);
* `timeout-minutes: 10` e corte duro de 4 min no próprio script;
* nunca apaga, nunca importa, nunca toca em `can_redistribute`, `job_sources` ou dados de usuário (favoritos e candidaturas são preservados).

## 2. Custo e limites gratuitos (documentação oficial do GitHub, lida em 2026-10-10)
* **Custo mensal esperado: US$ 0.** O uso do Actions é gratuito em repositório **público** com runner padrão do GitHub (sem franquia a gastar).
  Cada execução leva ~1–2 min × 4/dia. Mesmo se o repositório virasse privado, ~180 min/mês cabem folgadamente na franquia gratuita.
* Limite de 6 h por job (usamos 10 min). Limite de enfileiramento e de concorrência muito acima do uso.
* **Supabase (plano gratuito):** ~10 requisições por execução; tráfego desprezível.
* **Jobicy:** ≤ 1 passada por hora (a lease garante), 100 ids por consulta de status, ritmo de 1 req/s.

## 3. Riscos e limitações do GitHub Actions (importantes)
1. **Atrasos e descartes:** o GitHub pode atrasar (ou, sob carga, pular) execuções agendadas, sobretudo no minuto 0; por isso `17 */6`. A janela
   de 72 h do app tolera até 11 execuções perdidas seguidas (12 tentativas por janela).
2. **Desativação automática:** em repositório público, o agendamento é **desativado após 60 dias sem atividade no repositório**. Qualquer commit/PR
   normal evita; o monitor avisa se as execuções param (`schedule_missed`). Reativar: Actions → workflow → *Enable workflow*.
3. **Branch padrão:** só roda o arquivo que está na branch padrão (`main`).
4. **Notificações de falha** vão para quem **modificou o cron por último**; por isso o monitor também abre uma issue (e falha em caso crítico).
5. O segredo vive no GitHub: quem tem acesso de escrita ao repositório pode, em princípio, alterar o workflow; o environment restrito a `main` e a
   revogação rápida da chave limitam o dano. Chave vazada → revogue `orbijob_sync_worker` no Supabase (passo "Desativar").
6. A chave tem o papel `service_role` do Supabase; o banco limita o alcance (migration 6). O `delete` em `jobs` ainda é concedido a esse papel;
   endurecimento proposto (não aplicado) em `docs/JOBICY_WORKER_DEPLOY.md`.

## 4. Como ativar (só com sua autorização; ordem importa)
1. **Chave exclusiva** (Supabase → Project Settings → API Keys → *New secret key*): nome `orbijob_sync_worker`. Não use a legada `service_role`
   nem a `orbijob_ingest_local`. Não cole o valor em chat, arquivo ou commit.
2. **Environment e segredo** (GitHub → repositório → Settings → Environments → *New environment* `jobicy-revalidation`):
   *Deployment branches* → **Selected branches** → `main`; *Environment secrets* → **Add secret** `ORBIJOB_SYNC_WORKER_KEY` = a chave.
   (Não marque "Required reviewers": as execuções agendadas ficariam esperando aprovação.)
3. **Teste sem escrita:** Actions → *Jobicy revalidate* → *Run workflow* → `action = check`. Passa quando "Check the key" e "Pre-flight" ficam verdes.
4. **Variáveis** (Settings → Secrets and variables → Actions → *Variables*, não segredos):
   `SUPABASE_PUBLISHABLE_KEY` = a chave **publishable** do projeto (pública, a mesma do app) e `JOBICY_REVALIDATION_ENABLED` = `true`.
5. **Primeira revalidação real** (opcional, para não esperar o relógio): *Run workflow* → `action = revalidate`. Depois confira (abaixo).
6. A partir daí o agendamento roda sozinho a cada 6 h e o monitor passa a funcionar.

Conferência depois da primeira real: `select count(*) from jobs;` = **299** (ou o total atual); `select status, scope, fetched, upserted, closed from sync_runs order by started_at desc limit 1;`
= `ok`, `revalidate`, `0`, `0`, (fechadas confirmadas); `select min(last_checked_at) from jobs where status='open';` recente; o resumo da execução (aba *Summary*) mostra só contagens.

## 5. Como desativar (do mais leve ao mais completo; nada apaga vagas)
1. Variável `JOBICY_REVALIDATION_ENABLED` = `false` (ou apagá-la): o agendamento passa a ser ignorado.
2. Actions → *Jobicy revalidate* → **⋯ → Disable workflow** (e o mesmo no *Jobicy watchdog*).
3. Apagar o segredo `ORBIJOB_SYNC_WORKER_KEY` (a automação passa a falhar na checagem de segredo e **não grava nada**).
4. Revogar a chave `orbijob_sync_worker` no Supabase.
5. Se alguma vaga estiver errada no catálogo: `update public.job_sources set can_redistribute = false where id = 'jobicy';` (esconde tudo, não apaga).

## 6. Alertas (monitor `jobicy-watchdog`)
Uma issue com o rótulo `jobicy-alert` é aberta/atualizada enquanto houver alerta e **fechada sozinha** quando tudo normaliza. Alertas críticos também
fazem o job falhar (e-mail de falha do GitHub).

| Alerta | Quando | O que fazer |
|---|---|---|
| `validity_warning` / `validity_critical` | a vaga verificada há mais tempo tem ≥ 48 h / ≥ 60 h (a janela é 72 h) | rodar *Run workflow* → `revalidate`; ver as causas abaixo |
| `catalog_empty` | nenhuma vaga visível publicamente | revalidar; se as vagas venceram, elas voltam ao serem confirmadas |
| `schedule_missed` | nenhuma execução agendada em 14 h | ver se o agendamento foi desativado (60 dias) e reativar |
| `no_recent_success` | nenhum sucesso em 20 h | abrir a última execução |
| `consecutive_failures` | as 2 últimas execuções agendadas falharam | idem |
| `auth_failed` | o Supabase recusou a chave (segredo ausente, errado ou revogado) | recriar a chave e atualizar o segredo |
| `database_unreachable` / `jobicy_api_errors` | banco sem resposta / API de status do Jobicy falhou (nada é fechado por causa disso) | normalmente passa sozinho; se repetir, investigar |

Consumo dos limites gratuitos: não há medidor a esgotar no Actions para repositório público; o uso (execuções, duração) fica em *Actions → Usage*.

## 7. Passos restantes para a automação ficar ativa
1. Merge do PR (não liga nada).
2. Você cria a chave e o environment/segredo (passos 1–2) e define as duas variáveis (passo 4). **Não consigo fazer isso daqui**: não há credencial do
   GitHub nesta máquina.
3. `check` → conferir → `revalidate` (ou esperar o agendamento).
4. Antes de **13/10/2026 07:32 UTC** a primeira vaga sai do app; a revalidação manual local (`node worker/scripts/revalidate-local.mjs run --yes`, com a chave da CLI)
   continua disponível como ponte.
