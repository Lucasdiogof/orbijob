# B · Trajetórias — paleta

> PROPOSTA. Não aplicada ao app. Todas as razões abaixo foram **calculadas** (WCAG 2.x) por `build/brand.py`.

## light

| Papel | Hex |
|---|---|
| `bg` | `#F4FAF8` |
| `surface` | `#FFFFFF` |
| `container` | `#E0F1ED` |
| `ink` | `#0E2A2D` |
| `muted` | `#3F6165` |
| `line` | `#D3E7E3` |
| `outline` | `#678C90` |
| `primary` | `#0B7F72` |
| `onPrimary` | `#FFFFFF` |
| `primaryContainer` | `#CDEFE9` |
| `onPrimaryContainer` | `#04332E` |
| `accent` | `#CC3D1A` |
| `onAccent` | `#FFFFFF` |
| `accentText` | `#B03416` |
| `success` | `#2E7D32` |
| `danger` | `#B3261E` |

## dark

| Papel | Hex |
|---|---|
| `bg` | `#09181A` |
| `surface` | `#102527` |
| `container` | `#17383B` |
| `ink` | `#E6F6F3` |
| `muted` | `#9FC4C0` |
| `line` | `#1F3F42` |
| `outline` | `#6F9A96` |
| `primary` | `#3DD4BF` |
| `onPrimary` | `#04332E` |
| `primaryContainer` | `#0F5A52` |
| `onPrimaryContainer` | `#CDEFE9` |
| `accent` | `#FF8A6B` |
| `onAccent` | `#3A0D00` |
| `accentText` | `#FF8A6B` |
| `success` | `#7FD98A` |
| `danger` | `#FFB4AB` |

## Contraste (todos os pares passam)

| Tema | Par | Cores | Razão | Critério |
|---|---|---|---|---|
| light | ink / bg | #0E2A2D / #F4FAF8 | 14.32 | texto AA ≥ 4,5 ✅ |
| light | ink / surface | #0E2A2D / #FFFFFF | 15.13 | texto AA ≥ 4,5 ✅ |
| light | ink / container | #0E2A2D / #E0F1ED | 12.95 | texto AA ≥ 4,5 ✅ |
| light | muted / bg | #3F6165 / #F4FAF8 | 6.39 | texto AA ≥ 4,5 ✅ |
| light | muted / surface | #3F6165 / #FFFFFF | 6.75 | texto AA ≥ 4,5 ✅ |
| light | muted / container | #3F6165 / #E0F1ED | 5.78 | texto AA ≥ 4,5 ✅ |
| light | onPrimary / primary | #FFFFFF / #0B7F72 | 4.89 | texto AA ≥ 4,5 ✅ |
| light | primary / bg | #0B7F72 / #F4FAF8 | 4.63 | texto AA ≥ 4,5 ✅ |
| light | primary / surface | #0B7F72 / #FFFFFF | 4.89 | texto AA ≥ 4,5 ✅ |
| light | onPrimaryContainer / primaryContainer | #04332E / #CDEFE9 | 11.28 | texto AA ≥ 4,5 ✅ |
| light | onAccent / accent | #FFFFFF / #CC3D1A | 4.94 | texto AA ≥ 4,5 ✅ |
| light | accentText / surface | #B03416 / #FFFFFF | 6.27 | texto AA ≥ 4,5 ✅ |
| light | success / surface | #2E7D32 / #FFFFFF | 5.13 | texto AA ≥ 4,5 ✅ |
| light | danger / surface | #B3261E / #FFFFFF | 6.54 | texto AA ≥ 4,5 ✅ |
| light | outline / bg | #678C90 / #F4FAF8 | 3.47 | componente ≥ 3,0 ✅ |
| light | outline / surface | #678C90 / #FFFFFF | 3.66 | componente ≥ 3,0 ✅ |
| light | primary / bg | #0B7F72 / #F4FAF8 | 4.63 | componente ≥ 3,0 ✅ |
| dark | ink / bg | #E6F6F3 / #09181A | 16.28 | texto AA ≥ 4,5 ✅ |
| dark | ink / surface | #E6F6F3 / #102527 | 14.32 | texto AA ≥ 4,5 ✅ |
| dark | ink / container | #E6F6F3 / #17383B | 11.31 | texto AA ≥ 4,5 ✅ |
| dark | muted / bg | #9FC4C0 / #09181A | 9.62 | texto AA ≥ 4,5 ✅ |
| dark | muted / surface | #9FC4C0 / #102527 | 8.46 | texto AA ≥ 4,5 ✅ |
| dark | muted / container | #9FC4C0 / #17383B | 6.68 | texto AA ≥ 4,5 ✅ |
| dark | onPrimary / primary | #04332E / #3DD4BF | 7.49 | texto AA ≥ 4,5 ✅ |
| dark | primary / bg | #3DD4BF / #09181A | 9.82 | texto AA ≥ 4,5 ✅ |
| dark | primary / surface | #3DD4BF / #102527 | 8.64 | texto AA ≥ 4,5 ✅ |
| dark | onPrimaryContainer / primaryContainer | #CDEFE9 / #0F5A52 | 6.57 | texto AA ≥ 4,5 ✅ |
| dark | onAccent / accent | #3A0D00 / #FF8A6B | 7.35 | texto AA ≥ 4,5 ✅ |
| dark | accentText / surface | #FF8A6B / #102527 | 6.91 | texto AA ≥ 4,5 ✅ |
| dark | success / surface | #7FD98A / #102527 | 9.27 | texto AA ≥ 4,5 ✅ |
| dark | danger / surface | #FFB4AB / #102527 | 9.40 | texto AA ≥ 4,5 ✅ |
| dark | outline / bg | #6F9A96 / #09181A | 5.82 | componente ≥ 3,0 ✅ |
| dark | outline / surface | #6F9A96 / #102527 | 5.12 | componente ≥ 3,0 ✅ |
| dark | primary / bg | #3DD4BF / #09181A | 9.82 | componente ≥ 3,0 ✅ |

Logotipos/ícones são elementos gráficos (critério 3:1 para objetos gráficos); wordmarks usam as cores `ink`/`primary` acima.
