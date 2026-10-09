#!/usr/bin/env python3
"""Builds every identity asset. Usage: python3 build.py [assets|screens|render|all]
Requires: python fonttools+brotli+pillow, node (playwright-core in this folder), Chromium (CHROMIUM env var)."""
import json, pathlib, subprocess, sys, struct, io
import brand, screens
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]          # docs/design/identity
DESIGN = ROOT.parent                                         # docs/design
BUILD = pathlib.Path(__file__).resolve().parent
SCRATCH = BUILD / '.work'; SCRATCH.mkdir(exist_ok=True)
KEYS = brand.PALETTES.keys()

def w(path, text): path.parent.mkdir(parents=True, exist_ok=True); path.write_text(text)

def render(jobs):
    jf = SCRATCH / 'jobs.json'; jf.write_text(json.dumps(jobs))
    subprocess.run(['node', 'render.mjs', str(jf)], cwd=BUILD, check=True)

# ───────────── 1. vector assets ─────────────
def assets():
    for k in KEYS:
        d = ROOT / k
        for v in ('light', 'dark', 'mono-black', 'mono-white'):
            w(d / f'logo-horizontal-{v}.svg', brand.logo_svg(k, v))
        for kind in ('app', 'light', 'dark', 'mono-black', 'mono-white'):
            w(d / f'icon-{kind}.svg', brand.icon_svg(k, kind))
        w(d / 'icon-app-small.svg', brand.icon_svg(k, 'app', small=True))       # optical size for <= 32 px
        w(d / 'icon-app-maskable.svg', brand.icon_svg(k, 'app', maskable=True))  # Android adaptive (safe zone)
        w(d / 'favicon.svg', brand.icon_svg(k, 'app', small=True))
        # docs
        rows, ok = brand.audit_palette(k)
        assert ok, f'contrast failure in {k}'
        pal = f'# {screens.LABEL[k]} — paleta\n\n> PROPOSTA. Não aplicada ao app. Todas as razões abaixo foram **calculadas** (WCAG 2.x) por `build/brand.py`.\n\n'
        for mode in ('light', 'dark'):
            pal += f'## {mode}\n\n| Papel | Hex |\n|---|---|\n' + ''.join(f'| `{n}` | `{v}` |\n' for n, v in brand.PALETTES[k][mode].items()) + '\n'
        pal += '## Contraste (todos os pares passam)\n\n| Tema | Par | Cores | Razão | Critério |\n|---|---|---|---|---|\n' + ''.join(
            f'| {m} | {p} | {a} / {b} | {r:.2f} | {crit} ✅ |\n' for m, p, a, b, r, crit, okk in rows)
        pal += '\nLogotipos/ícones são elementos gráficos (critério 3:1 para objetos gráficos); wordmarks usam as cores `ink`/`primary` acima.\n'
        w(d / 'palette.md', pal)
        w(d / 'tokens.json', json.dumps(brand.tokens(k), indent=2, ensure_ascii=False) + '\n')
        t = brand.TYPE[k]
        w(d / 'typography.md', f'# {screens.LABEL[k]} — tipografia\n\n{t["note"]}\n\n| Papel | Família | Licença |\n|---|---|---|\n| Títulos / logotipo | {t["display"]} | SIL OFL 1.1 |\n| Texto | {t["text"]} | SIL OFL 1.1 |\n| Dados / rótulos | {t["mono"]} | SIL OFL 1.1 |\n\n'
          'Escala (dp): displayLarge 32/40 · headline 24/32 · title 18/24 · body 15/22 · bodySmall 13/18 · label 12/16.\n\n'
          'Arquivos `woff2` (latino) e licenças em `docs/design/fonts/`. Wordmarks do logotipo são **curvas vetoriais** (sem dependência de fonte instalada). '
          'Para o app final, incluir as famílias completas se for necessário suportar alfabetos além do latino (CJK, árabe etc.) com fontes de fallback adequadas (ex.: Noto, também OFL).\n')
        w(d / 'README.md', readme(k))
    print('assets ok')

