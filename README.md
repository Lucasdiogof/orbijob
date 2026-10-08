<p align="center"><b>OrbiJob</b> · by Lucksrei</p>

# OrbiJob

> **Status real: Fase 0 concluída (fundação). Em desenvolvimento inicial.** Não há backend publicado, nenhuma fonte de vagas integrada e nenhuma vaga real exibida. Nenhum recurso de vagas, ranking, perfil, favoritos, candidaturas ou autofill funciona ainda — estão **planejados**.

🇬🇧 [English README](README_EN.md) · Antigo nome provisório: *JobRadar* (descontinuado — [ver motivo](docs/BRAND_NAME_CHECK.md)).

## Missão
Ajudar qualquer pessoa, em qualquer profissão, a encontrar, avaliar e acompanhar oportunidades de emprego pelo mundo — com transparência sobre de onde vêm as vagas e onde ainda **não** há cobertura.

## O problema
Vagas estão espalhadas em centenas de portais; ofícios e saúde são mal atendidos por ferramentas focadas em tecnologia; candidaturas se perdem em planilhas.

## Funcionalidades
| Funcionalidade | Estado |
|---|---|
| Navegação Início / Explorar / Favoritos / Candidaturas, perfil no cabeçalho (adaptativa: barra inferior / rail) | ✅ implementada (páginas vazias honestas) |
| Busca com estados loading / vazio / erro / **sem fonte integrada**, tema claro/escuro, PT/EN/ES | ✅ implementada, **sem dados reais** |
| Resolvedor de profissões multilíngue (seed ISCO-08, 12 ocupações) | ✅ implementado e testado |
| Núcleo de conectores: contrato, dedupe, retry/backoff, rate limiter, regra de encerramento de vagas | ✅ implementado e testado (conector Lever só com fixture sintética) |
| Esquema SQL + RLS | ✅ proposto e testado em PGlite · ❌ **não aplicado** em Supabase |
| Catálogo de fontes e matriz de cobertura | ✅ documentado · **nenhuma fonte `READY`** |
| Busca mundial real, filtros internacionais, ranking 0–100 + confiança, detalhes da vaga | 🗓️ planejado |
| Perfil/currículo/experiências, favoritos, candidaturas, preenchimento assistido | 🗓️ planejado |

## Stack
Flutter / Dart · Clean Architecture · BLoC/Cubit · GetIt · Supabase (PostgreSQL, Auth, Storage) · Cloudflare Workers (TypeScript) · GitHub Actions · i18n PT/EN/ES. Priorizamos infraestrutura gratuita, respeitando limites e licenças.

## Arquitetura
Flutter → Cloudflare Workers (API + sincronização) → Supabase. Dados públicos (vagas) separados de dados privados (perfil, currículo, candidaturas), protegidos por RLS. Detalhes: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DATABASE.md](docs/DATABASE.md).

## Plataformas
Android, iOS e Web/PWA (projetos gerados). Até agora só testes Flutter headless foram executados; **nenhum build Android/iOS/Web foi gerado ou publicado**.

## Integrações de vagas
Todas as fontes estão `CONDITIONAL`, `RESEARCH` ou `EXTERNAL_ONLY` — nenhuma `READY` (faltam chaves, leitura de termos e validação ao vivo). Sem scraping proibido, sem burlar CAPTCHA, sem candidatura automática. Veja [docs/GLOBAL_SOURCES.md](docs/GLOBAL_SOURCES.md) e [docs/COVERAGE_MATRIX.md](docs/COVERAGE_MATRIX.md).

## Configuração local
Requisitos: Flutter estável (testado com 3.47.6), Node 22.
```bash
# App
cd app && flutter pub get && flutter gen-l10n && flutter analyze && flutter test
flutter run -d chrome
# Worker
cd worker && npm ci && npm run typecheck && npm test
# Catálogo e cobertura (gera data/coverage-matrix.csv e docs/*.md)
node scripts/build-coverage.mjs
# Aceite de buscas (precisa de internet; chaves opcionais)
USAJOBS_KEY=… USAJOBS_EMAIL=… ADZUNA_APP_ID=… ADZUNA_APP_KEY=… node scripts/acceptance.mjs --out docs/evidence/acceptance-$(date +%F).json
```
Copie `.env.example` para `.env` (nunca commitar). Nenhum projeto Supabase ou Cloudflare foi criado.

## Estrutura de diretórios
```
app/         Flutter (orbijob): lib/{core,features,l10n}, test/
worker/      Cloudflare Worker (TypeScript): src/, test/ (inclui RLS via PGlite)
supabase/    migrações propostas (não aplicadas)
data/        catálogo de fontes, seed de ocupações, matriz de cobertura (CSV)
scripts/     geração de cobertura e aceite de buscas
docs/        arquitetura, requisitos, fontes, banco, segurança, roadmap, design, portfólio, evidências
.github/     CI
```

## Testes
`flutter analyze` + `flutter test` (app) · `tsc` + `vitest` (worker: conectores, dedupe, retry, ocupações, RLS) · verificação da matriz gerada no CI. Cobertura de testes de integração/E2E: ainda não existe.

## Segurança
RLS dono-único, currículos em bucket privado (planejado/proposto), nenhum segredo no repositório (**público**), sem scraping proibido, sem candidatura automática, autofill só em domínios autorizados. [docs/SECURITY.md](docs/SECURITY.md)

## Identidade visual
Três propostas aguardam aprovação — [docs/design/IDENTITY_CONCEPTS.md](docs/design/IDENTITY_CONCEPTS.md). Nenhuma foi aplicada.

## Roadmap
[docs/ROADMAP.md](docs/ROADMAP.md) · issues por área no GitHub · [docs/HANDOFF.md](docs/HANDOFF.md)

## Screenshots
Ainda não existem.

## Licença
Ainda não definida; **todos os direitos reservados** até decisão (nenhum arquivo LICENSE).

## Créditos
Produto da **Lucksrei** · desenvolvimento: Lucas Diogo França.
