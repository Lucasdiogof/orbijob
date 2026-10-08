#!/usr/bin/env python3
"""Generates the three OrbiJob identity proposals (SVG logos/icons, palettes, HTML mockups).
Wordmarks are converted to outlines with fontTools using fonts installed on the build machine
(Inter / DejaVu Sans Mono, both open licences), so the SVGs do not depend on installed fonts.
Usage: python3 generate.py   then   python3 render.py  (PNG previews via headless Chromium)
"""
import math, pathlib
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

HERE = pathlib.Path(__file__).parent

def text_path(font_path, text, size, tracking=0.0):
    f = TTFont(font_path); gs = f.getGlyphSet(); cmap = f.getBestCmap(); upm = f['head'].unitsPerEm
    s = size / upm; x = 0.0; pen = SVGPathPen(gs)
    for ch in text:
        g = cmap[ord(ch)]
        tp = TransformPen(pen, (s, 0, 0, -s, x, 0))
        gs[g].draw(tp)
        x += gs[g].width * s + tracking
    return pen.getCommands(), x

def lum(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c = [v / 12.92 if v <= .03928 else ((v + .055) / 1.055) ** 2.4 for v in c]
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]
def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la + .05) / (lb + .05)

INTER_XB = '/usr/share/fonts/opentype/inter/InterDisplay-ExtraBold.otf'
INTER_MD = '/usr/share/fonts/opentype/inter/Inter-Medium.otf'
MONO_B = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'

C = {
 'a-orbita': dict(name='A · Órbita', slug='orbita',
   light=dict(bg='#F6F8FC', surface='#FFFFFF', ink='#0B1F4B', muted='#4A5878', primary='#2456D6', onPrimary='#FFFFFF', accent='#F59E0B', line='#D9E0EE'),
   dark=dict(bg='#0A1226', surface='#121C36', ink='#EAF0FF', muted='#A9B6D6', primary='#7BA2FF', onPrimary='#0A1226', accent='#FBBF24', line='#24304F'),
   fonts='Sora (títulos/logotipo) + Inter (texto)', radius=20),
 'b-trajetorias': dict(name='B · Trajetórias', slug='trajetorias',
   light=dict(bg='#F3FAF8', surface='#FFFFFF', ink='#0F2A2E', muted='#44666A', primary='#0B7F72', onPrimary='#FFFFFF', accent='#E5502F', line='#CFE5E1'),
   dark=dict(bg='#0A1819', surface='#112628', ink='#E6F6F3', muted='#9CC2BE', primary='#3DD4BF', onPrimary='#062321', accent='#FF8266', line='#1E3A3C'),
   fonts='Manrope (títulos/logotipo) + Manrope (texto)', radius=14),
 'c-minimal': dict(name='C · Minimal Tech', slug='minimal',
   light=dict(bg='#FFFFFF', surface='#FFFFFF', ink='#111113', muted='#585865', primary='#5B3DF5', onPrimary='#FFFFFF', accent='#111113', line='#E2E2E8'),
   dark=dict(bg='#0C0C0E', surface='#131316', ink='#F4F4F6', muted='#A4A4B2', primary='#A593FF', onPrimary='#0C0C0E', accent='#F4F4F6', line='#2A2A31'),
   fonts='Space Grotesk (títulos) + JetBrains Mono (rótulos/dados) + Inter (texto)', radius=6),
}

# ---------- icon glyphs (viewBox 0 0 100 100, drawn with given colors) ----------
def glyph_a(p, a):  # globe + tilted orbit + satellite dot
    return f'''<circle cx="50" cy="50" r="22" fill="{p}"/>
<path d="M30 44c10 4 30 4 40 0M29 56c10 4 32 4 42 0" stroke="{a if False else '#fff'}" stroke-opacity=".35" stroke-width="2.2" fill="none"/>
<ellipse cx="50" cy="50" rx="40" ry="15" transform="rotate(-24 50 50)" fill="none" stroke="{p}" stroke-width="4.5"/>
<circle cx="79" cy="33" r="7.5" fill="{a}"/>'''
def glyph_b(p, a):  # ring of nodes joined by trajectories, one highlighted
    pts = [(50 + 34 * math.cos(math.radians(t)), 50 + 34 * math.sin(math.radians(t))) for t in (-90, -30, 30, 90, 150, 210)]
    lines = ''.join(f'<path d="M{pts[i][0]:.1f} {pts[i][1]:.1f}Q50 50 {pts[(i+2)%6][0]:.1f} {pts[(i+2)%6][1]:.1f}" stroke="{p}" stroke-opacity=".45" stroke-width="2.4" fill="none"/>' for i in range(6))
    ring = ''.join(f'<path d="M{pts[i][0]:.1f} {pts[i][1]:.1f}L{pts[(i+1)%6][0]:.1f} {pts[(i+1)%6][1]:.1f}" stroke="{p}" stroke-width="4" stroke-linecap="round"/>' for i in range(6))
    dots = ''.join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{9 if i==1 else 6}" fill="{a if i==1 else p}"/>' for i, (x, y) in enumerate(pts))
    return lines + ring + dots