def readme(k):
    return f"""# OrbiJob — proposta {screens.LABEL[k]}

> **PROPOSTA. Não aplicada ao aplicativo.** Escolha pendente do proprietário. Comparação lado a lado: [`../../comparison/index.html`](../../comparison/index.html).

## Logotipo e ícone (vetor)
| Arquivo | Uso |
|---|---|
| `logo-horizontal-{{light,dark}}.svg` | logotipo completo para fundo claro / escuro |
| `logo-horizontal-mono-{{black,white}}.svg` | monocromático (carimbo, impressão, 1 cor) |
| `icon-app.svg` | ícone de aplicativo (tile da marca) |
| `icon-{{light,dark}}.svg` | ícone em tile claro / escuro |
| `icon-mono-{{black,white}}.svg` | símbolo sem tile, 1 cor |
| `icon-app-small.svg`, `favicon.svg` | versão óptica simplificada para ≤ 32 px |
| `icon-app-maskable.svg` | área segura para ícone adaptativo Android |
| `favicon.ico` | 16, 32 e 48 px (cada imagem renderizada do vetor no próprio tamanho) |

## Prévias (PNG)
- `png/` — logotipos, ícones (256 px), favicons e ícones em 16/32/48/64/128/512 px **nativos**; `application-white.png` e `application-dark.png` (aplicação em fundo branco e escuro).
- `icon-sizes-light.png`, `icon-sizes-dark.png` — teste de legibilidade nos tamanhos reais.
- `screens/{{light,dark}}/` — splash, login, home, explorar, detalhes, favoritos, candidatura, perfil, 4 estados (carregando, vazio, erro, sem fonte), tablet e desktop.
- `sheet-mobile-{{light,dark}}.png` — as 8 telas lado a lado; `screens.html` — telas ao vivo (HTML).

## Design
`palette.md` (contrastes calculados) · `tokens.json` (cor, tipografia, espaçamento, forma, movimento, breakpoints) · `typography.md`.

Todo conteúdo de tela (vagas, empresas, notas, salários, compatibilidade) é **fictício** e rotulado como tal. Reprodução: `docs/design/identity/build/README.md`.
"""

# ───────────── 2. HTML pages ─────────────
def screens_html():
    for k in KEYS:
        bgs = {'light': brand.PALETTES[k]['light']['bg'], 'dark': brand.PALETTES[k]['dark']['bg']}
        body = ''
        for mode in ('light', 'dark'):
            body += f'<h2 class="g">{mode}</h2><div class="wrap">'
            body += ''.join(fn(k, mode) for _, fn in screens.MOBILE) + ''.join(screens.s_states(k, mode))
            body += '</div><div class="wrap">' + ''.join(fn(k, mode) for _, _, fn in screens.LARGE) + '</div>'
        doc = (f'<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OrbiJob — {screens.LABEL[k]} · telas (proposta)</title>'
               f'<style>{screens.css("../../fonts")}body{{margin:0;background:#d9dce3;font-family:Inter,sans-serif;padding:24px}}.g{{font:700 18px Inter;margin:20px 0 10px;text-transform:uppercase;letter-spacing:.08em;color:#333}}.wrap{{display:flex;flex-wrap:wrap;gap:24px;align-items:flex-start}}h1.t{{font:700 22px Inter}}p.n{{font:14px Inter;color:#444}}</style>'
               f'<h1 class="t">OrbiJob — {screens.LABEL[k]}</h1><p class="n">Telas de PROPOSTA com conteúdo fictício idêntico nas três identidades. Nada aqui foi aplicado ao aplicativo real.</p>{body}</html>')
        w(ROOT / k / 'screens.html', doc)
    print('screens html ok')

