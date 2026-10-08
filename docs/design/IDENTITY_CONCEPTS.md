# OrbiJob — propostas de identidade visual (refinadas; nenhuma aprovada)

**Nenhuma identidade foi aplicada ao app.** O tema do Flutter continua com semente provisória (`kProvisionalSeed`) e os ícones padrão do Flutter permanecem. A escolha é do proprietário.

➡️ **Comece pela comparação:** [`comparison/README.md`](comparison/README.md) → `comparison/index.html` (navegável) ou `comparison/png/` (imagens rápidas).

| | A · Órbita | B · Trajetórias | C · Minimal Tech |
|---|---|---|---|
| Conceito | oportunidades ao redor do mundo: globo + órbita + ponto âmbar | pessoas e lugares conectados por rotas: anel de nós com um nó coral | busca com precisão: "O" de dois arcos, espaço negativo e ponto violeta |
| Wordmark | `OrbiJob` (Sora Bold, "Job" em azul) | `orbijob` (Manrope ExtraBold, ponto do "j" coral) | `ORBIJOB` (Space Grotesk SemiBold, caixa-alta espaçada) |
| Cores (claro) | azul `#1F5FE0`, âmbar `#F5A524`, fundo `#F5F8FF` | verde-azulado `#0B7F72`, coral `#CC3D1A`, fundo `#F4FAF8` | violeta `#5B3DF5`, preto `#111113`, fundo `#FFFFFF` |
| Linguagem de UI | suave, cantos 20 dp, sombras leves, navegação em pílula | acolhedora, cantos 16 dp, borda de "trilha" nos cartões, avatar com anel | densa, cantos 8 dp, linhas de 1 px, rótulos monoespaçados |
| Tipografia | Sora + Inter | Manrope | Space Grotesk + Inter + JetBrains Mono |

Entregáveis por proposta (em `identity/<proposta>/`): logotipo horizontal claro/escuro/monocromático (SVG), ícone de app claro/escuro/monocromático/maskable (SVG), favicon (SVG + ICO), PNGs de prévia e nos tamanhos reais 16–512 px, aplicação em fundo branco e escuro, `palette.md` (contrastes calculados), `tokens.json`, `typography.md`, 8 telas + 4 estados em claro/escuro, tablet e desktop. Veja `identity/<proposta>/README.md`.

**Fontes:** Sora, Manrope, Space Grotesk, Inter e JetBrains Mono, todas SIL OFL 1.1 (licenças em `fonts/`). **Conteúdo das telas:** fictício, igual nas três propostas e rotulado em cada tela.

**Verificações automáticas:** `comparison/verification.md`. **Recomendação de design (não decisão):** A · Órbita como principal, com ressalvas — veja `comparison/png/09-recomendacao.png`.

Próximo passo após a escolha: redesenhar o logotipo com as famílias completas, gerar ícones Android/iOS/PWA e splash definitivos, aplicar os tokens ao `ThemeData` (substituindo `kProvisionalSeed`) e atualizar `DESIGN_SYSTEM.md`.
