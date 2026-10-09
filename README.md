<p align="center"><b>OrbiJob</b> · by Lucksrei</p>

# OrbiJob

> **Status real: Fase 0 concluída (fundação) + identidade visual C integrada na `main` (PR #38) + Fase 2 de preparação (PR em revisão).** Não há backend publicado, nenhuma fonte de vagas integrada e nenhuma vaga real exibida. Busca real, ranking, perfil, candidaturas e autofill ainda **não funcionam** — estão **planejados**.

🇬🇧 [English README](README_EN.md) · Antigo nome provisório: *JobRadar* (descontinuado — [ver motivo](docs/BRAND_NAME_CHECK.md)).

## Missão
Ajudar qualquer pessoa, em qualquer profissão, a encontrar, avaliar e acompanhar oportunidades de emprego pelo mundo — com transparência sobre de onde vêm as vagas e onde ainda **não** há cobertura.

## O problema
Vagas estão espalhadas em centenas de portais; ofícios e saúde são mal atendidos por ferramentas focadas em tecnologia; candidaturas se perdem em planilhas.

## Funcionalidades
| Funcionalidade | Estado |
|---|---|
| Identidade **C — Minimal Tech** no app (tokens, Space Grotesk/Inter, logotipo, ícones Android/iOS/Web, splash, temas claro/escuro/sistema) | ✅ aplicada e testada (APK/iOS **não compilados** neste ambiente) |
| Navegação Início / Explorar / Favoritos / Candidaturas, perfil no cabeçalho (barra inferior < 600 dp, rail, rail estendido + lista/detalhe) | ✅ implementada (estados vazios honestos) |
| Componentes: botões, campo de busca, chips, cartão de vaga (compatibilidade e confiança separadas), favorito, badges, skeleton, estados | ✅ implementados (cartões só aparecem na prévia/testes: não há fonte de vagas) |
| Busca com estados carregando / vazio / erro / **sem fonte integrada**, PT/EN/ES | ✅ implementada, **sem dados reais** |
| Resolvedor de profissões multilíngue (seed ISCO-08, 12 ocupações) | ✅ implementado e testado |
| Núcleo de conectores: contrato, dedupe, retry/backoff, rate limiter, regra de encerramento de vagas | ✅ implementado e testado (conector Lever só com fixture sintética) |
| Esquema SQL + RLS | ✅ proposto e testado em PGlite · ❌ **não aplicado** em Supabase |
| Catálogo de fontes e matriz de cobertura | ✅ documentado · **nenhuma fonte `READY`** |
| Busca mundial real, filtros internacionais, ranking 0–100 + confiança calculados, candidatura oficial | 🗓️ planejado |
| Perfil/currículo/experiências, favoritos, candidaturas, preenchimento assistido | 🗓️ planejado |

## Stack
Flutter / Dart · Clean Architecture · BLoC/Cubit · GetIt · Supabase (PostgreSQL, Auth, Storage) · Cloudflare Workers (TypeScript) · GitHub Actions · i18n PT/EN/ES. Priorizamos infraestrutura gratuita, respeitando limites e licenças.

## Arquitetura
Flutter → Cloudflare Workers (API + sincronização) → Supabase. Dados públicos (vagas) separados de dados privados (perfil, currículo, candidaturas), protegidos por RLS. Detalhes: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DATABASE.md](docs/DATABASE.md).

## Plataformas
Android, iOS e Web/PWA. Verificado: build web de produção e prévia (capturas reais em [docs/design/flutter-screenshots](docs/design/flutter-screenshots/README.md)), testes de widget e validação dos recursos Android com `aapt2`. **Não verificado aqui:** APK (sem Android SDK) e iOS (sem macOS/Xcode). Nada foi publicado em lojas.

## Integrações de vagas
Todas as fontes estão `CONDITIONAL`, `RESEARCH` ou `EXTERNAL_ONLY` — nenhuma `READY` (faltam chaves, leitura de termos e validação ao vivo). Sem scraping proibido, sem burlar CAPTCHA, sem candidatura automática. Veja [docs/GLOBAL_SOURCES.md](docs/GLOBAL_SOURCES.md) e [docs/COVERAGE_MATRIX.md](docs/COVERAGE_MATRIX.md).

## Configuração local
Requisitos: Flutter estável (testado com 3.47.6), Node 22.
```bash
# App
cd app && flutter pub get && flutter gen-l10n && flutter analyze && flutter test
flutter run -d chrome                         # app real (sem dados)
flutter run -d chrome -t lib/main_preview.dart  # mesma UI com vagas FICTÍCIAS e faixa de aviso
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
`flutter analyze` + `flutter test` (179 testes: tokens e contraste, temas, navegação, **sem overflow** em 8 tamanhos × texto 100/150/200%, acessibilidade, i18n, assets/ícones/splash, configuração/autenticação/repositórios Supabase contra backend HTTP simulado) · `tsc` + `vitest` (58 testes do worker, incluindo RLS em PGlite e HTTP/retry) · testes SQL em PostgreSQL 16 real (`supabase/tests/run.sh`: auditoria + isolamento entre usuários) · build web e validação `aapt2` no CI. Testes de integração/E2E em dispositivo: ainda não existem.

## Segurança
RLS dono-único, currículos em bucket privado (planejado/proposto), nenhum segredo no repositório (**público**), sem scraping proibido, sem candidatura automática, autofill só em domínios autorizados. [docs/SECURITY.md](docs/SECURITY.md)

## Identidade visual
Identidade oficial: **C — Minimal Tech** (símbolo "O" de dois arcos com ponto violeta; ORBIJOB em Space Grotesk). [docs/design/identity/c-minimal/APPLIED.md](docs/design/identity/c-minimal/APPLIED.md) · [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md). As propostas A e B ficam como histórico.

## Roadmap
[docs/ROADMAP.md](docs/ROADMAP.md) · issues por área no GitHub · [docs/HANDOFF.md](docs/HANDOFF.md)

## Screenshots
Capturas reais do app em [docs/design/flutter-screenshots](docs/design/flutter-screenshots/README.md) (claro/escuro, mobile/tablet/desktop; as com vagas são prévia fictícia, sempre sinalizada).

## Licença
Ainda não definida; **todos os direitos reservados** até decisão (nenhum arquivo LICENSE).

## Créditos
Produto da **Lucksrei** · desenvolvimento: Lucas Diogo França.
