# OrbiJob — design system

**Identidade oficial: C — Minimal Tech** (decisão do proprietário). Detalhes, tokens, fontes, logotipo, ícones, splash e limitações: [`docs/design/identity/c-minimal/APPLIED.md`](design/identity/c-minimal/APPLIED.md). As propostas A e B são histórico de exploração e não são aplicadas.

## Estrutura no código (`app/lib/core/design`, `core/widgets`)
```
core/design/
  tokens/app_colors.dart        GERADO de docs/design/identity/c-minimal/tokens.json (38 papéis × claro/escuro)
  tokens/component_colors.dart  aliases por componente (inputs, cards, chips, navegação, loading, seleção)
  tokens/app_dimensions.dart    espaçamento (múltiplos de 4), raios, alvos de toque, movimento, classes de janela, camadas de estado
  typography/app_typography.dart Space Grotesk / Inter / JetBrains Mono + fallback
  theme/app_theme.dart          ThemeData claro/escuro a partir dos tokens (sem ColorScheme.fromSeed)
  brand/                        AppAssets, BrandLogo, BrandSymbol
core/widgets/                   AppButton, AppSearchField, AppFilterChip, CompatibilityIndicator, ConfidenceIndicator,
                                FavoriteButton, StatusBadge, SectionHeader, StateView, Skeleton*, AppNavBar/AppNavRail, FocusRing
features/*/presentation         JobCard, JobDetailView e páginas (Início, Explorar, Favoritos, Candidaturas, Perfil)
```
Regras: nenhuma cor literal fora de `core/design` (teste); nenhum texto de interface literal (teste; tudo em l10n PT/EN/ES); estado nunca só por cor; alvos ≥ 48 dp; foco de teclado visível (contorno de 2 px).

## Navegação e responsividade
Barra inferior < 600 dp · rail com rótulos 600–1023 dp (só ícones se a janela tiver < 480 dp de altura) · rail estendido ≥ 1024 dp, com Explorar em lista + detalhe. Perfil no cabeçalho. Tema: sistema (padrão), claro ou escuro, escolhido em Perfil → Aparência (em memória).

## Estados
Carregando (skeleton, estático com "reduzir movimento"), vazio, erro com "tentar novamente", **sem fonte integrada** (informação honesta + orientação), e vazios de Início/Favoritos/Candidaturas.

## Testes (app: 139; Worker: 43)
| Suíte | Testes | Cobre |
|---|---|---|
| `test/design/tokens_test.dart` | 9 | Dart = `tokens.json`; âncoras oficiais; WCAG AA (texto) e 3:1 (controles/foco) em claro e escuro; sem cor literal; sem `kProvisionalSeed` |
| `test/features/theme_modes_test.dart` | 5 | `ThemeMode.system` (claro/escuro), escolha manual claro/escuro, tokens no scaffold, famílias de fonte |
| `test/features/navigation_test.dart` | 17 | 4 destinos, barra/rail/rail estendido/paisagem curta, Início→Explorar com foco, chips de área, cartões, favoritar→Favoritos, mestre/detalhe, rótulos sem quebra a 100/150/200% |
| `test/features/responsive_test.dart` | 40 | **sem overflow**: 8 tamanhos (320×568 a 1280×800 e paisagem) × texto 100/150/200% × claro/escuro; pt/es a 200%; 4 estados; teclado aberto; safe areas (a detecção foi validada com um teste de mutação a 160 px) |
| `test/features/accessibility_test.dart` | 11 | diretrizes Flutter (toque Android 48 / iOS 44, rótulos, contraste de texto) em claro/escuro; semântica de seleção e favorito; foco visível por Tab; reduzir movimento |
| `test/features/components_test.dart` | 10 | cartão só com dados existentes, títulos longos sem truncar a 200%, chips, botões, anel, badge, estados, skeleton, logotipo |
| `test/features/i18n_test.dart` | 7 | PT/EN/ES com as mesmas chaves e placeholders, sem strings fixas em widgets, 3 idiomas renderizando, moeda/data localizadas |
| `test/features/search_cubit_test.dart` | 6 | estados de busca, "sem fonte" honesto, compatibilidade ≠ confiança |
| `test/assets/brand_assets_test.dart` | 34 | SVGs válidos e idênticos à fonte, geometria do símbolo, fontes/licenças, Android (adaptativo, zona segura, PNGs, splash), iOS (Contents.json, PNGs opacos e dimensões, storyboard), Web (manifest, ícones, favicon, splash) |

Além dos testes: `dart format`, `flutter analyze` (sem problemas), `flutter build web --release` (produção e prévia), `validate_android.sh` (`aapt2`), `verify.py` das propostas, gitleaks. Rodam no CI (`.github/workflows/ci.yml`).

## Limitações
Ver "Limitações conhecidas" em `APPLIED.md` (APK/iOS não compilados neste ambiente; sem fontes não latinas embutidas; sem persistência de tema/favoritos).
