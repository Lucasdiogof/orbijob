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
| `containerHigh` | `#EAEAF0` |
| `secondary` | `#111113` |
| `onSecondary` | `#FFFFFF` |
| `secondaryContainer` | `#E9E9EE` |
| `onSecondaryContainer` | `#111113` |
| `error` | `#B3261E` |
| `onError` | `#FFFFFF` |
| `errorContainer` | `#FDECEA` |
| `onErrorContainer` | `#5F1410` |
| `onSuccess` | `#FFFFFF` |
| `successContainer` | `#E3F4EA` |
| `onSuccessContainer` | `#0B3D20` |
| `warning` | `#8A5A00` |
| `onWarning` | `#FFFFFF` |
| `warningContainer` | `#FFF1D6` |
| `onWarningContainer` | `#4A2F00` |
| `disabledFg` | `#8A8A96` |
| `disabledBg` | `#EDEDF1` |
| `focus` | `#5B3DF5` |
| `divider` | `#E4E4EA` |
| `skeletonBase` | `#F4F4F7` |
| `skeletonHighlight` | `#EAEAF0` |

## dark

| Papel | Hex |
|---|---|
| `bg` | `#0C0C0E` |
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
| `containerHigh` | `#26262C` |
| `secondary` | `#F4F4F6` |
| `onSecondary` | `#111113` |
| `secondaryContainer` | `#26262C` |
| `onSecondaryContainer` | `#F4F4F6` |
| `error` | `#FFB4AB` |
| `onError` | `#690005` |
| `errorContainer` | `#93000A` |
| `onErrorContainer` | `#FFDAD6` |
| `onSuccess` | `#00391C` |
| `successContainer` | `#12432A` |
| `onSuccessContainer` | `#C6F0D6` |
| `warning` | `#FFC857` |
| `onWarning` | `#2B1A00` |
| `warningContainer` | `#4A3300` |
| `onWarningContainer` | `#FFE2A8` |
| `disabledFg` | `#6E6E7A` |
| `disabledBg` | `#1E1E23` |
| `focus` | `#A593FF` |
| `divider` | `#2A2A31` |
| `skeletonBase` | `#1C1C21` |
| `skeletonHighlight` | `#26262C` |

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
| light | onSecondary / secondary | #FFFFFF / #111113 | 18.86 | texto AA ≥ 4,5 ✅ |
| light | onSecondaryContainer / secondaryContainer | #111113 / #E9E9EE | 15.59 | texto AA ≥ 4,5 ✅ |
| light | onError / error | #FFFFFF / #B3261E | 6.54 | texto AA ≥ 4,5 ✅ |
| light | onErrorContainer / errorContainer | #5F1410 / #FDECEA | 11.52 | texto AA ≥ 4,5 ✅ |
| light | onSuccess / success | #FFFFFF / #1B7A43 | 5.37 | texto AA ≥ 4,5 ✅ |
| light | onSuccessContainer / successContainer | #0B3D20 / #E3F4EA | 10.80 | texto AA ≥ 4,5 ✅ |
| light | onWarning / warning | #FFFFFF / #8A5A00 | 5.93 | texto AA ≥ 4,5 ✅ |
| light | onWarningContainer / warningContainer | #4A2F00 / #FFF1D6 | 11.08 | texto AA ≥ 4,5 ✅ |
| light | error / surface | #B3261E / #FFFFFF | 6.54 | texto AA ≥ 4,5 ✅ |
| light | error / bg | #B3261E / #FFFFFF | 6.54 | texto AA ≥ 4,5 ✅ |
| light | success / bg | #1B7A43 / #FFFFFF | 5.37 | texto AA ≥ 4,5 ✅ |
| light | warning / surface | #8A5A00 / #FFFFFF | 5.93 | texto AA ≥ 4,5 ✅ |
| light | warning / bg | #8A5A00 / #FFFFFF | 5.93 | texto AA ≥ 4,5 ✅ |
| light | ink / containerHigh | #111113 / #EAEAF0 | 15.74 | texto AA ≥ 4,5 ✅ |
| light | muted / containerHigh | #55555F / #EAEAF0 | 6.15 | texto AA ≥ 4,5 ✅ |
| light | outline / bg | #8A8A96 / #FFFFFF | 3.41 | componente ≥ 3,0 ✅ |
| light | outline / surface | #8A8A96 / #FFFFFF | 3.41 | componente ≥ 3,0 ✅ |
| light | primary / bg | #5B3DF5 / #FFFFFF | 6.12 | componente ≥ 3,0 ✅ |
| light | focus / bg | #5B3DF5 / #FFFFFF | 6.12 | componente ≥ 3,0 ✅ |
| light | focus / surface | #5B3DF5 / #FFFFFF | 6.12 | componente ≥ 3,0 ✅ |
| light | primary / surface | #5B3DF5 / #FFFFFF | 6.12 | componente ≥ 3,0 ✅ |
| light | outline / container | #8A8A96 / #F4F4F7 | 3.11 | componente ≥ 3,0 ✅ |
| dark | ink / bg | #F4F4F6 / #0C0C0E | 17.79 | texto AA ≥ 4,5 ✅ |
| dark | ink / surface | #F4F4F6 / #131316 | 16.88 | texto AA ≥ 4,5 ✅ |
| dark | ink / container | #F4F4F6 / #1C1C21 | 15.45 | texto AA ≥ 4,5 ✅ |
| dark | muted / bg | #A6A6B3 / #0C0C0E | 8.12 | texto AA ≥ 4,5 ✅ |
| dark | muted / surface | #A6A6B3 / #131316 | 7.71 | texto AA ≥ 4,5 ✅ |
| dark | muted / container | #A6A6B3 / #1C1C21 | 7.05 | texto AA ≥ 4,5 ✅ |
| dark | onPrimary / primary | #1A0F57 / #A593FF | 6.57 | texto AA ≥ 4,5 ✅ |
| dark | primary / bg | #A593FF / #0C0C0E | 7.65 | texto AA ≥ 4,5 ✅ |
| dark | primary / surface | #A593FF / #131316 | 7.26 | texto AA ≥ 4,5 ✅ |
| dark | onPrimaryContainer / primaryContainer | #E6E0FF / #3A2C99 | 8.23 | texto AA ≥ 4,5 ✅ |
| dark | onAccent / accent | #111113 / #F4F4F6 | 17.17 | texto AA ≥ 4,5 ✅ |
| dark | accentText / surface | #F4F4F6 / #131316 | 16.88 | texto AA ≥ 4,5 ✅ |
| dark | success / surface | #6BD79B / #131316 | 10.44 | texto AA ≥ 4,5 ✅ |
| dark | danger / surface | #FFB4AB / #131316 | 10.92 | texto AA ≥ 4,5 ✅ |
| dark | onSecondary / secondary | #111113 / #F4F4F6 | 17.17 | texto AA ≥ 4,5 ✅ |
| dark | onSecondaryContainer / secondaryContainer | #F4F4F6 / #26262C | 13.69 | texto AA ≥ 4,5 ✅ |
| dark | onError / error | #690005 / #FFB4AB | 7.72 | texto AA ≥ 4,5 ✅ |
| dark | onErrorContainer / errorContainer | #FFDAD6 / #93000A | 7.24 | texto AA ≥ 4,5 ✅ |
| dark | onSuccess / success | #00391C / #6BD79B | 7.38 | texto AA ≥ 4,5 ✅ |
| dark | onSuccessContainer / successContainer | #C6F0D6 / #12432A | 9.04 | texto AA ≥ 4,5 ✅ |
| dark | onWarning / warning | #2B1A00 / #FFC857 | 10.92 | texto AA ≥ 4,5 ✅ |
| dark | onWarningContainer / warningContainer | #FFE2A8 / #4A3300 | 9.46 | texto AA ≥ 4,5 ✅ |
| dark | error / surface | #FFB4AB / #131316 | 10.92 | texto AA ≥ 4,5 ✅ |
| dark | error / bg | #FFB4AB / #0C0C0E | 11.51 | texto AA ≥ 4,5 ✅ |
| dark | success / bg | #6BD79B / #0C0C0E | 11.00 | texto AA ≥ 4,5 ✅ |
| dark | warning / surface | #FFC857 / #131316 | 12.05 | texto AA ≥ 4,5 ✅ |
| dark | warning / bg | #FFC857 / #0C0C0E | 12.70 | texto AA ≥ 4,5 ✅ |
| dark | ink / containerHigh | #F4F4F6 / #26262C | 13.69 | texto AA ≥ 4,5 ✅ |
| dark | muted / containerHigh | #A6A6B3 / #26262C | 6.25 | texto AA ≥ 4,5 ✅ |
| dark | outline / bg | #7A7A88 / #0C0C0E | 4.62 | componente ≥ 3,0 ✅ |
| dark | outline / surface | #7A7A88 / #131316 | 4.39 | componente ≥ 3,0 ✅ |
| dark | primary / bg | #A593FF / #0C0C0E | 7.65 | componente ≥ 3,0 ✅ |
| dark | focus / bg | #A593FF / #0C0C0E | 7.65 | componente ≥ 3,0 ✅ |
| dark | focus / surface | #A593FF / #131316 | 7.26 | componente ≥ 3,0 ✅ |
| dark | primary / surface | #A593FF / #131316 | 7.26 | componente ≥ 3,0 ✅ |
| dark | outline / container | #7A7A88 / #1C1C21 | 4.01 | componente ≥ 3,0 ✅ |

Logotipos/ícones são elementos gráficos (critério 3:1 para objetos gráficos); wordmarks usam as cores `ink`/`primary` acima.
