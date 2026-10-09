# Comparação das identidades do OrbiJob

> **Material histórico.** Esta comparação serviu à decisão: o proprietário escolheu a identidade **C — Minimal Tech**, hoje aplicada ao app ([`../identity/c-minimal/APPLIED.md`](../identity/c-minimal/APPLIED.md)). A e B não são aplicadas. Todo conteúdo de tela aqui é fictício e identificado como tal (mockups; as capturas do app real estão em [`../flutter-screenshots/`](../flutter-screenshots/README.md)).

## Como visualizar
1. **Navegável (recomendado):** abra [`index.html`](index.html) no navegador (duplo clique ou `python3 -m http.server` na pasta `docs/design`, depois `http://localhost:8000/comparison/`). Usa fontes locais de `../fonts/` e imagens de `../identity/`, portanto **mantenha a estrutura de pastas**. O GitHub exibe HTML como código; clone o repositório (ou baixe a branch) para ver a página.
2. **Visualização rápida (PNG, direto no GitHub):** a pasta [`png/`](png/) tem as seções da página: logotipos, ícones, paletas, home claro/escuro, explorar, tablet/desktop, estados, prós e contras e recomendação.
3. **Por proposta:** `../identity/<proposta>/` — `sheet-mobile-light.png` e `sheet-mobile-dark.png` (8 telas lado a lado), `screens/` (cada tela), `screens.html` (telas ao vivo), `png/` (logos, ícones, favicons, aplicação em fundo branco e escuro).

| Proposta | Pasta |
|---|---|
| A · Órbita | [`../identity/a-orbita/`](../identity/a-orbita/) |
| B · Trajetórias | [`../identity/b-trajetorias/`](../identity/b-trajetorias/) |
| C · Minimal Tech | [`../identity/c-minimal/`](../identity/c-minimal/) |

## O que há na comparação
Logotipos (claro, escuro, monocromáticos) · ícones nos tamanhos reais 16/32/48/64/128/512 px · paletas e tipografia · home, explorar, detalhes, favoritos, candidatura, perfil, splash e login em claro e escuro · tablet e desktop (navigation rail) · estados carregando/vazio/erro/sem fonte · pontos fortes, fracos, riscos · recomendação fundamentada.

## Verificações
[`verification.md`](verification.md) (gerado por `python3 docs/design/identity/build/verify.py`): SVGs íntegros, PNGs em tamanho nativo, `favicon.ico`, contraste WCAG AA calculado, legibilidade em 16/32 px, ausência de overflow e de alvos de toque < 44 px nas telas, licenças de fontes. **Não coberto:** teste com usuários, simulação de daltonismo, leitores de tela, marca registrada.

## Regerar
Ver [`../identity/build/README.md`](../identity/build/README.md).
