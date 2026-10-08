"""OrbiJob identity proposals: marks, wordmarks, palettes, tokens. Pure functions, no I/O except reading fonts.
All geometry is hand-built (no raster, no upscaling). Text is converted to outlines from OFL fonts in ../../fonts.
"""
import math, pathlib
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

FONTS = pathlib.Path(__file__).resolve().parents[2] / 'fonts'

# ───────────────────────── contrast helpers ─────────────────────────
def _lum(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [v / 12.92 if v <= .03928 else ((v + .055) / 1.055) ** 2.4 for v in c]
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]
def contrast(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True); return (la + .05) / (lb + .05)

# ───────────────────────── palettes (M3-style roles) ─────────────────────────
PALETTES = {
 'a-orbita': {
  'light': dict(bg='#F5F8FF', surface='#FFFFFF', container='#E8EFFE', ink='#0A1B44', muted='#43517A', line='#DCE4F5', outline='#6B7AA3',
                primary='#1F5FE0', onPrimary='#FFFFFF', primaryContainer='#DCE7FF', onPrimaryContainer='#0A2A6B',
                accent='#F5A524', onAccent='#2B1A00', accentText='#8A5200', success='#0E7A4B', danger='#B3261E'),
  'dark':  dict(bg='#081330', surface='#0F1D42', container='#172A5A', ink='#EEF3FF', muted='#A9B8E0', line='#223463', outline='#7C8DBB',
                primary='#8DB6FF', onPrimary='#06163F', primaryContainer='#1B3A85', onPrimaryContainer='#DCE7FF',
                accent='#FFC247', onAccent='#2B1A00', accentText='#FFC247', success='#5BD69A', danger='#FFB4AB')},
 'b-trajetorias': {
  'light': dict(bg='#F4FAF8', surface='#FFFFFF', container='#E0F1ED', ink='#0E2A2D', muted='#3F6165', line='#D3E7E3', outline='#678C90',
                primary='#0B7F72', onPrimary='#FFFFFF', primaryContainer='#CDEFE9', onPrimaryContainer='#04332E',
                accent='#CC3D1A', onAccent='#FFFFFF', accentText='#B03416', success='#2E7D32', danger='#B3261E'),
  'dark':  dict(bg='#09181A', surface='#102527', container='#17383B', ink='#E6F6F3', muted='#9FC4C0', line='#1F3F42', outline='#6F9A96',
                primary='#3DD4BF', onPrimary='#04332E', primaryContainer='#0F5A52', onPrimaryContainer='#CDEFE9',
                accent='#FF8A6B', onAccent='#3A0D00', accentText='#FF8A6B', success='#7FD98A', danger='#FFB4AB')},
 'c-minimal': {
  'light': dict(bg='#FFFFFF', surface='#FFFFFF', container='#F4F4F7', ink='#111113', muted='#55555F', line='#E4E4EA', outline='#8A8A96',
                primary='#5B3DF5', onPrimary='#FFFFFF', primaryContainer='#ECE8FF', onPrimaryContainer='#2A1A8A',
                accent='#111113', onAccent='#FFFFFF', accentText='#111113', success='#1B7A43', danger='#B3261E'),
  'dark':  dict(bg='#0C0C0E', surface='#131316', container='#1C1C21', ink='#F4F4F6', muted='#A6A6B3', line='#2A2A31', outline='#7A7A88',
                primary='#A593FF', onPrimary='#1A0F57', primaryContainer='#3A2C99', onPrimaryContainer='#E6E0FF',
                accent='#F4F4F6', onAccent='#111113', accentText='#F4F4F6', success='#6BD79B', danger='#FFB4AB')},
}

