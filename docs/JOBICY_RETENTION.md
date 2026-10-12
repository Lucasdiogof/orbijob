# Retenção do catálogo

> **Estado (2026-10-11):** política **decidida** (o proprietário delegou a decisão: compactar após 14 dias, remover após 90) e **migration escrita e testada**
> (`supabase/migrations/20261016000000_jobicy_retention.sql`). **NÃO foi aplicada no Supabase e NADA está agendado.** Aplicar a migration e ligar o agendamento
> são etapas separadas, que exigem autorização explícita (seção 5). Pré-requisito para ligar a descoberta contínua (`docs/JOBICY_DISCOVERY.md`, seção 7).

## 1. Medições (produção, 2026-10-10, 299 vagas, somente leitura)
| Componente de `public.jobs` | Tamanho | Por vaga | Parcela |
|---|---|---|---|
| Índice de busca `jobs_search_idx` (GIN sobre título + empresa + **descrição**) | 5,4 MB | 17,9 KB | 49 % |
| TOAST (descrição comprimida ≈ 3,9 KB + `tsvector` armazenado ≈ 8,4 KB) | 5,0 MB | 16,8 KB | 46 % |
| Linha (heap) | 0,32 MB | 1,07 KB | 3 % |
| Índice de título (trigram) | 0,32 MB | 1,07 KB | 3 % |
| Demais índices (url, fingerprint, país, chaves) | ≈ 0,3 MB | ≈ 1 KB | 3 % |
| **Total da tabela** | **11 MB** | **≈ 37 KB** | |

* Banco inteiro: 24 MB (limite do plano gratuito: 500 MB; confirme o valor vigente no painel).
* Descrição média: 6,6 mil caracteres (máx. 20 mil). **95 % do peso da vaga é a descrição**, direta (TOAST) ou indireta (`tsvector` + índice GIN).
* Sem a descrição, uma vaga pesa **≈ 3,4 KB** (linha 1,1 + índices 2,0 + GIN só de título/empresa ≈ 0,3): cerca de **1/11**.
* Referências de usuário hoje: `saved_jobs` 0, `viewed_jobs` 0, `applications` com vaga 0 (ainda não há dados reais de usuários ligados a vagas).

## 2. Integridade referencial (o que apagar quebra)
| Tabela | Chave para `jobs` | Efeito de apagar a vaga |
|---|---|---|
| `saved_jobs.job_id` | `on delete cascade` | **apaga o favorito** (mesmo havendo `snapshot`) |
| `viewed_jobs.job_id` | `on delete cascade` | apaga o histórico de visualização |
| `applications.job_id` | `on delete set null` | mantém a candidatura, **perde o vínculo** com a vaga |
| `job_clusters.canonical_job_id` | sem ação | **bloqueia** a exclusão (hoje sem uso) |

**Achado no código do app (verificado em `app/lib`):** o app **nunca grava `job_id`**. Favoritos (`saved_jobs`) e candidaturas guardam a vaga num `snapshot` JSON próprio (identidade, empresa, título, URL, salário, datas; **sem descrição**) e são lidos só dele, com chave `job_key = fonte:id`. Logo, hoje nenhuma tabela de usuário aponta para `jobs` e compactar ou apagar uma vaga encerrada **não afeta favoritos nem candidaturas**. A checagem de referências na limpeza continua obrigatória como defesa, caso uma versão futura do app passe a gravar `job_id`.

Conclusão: **apagar só é seguro para vaga que nenhuma dessas tabelas referencia**. Qualquer vaga referenciada deve ser *compactada*, nunca apagada. É também por isso que o `service_role` não tem `DELETE` (migration 7): a limpeza roda com o papel do dono do banco (`pg_cron`), fora do alcance de qualquer chave.

## 3. Estratégia proposta: três camadas
| Camada | Critério objetivo | Ação | Peso |
|---|---|---|---|
| **A. Ativa** | `status = 'open'` | nada | ≈ 37 KB |
| **B. Carência** | `closed` há ≤ 14 dias (`last_checked_at` da transição) | nada (favoritos e detalhes seguem completos) | ≈ 37 KB |
| **C. Compactada** | `closed` há > 14 dias | `description = ''`, `requirements = '{}'`, `skills = '{}'`; mantém título, empresa, país, salário, datas, URL do Jobicy, fingerprint | ≈ 3,4 KB |
| **D. Removida** | `closed` há > 90 dias **e** sem referência em `saved_jobs`, `viewed_jobs`, `applications`, `job_clusters` | `DELETE` + gravar lápide (`source_id`, `external_id`, `deleted_at`, ≈ 100 B) | ≈ 0,1 KB |

