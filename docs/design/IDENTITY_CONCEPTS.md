# OrbiJob — três propostas de identidade visual (nenhuma aprovada)

**Nenhuma identidade foi aplicada ao app.** O tema atual usa semente provisória (`kProvisionalSeed`). A aprovação é do proprietário.

Todos os arquivos estão em `docs/design/identity/<proposta>/`:
`logo-horizontal-{light,dark}.svg|png` · `icon-{light,dark}.svg|png` · `palette.md` (com razões de contraste WCAG calculadas) · `preview.html|png` (login, home e cartão de vaga, claro e escuro).
Reprodutível: `python3 docs/design/identity/generate.py && python3 docs/design/identity/render.py` (requer `fonttools`, Chromium headless). Wordmarks são **curvas vetoriais** geradas de Inter / DejaVu Sans Mono (fontes abertas) — as fontes finais sugeridas abaixo (Sora, Manrope, Space Grotesk) **não estavam instaláveis offline**, portanto os logotipos finais devem ser redesenhados com elas antes da adoção. Prévias usam Inter como fonte de interface. Os dados nas telas são **exemplos ilustrativos, rotulados como tal**.

| | A · Órbita | B · Trajetórias | C · Minimal Tech |
|---|---|---|---|
| Conceito | Globo com órbita e "satélite" = oportunidade que gira ao redor do mundo | Rede de pontos ligados por trajetórias; um nó em destaque = a vaga certa | "O" geométrico com cunha e pixel: precisão, dados, engenharia |
| Logotipo | Wordmark "OrbiJob" extra-bold arredondado | wordmark minúsculo "orbijob", peso médio, espaçado | wordmark monoespaçado "orbijob" |
| Ícone | planeta + anel + ponto âmbar | hexágono de 6 nós, 1 em coral | arco "O" + haste + pixel violeta |
| Paleta clara | fundo `#F6F8FC`, tinta `#0B1F4B`, azul `#2456D6`, âmbar `#F59E0B` | `#F3FAF8`, `#0F2A2E`, verde-azulado `#0B7F72`, coral `#E5502F` | `#FFFFFF`, `#111113`, violeta `#5B3DF5` |
| Paleta escura | `#0A1226`, azul `#7BA2FF`, âmbar `#FBBF24` | `#0A1819`, turquesa `#3DD4BF`, coral `#FF8266` | `#0C0C0E`, lavanda `#A593FF` |
| Tipografia sugerida | Sora + Inter | Manrope | Space Grotesk + JetBrains Mono + Inter |
| Linguagem de UI | cantos 20dp, ilustração de órbita, suave e amigável | cantos 14dp, linhas de trajetória, humano e editorial | cantos 6dp, linhas finas, rótulos mono, denso e técnico |
| Risco | astro/planeta é motivo comum em apps | ícone detalhado: precisa simplificação em 16–24px | pode soar frio para ofícios/saúde |

Aplicações: login, home e cartão de vaga em cada `preview.png`. Acessibilidade: `palette.md` traz razões de contraste WCAG calculadas para 4 pares por tema; todos os pares calculados atingiram AA (≥ 4,5:1). Outros pares (bordas, estados, gráficos) ainda não foram verificados.

Próximo passo: escolher uma proposta (ou combinar), então gerar assets finais (SVG redesenhado, ícones de app Android/iOS/PWA, splash), tokens `ColorScheme` e substituir `kProvisionalSeed`.
