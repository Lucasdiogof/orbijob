# Roadmap

| Fase | Entregas | Critério de saída |
|---|---|---|
| 0 Fundação (esta) | docs, esqueleto Flutter/Worker, esquema SQL proposto, catálogo de fontes, resolvedor de profissões, CI | testes verdes; bloqueios registrados |
| 1 Fontes reais | chaves gratuitas; `acceptance.mjs` com internet; leitura de termos; 1º conector real (USAJOBS ou Adzuna); sync + `sync_runs` | ≥1 fonte `READY` com evidência |
| 2 Backend | projeto Supabase (com aprovação), migração em staging, Worker de busca/cron, cache, rate limit | RLS testada no Supabase real |
| 3 Perfil + Auth | login Supabase, perfis múltiplos, upload de currículo privado | isolamento comprovado |
| 4 Ranking | motor determinístico + confiança + justificativas | testes com fixtures de ≥8 profissões |
| 5 Favoritos & candidaturas | CRUD, etapas manuais, lembretes | fluxo E2E |
| 6 Autofill | mobile (InAppWebView), web (copiar), allowlist | relatório de campos, zero submit |
| 7 Expansão de fontes | serviços públicos por país conforme `COVERAGE_MATRIX` | cobertura documentada |
| 8 Lançamento | marca definitiva, lojas, PWA, portfólio Lucksrei | checklist de release |

Issues sugeridas: `docs/ISSUES_SEED.md`.
