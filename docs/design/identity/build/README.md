# Build das propostas de identidade

Gera todos os SVGs, PNGs, tokens, telas HTML e a comparação das três propostas do OrbiJob.

```bash
pip install fonttools brotli pillow      # Python 3.11+
cd docs/design/identity/build && npm i   # playwright-core (usa Chromium já instalado; CHROMIUM=/caminho/chromium)
python3 build.py all                     # assets, screens, render, rasters, sheets, shrink
node check.mjs .work/layout.json ../a-orbita/screens.html ../b-trajetorias/screens.html ../c-minimal/screens.html
python3 comparison.py                    # ../../comparison/index.html + PNGs rápidos
python3 verify.py                        # SVG, PNG nativo, ICO, contraste, legibilidade, layout (exit != 0 se falhar)
```

| Arquivo | Papel |
|---|---|
| `brand.py` | geometria dos símbolos, wordmarks (fontes OFL → curvas), paletas, auditoria de contraste, tokens |
| `screens.py` | telas HTML/CSS: mesmo conteúdo fictício nas três propostas, "pele" própria de cada uma |
| `build.py` | orquestra geração e renderização |
| `render.mjs`, `check.mjs` | captura (Playwright) e checagem de overflow/alvos de toque |
| `comparison.py`, `recommendation.html` | página de comparação |
| `verify.py` | verificações automáticas |

Fontes: `docs/design/fonts/` (SIL OFL 1.1). Nada aqui altera o aplicativo Flutter.