# Final design-system tokens of identity C = base roles above + these. Opacity tokens are state layers over `primary`.
C_EXTENDED = {
 'light': dict(containerHigh='#EAEAF0', secondary='#111113', onSecondary='#FFFFFF', secondaryContainer='#E9E9EE', onSecondaryContainer='#111113',
               error='#B3261E', onError='#FFFFFF', errorContainer='#FDECEA', onErrorContainer='#5F1410',
               onSuccess='#FFFFFF', successContainer='#E3F4EA', onSuccessContainer='#0B3D20',
               warning='#8A5A00', onWarning='#FFFFFF', warningContainer='#FFF1D6', onWarningContainer='#4A2F00',
               disabledFg='#8A8A96', disabledBg='#EDEDF1', focus='#5B3DF5', divider='#E4E4EA',
               skeletonBase='#F4F4F7', skeletonHighlight='#EAEAF0'),
 'dark':  dict(containerHigh='#26262C', secondary='#F4F4F6', onSecondary='#111113', secondaryContainer='#26262C', onSecondaryContainer='#F4F4F6',
               error='#FFB4AB', onError='#690005', errorContainer='#93000A', onErrorContainer='#FFDAD6',
               onSuccess='#00391C', successContainer='#12432A', onSuccessContainer='#C6F0D6',
               warning='#FFC857', onWarning='#2B1A00', warningContainer='#4A3300', onWarningContainer='#FFE2A8',
               disabledFg='#6E6E7A', disabledBg='#1E1E23', focus='#A593FF', divider='#2A2A31',
               skeletonBase='#1C1C21', skeletonHighlight='#26262C'),
}
C_STATE_OPACITY = dict(hover=0.08, focus=0.12, pressed=0.12, selected=0.12)
for _m in ('light', 'dark'):
    PALETTES['c-minimal'][_m].update(C_EXTENDED[_m])

# text pairs that must reach WCAG AA (4.5) and UI-component pairs that must reach 3.0
C_TEXT_PAIRS = [('onSecondary', 'secondary'), ('onSecondaryContainer', 'secondaryContainer'), ('onError', 'error'), ('onErrorContainer', 'errorContainer'),
                ('onSuccess', 'success'), ('onSuccessContainer', 'successContainer'), ('onWarning', 'warning'), ('onWarningContainer', 'warningContainer'),
                ('error', 'surface'), ('error', 'bg'), ('success', 'bg'), ('warning', 'surface'), ('warning', 'bg'), ('ink', 'containerHigh'), ('muted', 'containerHigh')]
C_UI_PAIRS = [('focus', 'bg'), ('focus', 'surface'), ('primary', 'surface'), ('outline', 'container')]
TEXT_PAIRS = [('ink', 'bg'), ('ink', 'surface'), ('ink', 'container'), ('muted', 'bg'), ('muted', 'surface'), ('muted', 'container'),
              ('onPrimary', 'primary'), ('primary', 'bg'), ('primary', 'surface'), ('onPrimaryContainer', 'primaryContainer'),
              ('onAccent', 'accent'), ('accentText', 'surface'), ('success', 'surface'), ('danger', 'surface')]
UI_PAIRS = [('outline', 'bg'), ('outline', 'surface'), ('primary', 'bg')]

def audit_palette(key):
    rows, ok = [], True
    tp = TEXT_PAIRS + (C_TEXT_PAIRS if key == 'c-minimal' else []); up = UI_PAIRS + (C_UI_PAIRS if key == 'c-minimal' else [])
    for mode, c in PALETTES[key].items():
        for a, b in tp:
            r = contrast(c[a], c[b]); p = r >= 4.5; ok &= p
            rows.append((mode, f'{a} / {b}', c[a], c[b], r, 'texto AA ≥ 4,5', p))
        for a, b in up:
            r = contrast(c[a], c[b]); p = r >= 3.0; ok &= p
            rows.append((mode, f'{a} / {b}', c[a], c[b], r, 'componente ≥ 3,0', p))
    return rows, ok

