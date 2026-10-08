# JobRadar (nome provisório)

> **Status real: Fase 0 — fundação e planejamento.** Não há backend publicado, nenhuma fonte de vagas integrada e nenhuma vaga real exibida. O nome é provisório e tem **alto risco de conflito de marca** ([detalhes](docs/BRAND_NAME_CHECK.md)).

Plataforma para buscar e acompanhar vagas de **qualquer profissão**, em qualquer país onde existam fontes legalmente utilizáveis — com transparência sobre o que está (e o que não está) coberto.

## Problema
Vagas estão espalhadas em centenas de portais; ofícios e saúde são mal atendidos pelas ferramentas focadas em tecnologia; candidaturas se perdem em planilhas.

## Funcionalidades
| Funcionalidade | Estado |
|---|---|
| Tela de busca com estados loading/vazio/erro/sem-fonte, tema claro/escuro, pt/en/es | ✅ implementado (sem dados reais) |
| Resolvedor de profissões multilíngue (seed ISCO-08, 12 ocupações) | ✅ implementado e testado |
| Contrato de conectores, dedupe, retry/backoff, rate limiter, regra de encerramento | ✅ implementado e testado (conector Lever só com fixture sintética) |
| Esquema SQL + RLS | ✅ proposto, testado em PGlite; ❌ não aplicado em Supabase |
| Catálogo de fontes e matriz de cobertura | ✅ documentado; nenhuma fonte `READY` |
| Fontes reais, perfil, ranking, favoritos, candidaturas, autofill | 🗓️ planejado ([roadmap](docs/ROADMAP.md)) |

## Tecnologias
Flutter/Dart · BLoC/Cubit · get_it · Cloudflare Workers (TypeScript) · Supabase (Postgres, Auth, Storage) · Vitest · GitHub Actions.

## Arquitetura
Ver [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Fontes: [docs/GLOBAL_SOURCES.md](docs/GLOBAL_SOURCES.md) · banco: [docs/DATABASE.md](docs/DATABASE.md) · segurança: [docs/SECURITY.md](docs/SECURITY.md).

## Plataformas
Android, iOS e Web/PWA (código gerado; apenas testes Flutter headless foram executados).

## Como executar
```bash
# App
cd app && flutter pub get && flutter gen-l10n && flutter analyze && flutter test && flutter run -d chrome
# Worker (testes)
cd worker && npm ci && npm run typecheck && npm test
# Catálogo / cobertura
node scripts/build-coverage.mjs
# Aceite de buscas (precisa de internet; chaves opcionais)
USAJOBS_KEY=… USAJOBS_EMAIL=… ADZUNA_APP_ID=… ADZUNA_APP_KEY=… node scripts/acceptance.mjs --out docs/evidence/acceptance-$(date +%F).json
```

## Ambientes
Copie `.env.example` para `.env` (nunca commitar). Segredos do Worker via `wrangler secret put`. Nenhum projeto Supabase/Cloudflare foi criado.

## Segurança
RLS dono-único, currículos em bucket privado, sem segredos no repositório, sem scraping proibido, sem candidatura automática. [docs/SECURITY.md](docs/SECURITY.md)

## Roadmap
[docs/ROADMAP.md](docs/ROADMAP.md) · Handoff: [docs/HANDOFF.md](docs/HANDOFF.md)

## Screenshots
Ainda não existem.

## Licença
Ainda não definida (proposital); nenhum arquivo LICENSE foi adicionado. Todos os direitos reservados até decisão.
