# HANDOFF — estado ao fim da Fase 0 (2026-10-08)

## O que existe
- Repositório **local** `jobradar` (git, branch `main`). **Não foi publicado no GitHub** (ver bloqueios).
- `app/` Flutter 3.47.6 (Dart 3.13): busca com estados, tema M3, l10n pt/en/es, BLoC + get_it. `flutter analyze` limpo; 7 testes (cubit, widget, contraste, alvo de toque, tema escuro).
- `worker/` TypeScript: contrato de conectores, normalizador Lever (fixture sintética), dedupe, retry/backoff, rate limiter, regra de encerramento, resolvedor de profissões, teste de RLS (PGlite). `tsc` limpo; 43 testes.
- `supabase/migrations/…_init.sql` (proposta, **não aplicada**).
- `data/` catálogo de fontes, seed de ocupações, matriz CSV (gerada). `scripts/` geradores e aceite.
- `docs/` todos os documentos pedidos + GLOBAL_SOURCES, COVERAGE_MATRIX, SOURCES_TABLE, OCCUPATIONS, BRAND_NAME_CHECK, design/IDENTITY_CONCEPTS, portfolio, ISSUES_SEED, evidence/.

## Bloqueios registrados (nada foi simulado)
1. **Criação do repositório GitHub negada:** `create_repository` → 403 "Resource not accessible by integration". A sessão só tinha escopo ao repositório existente `Lucasdiogof/busaogyn` (outro produto, não alterado). Issues **não** foram criadas (sem repositório) → `docs/ISSUES_SEED.md`.
2. **Egress bloqueado:** APIs de vagas e a maior parte da documentação oficial inacessíveis → nenhuma validação ao vivo; evidências de terceiros marcadas como `secondary`.
3. **Nome:** conflito amplo; busca oficial de marca (INPI/USPTO/EUIPO/WIPO), lojas e domínios não feita.
4. **Chaves** (USAJOBS, Adzuna, France Travail) não obtidas — requer ação do proprietário.
5. **LICENSE** não criada (licença não definida). Sem Supabase, sem deploy Cloudflare, sem alteração em lucksrei.com, sem serviços pagos.

## Para publicar
Criar o repositório (privado) pela conta `Lucasdiogof` com um token/escopo que permita, então: `git remote add origin … && git push -u origin main`, e criar as issues de `docs/ISSUES_SEED.md`.

## Próxima etapa recomendada
Fase 1: obter chaves gratuitas, rodar `scripts/acceptance.mjs` com internet, ler termos oficiais, implementar **um** conector (USAJOBS ou Adzuna) e promover a `READY` só com evidência. Decidir identidade/nome.