* **Vaga referenciada** (favorito, histórico, candidatura) nunca passa da camada C: continua existindo, compacta, para sempre. Favoritos e candidaturas já vivem do próprio snapshot (sem descrição), então nada muda para eles; o link do anúncio original permanece.
* **Lápide:** registro mínimo (fonte, id, data) de cada vaga removida, em `ops.job_tombstones` (≈ 3,6 MB por ano a 100 vagas/dia), para auditoria e recuperação. A barreira contra reimportar uma vaga removida é o endpoint de status: a descoberta só insere vaga que o Jobicy confirma `active`.
* **Por que compactar em vez de só apagar:** preserva identidade, histórico de candidaturas e favoritos com custo ~11 vezes menor, e a descrição de uma vaga encerrada não tem valor de produto (o Jobicy não a lista mais).
* **Vaga aberta nunca é tocada.** Vaga `open` sem revalidação (> 72 h) é *escondida pelo app*, não encerrada: a retenção não olha para ela.

## 4. Estimativa de armazenamento (modelo, não medição)
Premissas: entrada ≈ 100 vagas/dia (feed: 715 em 7 dias); linha completa 37 KB; compactada 3,4 KB; outras tabelas ≈ 13 MB. **A duração média de uma vaga aberta (L) ainda não foi medida**: só há 3 dias de dados e nenhuma encerrada. Por isso a tabela varia L.

| L (dias abertas) | completas (A+B) | compactadas (C, 76 dias) | total estimado do banco | % de 500 MB |
|---|---|---|---|---|
| 14 | 2.800 → 103 MB | 7.600 → 26 MB | ≈ 142 MB | 28 % |
| 30 | 4.400 → 162 MB | 26 MB | ≈ 201 MB | 40 % |
| 60 | 7.400 → 272 MB | 26 MB | ≈ 311 MB | 62 % |
| 90 | 10.400 → 383 MB | 26 MB | ≈ 422 MB | **84 %** |
| *sem retenção* | cresce ≈ 3,9 MB/dia | | 500 MB em ≈ 4 meses; **teto de 4.000 em ≈ 33 dias** | |

Leitura: com a retenção, o regime estável cabe no plano gratuito para L até ≈ 60 dias; acima disso é preciso reduzir a carência ou a cota por passada. O primeiro mês de operação mede L de verdade (`sync_runs.closed` + idade das encerradas).

**Ajuste necessário no teto do catálogo:** hoje `SYNC_MAX_CATALOGUE = 4000` conta *todas* as linhas. Com compactação, o que pesa são as linhas completas (A+B). Proposta: contar só as completas e subir o teto para ≈ 6.000 (≈ 220 MB), mantendo ≤ 60 % do plano. Enquanto a retenção não existir, **o teto de 4.000 permanece**.

**Observação PostgreSQL:** `DELETE`/`UPDATE` liberam espaço para reuso, mas o tamanho do arquivo só encolhe com `VACUUM FULL` (trava a tabela; viável nesta escala, fora do horário) — o que importa para o limite é o pico, e o autovacuum reaproveita o espaço. O GIN limpa na rotina de vacuum.

## 5. Execução proposta (quando autorizada)
* **Migration 9 (`20261016000000_jobicy_retention.sql`, escrita, não aplicada):** cria `ops.job_tombstones`, `ops.retention_runs` (log; de propósito **não** usa `sync_runs`, para não fazer a revalidação recuar por `too_soon`), `ops.jobicy_retention_plan()` (somente leitura: contagens por camada) e `ops.jobicy_retention_apply(frase, compact_after, delete_after, batch, allow_large)`. Tudo revogado de `anon`, `authenticated` e `service_role`. A idade de uma vaga encerrada é `last_checked_at` (a revalidação o grava no fechamento e nada mexe depois).
* **Ativação em duas etapas** (igual à revalidação): a migration só cria funções; `scripts/supabase/ops/enable_retention_cron.sql` (frase `EU-AUTORIZO-A-RETENCAO-AUTOMATICA`) agenda um job **diário** às 04:37 UTC (≈ 100 vagas encerram por dia no volume atual do feed; um job semanal com lote de 200 não acompanharia) e `disable_retention_cron.sql` o remove.
* **Dry-run obrigatório** antes da primeira execução: `select * from ops.jobicy_retention_plan();` e conferência manual de uma amostra.
* **Travas:** a função recusa sem a frase do proprietário (`EU-AUTORIZO-A-RETENCAO`), com política absurda (compactar < 7 dias; remover < 30 dias ou < 14 dias depois de compactar), com outra chamada em andamento, e quando mexeria em mais de 20 % das encerradas (e mais de 50) de uma vez, salvo `allow_large`. No máximo `batch` (padrão 200, máx. 500) vagas de cada tipo por chamada; vagas bloqueadas por outra transação são puladas.
* **Testes:** 18 testes em PGlite (`worker/test/retention.test.ts`: vaga aberta nunca é tocada, referenciada nunca é apagada, só a fonte `jobicy`, lotes, guardas, privilégios, enable/disable/rollback; mutação removendo a checagem de referência reprova 2) e `supabase/tests/12_retention.sql` em PostgreSQL real 16 e 17 no CI.