# ───────────────────────── type ─────────────────────────
FONT_FILES = {
 'sora700': 'sora-latin-700-normal.woff2', 'manrope800': 'manrope-latin-800-normal.woff2',
 'spacegrotesk600': 'space-grotesk-latin-600-normal.woff2',
}
_cache = {}
def _font(name):
    if name not in _cache:
        f = TTFont(FONTS / FONT_FILES[name]); _cache[name] = (f, f.getGlyphSet(), f.getBestCmap(), f['head'].unitsPerEm, f['OS/2'])
    return _cache[name]

def glyph_runs(name, text, size, tracking=0.0):
    """Returns list of dict(ch, contours=[(d, bbox)], x). Coordinates are y-down, baseline y=0."""
    f, gs, cmap, upm, os2 = _font(name); s = size / upm; x = 0.0; out = []
    for ch in text:
        g = gs[cmap[ord(ch)]]; rec = DecomposingRecordingPen(gs); g.draw(rec)
        contours, cur = [], []
        for op, args in rec.value:
            cur.append((op, args))
            if op in ('closePath', 'endPath'): contours.append(cur); cur = []
        cs = []
        for c in contours:
            p = SVGPathPen(None); tp = TransformPen(p, (s, 0, 0, -s, x, 0)); b = BoundsPen(gs); tb = TransformPen(b, (s, 0, 0, -s, x, 0))
            for pen in (tp, tb):
                for op, args in c: getattr(pen, op)(*args)
            cs.append((p.getCommands(), b.bounds))
        out.append(dict(ch=ch, contours=cs, x=x)); x += g.width * s + tracking
    return out, x - tracking

def metrics(name, size):
    f, gs, cmap, upm, os2 = _font(name); return os2.sxHeight * size / upm, os2.sCapHeight * size / upm

# ───────────────────────── glyphs (viewBox 0 0 100 100) ─────────────────────────
_uid = [0]
def _id(p):
    _uid[0] += 1; return f'{p}{_uid[0]}'

def _ell_pt(cx, cy, rx, ry, rot, t):
    t = math.radians(t); x, y = rx * math.cos(t), ry * math.sin(t); r = math.radians(rot)
    return cx + x * math.cos(r) - y * math.sin(r), cy + x * math.sin(r) + y * math.cos(r)

def glyph_a(c, small=False, clean=False):
    """Globe + elegant tilted orbit + amber opportunity dot. Orbit passes behind the globe and in front, with a cut-out where it crosses."""
    cx = cy = 50; R = 25 if not (small or clean) else 27; rx, ry, rot = 45, 16.5, -28
    sw = 5.2 if not (small or clean) else (7.4 if small else 6.2); dot_r = 7.6 if not (small or clean) else (9.4 if small else 8.6)
    m = _id('ma')
    back = f'M{-rx} 0A{rx} {ry} 0 0 1 {rx} 0'; front = f'M{-rx} 0A{rx} {ry} 0 0 0 {rx} 0'
    tf = f'translate({cx} {cy}) rotate({rot})'
    dx, dy = _ell_pt(cx, cy, rx, ry, rot, -38)
    one = f'<path d="M50 {cy-R}C{cx-15} {cy-14} {cx-15} {cy+14} 50 {cy+R}" stroke="#000" stroke-width="2.8" fill="none" stroke-linecap="round"/>'
    two = f'<path d="M{cx-R} {cy+1}C{cx-9} {cy+8} {cx+9} {cy+8} {cx+R} {cy+1}" stroke="#000" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
    merid = '' if small else (one if clean else one + two)   # clean icons keep ONE meridian so the sphere still reads as a globe
    return (f'<mask id="{m}" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100"><rect width="100" height="100" fill="#fff"/>'
            f'<g transform="{tf}"><path d="{front}" stroke="#000" stroke-width="{sw+3.4}" fill="none"/></g>{merid}</mask>'
            f'<g transform="{tf}"><path d="{back}" stroke="{c["orbit"]}" stroke-width="{sw}" fill="none" stroke-linecap="round"/></g>'
            f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="{c["globe"]}" mask="url(#{m})"/>'
            f'<g transform="{tf}"><path d="{front}" stroke="{c["orbit"]}" stroke-width="{sw}" fill="none" stroke-linecap="round"/></g>'
            f'<circle cx="{dx:.2f}" cy="{dy:.2f}" r="{dot_r}" fill="{c["dot"]}"/>')

