# Diagnóstico do agendamento do GitHub Actions (temporário)

## O problema
Os workflows `Jobicy revalidate` (`17 */6 * * *`) e `Jobicy watchdog` (`43 5,17 * * *`) funcionam manualmente (`workflow_dispatch`), mas **nunca geraram
uma execução `schedule`**. Ambos estão na `main` desde 2026-10-10 15:54:52 UTC, estão `active`, o repositório é público e a branch padrão é a `main`.
Em 2026-10-10 18:44 UTC já tinham passado o das 17:43 (monitor) e o das 18:17 (revalidação).

## O que foi verificado (sem causa objetiva encontrada)
* Estado real: workflows `active`; `main` é a branch padrão; o arquivo existe nela (HEAD da `main` o contém); repositório não arquivado, não desabilitado.
* Eventos: 0 execuções de `schedule` em qualquer workflow do repositório (a lista de execuções só tem `push`, `pull_request` e `workflow_dispatch`).
* Sintaxe: `17 */6 * * *` e `43 5,17 * * *` são cron padrão (UTC) válidos; o mesmo arquivo roda por `workflow_dispatch`, então o YAML é válido.
* Painel de status do GitHub: nenhum incidente desde 2026-10-09, todos os sistemas normais.
* Documentação oficial: o evento `schedule` "pode ser atrasado em períodos de carga alta, e algumas execuções podem ser descartadas";
  só dispara se o arquivo estiver na branch padrão; em repositório público é desativado após 60 dias sem atividade (não é o caso: repositório ativo hoje).
* Duas ausências em dois workflows e horários diferentes tornam improvável "um atraso isolado", mas **isso é uma hipótese, não uma prova**: o primeiro
  agendamento de um workflow recém-criado pode demorar, e o GitHub não dá visibilidade do agendador.

## O diagnóstico
`.github/workflows/diagnostics-schedule.yml` (este PR): a cada 15 minutos (`7,22,37,52 * * * *`) registra a hora UTC, o evento, o cron e o SHA. **Só isso:**
sem segredos, sem variáveis, sem checkout, sem rede, sem Supabase, sem alterar vagas, `permissions: {}`.

> Como todo workflow agendado, só começa a disparar **depois do merge na `main`** (a branch do PR não agenda). Também é possível rodá-lo na hora por *Run workflow*,
> o que só prova que o arquivo é válido, não o agendador.

### Como interpretar (a partir do merge)
| Resultado | Significado | Próximo passo |
|---|---|---|
| Aparecem execuções `schedule` do diagnóstico (a ~15 min), mas **não** as de produção | o agendador funciona; algo é específico dos workflows de produção | comparar cron/arquivo; ver se o `if:` do job (variáveis) e o nome do environment interferem; abrir chamado ao suporte do GitHub com os IDs |
| Aparecem execuções `schedule` de **todos** (inclusive produção) depois de algum tempo | era o atraso do primeiro registro | remover o diagnóstico; manter o monitor |
| **Nenhuma** execução `schedule` do diagnóstico em ~1 hora | o repositório não está recebendo eventos agendados | suporte do GitHub (Actions); enquanto isso, rodar a revalidação manualmente (workflow_dispatch `revalidate`) a cada ~2 dias ou usar a ponte local |
| Execuções chegam muito atrasadas (> 30 min) | carga do agendador | manter, e o monitor tolera até 14 h |

## Como remover o diagnóstico (depois de entender)
1. Apague o arquivo: `git rm .github/workflows/diagnostics-schedule.yml` e este documento (ou mova a conclusão para `docs/JOBICY_ACTIONS_AUTOMATION.md`).
2. Faça o PR e o merge. Execuções antigas podem ficar no histórico (apague na aba Actions se quiser).
3. Não deixe o diagnóstico ligado: são ~96 execuções/dia (grátis em repositório público, mas inúteis depois da conclusão).

## Enquanto isso (prazo de 13/10 às 16:43 UTC)
A revalidação manual funciona: Actions → *Jobicy revalidate* → *Run workflow* → `revalidate` (renova as 299 vagas por mais 72 h, ~2 minutos).
Faça isso pelo menos a cada 2 dias até o agendamento ser confirmado.
