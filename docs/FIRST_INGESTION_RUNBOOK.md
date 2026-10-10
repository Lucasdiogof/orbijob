# Primeira ingestão real (Jobicy): sequência controlada

Cada passo que altera algo fora do repositório (Supabase, Cloudflare) exige **autorização explícita e separada** do proprietário. A ordem abaixo mantém a fonte **não publicada** (`can_redistribute = false`) durante toda a ingestão: o app não vê nenhuma vaga até a publicação, que é um passo à parte.

Estado em 2026-10-10:

| Peça | Estado |
|---|---|
| Conector Jobicy, pipeline `runSync`, `SupabaseJobStore`, ponto de entrada do Worker | no `main`; testados, inclusive contra PostgREST real e em workerd local; **Worker não publicado** |
| Flutter lendo `public.jobs` | no `main` |
| Migration 6 (`service_role_grants`) | **aplicada e auditada** (15 grants; histórico com 6 versões) |
| Linha `jobicy` em `job_sources` | **criada**: `status = CONDITIONAL`, **`can_redistribute = false`** |
| `jobs`, `sync_runs` no Supabase hospedado | **vazias** |
| Chave legada `service_role` | **exposta em 2026-10-10 (saída de ferramenta): considerar comprometida** (passo 0) |
| Secrets no Cloudflare, Cron, deploy | nada configurado |

## Passos (cada um é uma autorização separada)

- [x] Migration 6 aplicada e auditada. · [x] Fonte `jobicy` criada (não publicada).
- [ ] **0. Credencial:** criar uma chave `sb_secret_…` nova e exclusiva; desativar a chave legada `service_role`.
- [ ] **1. Primeira ingestão LOCAL e controlada** (`worker/scripts/first-ingestion-local.mjs`): uma passada, até 3 páginas, sem Cloudflare, sem cron.
- [ ] **2. Revisão dos registros gravados** (relatório do `verify` e amostra), e dos direitos de uso/atribuição (reler o "Fair Use" do README do Jobicy no dia).
- [ ] **3. Publicar o Jobicy** (`scripts/supabase/ops/publish_jobicy.sql`), só com autorização escrita do proprietário.
- [ ] **4. Plano Workers Paid** (o gratuito não suporta o cron: 10 ms de CPU, 50 subrequests).
- [ ] **5. Segredos no Cloudflare** (`wrangler secret put`), **6. deploy do Worker**, **7. cron**: somente depois dos passos 1–3.
- [ ] **8. Teste no Flutter com vagas reais** e **9. favoritos e isolamento entre usuários**.

Interruptores de emergência, do mais leve ao mais drástico: `update public.job_sources set can_redistribute = false where id = 'jobicy'` (esconde tudo no app, reversível; é o único `update` desta tabela que o repositório documenta) → remover o cron e republicar (`crons = []`) → `wrangler delete` do Worker.

## 0. Credencial exposta e substituição (decisão do proprietário)

**O que foi exposto:** em 2026-10-10 o comando `supabase projects api-keys` imprimiu a chave **legada** `service_role` (um JWT longo que começa com `eyJ`) na saída de uma ferramenta desta sessão. Ela não foi gravada em arquivo, enviada a nenhum serviço nem usada. Trate como comprometida: ela tem `BYPASSRLS` e, após a migration 6, só os 15 grants da migration (catálogo, `sync_runs`, leitura de `resumes`), **não** acessa dados de usuário. O risco real é alguém com a chave gravar ou apagar vagas e fontes.

