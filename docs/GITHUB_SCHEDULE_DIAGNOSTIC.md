# Agendamento do GitHub Actions: conclusão do diagnóstico

## O que se observou (2026-10-10)
* Os workflows `Jobicy revalidate` (`17 */6 * * *`) e `Jobicy watchdog` (`43 5,17 * * *`) entraram na `main` às 15:54 UTC. Funcionam por `workflow_dispatch`.
* Durante ~5 h **não houve nenhuma execução `schedule`** em nenhum workflow (por isso o diagnóstico temporário e a alternativa dentro do Supabase).
* Depois disso o GitHub **passou a disparar os dois, com forte atraso**:
  | Workflow | Horário previsto (UTC) | Execução real (UTC) | Atraso |
  |---|---|---|---|
  | Jobicy watchdog | 17:43 | 20:41 | ~3 h |
  | Jobicy revalidate | 18:17 | 21:46 | ~3,5 h |
* O workflow de diagnóstico (a cada 15 min, só registrava hora/evento) **nunca teve uma execução `schedule`**, mesmo depois do merge. Ele não ajudou a explicar nada
  e foi removido (`.github/workflows/diagnostics-schedule.yml`).

## Conclusão (o que é prova e o que é hipótese)
* **Provado:** o agendador do GitHub funciona neste repositório, mas **atrasa** (3–3,5 h nas duas primeiras execuções) e já houve uma janela de ~5 h sem nenhuma.
  Isso é compatível com o que a documentação do GitHub diz (agendamentos podem ser atrasados ou descartados sob carga). A causa exata do atraso inicial **não é provada**.
* **Provado:** a revalidação não depende desse agendador. A execução das 21:46 UTC encontrou a revalidação do Supabase Cron das 21:31 e **recuou pela lease
  (`resultado: skipped (too_soon)`)**, sem mudar nenhuma vaga: os dois mecanismos não se atropelam.
* **Decisão:** o mecanismo principal da revalidação é o Supabase Cron (`docs/JOBICY_SUPABASE_CRON.md`). O GitHub Actions fica como contingência (mesma lease), e o monitor
  (`jobicy-watchdog`) continua olhando o catálogo público. Um atraso de várias horas do GitHub não afeta a janela de 72 h do app.

## Se o agendamento do GitHub parar de novo
1. Actions → *Jobicy revalidate* → *Run workflow* → `revalidate` (renova as vagas por mais 72 h, ~2 min). Se o Supabase Cron já rodou na última hora, o resultado será `skipped (too_soon)`: está certo.
2. Repositório público: o GitHub desativa agendamentos após 60 dias sem atividade. Reativar: Actions → workflow → *Enable workflow*.