def glyph_c(p, a):  # geometric O with J-hook cut and pixel
    return f'''<path d="M50 14a36 36 0 1 0 36 36" fill="none" stroke="{p}" stroke-width="13" stroke-linecap="butt"/>
<rect x="73" y="14" width="13" height="13" fill="{a}"/>
<rect x="43.5" y="40" width="13" height="26" fill="{p}"/>'''
GLY = {'a-orbita': glyph_a, 'b-trajetorias': glyph_b, 'c-minimal': glyph_c}

def icon_svg(key, mode):
    c = C[key][mode]; acc = c['accent'] if key != 'c-minimal' else C[key]['light']['primary'] if mode == 'light' else C[key]['dark']['primary']
    if key == 'c-minimal': acc = c['primary']; prim = c['ink']
    else: prim = c['primary']
    bg = c['bg']; r = {'a-orbita': 22, 'b-trajetorias': 30, 'c-minimal': 14}[key]
    body = GLY[key](prim, acc if key != 'a-orbita' else c['accent'])
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="OrbiJob"><rect width="100" height="100" rx="{r}" fill="{bg}"/><g transform="translate(10 10) scale(.8)">{body}</g></svg>\n'

def glyph_only(key, mode):
    c = C[key][mode]
    if key == 'c-minimal': prim, acc = c['ink'], c['primary']
    else: prim, acc = c['primary'], c['accent']
    return GLY[key](prim, acc)

def logo_h(key, mode):
    c = C[key][mode]
    if key == 'a-orbita': d, w = text_path(INTER_XB, 'OrbiJob', 44, -0.8); fill = c['ink']; word = f'<path d="{d}" fill="{fill}"/>'
    elif key == 'b-trajetorias':
        d, w = text_path(INTER_MD, 'orbijob', 46, 0.6); word = f'<path d="{d}" fill="{c["ink"]}"/>'
    else:
        d, w = text_path(MONO_B, 'orbijob', 40, 1.5); word = f'<path d="{d}" fill="{c["ink"]}"/>'
    W = 100 + 14 + w + 8
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} 100" role="img" aria-label="OrbiJob">'
            f'<g transform="translate(0 0)">{glyph_only(key, mode)}</g><g transform="translate(114 66)">{word}</g></svg>\n'), W

def hero(key, c):
    p, a, l = c['primary'], c['accent'], c['line']
    if key == 'a-orbita':
        return f'<svg viewBox="0 0 300 130" width="100%"><circle cx="150" cy="120" r="100" fill="{p}" opacity=".12"/><circle cx="150" cy="120" r="70" fill="none" stroke="{p}" stroke-width="2" opacity=".5"/><ellipse cx="150" cy="95" rx="125" ry="38" transform="rotate(-8 150 95)" fill="none" stroke="{p}" stroke-width="3"/><circle cx="250" cy="70" r="9" fill="{a}"/><circle cx="60" cy="108" r="5" fill="{p}"/></svg>'
    if key == 'b-trajetorias':
        return f'<svg viewBox="0 0 300 130" width="100%"><path d="M20 105C70 105 80 40 130 45S200 100 240 35" stroke="{p}" stroke-width="3" fill="none"/><path d="M20 105C90 70 140 120 190 80S250 60 282 85" stroke="{p}" stroke-opacity=".4" stroke-width="2" fill="none"/>' + ''.join(f'<circle cx="{x}" cy="{y}" r="6" fill="{p}"/>' for x, y in ((20,105),(130,45),(190,80))) + f'<circle cx="240" cy="35" r="10" fill="{a}"/></svg>'
    return f'<svg viewBox="0 0 300 130" width="100%"><g stroke="{l}" stroke-width="1">' + ''.join(f'<path d="M{x} 0V130"/>' for x in range(0,301,30)) + ''.join(f'<path d="M0 {y}H300"/>' for y in range(0,131,26)) + f'</g><rect x="120" y="39" width="60" height="52" fill="none" stroke="{c["ink"]}" stroke-width="3"/><rect x="170" y="39" width="10" height="10" fill="{p}"/></svg>'

