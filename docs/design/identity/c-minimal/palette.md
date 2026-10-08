# C · Minimal Tech — paleta

> PROPOSTA. Não aplicada ao app. Todas as razões abaixo foram **calculadas** (WCAG 2.x) por `build/brand.py`.

## light

| Papel | Hex |
|---|---|
| `bg` | `#FFFFFF` |
| `surface` | `#FFFFFF` |
| `container` | `#F4F4F7` |
| `ink` | `#111113` |
| `muted` | `#55555F` |
| `line` | `#E4E4EA` |
| `outline` | `#8A8A96` |
| `primary` | `#5B3DF5` |
| `onPrimary` | `#FFFFFF` |
| `primaryContainer` | `#ECE8FF` |
| `onPrimaryContainer` | `#2A1A8A` |
| `accent` | `#111113` |
| `onAccent` | `#FFFFFF` |
| `accentText` | `#111113` |
| `success` | `#1B7A43` |
| `danger` | `#B3261E` |

## dark

| Papel | Hex |
|---|---|
| `bg` | `#0B0B0D` |
| `surface` | `#131316` |
| `container` | `#1C1C21` |
| `ink` | `#F4F4F6` |
| `muted` | `#A6A6B3` |
| `line` | `#2A2A31` |
| `outline` | `#7A7A88` |
| `primary` | `#A593FF` |
| `onPrimary` | `#1A0F57` |
| `primaryContainer` | `#3A2C99` |
| `onPrimaryContainer` | `#E6E0FF` |
| `accent` | `#F4F4F6` |
| `onAccent` | `#111113` |
| `accentText` | `#F4F4F6` |
| `success` | `#6BD79B` |
| `danger` | `#FFB4AB` |

## Contraste (todos os pares passam)

| Tema | Par | Cores | Razão | Critério |
|---|---|---|---|---|
| light | ink / bg | #111113 / #FFFFFF | 18.86 | texto AA ≥ 4,5 ✅ |
| light | ink / surface | #111113 / #FFFFFF | 18.86 | texto AA ≥ 4,5 ✅ |
| light | ink / container | #111113 / #F4F4F7 | 17.18 | texto AA ≥ 4,5 ✅ |
| light | muted / bg | #55555F / #FFFFFF | 7.37 | texto AA ≥ 4,5 ✅ |
| light | muted / surface | #55555F / #FFFFFF | 7.37 | texto AA ≥ 4,5 ✅ |
| light | muted / container | #55555F / #F4F4F7 | 6.71 | texto AA ≥ 4,5 ✅ |
| light | onPrimary / primary | #FFFFFF / #5B3DF5 | 6.12 | texto AA ≥ 4,5 ✅ |
| light | primary / bg | #5B3DF5 / #FFFFFF | 6.12 | texto AA ≥ 4,5 ✅ |
| light | primary / surface | #5B3DF5 / #FFFFFF | 6.12 | texto AA ≥ 4,5 ✅ |
| light | onPrimaryContainer / primaryContainer | #2A1A8A / #ECE8FF | 10.88 | texto AA ≥ 4,5 ✅ |
| light | onAccent / accent | #FFFFFF / #111113 | 18.86 | texto AA ≥ 4,5 ✅ |
| light | accentText / surface | #111113 / #FFFFFF | 18.86 | texto AA ≥ 4,5 ✅ |
| light | success / surface | #1B7A43 / #FFFFFF | 5.37 | texto AA ≥ 4,5 ✅ |
| light | danger / surface | #B3261E / #FFFFFF | 6.54 | texto AA ≥ 4,5 ✅ |
| light | outline / bg | #8A8A96 / #FFFFFF | 3.41 | componente ≥ 3,0 ✅ |
| light | outline / surface | #8A8A96 / #FFFFFF | 3.41 | componente ≥ 3,0 ✅ |
| light | primary / bg | #5B3DF5 / #FFFFFF | 6.12 | componente ≥ 3,0 ✅ |
| dark | ink / bg | #F4F4F6 / #0B0B0D | 17.90 | texto AA ≥ 4,5 ✅ |
| dark | ink / surface | #F4F4F6 / #131316 | 16.88 | texto AA ≥ 4,5 ✅ |
| dark | ink / container | #F4F4F6 / #1C1C21 | 15.45 | texto AA ≥ 4,5 ✅ |
| dark | muted / bg | #A6A6B3 / #0B0B0D | 8.17 | texto AA ≥ 4,5 ✅ |
| dark | muted / surface | #A6A6B3 / #131316 | 7.71 | texto AA ≥ 4,5 ✅ |
| dark | muted / container | #A6A6B3 / #1C1C21 | 7.05 | texto AA ≥ 4,5 ✅ |
| dark | onPrimary / primary | #1A0F57 / #A593FF | 6.57 | texto AA ≥ 4,5 ✅ |
| dark | primary / bg | #A593FF / #0B0B0D | 7.69 | texto AA ≥ 4,5 ✅ |
| dark | primary / surface | #A593FF / #131316 | 7.26 | texto AA ≥ 4,5 ✅ |
| dark | onPrimaryContainer / primaryContainer | #E6E0FF / #3A2C99 | 8.23 | texto AA ≥ 4,5 ✅ |
| dark | onAccent / accent | #111113 / #F4F4F6 | 17.17 | texto AA ≥ 4,5 ✅ |
| dark | accentText / surface | #F4F4F6 / #131316 | 16.88 | texto AA ≥ 4,5 ✅ |
| dark | success / surface | #6BD79B / #131316 | 10.44 | texto AA ≥ 4,5 ✅ |
| dark | danger / surface | #FFB4AB / #131316 | 10.92 | texto AA ≥ 4,5 ✅ |
| dark | outline / bg | #7A7A88 / #0B0B0D | 4.65 | componente ≥ 3,0 ✅ |
| dark | outline / surface | #7A7A88 / #131316 | 4.39 | componente ≥ 3,0 ✅ |
| dark | primary / bg | #A593FF / #0B0B0D | 7.69 | componente ≥ 3,0 ✅ |

Logotipos/ícones são elementos gráficos (critério 3:1 para objetos gráficos); wordmarks usam as cores `ink`/`primary` acima.
