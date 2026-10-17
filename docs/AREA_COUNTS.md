# Contagem de vagas por área (Home): diagnóstico e correção (2026-10-17)

## Sintoma
Os chips de área da Home sumiam (principalmente Tecnologia e Saúde) e o console mostrava vários HTTP 500 `57014` (statement timeout) vindos de `jobs?select=id,job_sources!inner(id)...`.

## Causa raiz
1. `SupabaseJobCatalogRepository.areaCounts()` fazia **uma contagem exata por área (17 áreas)**, cada uma com `or=(title.ilike.*k1*,title.ilike.*k2*,...)` de **15 a 94 palavras**.
2. O PostgREST transforma isso em um `BitmapOr` de uma varredura do índice trigram por palavra: o custo cresce **linearmente com o número de palavras** (cerca de 40 ms por palavra) e com a quantidade de títulos que casam.
3. O papel público (`anon`) tem **statement timeout de 3 s** (erro `57014`). Medido sequencialmente na base real: 1,0 a 3,3 s por área; **Tecnologia (53 palavras) 3,3 s e Saúde (94) 3,1 s estouravam sozinhas**.
4. O banco gratuito atende uma consulta por vez, então 3 contagens em paralelo (o código antigo) se enfileiravam, estouravam o limite e eram refeitas uma a uma, segurando o banco enquanto a lista da Home carregava. Resultado: 27 requisições, 9 falhas e contagens terminando só após ~14 s.
5. A Home em si **não esperava** as contagens (`AreasCubit.load` não bloqueia a tela). Os "12 s" que medi antes eram um artefato do painel de navegador oculto, que limita a renderização a ~2 fps. Em Chrome real a Home pinta em ~1,5 s.

O mesmo código roda em Android e iOS, então o problema (timeouts e chips ausentes) era igual lá; a correção vale para as três plataformas.

## Correção (sem mexer em timeout, RLS ou banco)
- `title_pattern.dart`: as palavras viram **uma expressão regular** `title ~* 'k1|k2|...'` (PostgREST `imatch`) com todos os metacaracteres escapados. É a mesma regra de "o título contém qualquer palavra, sem diferenciar maiúsculas".
- Contagens por área e por especialidade e o **filtro de área da lista (Explorar)** usam essa regex.
- No máximo 2 contagens simultâneas; cada contagem concluída aparece como chip na hora (`onPartial`).
- `AreasCubit`: cache local dos últimos números (chips instantâneos no próximo acesso), uma única execução por vez, uma área que falha mantém o último número conhecido, falha total não derruba nada.
- Testes novos: escape da regex, equivalência da regex com a regra local para todas as áreas/especialidades, comportamento do cubit (progressivo, cache, falha, chamada duplicada).

## Evidência
Mesma base, mesmo filtro de visibilidade (`status=open`, fonte autorizada, verificado nas últimas 72 h), leitura anônima:

| Área | `ilike` (antes) | regex `imatch` (depois) | Contagem igual? |
|---|---|---|---|
| Tecnologia | 2,1 a 3,3 s (às vezes 500) | 0,7 a 0,8 s | sim (1.767) |
| Saúde | 3,1 s (500) | 1,0 s | n/a (antes estourava); depois: 1.395 |
| Finanças | 2,4 s | 0,65 s | sim (883) |
| Educação | 1,9 s | 0,56 s | sim (2.432) |
| Demais 13 áreas | 0,7 a 3,1 s | 0,3 a 0,7 s | sim, todas idênticas |

Chrome real (Puppeteer), produção antes da correção: Home pintada em ~1,6 s; contagens: 27 respostas, **9 falhas**, última concluída em ~13,9 s, chips de Tecnologia/Saúde ausentes.
Depois da correção (build novo, 3 execuções frias): Home em ~1,3 a 1,5 s; 17 contagens, **0 falhas**, última em ~9,6 s; 17 chips, incluindo Saúde. Os números de banco variam com a carga: em uma rodada posterior a produção antiga não falhou, mas as medições sequenciais acima mostram o mesmo padrão (custo proporcional às palavras, 2 áreas no limite).

## Não feito (e por quê)
Uma função/tabela de contagem pré-calculada no Supabase (um único pedido para todas as áreas) reduziria o tempo total, mas é mudança estrutural e não pôde ser validada aqui (este ambiente não acessa o projeto do OrbiJob). Com a regex, nenhuma contagem passa de ~1 s e as demais ficam em cache, então não é necessária agora. Se quiser, o desenho seria: tabela `catalog_area_counts(area, open_count, computed_at)` atualizada por `pg_cron` com timeout maior e lida pelo app; o SQL seria gerado a partir do enum `JobArea` para não duplicar as palavras.

## Commit
`74f3e6f` (feito por você a partir do trabalho em andamento; CI e deploy verdes). Este documento: `recordAreaCountsDiagnosis`.