def phone(key, mode, screen, logo_svg):
    c = C[key][mode]; r = C[key]['radius']
    mono = key == 'c-minimal'
    css = f'--bg:{c["bg"]};--sf:{c["surface"]};--ink:{c["ink"]};--mu:{c["muted"]};--pr:{c["primary"]};--on:{c["onPrimary"]};--ac:{c["accent"]};--ln:{c["line"]};--r:{r}px;'
    lab = 'font-family:"DejaVu Sans Mono",monospace;font-size:10px;letter-spacing:.04em;text-transform:uppercase;' if mono else 'font-size:11px;'
    ex = '<div class="ex">EXEMPLO ILUSTRATIVO · NÃO É VAGA REAL</div>'
    if screen == 'login':
        body = f'''<div class="logo">{logo_svg}</div><div style="margin:14px 0 18px">{hero(key,c)}</div>
<h2>Encontre trabalho em qualquer lugar do mundo</h2><p class="mu">Qualquer profissão. Fontes autorizadas e transparentes.</p>
<div class="field">E-mail</div><div class="field">Senha</div><div class="btn">Entrar</div><div class="btn ghost">Criar conta</div>'''
    elif screen == 'home':
        body = f'''<div class="top"><div class="logo sm">{logo_svg}</div><div class="av">L</div></div>
<div class="search">Qualquer profissão, em qualquer país</div>
<div class="chips"><span>Presencial</span><span>Remoto</span><span class="on">Brasil</span><span>Salário</span></div>
<div class="card"><div style="{lab}" class="mu">Para você</div><b>Compatibilidade 0–100</b><p class="mu">Aparecerá aqui quando houver fontes conectadas e perfil preenchido.</p><div class="bar"><i style="width:68%"></i></div></div>
<div class="card"><b>Candidaturas</b><p class="mu">Acompanhe etapas, entrevistas e propostas.</p></div>
<div class="nav"><span class="on">Início</span><span>Explorar</span><span>Favoritos</span><span>Candidaturas</span></div>'''
    else:
        body = f'''<div class="top"><b>Detalhe da vaga</b><div class="av">♡</div></div>
<div class="card big"><div style="{lab}" class="mu">Empresa Exemplo · Cidade Exemplo</div><h3>Título da vaga (exemplo)</h3>
<div class="chips"><span>Remoto</span><span>Tempo integral</span><span>Salário informado</span></div>
<div class="score"><div class="ring"><b>82</b></div><div><b>Compatibilidade</b><br><span class="mu">Confiança da análise: média</span></div></div>
<ul class="mu"><li>Competências: 4 de 5 atendidas</li><li>Idioma: atende</li><li>Licença exigida: pendente (não declarada)</li></ul>
<div class="btn">Abrir candidatura oficial</div><p class="mu" style="font-size:10px">Fonte: exemplo · atribuição obrigatória da fonte aparece aqui</p></div>'''
    return f'<div class="phone" style="{css}"><div class="scr">{ex}{body}</div></div>'

