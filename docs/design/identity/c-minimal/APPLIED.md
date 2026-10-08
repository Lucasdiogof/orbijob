# Identidade C — Minimal Tech: aplicação definitiva no app

**Decisão do proprietário: a identidade oficial do OrbiJob é a C — Minimal Tech.** As propostas A (Órbita) e B (Trajetórias) permanecem somente como histórico de exploração e **não** são aplicadas.
Conceito: busca inteligente de oportunidades profissionais em qualquer lugar do mundo. Símbolo: "O" geométrico de dois arcos opostos (espaço negativo nos vãos diagonais) com ponto violeta central. Wordmark: ORBIJOB em Space Grotesk. Preto, branco e violeta.

## Fonte de verdade e como regenerar
| Origem | Gera |
|---|---|
| `docs/design/identity/build/brand.py` (paleta + auditoria WCAG) | `c-minimal/tokens.json`, `palette.md` |
| `build/dart_tokens.py` | `app/lib/core/design/tokens/app_colors.dart` (**gerado**, não editar) |
| `build/apply_c.py` | `symbol-*.svg`, cópias em `app/assets/brand/`, fontes TTF, ícones/splash Android, iOS e Web, `manifest.json`, `index.html` |
| `build/validate_android.sh` | validação dos recursos Android com `aapt2` |
| `build/flutter_screens.sh` | builds web reais + capturas em `docs/design/flutter-screenshots/` |

Testes impedem divergência: `tokens_test.dart` compara o Dart com o `tokens.json`; `brand_assets_test.dart` compara byte a byte `app/assets/brand/*` com esta pasta.

## Tokens (resumo; lista completa e contrastes calculados em [`palette.md`](palette.md))
| Papel | Claro | Escuro |
|---|---|---|
| background (`bg`) | `#FFFFFF` | `#0C0C0E` |
| surface / container / containerHigh | `#FFFFFF` / `#F4F4F7` / `#EAEAF0` | `#131316` / `#1C1C21` / `#26262C` |
| texto principal (`ink`) / secundário (`muted`) | `#111113` / `#55555F` | `#F4F4F6` / `#A6A6B3` |
| primary / onPrimary | `#5B3DF5` / `#FFFFFF` | `#A593FF` / `#1A0F57` |
| primaryContainer / on | `#ECE8FF` / `#2A1A8A` | `#3A2C99` / `#E6E0FF` |
| secondary / onSecondary | `#111113` / `#FFFFFF` | `#F4F4F6` / `#111113` |
| outline (controles, ≥3:1) / divider (decorativo) | `#8A8A96` / `#E4E4EA` | `#7A7A88` / `#2A2A31` |
| error / success / warning (+ on e container) | `#B3261E` / `#1B7A43` / `#8A5A00` | `#FFB4AB` / `#6BD79B` / `#FFC857` |
| disabled (fg / bg) | `#8A8A96` / `#EDEDF1` | `#6E6E7A` / `#1E1E23` |
| focus | `#5B3DF5` | `#A593FF` |
| skeleton (base / highlight) | `#F4F4F7` / `#EAEAF0` | `#1C1C21` / `#26262C` |

Camadas de estado sobre `primary`: hover 8%, foco 12%, pressionado 12%, selecionado 12% (`AppStateLayer`). Aliases por componente (inputs, cards, chips, navegação, loading, seleção) em `component_colors.dart` mapeiam para os papéis acima: widgets **nunca** usam cor literal (um teste varre `lib/` e falha se encontrar `Color(0x…)`/`Colors.x` fora de `core/design`). `kProvisionalSeed` foi removido.
Ajuste em relação à proposta: fundo escuro oficial `#0C0C0E` (era `#0B0B0D`).
Acessibilidade das cores: todos os pares de texto ≥ 4,5:1 e controles/foco/bordas de campo ≥ 3:1 (72 pares auditados, claro e escuro). Estados nunca dependem só de cor: seleção de chip = preenchimento + borda + ícone de check; compatibilidade = número + anel; confiança = texto + 3 segmentos; erro = ícone + texto; foco de teclado = contorno de 2 px.

## Tipografia
| Papel | Família | Pesos | Uso |
|---|---|---|---|
| Títulos e marca | Space Grotesk | 500, 600, 700 | `display/headline/title*` |
| Leitura e controles | Inter | 400, 500, 600, 700 | `body*`, `label*`, botões, campos |
| Técnico | JetBrains Mono | 500 | **apenas** códigos ISO (moeda) — nunca texto corrido |

Escala (px/linha): display 32/40 · headline 24/32 · title 20/28 e 17/24 · body 16/24, 15/22, 13/18 · label 15/20, 13/16, 12/16. Todas as famílias são SIL OFL 1.1 (subconjunto latino, 8 arquivos TTF, ≈ 410 KB), com licenças em `app/assets/fonts/OFL-*.txt` registradas na tela de licenças do app. Fallback: Inter → Noto Sans (+ Arabic, Devanagari, JP, KR, SC, TC) → fonte do sistema; não há fontes não latinas embutidas (limitação). Testado com escala de texto 100%, 150% e 200%.

## Logotipo
SVGs oficiais nesta pasta (texto convertido em curvas; sem fonte externa): `logo-horizontal-{light,dark,mono-black,mono-white}.svg` e `symbol-{light,dark,mono-black,mono-white}.svg` (símbolo isolado). Para fundos coloridos ou fotográficos use as versões monocromáticas (branca/preta conforme o contraste). Referência no app: `AppAssets` + `BrandLogo` / `BrandSymbol`. Geometria do símbolo inalterada em relação à proposta aprovada (raio 31, traço 13, vão 9°, ponto r 9). Área de proteção recomendada: metade da altura do símbolo; altura mínima do logotipo horizontal 20 dp, do símbolo 16 dp.