**Chave legada x chave nova** ([guia oficial de chaves](https://supabase.com/docs/guides/api/api-keys)):

| | Legada `service_role` | Nova `sb_secret_…` |
|---|---|---|
| Formato | JWT assinado com o segredo JWT legado do projeto (o mesmo que assina `anon` e os tokens de usuário) | string opaca, não é JWT |
| Revogação | só desativando as chaves legadas (reversível) ou girando o segredo JWT (afeta sessões) | apagar a chave (irreversível) ou criar outras; **independente das demais** |
| Cabeçalho | `apikey` e `Authorization: Bearer` | **só** `apikey` (o `SupabaseJobStore` já faz isso) |

**Dependentes encontrados neste repositório e na conta:** nenhum. O CI não usa secrets; o Flutter usa só `sb_publishable_…` (e recusa chave privilegiada ao iniciar); o Worker `orbijob-jobicy-sync` **não existe** na Cloudflare (`wrangler secret list` responde "not found"); os scripts de e2e usam a publishable. Logo, desativar a legada não derruba nada.

**Estratégia recomendada (ordem importa; fonte: guia oficial, "rotating a leaked secret key"):**
1. Criar uma chave secreta nova, nome exato `orbijob-ingest-local`, em *Project Settings → API Keys* (https://supabase.com/dashboard/project/rpmlfxwebnlxnwadyvle/settings/api-keys). **Não é preciso copiá-la nem colá-la em lugar nenhum:** o runner a busca pelo nome na CLI do Supabase já logada (`supabase projects api-keys --reveal`), só em memória. Já existe uma secreta chamada `default` (criada com o projeto, sem dependentes): não a use, pois não é exclusiva. Uma chave por componente: depois, o Worker ganha a sua própria. (A CLI não cria chaves; a API de gestão cria com `POST /v1/projects/{ref}/api-keys`, mas exige um token pessoal com escopo `secrets:write`, que não deve ser extraído do login da CLI.)
2. Confirmar que nada usa a legada (o painel mostra "last used" por chave).
3. **Desativar** (não girar o segredo JWT) a chave legada `service_role` na mesma tela. É reversível e **não** invalida sessões de usuário nem a chave `anon`/publishable. **Não** girar nem revogar o segredo JWT: isso só vale se houver suspeita de uso malicioso e, nesse caso, pode deslogar usuários (aguardar >1h15 após a expiração dos tokens de 1h).
4. A legada `anon` (também impressa) é pública por desenho; pode continuar ativa.

O runner local **recusa** a chave legada e qualquer chave que não seja `sb_secret_…`.

## 1. Primeira ingestão local e controlada

Roda o **mesmo código do Worker** (`runScheduledSync`), em processo local, **sem Cloudflare, sem cron, sem deploy**: `cd worker && node scripts/first-ingestion-local.mjs <modo>`.

| Garantia | Como |
|---|---|
| Credencial fora de logs, arquivos e argumentos | por ordem: `ORBIJOB_SUPABASE_SECRET` (só na memória do processo); a chave `orbijob-ingest-local` lida da CLI logada (a saída da CLI é capturada em memória e descartada, só o valor dessa chave é usado); ou, com `--prompt-key`, prompt **sem eco**. O logger oculta a chave; nenhuma mensagem de erro a contém |
| Chave certa | só aceita `sb_secret_…`; recusa a legada `service_role` e a publishable **antes de qualquer requisição** (a chave recusada não é enviada a ninguém) |
| Uma única execução | o `preflight` exige `jobs` e `sync_runs` vazias; depois da passada elas deixam de estar; a trava de hora do Worker (`lease.ts`) reforça |
| Limites | até 3 páginas (≤ 300 vagas; teto 5, recusa valores maiores); **orçamento de 3 minutos** (a passada se encerra sozinha como `partial/deadline` e não fecha nada) e corte duro em **4 minutos** |
| Não publica | nada no runner toca `can_redistribute`; o preflight exige `false` e o `verify` confere que continua `false` |
| Atribuição | preflight e verify exigem o texto `Remote jobs via Jobicy (https://jobicy.com)` na fonte |
| URLs | cada `original_url`/`canonical_url` precisa ser `https` em `jobicy.com` |
| Duplicidade | chave única `(source_id, external_id)`; avisos para `fingerprint` e `canonical_url` repetidos |
| Auditoria | exatamente 1 linha em `sync_runs`, encerrada, com `fetched/upserted/duplicates/closed/http_errors/error_class`; sem HTML nas descrições; nenhuma vaga de outra fonte |
| Visão pública | com a chave publishable, `jobs` continua com **0** linhas visíveis (política `jobs_read`) |

**Resultado esperado:** com o teto de 3 páginas e um feed mais longo, a passada termina `partial` com `error_class = max_pages`. Isso é o normal da primeira ingestão limitada: guarda as vagas lidas, **não fecha nada** e não bloqueia a publicação. Falhas de verdade (`failed`, erro HTTP, prazo) aparecem como falha/aviso e bloqueiam a publicação.

Sequência: `preflight` (somente leitura) → `run --yes` (grava, depois roda o `verify` sozinho) → `verify` quando quiser reler. Todas as saídas são contagens e booleanos, sem conteúdo de vagas.

**Recuperação se falhar:**
* *Antes de gravar* (preflight reprovado, credencial recusada, Jobicy fora do ar): nada foi escrito; corrigir a causa e repetir.
* *Passada `failed`/`partial`* (ex.: `http_429`): as gravações são *upserts* idempotentes, então repetir é seguro; a trava impede nova passada por 60 min. Se o `verify` apontar dados errados, **parar**: a fonte continua não publicada (invisível ao app) e nada precisa ser desfeito às pressas.
* *Processo interrompido* (limite de 4 min, queda): pode ficar uma linha `running` em `sync_runs`; ela vira `failed` sozinha após 20 min (`stale_lock`). Como o preflight exige `sync_runs` vazia, uma nova tentativa exige limpar os restos: **com autorização do proprietário**, apagar `jobs` do `jobicy` e as linhas de `sync_runs` do `jobicy` (o `service_role` tem `delete` em `jobs`; em `sync_runs` a limpeza é feita pelo proprietário/`postgres`, e só da própria tentativa).
* *Dados claramente errados:* manter `can_redistribute = false`, apagar as vagas do `jobicy` (com autorização) e corrigir o conector antes de repetir.

## 2. Revisão dos registros (somente leitura)
```sql
select status, fetched, upserted, duplicates, closed, http_errors, error_class, started_at from public.sync_runs order by started_at desc limit 3;
select status, count(*) from public.jobs where source_id = 'jobicy' group by status;
select external_id, title, company, work_mode, country, geo_restrictions, salary_min, salary_currency, salary_period, published_at, original_url
from public.jobs where source_id = 'jobicy' order by published_at desc nulls last limit 10;
```
Conferir: `sync_runs` com `ok`; links em `jobicy.com`; salários só com moeda e período; nenhum HTML; nenhuma vaga de outra fonte.

## 3. Publicar (operação separada; exige autorização escrita do proprietário)
A linha nasce e permanece com `can_redistribute = false`. Publicar é rodar `scripts/supabase/ops/publish_jobicy.sql`, que **se recusa** a funcionar sem a trava `orbijob.publish_jobicy` (valor `EU-REVISEI-OS-REGISTROS-E-AUTORIZO`, definido na mesma sessão antes do script), sem uma passada concluída (`ok`, ou `partial` só por `max_pages`) e sem nenhuma `failed`/`running`/parcial por outro motivo, sem vagas, ou com URL fora de `jobicy.com`. Nenhum outro arquivo do repositório liga a flag (`scripts/supabase/no_premature_publish.test.mjs` falha no CI). A decisão se apoia no "Fair Use" do README do Jobicy (não é um contrato; volume fora do normal exige falar com a fonte).

## 4–7. Cloudflare (nada feito; só depois dos passos 1–3)
* **Plano:** Workers Paid (US$ 5/mês) é obrigatório para o cron ([limites](JOBICY_WORKER.md)). Decisão e pagamento do proprietário.
* **Segredos:** uma chave `sb_secret_…` **própria do Worker** (não a do passo 1) e a URL, via `wrangler secret put`, digitados no terminal do proprietário; nunca em arquivo ou chat.
* **Cron:** no máximo uma passada por hora (a fonte pede); valor recomendado `0 */6 * * *` (já no `wrangler.toml`). O cron só existe depois do `wrangler deploy`, que exige autorização separada.

## 8–9. Flutter com vagas reais
Só depois da publicação. Abrir o app (`scripts\windows\run_orbijob_web.ps1`) → Explorar → **Ver vagas recentes** → "Fonte: Jobicy" → abrir uma vaga → **Abrir anúncio original** → salvar nos favoritos → F5 → outra conta não vê os favoritos da primeira → filtros.

## O que pode dar errado e como se percebe

| Sintoma | Provável causa | Ação |
|---|---|---|
| `permission denied` / 401 / 403 | chave errada ou desativada; migration 6 | parar; conferir a chave e a auditoria de grants |
| `sync_runs.status = 'failed'`, `error_class = 'http_429'` | limite da fonte | esperar; não repetir antes de 60 min |
| App mostra "Nenhuma fonte integrada" / "Nenhuma vaga" | fonte não publicada (esperado até o passo 3) ou catálogo vazio | conferir o estado e o passo 3 |

## Compromissos com a fonte (Jobicy)
Atribuição visível ("Fonte: Jobicy") e link para a página canônica; nunca apresentar as vagas como nossas; uma passada por hora no máximo; descrições reduzidas a texto simples; para grande volume ou uso diferente do normal, contatar o Jobicy.
