# OrbiJob — proposta B · Trajetórias

> **PROPOSTA. Não aplicada ao aplicativo.** Escolha pendente do proprietário. Comparação lado a lado: [`../../comparison/index.html`](../../comparison/index.html).

## Logotipo e ícone (vetor)
| Arquivo | Uso |
|---|---|
| `logo-horizontal-{light,dark}.svg` | logotipo completo para fundo claro / escuro |
| `logo-horizontal-mono-{black,white}.svg` | monocromático (carimbo, impressão, 1 cor) |
| `icon-app.svg` | ícone de aplicativo (tile da marca) |
| `icon-{light,dark}.svg` | ícone em tile claro / escuro |
| `icon-mono-{black,white}.svg` | símbolo sem tile, 1 cor |
| `icon-app-small.svg`, `favicon.svg` | versão óptica simplificada para ≤ 32 px |
| `icon-app-maskable.svg` | área segura para ícone adaptativo Android |
| `favicon.ico` | 16, 32 e 48 px (cada imagem renderizada do vetor no próprio tamanho) |

## Prévias (PNG)
- `png/` — logotipos, ícones (256 px), favicons e ícones em 16/32/48/64/128/512 px **nativos**; `application-white.png` e `application-dark.png` (aplicação em fundo branco e escuro).
- `icon-sizes-light.png`, `icon-sizes-dark.png` — teste de legibilidade nos tamanhos reais.
- `screens/{light,dark}/` — splash, login, home, explorar, detalhes, favoritos, candidatura, perfil, 4 estados (carregando, vazio, erro, sem fonte), tablet e desktop.
- `sheet-mobile-{light,dark}.png` — as 8 telas lado a lado; `screens.html` — telas ao vivo (HTML).

## Design
`palette.md` (contrastes calculados) · `tokens.json` (cor, tipografia, espaçamento, forma, movimento, breakpoints) · `typography.md`.

Todo conteúdo de tela (vagas, empresas, notas, salários, compatibilidade) é **fictício** e rotulado como tal. Reprodução: `docs/design/identity/build/README.md`.