CSS = '''
*{box-sizing:border-box}body{margin:0;background:#e9ebf0;font-family:Inter,sans-serif;color:#111}
.h{padding:18px 24px 0;font:600 18px Inter}.sub{padding:0 24px;color:#555;font-size:13px}
.row{display:flex;gap:18px;padding:18px 24px;flex-wrap:wrap}
.phone{width:300px;height:620px;border-radius:30px;background:var(--bg);color:var(--ink);border:8px solid #1b1b1f;overflow:hidden;position:relative}
.scr{padding:14px 16px;height:100%;display:flex;flex-direction:column;gap:8px;font-size:12px}
.ex{background:var(--ac);color:var(--bg);font:700 9px Inter;padding:3px 6px;border-radius:4px;align-self:flex-start}
.logo svg{height:30px;width:auto;display:block}.logo.sm svg{height:24px}
h2{font-size:19px;line-height:1.2;margin:0}h3{margin:4px 0;font-size:16px}p{margin:0}.mu{color:var(--mu)}
.field{border:1px solid var(--ln);background:var(--sf);border-radius:var(--r);padding:11px 12px;color:var(--mu)}
.btn{background:var(--pr);color:var(--on);text-align:center;padding:11px;border-radius:var(--r);font-weight:700}
.btn.ghost{background:transparent;color:var(--pr);border:1px solid var(--pr)}
.top{display:flex;justify-content:space-between;align-items:center}.av{width:28px;height:28px;border-radius:50%;background:var(--pr);color:var(--on);display:grid;place-items:center;font-weight:700}
.search{border:1px solid var(--ln);background:var(--sf);border-radius:var(--r);padding:10px 12px;color:var(--mu)}
.chips{display:flex;gap:6px;flex-wrap:wrap}.chips span{border:1px solid var(--ln);border-radius:calc(var(--r) * 2);padding:3px 9px;font-size:11px}
.chips span.on{background:var(--pr);color:var(--on);border-color:var(--pr)}
.card{background:var(--sf);border:1px solid var(--ln);border-radius:var(--r);padding:12px;display:flex;flex-direction:column;gap:6px}
.bar{height:6px;background:var(--ln);border-radius:9px}.bar i{display:block;height:100%;background:var(--pr);border-radius:9px}
.nav{margin-top:auto;display:flex;justify-content:space-around;border-top:1px solid var(--ln);padding-top:8px;color:var(--mu);font-size:11px}.nav .on{color:var(--pr);font-weight:700}
.score{display:flex;gap:10px;align-items:center}.ring{width:52px;height:52px;border-radius:50%;border:5px solid var(--pr);display:grid;place-items:center;font-size:17px}
ul{margin:0;padding-left:16px;display:grid;gap:3px}
'''

def build():
    index = []
    for key, meta in C.items():
        d = HERE / key; d.mkdir(exist_ok=True)
        logos = {}
        for mode in ('light', 'dark'):
            svg, W = logo_h(key, mode); (d / f'logo-horizontal-{mode}.svg').write_text(svg); logos[mode] = svg
            (d / f'icon-{mode}.svg').write_text(icon_svg(key, mode))
        # palette + contrast evidence
        rows = []
        for mode in ('light', 'dark'):
            c = meta[mode]
            pairs = [('ink/bg', c['ink'], c['bg']), ('muted/bg', c['muted'], c['bg']), ('onPrimary/primary', c['onPrimary'], c['primary']), ('primary/bg', c['primary'], c['bg'])]
            for n, a, b in pairs:
                r = contrast(a, b); rows.append(f'| {mode} | {n} | {a} on {b} | {r:.2f} | {"AA" if r >= 4.5 else ("AA large/UI only" if r >= 3 else "FAIL")} |')
        pal = f'# {meta["name"]} — paleta\n\n' + '\n'.join(f'- **{m}**: ' + ', '.join(f'`{k}` {v}' for k, v in meta[m].items()) for m in ('light', 'dark')) + f'\n\nTipografia sugerida: {meta["fonts"]}\n\n## Contraste calculado (WCAG)\n\n| Tema | Par | Cores | Razão | Resultado |\n|---|---|---|---|---|\n' + '\n'.join(rows) + '\n'
        (d / 'palette.md').write_text(pal)
        html = f'<!doctype html><meta charset=utf-8><title>OrbiJob {meta["name"]}</title><style>{CSS}</style><div class=h>OrbiJob — Proposta {meta["name"]}</div><div class=sub>Prévia de proposta. Nenhuma identidade foi aplicada ao app. Dados de tela são exemplos ilustrativos.</div>'
        for mode in ('light', 'dark'):
            html += '<div class=row>' + ''.join(phone(key, mode, s, logos[mode]) for s in ('login', 'home', 'jobcard')) + '</div>'
        (d / 'preview.html').write_text(html)
        index.append(key)
    print('ok', index)

build()