# ───────────── 3. rendering ─────────────
SCALE = 1.5
def render_all():
    jobs = []
    for k in KEYS:
        d = ROOT / k
        url = str(d / 'screens.html')
        for mode in ('light', 'dark'):
            for i, (sid, _) in enumerate(screens.MOBILE, 1):
                jobs.append(dict(type='element', url=url, selector=f'#{k}-{mode}-m-{sid}', out=str(d / 'screens' / mode / f'{i:02d}-{sid}.png'), scale=SCALE))
            for sid in ('loading', 'empty', 'error', 'nosource'):
                jobs.append(dict(type='element', url=url, selector=f'#{k}-{mode}-m-state-{sid}', out=str(d / 'screens' / mode / f'09-state-{sid}.png'), scale=SCALE))
            for layout, sid, _ in screens.LARGE:
                name = {'t': 'tablet', 'd': 'desktop'}[layout]
                jobs.append(dict(type='element', url=url, selector=f'#{k}-{mode}-{layout}-{sid}', out=str(d / 'screens' / mode / f'{name}-{sid}.png'), scale=1))
        for p in (d / 'screens' / 'light', d / 'screens' / 'dark'): p.mkdir(parents=True, exist_ok=True)
    render(jobs)
    print('screens rendered')

# ───────────── 4. logo / icon / favicon rasters ─────────────
SIZES = [16, 32, 48, 64, 128, 512]

