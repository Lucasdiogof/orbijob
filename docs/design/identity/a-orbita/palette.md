# A · Órbita — paleta

> PROPOSTA. Não aplicada ao app. Todas as razões abaixo foram **calculadas** (WCAG 2.x) por `build/brand.py`.

## light

| Papel | Hex |
|---|---|
| `bg` | `#F5F8FF` |
| `surface` | `#FFFFFF` |
| `container` | `#E8EFFE` |
| `ink` | `#0A1B44` |
| `muted` | `#43517A` |
| `line` | `#DCE4F5` |
| `outline` | `#6B7AA3` |
| `primary` | `#1F5FE0` |
| `onPrimary` | `#FFFFFF` |
| `primaryContainer` | `#DCE7FF` |
| `onPrimaryContainer` | `#0A2A6B` |
| `accent` | `#F5A524` |
| `onAccent` | `#2B1A00` |
| `accentText` | `#8A5200` |
| `success` | `#0E7A4B` |
| `danger` | `#B3261E` |

## dark

| Papel | Hex |
|---|---|
| `bg` | `#081330` |
| `surface` | `#0F1D42` |
| `container` | `#172A5A` |
| `ink` | `#EEF3FF` |
| `muted` | `#A9B8E0` |
| `line` | `#223463` |
| `outline` | `#7C8DBB` |
| `primary` | `#8DB6FF` |
| `onPrimary` | `#06163F` |
| `primaryContainer` | `#1B3A85` |
| `onPrimaryContainer` | `#DCE7FF` |
| `accent` | `#FFC247` |
| `onAccent` | `#2B1A00` |
| `accentText` | `#FFC247` |
| `success` | `#5BD69A` |
| `danger` | `#FFB4AB` |

## Contraste (todos os pares passam)

| Tema | Par | Cores | Razão | Critério |
|---|---|---|---|---|
| light | ink / bg | #0A1B44 / #F5F8FF | 15.76 | texto AA ≥ 4,5 ✅ |
| light | ink / surface | #0A1B44 / #FFFFFF | 16.76 | texto AA ≥ 4,5 ✅ |
| light | ink / container | #0A1B44 / #E8EFFE | 14.53 | texto AA ≥ 4,5 ✅ |
| light | muted / bg | #43517A / #F5F8FF | 7.33 | texto AA ≥ 4,5 ✅ |
| light | muted / surface | #43517A / #FFFFFF | 7.79 | texto AA ≥ 4,5 ✅ |
| light | muted / container | #43517A / #E8EFFE | 6.75 | texto AA ≥ 4,5 ✅ |
| light | onPrimary / primary | #FFFFFF / #1F5FE0 | 5.57 | texto AA ≥ 4,5 ✅ |
| light | primary / bg | #1F5FE0 / #F5F8FF | 5.24 | texto AA ≥ 4,5 ✅ |
| light | primary / surface | #1F5FE0 / #FFFFFF | 5.57 | texto AA ≥ 4,5 ✅ |
| light | onPrimaryContainer / primaryContainer | #0A2A6B / #DCE7FF | 10.87 | texto AA ≥ 4,5 ✅ |
| light | onAccent / accent | #2B1A00 / #F5A524 | 8.23 | texto AA ≥ 4,5 ✅ |
| light | accentText / surface | #8A5200 / #FFFFFF | 6.39 | texto AA ≥ 4,5 ✅ |
| light | success / surface | #0E7A4B / #FFFFFF | 5.38 | texto AA ≥ 4,5 ✅ |
| light | danger / surface | #B3261E / #FFFFFF | 6.54 | texto AA ≥ 4,5 ✅ |
| light | outline / bg | #6B7AA3 / #F5F8FF | 4.00 | componente ≥ 3,0 ✅ |
| light | outline / surface | #6B7AA3 / #FFFFFF | 4.25 | componente ≥ 3,0 ✅ |
| light | primary / bg | #1F5FE0 / #F5F8FF | 5.24 | componente ≥ 3,0 ✅ |
| dark | ink / bg | #EEF3FF / #081330 | 16.49 | texto AA ≥ 4,5 ✅ |
| dark | ink / surface | #EEF3FF / #0F1D42 | 14.83 | texto AA ≥ 4,5 ✅ |
| dark | ink / container | #EEF3FF / #172A5A | 12.47 | texto AA ≥ 4,5 ✅ |
| dark | muted / bg | #A9B8E0 / #081330 | 9.27 | texto AA ≥ 4,5 ✅ |
| dark | muted / surface | #A9B8E0 / #0F1D42 | 8.33 | texto AA ≥ 4,5 ✅ |
| dark | muted / container | #A9B8E0 / #172A5A | 7.01 | texto AA ≥ 4,5 ✅ |
| dark | onPrimary / primary | #06163F / #8DB6FF | 8.60 | texto AA ≥ 4,5 ✅ |
| dark | primary / bg | #8DB6FF / #081330 | 8.96 | texto AA ≥ 4,5 ✅ |
| dark | primary / surface | #8DB6FF / #0F1D42 | 8.05 | texto AA ≥ 4,5 ✅ |
| dark | onPrimaryContainer / primaryContainer | #DCE7FF / #1B3A85 | 8.50 | texto AA ≥ 4,5 ✅ |
| dark | onAccent / accent | #2B1A00 / #FFC247 | 10.44 | texto AA ≥ 4,5 ✅ |
| dark | accentText / surface | #FFC247 / #0F1D42 | 10.25 | texto AA ≥ 4,5 ✅ |
| dark | success / surface | #5BD69A / #0F1D42 | 9.05 | texto AA ≥ 4,5 ✅ |
| dark | danger / surface | #FFB4AB / #0F1D42 | 9.70 | texto AA ≥ 4,5 ✅ |
| dark | outline / bg | #7C8DBB / #081330 | 5.57 | componente ≥ 3,0 ✅ |
| dark | outline / surface | #7C8DBB / #0F1D42 | 5.01 | componente ≥ 3,0 ✅ |
| dark | primary / bg | #8DB6FF / #081330 | 8.96 | componente ≥ 3,0 ✅ |

Logotipos/ícones são elementos gráficos (critério 3:1 para objetos gráficos); wordmarks usam as cores `ink`/`primary` acima.