## 6. Recuperação e rollback
* **Antes da primeira execução real:** `select ops.jobicy_retention_export();` devolve as linhas completas que a próxima execução compactaria ou removeria (somente leitura, até 1000 por chamada). Salve o resultado em arquivo na pasta de backups local (`orbijob-backups`) com o SHA-256. **Restaurar:** `select ops.jobicy_retention_restore('EU-AUTORIZO-A-RESTAURACAO', '<json do export>'::jsonb);` reinsere as vagas removidas com o mesmo id (e apaga a lápide) e devolve descrição, requisitos e skills das compactadas; **nunca sobrescreve** uma vaga que tem conteúdo. Round trip testado: o banco volta idêntico, ids incluídos (`retention.test.ts` e `12_retention.sql` no CI).
* A **compactação é irreversível dentro do banco**; o backup é o caminho de volta (reimportar a descrição). A **remoção** é recuperável a partir do mesmo backup; a lápide registra o que foi removido e quando.
* **Desligar:** apagar o job do `pg_cron` (script de disable); nada mais precisa ser desfeito.
* **Rollback da migration:** remove as funções e a tabela de lápides; não mexe em vagas.

## 6b. Auditoria da migration (2026-10-11)
| Ponto | Resultado |
|---|---|
| Vaga aberta pode ser apagada ou compactada? | **Não.** Todos os caminhos filtram `status = 'closed'` (o `UPDATE` e o `DELETE` repetem o filtro). Teste com vaga aberta de 400 dias |
| Integridade referencial e cascata | `saved_jobs`/`viewed_jobs` (cascade), `applications` (set null) e `job_clusters` (sem ação) são checados na seleção **e de novo no próprio `DELETE`** (uma referência gravada depois da lista ainda barra a exclusão). Seleção com `FOR UPDATE SKIP LOCKED`: um `INSERT` concorrente em favoritos segura o lock da vaga e a vaga é pulada. Mutação removendo a checagem reprova 2 testes |
| Vínculos de usuário | Vaga referenciada só é compactada, nunca apagada. O app hoje não grava `job_id`; favoritos e candidaturas guardam snapshot próprio |
| Trava de 20 % | `maior(50, 20 % das encerradas)`. Sem encerradas ou com poucas, o piso de 50 permite limpeza pequena (testado com 0, 1, 50 e 51 candidatas); acima, recusa, não altera nada e registra em `ops.retention_runs`. **Risco conhecido:** uma recusa não é alertada além do log e, se o acúmulo continuar, o job diário continua recusando até alguém rodar uma vez `ops.jobicy_retention_apply(frase, …, allow_large => true)`. Em regime estável (≈ 2 % das encerradas por dia) a trava não dispara |
| Ritmo | Lote de 200 por tipo por chamada, diário = 1400 por semana de capacidade, acima do ≈ 700 por semana de fechamentos esperados |
| Idempotência e concorrência | Segunda chamada não faz nada (testado). `pg_try_advisory_xact_lock`: chamada concorrente devolve `skipped:locked`. Não usa `sync_runs`, então não interfere nas leases da revalidação e da descoberta |
| Permissões e RLS | Funções e tabelas de `ops` fechadas a `anon`, `authenticated` e `service_role` (testado nos três papéis, inclusive export e restore); RLS ligado sem política; `search_path` fixado nas funções. Quem executa é o `pg_cron` (papel do banco) |
| Armazenamento | Compactar libera ≈ 34 KB por vaga para reuso; o arquivo só encolhe com `VACUUM FULL` (o limite do plano conta o tamanho do arquivo: o que importa é o pico). Tabelas `ops` novas: ≈ 100 B por vaga removida |
| PostgreSQL 16/17 | CI (`supabase-sql`) e PGlite |
| Privacidade publicada | Coerente: a política diz que vagas encerradas antigas podem ser resumidas ou removidas e que favoritos e candidaturas guardam cópia própria |

## 7. Decisões e pendências
1. ~~Carência de 14 dias para compactar e 90 dias para remover~~ **decidido** (2026-10-11, delegado ao assistente).
2. ~~Aceitar descartar a descrição de vaga encerrada antiga~~ **decidido**: sim (favoritos e candidaturas não dependem dela).
3. **Pendente:** autorizar a aplicação da migration 9 (`supabase db push`, com backup e dry-run) e, depois, o agendamento diário. Nada disso foi feito.
4. Confirmar no painel o limite vigente do plano gratuito (500 MB assumidos).

