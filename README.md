<p align="center"><b>OrbiJob</b> · by Lucksrei</p>

# OrbiJob

> **Status real (2026-10-10):** backend no ar (Supabase, 8 migrations aplicadas, RLS) com **299 vagas reais do Jobicy** (133 empresas), **revalidadas automaticamente a cada 6 h** pelo Supabase Cron. **A importação de vagas novas ainda está desligada** (proposta em PR separado). Cloudflare Worker **não** implantado. Ranking, preenchimento assistido e as demais fontes continuam **planejados**; o app não foi validado ponta a ponta no aparelho.

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
| Esquema SQL + RLS | ✅ testado em PostgreSQL 16/17 · ✅ 8 migrations aplicadas no Supabase do proprietário (Auth, RLS, Storage, cotas, privilégio mínimo do `service_role`, revalidação por `pg_cron`) |
| Catálogo real do **Jobicy** (fonte `CONDITIONAL`, com atribuição e link do anúncio original) | ✅ 299 vagas gravadas · primeira ingestão controlada; **sem importação automática de novas vagas** |
| Revalidação automática (fecha só o que o Jobicy confirma encerrado; renova as ativas) | ✅ Supabase Cron + `pg_net`, a cada 6 h, sem chave e sem serviço pago · contingência: GitHub Actions · [arquitetura implantada](docs/DEPLOYED_ARCHITECTURE.md) |
| Catálogo de fontes e matriz de cobertura | ✅ documentado · **nenhuma fonte `READY`** |
| Busca mundial real, filtros internacionais, ranking 0–100 + confiança calculados, candidatura oficial | 🗓️ planejado |
| Perfil/experiências/formação, currículos PDF, favoritos, candidaturas manuais, pesquisas salvas e preferências ligados ao Supabase | ✅ implementado e testado com backend simulado · ⚠️ **não validado ponta a ponta contra o Supabase real** |
| Preenchimento assistido, envio de candidaturas | 🗓️ planejado (o OrbiJob nunca envia candidaturas por conta própria) |

## Stack
Flutter / Dart · Clean Architecture · BLoC/Cubit · GetIt · Supabase (PostgreSQL, Auth, Storage) · Cloudflare Workers (TypeScript) · GitHub Actions · i18n PT/EN/ES. Priorizamos infraestrutura gratuita, respeitando limites e licenças.

## Arquitetura
Implantado hoje: Flutter → Supabase (leitura do catálogo com RLS); revalidação dentro do próprio Supabase (`pg_cron` + `pg_net`), com GitHub Actions como contingência. O código do Cloudflare Worker (API + sincronização) existe e é reaproveitado, mas **não está implantado**. Dados públicos (vagas) separados de dados privados (perfil, currículo, candidaturas), protegidos por RLS. Detalhes: [docs/DEPLOYED_ARCHITECTURE.md](docs/DEPLOYED_ARCHITECTURE.md) (o que roda hoje e como recuperar), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DATABASE.md](docs/DATABASE.md), [docs/JOBICY_SUPABASE_CRON.md](docs/JOBICY_SUPABASE_CRON.md).

## Plataformas
Android, iOS e Web/PWA. Verificado: build web de produção e prévia (capturas reais em [docs/design/flutter-screenshots](docs/design/flutter-screenshots/README.md)), testes de widget e validação dos recursos Android com `aapt2`. **Não verificado aqui:** APK (sem Android SDK) e iOS (sem macOS/Xcode). Nada foi publicado em lojas.

## Integrações de vagas
Única fonte com dados reais: **Jobicy** (`CONDITIONAL`; API oficial sem chave, atribuição e link original preservados). As demais estão `CONDITIONAL`, `RESEARCH` ou `EXTERNAL_ONLY` — nenhuma `READY`. Sem scraping proibido, sem burlar CAPTCHA, sem candidatura automática. Veja [docs/GLOBAL_SOURCES.md](docs/GLOBAL_SOURCES.md) e [docs/COVERAGE_MATRIX.md](docs/COVERAGE_MATRIX.md).

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
Copie `.env.example` para `.env` (nunca commitar). O projeto Supabase do proprietário existe (8 migrations aplicadas); nenhum Cloudflare foi publicado. Passo a passo do app contra o projeto real: `docs/SUPABASE_SETUP.md` (Fase 4). No Windows, um comando prepara um Flutter isolado e abre o app em `localhost:3000`: `docs/WINDOWS_WEB_RUN.md`.

## Estrutura de diretórios
```
app/         Flutter (orbijob): lib/{core,features,l10n}, test/
worker/      Cloudflare Worker (TypeScript): src/, test/ (inclui RLS via PGlite)
supabase/    migrations (1–8 aplicadas no projeto do proprietário), testes SQL e rollbacks
data/        catálogo de fontes, seed de ocupações, matriz de cobertura (CSV)
scripts/     geração de cobertura e aceite de buscas
docs/        arquitetura, requisitos, fontes, banco, segurança, roadmap, design, portfólio, evidências
.github/     CI, revalidação (contingência) e monitor
```

## Testes
`flutter analyze` + `flutter test` (tokens e contraste, temas, navegação, **sem overflow** em vários tamanhos e escalas de texto, acessibilidade, i18n, repositórios Supabase contra backend HTTP simulado) · `tsc` + `vitest` no `worker/` (conectores, lease, revalidação, RLS e a revalidação em SQL rodando em PostgreSQL real via PGlite) · testes SQL em PostgreSQL 16 e 17 (`supabase/tests/run.sh`) · build web e validação `aapt2` no CI. Os números atuais estão no CI. Testes de integração/E2E em dispositivo: ainda não existem.

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