def glyph_b(c, small=False, clean=False):
    """Four nodes joined by route arcs form an open O (people and places connected); one coral node is the opportunity."""
    cx = cy = 50; r = 32; sw = 7.5 if not small else 10; nodes = [-45, 45, 135, 225]
    nr = 9.5 if not small else 11.5; cr = 13 if not small else 14.5
    pt = lambda a, rr=r: (cx + rr * math.cos(math.radians(a)), cy + rr * math.sin(math.radians(a)))
    arcs = ''
    for i, a in enumerate(nodes):
        b = nodes[(i + 1) % 4] + (360 if i == 3 else 0)
        pa, pb = pt(a), pt(b)
        arcs += f'<path d="M{pa[0]:.2f} {pa[1]:.2f}A{r} {r} 0 0 1 {pb[0]:.2f} {pb[1]:.2f}" stroke="{c["ring"]}" stroke-width="{sw}" fill="none"/>'
    dots = ''.join(f'<circle cx="{pt(a)[0]:.2f}" cy="{pt(a)[1]:.2f}" r="{nr}" fill="{c["ring"]}"/>' for a in nodes[1:])
    ping = '' if (small or clean) else f'<circle cx="{pt(-45)[0]:.2f}" cy="{pt(-45)[1]:.2f}" r="19" fill="none" stroke="{c["dot"]}" stroke-width="2.6" opacity=".55"/>'
    return arcs + dots + ping + f'<circle cx="{pt(-45)[0]:.2f}" cy="{pt(-45)[1]:.2f}" r="{cr}" fill="{c["dot"]}"/>'