def rasters():
    jobs = []
    for k in KEYS:
        d = ROOT / k; (d / 'png').mkdir(exist_ok=True)
        for v, bg in (('light', '#FFFFFF'), ('dark', brand.PALETTES[k]['dark']['bg']), ('mono-black', '#FFFFFF'), ('mono-white', '#111111')):
            f = d / f'logo-horizontal-{v}.svg'
            vb = [float(x) for x in f.read_text().split('viewBox="')[1].split('"')[0].split()]
            h = 160; wd = int(round(h * vb[2] / vb[3]))
            jobs.append(dict(type='svg', file=str(f), out=str(d / 'png' / f'logo-horizontal-{v}.png'), width=wd + 80, height=h + 80, svgWidth=wd, svgHeight=h, bg=bg))
        for kind, bg in (('app', '#E9EBF0'), ('light', '#FFFFFF'), ('dark', '#111111'), ('mono-black', '#FFFFFF'), ('mono-white', '#111111')):
            jobs.append(dict(type='svg', file=str(d / f'icon-{kind}.svg'), out=str(d / 'png' / f'icon-{kind}-256.png'), width=256, height=256, svgWidth=256, svgHeight=256, bg=bg if kind.startswith('mono') or kind == 'app' else None))
        # native-size rasters, each rendered straight from vector at its own size (optical variant <= 32 px)
        for s in SIZES:
            src = 'icon-app-small.svg' if s <= 32 else 'icon-app.svg'
            jobs.append(dict(type='svg', file=str(d / src), out=str(d / 'png' / f'icon-{s}.png'), width=s, height=s, svgWidth=s, svgHeight=s))
        for s in (16, 32, 48):
            src = 'favicon.svg' if s <= 32 else 'icon-app.svg'
            jobs.append(dict(type='svg', file=str(d / src), out=str(d / 'png' / f'favicon-{s}.png'), width=s, height=s, svgWidth=s, svgHeight=s))
        # application on white / on dark (logo + icon lockup, tagline)
        for mode, name in (('light', 'white'), ('dark', 'dark')):
            pal = brand.PALETTES[k][mode]
            html = (f'<!doctype html><meta charset=utf-8><style>{screens.css("../../../fonts")}body{{margin:0}}.app{{width:1200px;height:630px;background:{"#FFFFFF" if name == "white" else pal["bg"]};display:flex;flex-direction:column;align-items:center;justify-content:center;gap:34px;font-family:{screens.brand.TYPE[k]["text"]},sans-serif;color:{pal["ink"]}}}.app p{{margin:0;font-size:26px;color:{pal["muted"]}}}</style>'
                    f'<div class="app" id="app">{screens.svg_inline(brand.icon_svg(k, "app"), 168)}{screens.svg_inline(brand.logo_svg(k, mode), 96)}<p>Oportunidades em qualquer lugar do mundo</p></div>')
            w(d / '_application.html', html)
            jobs.append(dict(type='element', url=str(d / '_application.html'), selector='#app', out=str(d / 'png' / f'application-{name}.png'), scale=1))
            render([jobs.pop()]); (d / '_application.html').unlink()
    render(jobs)
    # favicon.ico: multi-image ICO built from the native 16/32/48 renders (no resampling)
    for k in KEYS:
        d = ROOT / k / 'png'
        imgs = [Image.open(d / f'favicon-{s}.png').convert('RGBA') for s in (16, 32, 48)]
        entries, blobs, off = b'', b'', 6 + 16 * len(imgs)
        for im in imgs:
            buf = io.BytesIO(); im.save(buf, 'PNG'); b = buf.getvalue()
            entries += struct.pack('<BBBBHHII', im.width % 256, im.height % 256, 0, 0, 1, 32, len(b), off + len(blobs)); blobs += b
        (ROOT / k / 'favicon.ico').write_bytes(struct.pack('<HHH', 0, 1, len(imgs)) + entries + blobs)
    # icon size sheet: every size placed at its REAL pixel size (no scaling), on light and dark strips
    for k in KEYS:
        d = ROOT / k
        for mode, bg in (('light', (255, 255, 255)), ('dark', (17, 17, 20))):
            ims = [Image.open(d / 'png' / f'icon-{s}.png').convert('RGBA') for s in SIZES]
            W = sum(i.width for i in ims) + 40 * (len(ims) + 1); H = 512 + 80
            sheet = Image.new('RGB', (W, H), bg); x = 40
            for i in ims:
                sheet.paste(i, (x, 40 + (512 - i.height) // 2), i); x += i.width + 40
            sheet.save(d / f'icon-sizes-{mode}.png')
    print('rasters ok')

def shrink():
    """Palette-quantise screen PNGs (flat UI colours; 256 colours + dithering off) to keep the repository small."""
    import os
    before = after = 0
    for k in KEYS:
        for f in list((ROOT / k / 'screens').rglob('*.png')) + list((ROOT / k).glob('sheet-mobile-*.png')):
            before += f.stat().st_size
            im = Image.open(f).convert('RGB').quantize(colors=256, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE)
            im.save(f, optimize=True); after += f.stat().st_size
    print(f'shrink: {before/1e6:.1f} MB -> {after/1e6:.1f} MB')

def contact_sheets():
    for k in KEYS:
        d = ROOT / k
        for mode in ('light', 'dark'):
            names = ['01-splash', '02-login', '03-home', '04-explore', '05-detail', '06-favorites', '07-application', '08-profile']
            ims = [Image.open(d / 'screens' / mode / f'{n}.png').convert('RGB') for n in names]
            ims = [i.resize((i.width * 2 // 3, i.height * 2 // 3), Image.LANCZOS) for i in ims]   # downscale only
            cw, ch = ims[0].size; S = Image.new('RGB', (4 * (cw + 12) + 12, 2 * (ch + 12) + 12), (125, 128, 138))
            for n, im in enumerate(ims): S.paste(im, (12 + (n % 4) * (cw + 12), 12 + (n // 4) * (ch + 12)))
            S.save(d / f'sheet-mobile-{mode}.png', optimize=True)
    print('sheets ok')

if __name__ == '__main__':
    step = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if step in ('assets', 'all'): assets()
    if step in ('screens', 'all'): screens_html()
    if step in ('render', 'all'): render_all()
    if step in ('rasters', 'all'): rasters()
    if step in ('sheets', 'all'): contact_sheets()
    if step in ('shrink', 'all'): shrink()