## Ícones
| Plataforma | Entrega |
|---|---|
| Android | adaptativo (primeiro plano vetorial, fundo `#111113`), monocromático (Android 13+), round e legado PNG (48–192 px, quadrado e redondo). Símbolo com raio de 28,4 dp dentro da zona segura de 33 dp (margem ≥ 14%): não é cortado por máscara circular, squircle ou quadrada ([`applied/android-adaptive-masks.png`](applied/android-adaptive-masks.png)). Sem wordmark no launcher. |
| iOS | `AppIcon.appiconset` com 15 PNGs opacos (sem canal alfa), quadrados, 20 a 1024 px; nome exibido OrbiJob; bundle id `com.lucksrei.orbijob` e signing intactos. |
| Web/PWA | `favicon.svg`, `favicon.png` (32), `favicon.ico` (16/32/48 renderizados nativamente), `Icon-192/512`, `Icon-maskable-192/512` (área segura de 80%), `apple-touch-icon` (180, opaco). Links versionados `?v=c1`. |
Conjunto completo nos tamanhos reais: [`applied/icon-set.png`](applied/icon-set.png).

## Splash
Estática, sem animação e sem textos. Fundo = token (`#FFFFFF` claro / `#0C0C0E` escuro) e símbolo centralizado.
- **Android:** `windowBackground` (API < 31) e `windowSplashScreen*` (API 31+: ícone de 288 dp com símbolo dentro do círculo visível de 192 dp, duração 0), variantes `night`.
- **iOS:** `LaunchScreen.storyboard` com cor nomeada `LaunchBackground` (claro/escuro) e `LaunchImage` com variante escura.
- **Web:** `#splash` inline (SVG claro/escuro por `prefers-color-scheme`) removido no evento `flutter-first-frame`; sem animação, logo não há o que reduzir.
- **Flutter:** nenhuma tela de splash adicional nem transição que atrase o primeiro frame. Inicialização fria: splash nativo → app; quente: sem splash (processo ativo).
Service worker: o Flutter 3.47 gera um worker que se **desregistra** e não faz cache de assets; portanto não sobram ícones antigos do SW. Para o cache HTTP/favicons dos navegadores os links usam `?v=c1` (aumente ao trocar a identidade).

## Padrões visuais
Cantos 8 dp (campos, botões, cartões), linhas de 1 px em vez de sombras, rótulos em Inter (não monoespaçada), densidade confortável, alvos de toque ≥ 48 dp, navegação com linha de 2 px no topo (barra) / 3 px à esquerda (rail) no item ativo.

## Componentes (`app/lib/core/widgets`, `features/search/presentation/widgets`)
`AppButton` (primário/secundário/terciário, loading) · `AppSearchField` · `AppFilterChip` · `JobCard` · `CompatibilityIndicator` · `ConfidenceIndicator` · `FavoriteButton` · `AppNavBar` / `AppNavRail` · `StatusBadge` · `SectionHeader` · `StateView` (vazio, informação, erro) · `SkeletonList` · `FocusRing` · `BrandLogo` / `BrandSymbol`.
Hierarquia do cartão de vaga: cargo → empresa → cidade/país → modalidade → salário e moeda → data → compatibilidade → confiança → favorito → fonte. Campos ausentes na fonte **não são desenhados**; compatibilidade e confiança são métricas separadas (modelo `JobMatch`).

## Responsividade
Compacto (< 600 dp): barra inferior. Médio (600–1023): rail com rótulos; em janelas baixas (< 480 dp, paisagem de celular) rail só com ícones, tooltips e rótulos semânticos. Expandido (≥ 1024): rail estendido e Explorar em lista + detalhe. Conteúdo com largura máxima de leitura. Rótulos de navegação reduzem a escala em vez de quebrar palavras; o anel de compatibilidade cresce com o texto; `StateView` rola quando falta espaço (teclado aberto, paisagem, 200% de texto).

## Evidências
- Capturas **reais** do Flutter (build web, Chromium headless): [`../../flutter-screenshots/`](../../flutter-screenshots/README.md).
- Testes: ver tabela em [`docs/DESIGN_SYSTEM.md`](../../../DESIGN_SYSTEM.md).
- Android: `aapt2 compile` e `link` (API 23 `android.jar`) sem erros; recursos resolvidos (`applied/android-resources-validation.txt`).

## Limitações conhecidas
- **APK não compilado** (sem Android SDK offline) e **iOS não compilado** (exige macOS/Xcode): ícones, splash e storyboard foram validados por inspeção estrutural e testes, não em dispositivo/simulador. O storyboard usa o formato `toolsVersion 13122` com `namedColor`, ainda sem abrir no Xcode.
- iOS 18 (ícones escuro e tingido) não incluídos; o ícone atual é escuro e funciona nos dois temas.
- Atributos `windowSplashScreen*` (API 31) validados só por compilação de recursos (o jar de validação é API 23).
- Preferência de tema e favoritos ficam em memória (sem persistência).
- País exibido como código ISO (sem tabela de nomes localizados); sem fontes não latinas embutidas.
- Sem dados reais: o fluxo real mostra estados vazios/"sem fonte integrada"; cartões aparecem só na prévia (`lib/main_preview.dart`) e nos testes, sempre rotulados como ilustrativos.
- Sem teste com usuários, leitor de tela em aparelho real ou simulação de daltonismo.