def glyph_c(c, small=False, clean=False):
    """Geometric O built from two opposite arcs; the diagonal gaps are the negative space; violet precision point at the centre."""
    cx = cy = 50; r = 31; sw = 13 if not small else 16; g = 9
    def arc(a, b):
        pa = (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
        pb = (cx + r * math.cos(math.radians(b)), cy + r * math.sin(math.radians(b)))
        return f'M{pa[0]:.2f} {pa[1]:.2f}A{r} {r} 0 0 1 {pb[0]:.2f} {pb[1]:.2f}'
    return (f'<path d="{arc(-45+g, 135-g)}" stroke="{c["arc"]}" stroke-width="{sw}" fill="none"/>'
            f'<path d="{arc(135+g, 315-g)}" stroke="{c["arc"]}" stroke-width="{sw}" fill="none"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{9 if not small else 11}" fill="{c["dot"]}"/>')

GLYPH = {'a-orbita': glyph_a, 'b-trajetorias': glyph_b, 'c-minimal': glyph_c}

def glyph_colors(key, variant):
    P = PALETTES[key]
    if key == 'a-orbita':
        t = {'light': dict(globe='#0A2A6B', orbit='#4C8DFF', dot='#F5A524'), 'dark': dict(globe='#8DB6FF', orbit='#D6E4FF', dot='#FFC247'),
             'app': dict(globe='#EAF1FF', orbit='#7FB0FF', dot='#FFB020')}
    elif key == 'b-trajetorias':
        t = {'light': dict(ring='#0B7F72', path='#0B7F72', dot='#E5502F'), 'dark': dict(ring='#3DD4BF', path='#3DD4BF', dot='#FF8A6B'),
             'app': dict(ring='#F2FFFC', path='#F2FFFC', dot='#FF7A59')}
    else:
        t = {'light': dict(arc='#111113', dot='#5B3DF5'), 'dark': dict(arc='#F4F4F6', dot='#A593FF'), 'app': dict(arc='#FFFFFF', dot='#8B6CFF')}
    if variant in ('mono-black', 'mono-white'):
        col = '#000000' if variant == 'mono-black' else '#FFFFFF'
        return {k: col for k in t['light']}
    return t[variant]

TILES = {  # app tile backgrounds
 'a-orbita': dict(app=('#12408F', '#081B4A'), light='#EEF3FF', dark='#081B4A', radius=22.5),
 'b-trajetorias': dict(app=('#0B7A6E', '#064740'), light='#E6F5F2', dark='#06302D', radius=22.5),
 'c-minimal': dict(app=('#17171B', '#0C0C0E'), light='#F3F1FF', dark='#0C0C0E', radius=22.5),
}

def glyph_svg(key, variant, small=False, clean=False):
    return GLYPH[key](glyph_colors(key, variant), small, clean)

def icon_svg(key, kind, small=False, maskable=False):
    """kind: app | light | dark | mono-black | mono-white (mono = transparent, glyph only)"""
    if kind in ('mono-black', 'mono-white'):
        body = glyph_svg(key, kind, small, clean=True); bg = ''
        return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="OrbiJob">{bg}{body}</svg>\n'
    t = TILES[key]; gv = {'app': 'app', 'light': 'light', 'dark': 'dark'}[kind]
    scale = .56 if maskable else .74; off = (100 - 100 * scale) / 2
    rx = 0 if maskable else t['radius']; gid = _id('g')
    if kind == 'app':
        defs = f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{t["app"][0]}"/><stop offset="1" stop-color="{t["app"][1]}"/></linearGradient></defs>'
        fill = f'url(#{gid})'
    else:
        defs = ''; fill = t[kind]
    stroke = (f' stroke="{PALETTES[key]["light"]["line"]}" stroke-width="1"' if kind == 'light' else ' stroke="#FFFFFF" stroke-opacity=".14" stroke-width="1"') if not maskable else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="OrbiJob">{defs}'
            f'<rect x=".5" y=".5" width="99" height="99" rx="{rx}" fill="{fill}"{stroke}/>'
            f'<g transform="translate({off:.2f} {off:.2f}) scale({scale})">{glyph_svg(key, gv, small, clean=True)}</g></svg>\n')

# ───────────────────────── wordmarks ─────────────────────────
def _wordmark(key, variant):
    """returns (svg_fragment (positioned, baseline absolute), width). Contours of one glyph share a single path so counters stay open."""
    P = PALETTES[key]['dark' if variant in ('dark', 'mono-white') else 'light']
    mono = variant.startswith('mono'); mcol = '#000000' if variant == 'mono-black' else '#FFFFFF'
    def glyph_path(r, fill, base, only=None):
        d = ''.join(dd for i, (dd, _) in enumerate(r['contours']) if only is None or i in only)
        return f'<path d="{d}" fill="{fill}" transform="translate(0 {base:.2f})"/>' if d else ''
    if key == 'a-orbita':
        size = 62; runs, w = glyph_runs('sora700', 'OrbiJob', size, -1.2); x_h, cap = metrics('sora700', size)
        base = 50 + cap / 2
        cols = ['#0A1B44' if variant == 'light' else '#EEF3FF'] * 4 + [('#1F5FE0' if variant == 'light' else '#8DB6FF')] * 3
        if mono: cols = [mcol] * 7
        return ''.join(glyph_path(r, cols[i], base) for i, r in enumerate(runs)), w
    if key == 'b-trajetorias':
        size = 74; runs, w = glyph_runs('manrope800', 'orbijob', size, 0.2); x_h, cap = metrics('manrope800', size)
        base = 50 + x_h / 2; ink = mcol if mono else P['ink']; coral = mcol if mono else ('#E5502F' if variant == 'light' else '#FF8A6B')
        frag = ''
        for r in runs:
            if r['ch'] == 'j' and len(r['contours']) == 2:
                dot = min(range(2), key=lambda i: r['contours'][i][1][1]); stem = 1 - dot   # top-most contour (smallest ymin) is the dot
                frag += glyph_path(r, ink, base, {stem}) + glyph_path(r, coral, base, {dot})
            else:
                frag += glyph_path(r, ink, base)
        return frag, w
    size = 50; runs, w = glyph_runs('spacegrotesk600', 'ORBIJOB', size, 5.5); x_h, cap = metrics('spacegrotesk600', size)
    base = 50 + cap / 2; ink = mcol if mono else P['ink']
    return ''.join(glyph_path(r, ink, base) for r in runs), w

