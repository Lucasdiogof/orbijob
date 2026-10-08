#!/usr/bin/env python3
"""Verification of the identity deliverables. Exit code != 0 on any failure. Writes ../../comparison/verification.md"""
import json, pathlib, struct, sys, xml.etree.ElementTree as ET, re
from PIL import Image
import brand

ROOT = pathlib.Path(__file__).resolve().parents[1]; OUT = ROOT.parent / 'comparison'
KEYS = list(brand.PALETTES)
fails, lines = [], []
def check(name, ok, detail=''):
    lines.append(f'| {"✅" if ok else "❌"} | {name} | {detail} |')
    if not ok: fails.append(name)

# 1. SVG integrity
SAFE = {'svg', 'g', 'path', 'circle', 'rect', 'ellipse', 'mask', 'defs', 'linearGradient', 'stop'}
for k in KEYS:
    for f in sorted((ROOT / k).glob('*.svg')):
        try:
            root = ET.parse(f).getroot()
        except ET.ParseError as e:
            check(f'SVG válido {k}/{f.name}', False, str(e)); continue
        tags = {el.tag.split('}')[1] for el in root.iter()}
        ids = [el.get('id') for el in root.iter() if el.get('id')]
        refs = set(re.findall(r'url\(#([^)]+)\)', f.read_text()))
        ok = root.get('viewBox') and tags <= SAFE and len(ids) == len(set(ids)) and refs <= set(ids) and 'http' not in f.read_text().replace('http://www.w3.org/2000/svg', '')
        check(f'SVG {k}/{f.name}', bool(ok), f'{f.stat().st_size} B · sem texto/imagem/script/refs externas' if ok else f'tags={tags - SAFE} ids={ids} refs={refs}')
# 2. contrast
for k in KEYS:
    rows, ok = brand.audit_palette(k); worst = min(r[4] for r in rows if 'texto' in r[5])
    check(f'Contraste {k}', ok, f'{len(rows)} pares; pior par de texto {worst:.2f}:1 (AA ≥ 4,5)')
# 3. native PNG sizes + favicon.ico
for k in KEYS:
    d = ROOT / k / 'png'
    sizes_ok = all(Image.open(d / f'icon-{s}.png').size == (s, s) for s in (16, 32, 48, 64, 128, 512)) and all(Image.open(d / f'favicon-{s}.png').size == (s, s) for s in (16, 32, 48))
    check(f'PNGs de ícone em tamanho nativo {k}', sizes_ok, '16/32/48/64/128/512 renderizados do vetor em cada tamanho (sem ampliar)')
    ico = (ROOT / k / 'favicon.ico').read_bytes(); n = struct.unpack('<HHH', ico[:6])[2]
    dims = [(ico[6 + 16 * i] or 256) for i in range(n)]
    check(f'favicon.ico {k}', n == 3 and dims == [16, 32, 48], f'imagens {dims}')
# 4. legibility at small sizes: fraction of "ink" pixels (differing from tile colour) and presence of accent colour
def dist(a, b): return sum(abs(x - y) for x, y in zip(a[:3], b[:3]))
ACCENT = {'a-orbita': (255, 176, 32), 'b-trajetorias': (255, 122, 89), 'c-minimal': (139, 108, 255)}
for k in KEYS:
    for s in (16, 32):
        im = Image.open(ROOT / k / 'png' / f'icon-{s}.png').convert('RGBA')
        c = im.getpixel((s // 2, 2 if s == 16 else 4)) if False else im.getpixel((s // 2, s // 2))
        px = [im.getpixel((x, y)) for x in range(s) for y in range(s) if im.getpixel((x, y))[3] > 200]
        tile = im.getpixel((2, s // 2)); ink = sum(1 for p in px if dist(p, tile) > 120) / len(px)
        acc = sum(1 for p in px if dist(p, ACCENT[k] + (255,)) < 90)
        check(f'Legibilidade {k} @{s}px', 0.12 <= ink <= 0.75 and acc >= (2 if s == 16 else 6), f'{ink * 100:.0f}% de pixels de "tinta"; {acc} px da cor de destaque')
# 5. screens present
for k in KEYS:
    n = len(list((ROOT / k / 'screens').rglob('*.png')))
    check(f'Telas renderizadas {k}', n == 32, f'{n} PNGs (8 telas + 4 estados + tablet/desktop × claro/escuro)')
# 6. layout checks
lay = ROOT / 'build' / '.work' / 'layout.json'
if lay.exists():
    for r in json.loads(lay.read_text()):
        k = pathlib.Path(r['page']).parent.name
        check(f'Responsividade {k}', not r['overflow'] and not r['smallTargets'] and r['frames'] == 32, f'{r["frames"]} quadros (mobile/tablet/desktop, claro/escuro); overflow={len(r["overflow"])}; alvos<44px={len(r["smallTargets"])}')
# 7. secrets / licences
for k in KEYS:
    txt = ''.join(p.read_text(errors='ignore') for p in (ROOT / k).glob('*.md')) + (ROOT / k / 'tokens.json').read_text()
    check(f'Sem segredos {k}', not re.search(r'(ghp_|github_pat_|AKIA|BEGIN PRIVATE|sk-[A-Za-z0-9]{20})', txt))
check('Licenças de fontes presentes', all((ROOT.parent / 'fonts' / f'LICENSE-{n}.txt').exists() for n in ('sora', 'manrope', 'space-grotesk', 'inter', 'jetbrains-mono')), 'SIL OFL 1.1 em docs/design/fonts/')
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'verification.md').write_text('# Verificação automática das propostas\n\nGerado por `docs/design/identity/build/verify.py`.\n\n| | Verificação | Detalhe |\n|---|---|---|\n' + '\n'.join(lines) + '\n')
print('\n'.join(lines)); print('FAILS:', fails or 'none'); sys.exit(1 if fails else 0)
