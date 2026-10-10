# Retenção do catálogo: proposta (nada de exclusão está implementado)

> **Estado: PROPOSTA.** Nenhuma remoção ou compactação automática existe nem foi executada. Este documento só mede, propõe e define critérios.
> Pré-requisito para ligar a descoberta contínua (`docs/JOBICY_DISCOVERY.md`, seção 7).

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

Conclusão: **apagar só é seguro para vaga que nenhuma dessas tabelas referencia**. Qualquer vaga referenciada deve ser *compactada*, nunca apagada. É também por isso que o `service_role` não tem `DELETE` (migration 7): a limpeza roda com o papel do dono do banco (`pg_cron`), fora do alcance de qualquer chave.

## 3. Estratégia proposta: três camadas
| Camada | Critério objetivo | Ação | Peso |
|---|---|---|---|
| **A. Ativa** | `status = 'open'` | nada | ≈ 37 KB |
| **B. Carência** | `closed` há ≤ 14 dias (`last_checked_at` da transição) | nada (favoritos e detalhes seguem completos) | ≈ 37 KB |
| **C. Compactada** | `closed` há > 14 dias | `description = ''`, `requirements = '{}'`, `skills = '{}'`; mantém título, empresa, país, salário, datas, URL do Jobicy, fingerprint | ≈ 3,4 KB |
| **D. Removida** | `closed` há > 90 dias **e** sem referência em `saved_jobs`, `viewed_jobs`, `applications`, `job_clusters` | `DELETE` + gravar lápide (`source_id`, `external_id`, `deleted_at`, ≈ 100 B) | ≈ 0,1 KB |

* **Vaga referenciada** (favorito, histórico, candidatura) nunca passa da camada C: continua existindo, compacta, para sempre. Esta proposta não verifica como o app exibe uma vaga encerrada; é preciso conferir o detalhe de favorito encerrado antes de ativar. A descrição some, o link do anúncio original permanece.
* **Lápide:** impede que a descoberta reimporte uma vaga removida (defesa extra: a vaga encerrada já é barrada pelo endpoint de status). Custo ≈ 3,6 MB por ano a 100 vagas/dia.
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
* **Migration 9 (futura):** schema `ops` já existe; adicionar `ops.jobicy_retention_plan()` (somente leitura: devolve contagens por camada e as vagas candidatas), `ops.jobicy_retention_apply()` (aplica C e D em lotes de 200, com `lock` consultivo e lease própria) e a tabela de lápides. Todas revogadas de `anon`, `authenticated` e `service_role`, como o resto de `ops`.
* **Ativação em duas etapas** (igual à revalidação): a migration só cria funções; um SQL separado com frase de autorização agenda o job semanal (`pg_cron`, madrugada de domingo) e outro o desfaz.
* **Dry-run obrigatório** antes da primeira execução: `select * from ops.jobicy_retention_plan();` e conferência manual da amostra.
* **Teto de segurança por execução:** no máximo 500 linhas por rodada e recusa se mais de 20 % das encerradas forem candidatas de uma vez (sinal de dado errado).
* **Testes:** PGlite com os grants reais e CI em PostgreSQL 16/17: vaga referenciada nunca é apagada, vaga aberta nunca é tocada, compactação preserva identidade, lápide impede reimportação, idempotência, lotes.

## 6. Recuperação e rollback
* **Antes da primeira execução real:** exportar as linhas candidatas (JSONL) para a pasta de backups local (`orbijob-backups`), com SHA-256.
* A **compactação é irreversível dentro do banco**; o backup é o caminho de volta (reimportar a descrição). A **remoção** é recuperável a partir do mesmo backup; a lápide registra o que foi removido e quando.
* **Desligar:** apagar o job do `pg_cron` (script de disable); nada mais precisa ser desfeito.
* **Rollback da migration:** remove as funções e a tabela de lápides; não mexe em vagas.

## 7. Decisões que dependem do proprietário
1. Carência de 14 dias para compactar e 90 dias para remover (ou outros valores).
2. Aceitar que a descrição de vaga encerrada antiga seja descartada (a alternativa é manter e aceitar menos vagas).
3. Autorizar a migration 9 e, depois, o agendamento semanal.
4. Confirmar no painel o limite vigente do plano gratuito (500 MB assumidos).