def logo_svg(key, variant, bg=None):
    """Horizontal logo: glyph (no tile) + wordmark. variant: light | dark | mono-black | mono-white."""
    gap = {'a-orbita': 16, 'b-trajetorias': 16, 'c-minimal': 20}[key]
    gv = variant
    frag, w = _wordmark(key, variant)
    W = 100 + gap + w + 6
    back = f'<rect width="{W:.1f}" height="100" fill="{bg}"/>' if bg else ''
    # glyph colours: light/dark → palette variants, mono → single colour
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.1f} 100" role="img" aria-label="OrbiJob">{back}'
            f'{glyph_svg(key, gv)}<g transform="translate({100+gap} 0)">{frag}</g></svg>\n')

# ───────────────────────── design tokens ─────────────────────────
TYPE = {
 'a-orbita': dict(display='Sora', text='Inter', mono='JetBrains Mono', note='Sora 600/700 para títulos e logotipo; Inter para texto e dados.'),
 'b-trajetorias': dict(display='Manrope', text='Manrope', mono='JetBrains Mono', note='Manrope 600/800 para títulos e logotipo; Manrope 400/500 para texto.'),
 'c-minimal': dict(display='Space Grotesk', text='Inter', mono='JetBrains Mono', note='Space Grotesk 500/600 para títulos; Inter para texto; JetBrains Mono para rótulos e dados.'),
}
SHAPE = {
 'a-orbita': dict(radius=dict(xs=8, sm=12, md=20, lg=28, pill=999), density='confortável', elevation='sombra suave azulada (blur 24, 8% opacidade)'),
 'b-trajetorias': dict(radius=dict(xs=6, sm=10, md=14, lg=22, pill=999), density='confortável', elevation='sombra curta + trilha tracejada (rota)'),
 'c-minimal': dict(radius=dict(xs=4, sm=6, md=8, lg=12, pill=8), density='compacta', elevation='sem sombras; linhas de 1px'),
}
def tokens(key):
    t = _tokens(key)
    if key == 'c-minimal':
        t['stateLayers'] = C_STATE_OPACITY
    return t

def _tokens(key):
    return {
 'name': {'a-orbita': 'A · Órbita', 'b-trajetorias': 'B · Trajetórias', 'c-minimal': 'C · Minimal Tech'}[key],
 'status': 'PROPOSTA — não aplicada ao aplicativo',
 'color': PALETTES[key],
 'typography': {**TYPE[key], 'scale': {
    'displayLarge': dict(size=32, line=40, weight=700), 'headline': dict(size=24, line=32, weight=700), 'title': dict(size=18, line=24, weight=600),
    'body': dict(size=15, line=22, weight=400), 'bodySmall': dict(size=13, line=18, weight=400), 'label': dict(size=12, line=16, weight=600)}},
 'spacing': dict(unit=4, scale=[0, 4, 8, 12, 16, 20, 24, 32, 40, 56]),
 'shape': SHAPE[key],
 'touchTargetMin': 48,
 'motion': dict(fast='120ms', base='200ms', slow='320ms', easing='cubic-bezier(.2,0,0,1)', reduceMotion='respeitar preferência do sistema'),
 'breakpoints': dict(compact='<600', medium='600–1023', expanded='≥1024'),
 'navigation': dict(compact='bottom navigation (4 destinos)', medium='navigation rail', expanded='navigation rail + painel de detalhe'),
}
