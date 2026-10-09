"""HTML/CSS mock screens for the three identity proposals. Same illustrative content for all; only the skin differs.
Every figure/company/job here is FICTIONAL and labelled as such on each screen."""
import brand

KEYS = ['a-orbita', 'b-trajetorias', 'c-minimal']
CODE = {'a-orbita': 'pa', 'b-trajetorias': 'pb', 'c-minimal': 'pc'}
LABEL = {'a-orbita': 'A · Órbita', 'b-trajetorias': 'B · Trajetórias', 'c-minimal': 'C · Minimal Tech'}
BANNER = 'EXEMPLO FICTÍCIO · NÃO SÃO VAGAS REAIS'

JOBS = [
 dict(id='dev', title='Desenvolvedor Flutter', company='Empresa Exemplo Tech', place='Remoto · Global', mode='Remoto', contract='Tempo integral', salary='R$ 9.000–12.000/mês', match=88, conf='Alta', cat='Tecnologia'),
 dict(id='physio', title='Fisioterapeuta pélvica', company='Clínica Exemplo', place='Berlim · Alemanha', mode='Presencial', contract='Tempo integral', salary='€ 3.400–4.100/mês', match=81, conf='Média', cat='Saúde'),
 dict(id='painter', title='Pintor residencial', company='Serviços Exemplo', place='Sydney · Austrália', mode='Presencial', contract='Autônomo', salary='A$ 32–40/h', match=77, conf='Média', cat='Construção'),
 dict(id='mason', title='Pedreiro', company='Construtora Exemplo', place='Porto · Portugal', mode='Presencial', contract='Contrato', salary='€ 1.300–1.700/mês', match=74, conf='Média', cat='Construção'),
 dict(id='nurse', title='Enfermeiro', company='Hospital Exemplo', place='Toronto · Canadá', mode='Presencial', contract='Tempo integral', salary='CA$ 38–46/h', match=69, conf='Baixa', cat='Saúde'),
]
J = {j['id']: j for j in JOBS}

ICON = {
 'home': '<path d="M3 11l9-8 9 8M5 10v10h5v-6h4v6h5V10"/>',
 'explore': '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>',
 'heart': '<path d="M12 20s-8-5-8-11a4.5 4.5 0 0 1 8-2.5A4.5 4.5 0 0 1 20 9c0 6-8 11-8 11z"/>',
 'clip': '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4h6v3H9zM9 12h6M9 16h4"/>',
 'user': '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/>',
 'search': '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
 'filter': '<path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/>',
 'pin': '<path d="M12 21s7-6 7-11a7 7 0 0 0-14 0c0 5 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>',
 'globe': '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
 'check': '<path d="M5 12l5 5 9-10"/>',
 'chev': '<path d="M9 6l6 6-6 6"/>',
 'back': '<path d="M15 6l-6 6 6 6"/>',
 'file': '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4"/>',
 'bell': '<path d="M6 17V11a6 6 0 0 1 12 0v6l2 2H4z"/><path d="M10 21h4"/>',
 'plus': '<path d="M12 5v14M5 12h14"/>',
 'alert': '<circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16.5v.5"/>',
 'wifi': '<path d="M3 9a14 14 0 0 1 18 0M6 12.5a9.5 9.5 0 0 1 12 0M9 16a5 5 0 0 1 6 0"/><circle cx="12" cy="19" r=".8"/>',
 'brief': '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V4h6v3M3 13h18"/>',
 'cap': '<path d="M2 9l10-5 10 5-10 5z"/><path d="M6 11v5c3 2 9 2 12 0v-5"/>',
 'badge': '<circle cx="12" cy="9" r="5"/><path d="M8.5 13.5L7 21l5-3 5 3-1.5-7.5"/>',
 'lang': '<path d="M4 6h9M8.5 4v2M6 6c1 4 4 7 7 8M11 6c-1 4-4 7-7 9M14 20l4-10 4 10M15.5 17h5"/>',
 'bookmark': '<path d="M6 3h12v18l-6-4-6 4z"/>',
}
def ic(name, size=22, cls='ic'):
    return f'<svg class="{cls}" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{ICON[name]}</svg>'

def svg_inline(svg, height=None, cls=''):
    s = svg.strip()
    attrs = f' class="{cls}"' + (f' style="height:{height}px;width:auto"' if height else '')
    return s.replace('<svg ', f'<svg{attrs} ', 1)

# ───────────────────────── CSS ─────────────────────────
def css(fontrel):
    ff = lambda fam, file, w: f"@font-face{{font-family:'{fam}';font-weight:{w};font-display:swap;src:url('{fontrel}/{file}') format('woff2')}}"
    fonts = ''.join([ff('Sora', f'sora-latin-{w}-normal.woff2', w) for w in (400, 600, 700)] +
                    [ff('Manrope', f'manrope-latin-{w}-normal.woff2', w) for w in (400, 500, 600, 700, 800)] +
                    [ff('Space Grotesk', f'space-grotesk-latin-{w}-normal.woff2', w) for w in (400, 500, 600, 700)] +
                    [ff('Inter', f'inter-latin-{w}-normal.woff2', w) for w in (400, 500, 600, 700)] +
                    [ff('JetBrains Mono', f'jetbrains-mono-latin-{w}-normal.woff2', w) for w in (400, 500)])
    vars_ = ''
    for k in KEYS:
        t = brand.TYPE[k]; sh = brand.SHAPE[k]['radius']
        fd, ft, fm = (f"'{t['display']}',sans-serif", f"'{t['text']}',sans-serif", f"'{t['mono']}',monospace")
        extra = {
          'a-orbita': "--r-card:20px;--r-btn:999px;--r-chip:999px;--r-field:16px;--shadow:0 8px 24px rgba(15,40,110,.09);--card-border:1px solid transparent;--label-tt:none;--label-ls:0;--label-font:var(--ft);--label-size:12px;",
          'b-trajetorias': "--r-card:16px;--r-btn:14px;--r-chip:999px;--r-field:14px;--shadow:0 3px 10px rgba(8,60,55,.10);--card-border:1px solid var(--line);--label-tt:none;--label-ls:0;--label-font:var(--ft);--label-size:12px;",
          'c-minimal': "--r-card:8px;--r-btn:8px;--r-chip:6px;--r-field:8px;--shadow:none;--card-border:1px solid var(--line);--label-tt:uppercase;--label-ls:.06em;--label-font:var(--fm);--label-size:10.5px;",
        }[k]
        vars_ += f".{CODE[k]}{{--fd:{fd};--ft:{ft};--fm:{fm};{extra}}}"
        for mode, c in brand.PALETTES[k].items():
            vars_ += f".{CODE[k]}.{mode}{{" + ''.join(f"--{n.lower() if n.islower() else n}:{v};" for n, v in c.items()) + "}"
    return fonts + vars_ + CSS_BASE

CSS_BASE = '''
*{box-sizing:border-box;margin:0}
.frame{position:relative;overflow:hidden;background:var(--bg);color:var(--ink);font-family:var(--ft);font-size:15px;line-height:1.4;display:flex;flex-direction:column;-webkit-font-smoothing:antialiased}
.frame h1,.frame h2,.frame h3{font-family:var(--fd);letter-spacing:-.01em}
.m{width:390px;height:844px}.t{width:834px;height:1112px}.d{width:1280px;height:800px}
.sb{height:44px;display:flex;justify-content:space-between;align-items:flex-end;padding:0 24px 6px;font:600 14px var(--ft);flex:none}
.sb .r{display:flex;gap:6px;align-items:center}.sb i{display:block;width:24px;height:11px;border:1.5px solid var(--ink);border-radius:3px;position:relative}.sb i:after{content:'';position:absolute;inset:1.5px;right:5px;background:var(--ink);border-radius:1px}
.fict{flex:none;margin:2px 16px 0;padding:3px 8px;border-radius:var(--r-chip);background:var(--container);color:var(--muted);font:600 9.5px var(--ft);letter-spacing:.07em;text-align:center}
.scroll>*{flex:none}.scroll{flex:1;overflow:hidden;padding:12px 16px 8px;display:flex;flex-direction:column;gap:14px;min-height:0}
.row{display:flex;align-items:center;gap:10px}.sp{flex:1}.col{display:flex;flex-direction:column;gap:8px}
.mu{color:var(--muted)}.lbl{font:600 var(--label-size) var(--label-font);text-transform:var(--label-tt);letter-spacing:var(--label-ls);color:var(--muted)}
.ic{flex:none}
.nav{flex:none;display:flex;justify-content:space-around;padding:8px 8px 22px;background:var(--surface);border-top:1px solid var(--line)}
.nav a{display:flex;flex-direction:column;align-items:center;gap:3px;min-width:64px;min-height:48px;padding:6px 8px;color:var(--muted);font:500 11px var(--ft);border-radius:var(--r-chip);text-decoration:none}
.nav a.on{color:var(--primary);font-weight:700}
.pa .nav a.on .ic{background:var(--primaryContainer);padding:4px 14px;width:56px;height:30px;border-radius:999px;box-sizing:border-box;margin:-4px 0 -1px}
.pb .nav a.on:before{content:'';width:5px;height:5px;border-radius:50%;background:var(--accent);margin-bottom:-1px}
.pc .nav a.on{box-shadow:inset 0 2px 0 var(--primary);border-radius:0}
.rail{flex:none;width:92px;display:flex;flex-direction:column;align-items:center;gap:6px;padding:16px 6px;background:var(--surface);border-right:1px solid var(--line)}
.rail a{display:flex;flex-direction:column;align-items:center;gap:3px;width:76px;min-height:56px;padding:8px 4px;color:var(--muted);font:500 11px var(--ft);border-radius:var(--r-card);text-decoration:none}
.rail a.on{color:var(--primary);font-weight:700;background:var(--primaryContainer)}
.pc .rail a.on{background:transparent;box-shadow:inset 3px 0 0 var(--primary);border-radius:0}
.body{flex:1;display:flex;min-height:0}.main{flex:1;display:flex;flex-direction:column;min-width:0}
.top{display:flex;align-items:center;gap:10px;padding:6px 16px 0;flex:none}
.top .logo svg{height:26px;width:auto;display:block}
.av{width:40px;height:40px;border-radius:50%;background:var(--primaryContainer);color:var(--onPrimaryContainer);display:grid;place-items:center;font:700 14px var(--fd);flex:none}
.pb .av{box-shadow:0 0 0 2px var(--bg),0 0 0 4px var(--accent)}
.iconbtn{width:48px;height:48px;border-radius:50%;display:grid;place-items:center;color:var(--ink);flex:none}
.pc .iconbtn{border-radius:8px;border:1px solid var(--line)}
.field{display:flex;align-items:center;gap:10px;min-height:52px;padding:0 14px;background:var(--surface);border:1px solid var(--outline);border-radius:var(--r-field);color:var(--muted)}
.pa .field{border-color:transparent;box-shadow:var(--shadow)}
.field.big{min-height:56px;font-size:16px}.field .ph{flex:1;color:var(--muted)}.field b{color:var(--ink);font-weight:500}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;min-height:52px;padding:0 20px;border-radius:var(--r-btn);background:var(--primary);color:var(--onPrimary);font:700 15px var(--ft)}
.btn.sec{background:transparent;color:var(--primary);border:1.5px solid var(--outline)}.btn.sm{min-height:48px;font-size:14px}
.pc .btn{font-family:var(--fm);font-weight:500;letter-spacing:.02em;font-size:13.5px}
.chips{display:flex;gap:8px;flex-wrap:wrap}.chips.nw{flex-wrap:nowrap;overflow:hidden;margin-right:-16px}.chips.nw .chip{flex:none}.chip{display:inline-flex;align-items:center;gap:6px;min-height:44px;padding:0 14px;border:1px solid var(--outline);border-radius:var(--r-chip);color:var(--ink);font:500 13px var(--ft);background:var(--surface)}
.chip.on{background:var(--primaryContainer);border-color:transparent;color:var(--onPrimaryContainer);font-weight:700}
.chip.sm{min-height:26px;padding:0 10px;font-size:12px;border-color:var(--line);color:var(--muted)}
.pc .chip{font-family:var(--fm);font-size:12px}
.card{background:var(--surface);border:var(--card-border);border-radius:var(--r-card);box-shadow:var(--shadow);padding:14px;display:flex;flex-direction:column;gap:8px}
.pb .card.job{border-left:4px solid var(--primary)}
.card h3{font-size:16px;line-height:1.25}.card .meta{display:flex;gap:6px;align-items:center;color:var(--muted);font-size:13px}
.jobrow{display:flex;gap:12px;align-items:flex-start}
.ring{--v:80;width:50px;height:50px;border-radius:50%;background:conic-gradient(var(--primary) calc(var(--v)*1%),var(--line) 0);display:grid;place-items:center;flex:none;position:relative}
.ring:before{content:'';position:absolute;inset:5px;background:var(--surface);border-radius:50%}
.ring b{position:relative;font:700 15px var(--fd);color:var(--ink)}
.ring.lg{width:76px;height:76px}.ring.lg:before{inset:7px}.ring.lg b{font-size:24px}
.conf{display:inline-flex;gap:3px;align-items:center;font:600 11.5px var(--ft);color:var(--muted)}.conf i{width:7px;height:7px;border-radius:50%;background:var(--line);border:1px solid var(--outline)}.conf i.f{background:var(--primary);border-color:var(--primary)}
.sal{font:600 13.5px var(--ft);color:var(--ink)}
.src{font-size:11.5px;color:var(--muted)}
.sect{display:flex;justify-content:space-between;align-items:baseline}.sect h2{font-size:18px}.sect span{color:var(--primary);font:600 13px var(--ft)}
.tl{display:flex;flex-direction:column;gap:0}.tl .st{display:flex;gap:12px;min-height:62px}
.tl .dot{width:26px;display:flex;flex-direction:column;align-items:center}.tl .dot b{width:26px;height:26px;border-radius:50%;border:2px solid var(--outline);display:grid;place-items:center;background:var(--surface);color:var(--onPrimary);flex:none}
.tl .dot s{flex:1;width:2px;background:var(--line);margin:2px 0}.tl .done b{background:var(--primary);border-color:var(--primary)}.tl .done s{background:var(--primary)}
.tl .cur b{border-color:var(--primary);box-shadow:0 0 0 4px var(--primaryContainer)}
.pb .tl .cur b{background:var(--accent);border-color:var(--accent);box-shadow:0 0 0 4px var(--bg),0 0 0 6px var(--accent)}
.tl .tx b2{display:block}.tl .tx{padding-bottom:10px}.tl .tx strong{display:block;font:700 15px var(--fd)}.tl .tx span{font-size:13px;color:var(--muted)}
.li{display:flex;gap:12px;align-items:center;padding:12px 0;border-bottom:1px solid var(--line)}.li:last-child{border:0}.li .ico{width:40px;height:40px;border-radius:var(--r-field);background:var(--primaryContainer);color:var(--onPrimaryContainer);display:grid;place-items:center;flex:none}
.li strong{display:block;font:600 14.5px var(--ft)}.li span{font-size:13px;color:var(--muted)}
.sk{background:linear-gradient(90deg,var(--container),var(--line),var(--container));border-radius:var(--r-chip);height:12px}
.hero{border-radius:var(--r-card);background:var(--primaryContainer);color:var(--onPrimaryContainer);padding:16px;display:flex;gap:12px;align-items:center;overflow:hidden;position:relative}
.hero svg.art{position:absolute;right:-6px;bottom:-4px;height:110%;opacity:.95}
.pc .hero{background:var(--container);color:var(--ink);border:1px solid var(--line)}
.center{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:12px;padding:24px}
.state-ic{width:72px;height:72px;border-radius:50%;background:var(--primaryContainer);color:var(--onPrimaryContainer);display:grid;place-items:center}
.pc .state-ic{border-radius:12px}
.deco{position:absolute;left:0;right:0;bottom:28px;height:190px;opacity:.4;pointer-events:none}.deco svg{width:100%;height:100%;display:block}.splash{align-items:center;justify-content:center;gap:18px;text-align:center}
.pa .splash{background:radial-gradient(120% 70% at 50% 0%,var(--primaryContainer),var(--bg) 70%)}
.pb .splash{background:linear-gradient(180deg,var(--bg),var(--container))}
.split{flex:1;display:flex;min-height:0}.listcol{width:430px;flex:none;border-right:1px solid var(--line);padding:14px 16px;display:flex;flex-direction:column;gap:12px;overflow:hidden}
.detail{flex:1;padding:18px 24px;display:flex;flex-direction:column;gap:14px;overflow:hidden}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:14px}
'''

# ───────────────────────── components ─────────────────────────
def nav_items(l):
    return [('home', 'Início'), ('explore', 'Explorar'), ('heart', 'Favoritos'), ('clip', 'Candidaturas')]

def bottom_nav(active):
    return '<nav class="nav">' + ''.join(f'<a class="{"on" if i == active else ""}">{ic(n)}<span>{t}</span></a>' for i, (n, t) in enumerate(nav_items(0))) + '</nav>'

def rail(active, logo_mark):
    return f'<aside class="rail"><div style="height:44px;display:grid;place-items:center">{logo_mark}</div>' + ''.join(f'<a class="{"on" if i == active else ""}">{ic(n, 24)}<span>{t}</span></a>' for i, (n, t) in enumerate(nav_items(0))) + '</aside>'

def conf_dots(level):
    n = {'Alta': 3, 'Média': 2, 'Baixa': 1}[level]
    return f'<span class="conf">{"".join("<i class=f></i>" if i < n else "<i></i>" for i in range(3))}&nbsp;Confiança {level.lower()}</span>'

def job_card(j, fav=False, note=None, detail_btn=False):
    heart = f'<span style="color:{"var(--accent)" if fav else "var(--muted)"}">{ic("heart", 22)}</span>'
    if fav: heart = heart.replace('fill="none"', 'fill="currentColor"')
    return (f'<div class="card job"><div class="jobrow"><div class="col" style="flex:1;gap:4px"><span class="lbl">{j["cat"]}</span><h3>{j["title"]}</h3>'
            f'<div class="meta">{j["company"]}</div><div class="meta">{ic("pin", 15)} {j["place"]}</div></div>'
            f'<div class="col" style="align-items:center;gap:6px"><div class="ring" style="--v:{j["match"]}"><b>{j["match"]}</b></div>{heart}</div></div>'
            f'<div class="chips"><span class="chip sm">{j["mode"]}</span><span class="chip sm">{j["contract"]}</span></div>'
            f'<div class="row"><span class="sal">{j["salary"]}</span><span class="sp"></span>{conf_dots(j["conf"])}</div>'
            + (f'<div class="src" style="border-top:1px solid var(--line);padding-top:8px">✎ {note}</div>' if note else f'<div class="src">Fonte: exemplo · atribuição da fonte aparece aqui</div>') + '</div>')

def statusbar():
    return '<div class="sb"><span>9:41</span><span class="r">' + ic('wifi', 16) + '<i></i></span></div>'

def wrap(key, mode, layout, sid, inner, nav_active=None, logo_mark='', extra_cls=''):
    cls = f'frame {layout} {CODE[key]} {mode} {extra_cls}'
    ban = f'<div class="fict">{BANNER}</div>'
    if layout == 'm':
        body = f'{statusbar()}{ban}{inner}' + (bottom_nav(nav_active) if nav_active is not None else '')
    else:
        body = f'{ban}<div class="body">{rail(nav_active if nav_active is not None else 0, logo_mark)}{inner}</div>'
    return f'<div class="{cls}" id="{key}-{mode}-{layout}-{sid}" data-label="{sid}">{body}</div>'

def header(key, mode, title=None, back=False, right=''):
    P = brand
    if title is None:
        mark = svg_inline(brand.icon_svg(key, 'app'), 32)
        left = f'<span class="logo">{svg_inline(brand.logo_svg(key, mode), None)}</span>'
    else:
        left = (f'<span class="iconbtn">{ic("back")}</span>' if back else '') + f'<h2 style="font-size:19px">{title}</h2>'
    return f'<div class="top">{left}<span class="sp"></span>{right}</div>'

AVATAR = '<span class="av">PE</span>'
BELL = f'<span class="iconbtn">{ic("bell")}</span>'

def hero_art(key, mode):
    c = brand.PALETTES[key][mode]
    return {
     'a-orbita': f'<svg class="art" viewBox="0 0 160 120"><circle cx="100" cy="70" r="40" fill="{c["primary"]}" opacity=".25"/><ellipse cx="100" cy="70" rx="70" ry="22" transform="rotate(-18 100 70)" fill="none" stroke="{c["primary"]}" stroke-width="3"/><circle cx="150" cy="38" r="8" fill="{c["accent"]}"/></svg>',
     'b-trajetorias': f'<svg class="art" viewBox="0 0 160 120"><path d="M10 100C50 100 60 40 100 50S140 90 150 30" fill="none" stroke="{c["primary"]}" stroke-width="3" stroke-dasharray="2 7" stroke-linecap="round"/><circle cx="10" cy="100" r="6" fill="{c["primary"]}"/><circle cx="100" cy="50" r="6" fill="{c["primary"]}"/><circle cx="150" cy="30" r="10" fill="{c["accent"]}"/></svg>',
     'c-minimal': f'<svg class="art" viewBox="0 0 160 120"><g stroke="{c["line"]}" stroke-width="1">' + ''.join(f'<path d="M{x} 0V120"/>' for x in range(20, 160, 20)) + ''.join(f'<path d="M0 {y}H160"/>' for y in range(20, 120, 20)) + f'</g><circle cx="110" cy="62" r="28" fill="none" stroke="{c["ink"]}" stroke-width="8"/><circle cx="110" cy="62" r="7" fill="{c["primary"]}"/></svg>',
    }[key]

# ───────────────────────── screens (mobile) ─────────────────────────
def s_splash(key, mode):
    big = svg_inline(brand.icon_svg(key, 'app'), 104)
    word = svg_inline(brand.logo_svg(key, mode), 34)
    deco = f'<div class="deco">{hero_art(key, mode).replace("class=\"art\"", "")}</div>'
    return wrap(key, mode, 'm', 'splash', f'{deco}<div class="scroll splash" style="justify-content:center;position:relative">{big}<div>{svg_inline(brand.logo_svg(key, mode), 38)}</div><p class="mu" style="max-width:240px">Oportunidades em qualquer lugar do mundo, para qualquer profissão.</p></div><div style="height:46px"></div>')

def s_login(key, mode):
    inner = (f'<div class="scroll" style="gap:16px;padding-top:24px"><div>{svg_inline(brand.logo_svg(key, mode), 34)}</div>'
             f'<div class="col" style="gap:6px;margin-top:8px"><h1 style="font-size:28px;line-height:1.15">Encontre trabalho em qualquer lugar do mundo</h1><p class="mu">Entre para salvar vagas e acompanhar candidaturas.</p></div>'
             f'<div class="col" style="gap:12px;margin-top:6px"><div class="field"><span class="ph">E-mail</span></div><div class="field"><span class="ph">Senha</span>{ic("globe",18)}</div>'
             f'<div class="btn">Entrar</div><div class="row" style="justify-content:center"><span class="mu">ou</span></div>'
             f'<div class="btn sec">Continuar com e-mail institucional</div></div><span class="sp"></span>'
             f'<p class="mu" style="text-align:center;font-size:13px">Não tem conta? <b style="color:var(--primary)">Criar conta</b></p></div>')
    return wrap(key, mode, 'm', 'login', inner)

def home_body(key, mode, wide=False):
    cats = ['Tecnologia', 'Saúde', 'Construção', 'Educação', 'Serviços', 'Indústria']
    hero = (f'<div class="hero"><div class="col" style="gap:4px;max-width:{"60%" if not wide else "50%"}"><span class="lbl" style="color:inherit;opacity:.8">Olá, Pessoa Exemplo</span>'
            f'<h2 style="font-size:20px;line-height:1.2">O que você quer fazer agora?</h2></div>{hero_art(key, mode)}</div>')
    search = f'<div class="field big">{ic("search")}<span class="ph">Qualquer profissão ou país</span><span class="mu">{ic("filter")}</span></div>'
    chips = '<div class="chips nw">' + ''.join(f'<span class="chip{" on" if i == 0 else ""}">{c}</span>' for i, c in enumerate(cats[:4 if not wide else 6])) + '</div>'
    foryou = f'<div class="sect"><h2>Para você</h2><span>Ver todas</span></div>'
    cards = [job_card(J['dev']), job_card(J['physio'])]
    apps = (f'<div class="sect"><h2>Candidaturas em andamento</h2><span>Ver</span></div><div class="card" style="padding:4px 14px">'
            f'<div class="li"><div class="ico">{ic("clip",20)}</div><div style="flex:1"><strong>Fisioterapeuta pélvica</strong><span>Etapa: Entrevista</span></div>{ic("chev",18)}</div>'
            f'<div class="li"><div class="ico">{ic("clip",20)}</div><div style="flex:1"><strong>Pedreiro</strong><span>Etapa: Inscrito</span></div>{ic("chev",18)}</div></div>')
    return hero, search, chips, foryou, cards, apps

def s_home(key, mode):
    hero, search, chips, foryou, cards, apps = home_body(key, mode)
    inner = (header(key, mode, right=BELL + AVATAR) + f'<div class="scroll">{hero}{search}{chips}{foryou}{cards[0]}{cards[1]}{apps}</div>')
    return wrap(key, mode, 'm', 'home', inner, 0)

def s_explore(key, mode):
    inner = (header(key, mode, 'Explorar', right=AVATAR) +
             f'<div class="scroll"><div class="field big">{ic("search")}<span class="ph">Qualquer profissão ou país</span></div>'
             f'<div class="chips nw"><span class="chip on">{ic("globe",16)} Todos os países</span><span class="chip">Modalidade</span><span class="chip">Salário</span><span class="chip">Idioma</span></div>'
             f'<div class="row"><span class="lbl">Ordenado por compatibilidade</span><span class="sp"></span><span class="mu">{ic("filter",20)}</span></div>'
             + ''.join(job_card(j) for j in JOBS[:4]) + '</div>')
    return wrap(key, mode, 'm', 'explore', inner, 1)

def detail_content(key, mode, j):
    reasons = [('check', 'Competências: 4 de 5 atendidas'), ('check', 'Idioma: alemão B1 informado · B2 desejado (parcial)'), ('alert', 'Licença profissional exigida: ainda não declarada (pendente)')]
    li = ''.join(f'<div class="li" style="padding:8px 0"><div class="ico" style="width:32px;height:32px;{"background:var(--container);color:var(--accentText)" if n == "alert" else ""}">{ic(n,18)}</div><span style="color:var(--ink);font-size:14px">{t}</span></div>' for n, t in reasons)
    return (f'<div class="row" style="align-items:flex-start"><div class="col" style="flex:1;gap:4px"><span class="lbl">{j["cat"]}</span><h1 style="font-size:24px;line-height:1.15">{j["title"]}</h1><div class="meta mu">{j["company"]} · {j["place"]}</div></div></div>'
            f'<div class="chips"><span class="chip sm">{j["mode"]}</span><span class="chip sm">{j["contract"]}</span><span class="chip sm">{j["salary"]}</span></div>'
            f'<div class="card"><div class="row"><div class="ring lg" style="--v:{j["match"]}"><b>{j["match"]}</b></div><div class="col" style="gap:4px"><strong style="font:700 16px var(--fd)">Compatibilidade</strong>{conf_dots(j["conf"])}<span class="src">Pontuação e confiança são separadas</span></div></div><div>{li}</div></div>'
            f'<div class="col"><h2 style="font-size:17px">Sobre a vaga</h2><p class="mu" style="font-size:14px">Texto ilustrativo de descrição da vaga. Em produção, o conteúdo vem da fonte autorizada e é exibido com atribuição.</p></div>')

def s_detail(key, mode):
    j = J['physio']
    inner = (header(key, mode, 'Detalhes', back=True, right=f'<span class="iconbtn" style="color:var(--accent)">{ic("heart").replace("fill=\"none\"", "fill=\"currentColor\"")}</span>') +
             f'<div class="scroll">{detail_content(key, mode, j)}</div>'
             f'<div style="padding:8px 16px 22px;display:flex;flex-direction:column;gap:8px;border-top:1px solid var(--line);background:var(--surface)"><div class="btn">Abrir candidatura oficial</div><div class="src" style="text-align:center">Fonte: exemplo · você revisa e envia no site oficial</div></div>')
    return wrap(key, mode, 'm', 'detail', inner)

def s_favorites(key, mode):
    inner = (header(key, mode, 'Favoritos', right=AVATAR) +
             '<div class="scroll">' + job_card(J['physio'], True, 'Nota: perguntar sobre revalidação do diploma') + job_card(J['painter'], True, 'Nota: conferir visto de trabalho') + job_card(J['mason'], True, 'Nota: comparar com outra oferta') + '</div>')
    return wrap(key, mode, 'm', 'favorites', inner, 2)

def tl_content():
    steps = [('Inscrito', 'Canal: site oficial · 12/10', 'done'), ('Triagem', 'Atualizado manualmente', 'done'), ('Entrevista', 'Lembrete: preparar perguntas', 'cur'), ('Proposta', 'Ainda não ocorreu', 'todo')]
    out = ''
    for i, (t, s, st) in enumerate(steps):
        mark = ic('check', 14) if st == 'done' else ''
        line = '' if i == len(steps) - 1 else '<s></s>'
        out += f'<div class="st {st}"><div class="dot"><b>{mark}</b>{line}</div><div class="tx"><strong>{t}</strong><span>{s}</span></div></div>'
    return f'<div class="tl">{out}</div>'

def s_application(key, mode):
    j = J['physio']
    inner = (header(key, mode, 'Candidatura', back=True, right=AVATAR) +
             f'<div class="scroll"><div class="card"><span class="lbl">{j["cat"]}</span><h3>{j["title"]}</h3><div class="meta">{j["company"]} · {j["place"]}</div></div>'
             f'<div class="sect"><h2>Etapas</h2><span>Histórico</span></div><div class="card">{tl_content()}</div>'
             f'<div class="btn">Atualizar etapa</div><div class="card" style="gap:4px"><span class="lbl">Observações</span><span style="font-size:14px">Perguntar sobre equipe e rotina de atendimento. (nota de exemplo)</span></div></div>')
    return wrap(key, mode, 'm', 'application', inner, 3)

def s_profile(key, mode):
    rows = [('brief', 'Experiências', 'Clínica Exemplo · 2019–2024'), ('cap', 'Formação', 'Fisioterapia · Instituição Exemplo'), ('badge', 'Licenças', 'Registro profissional · informado por você'), ('lang', 'Idiomas', 'Português nativo · Inglês B2 · Alemão B1'), ('file', 'Currículo (PDF)', 'curriculo-exemplo.pdf · privado')]
    inner = (header(key, mode, 'Perfil profissional', back=True) +
             f'<div class="scroll"><div class="row" style="gap:14px"><span class="av" style="width:64px;height:64px;font-size:20px">PE</span><div class="col" style="gap:2px"><h2 style="font-size:20px">Pessoa Exemplo</h2><span class="mu">Brasil · busca vagas em 3 países</span></div></div>'
             f'<div class="chips"><span class="chip on">Fisioterapia pélvica</span><span class="chip">Desenvolvimento</span><span class="chip">{ic("plus",16)} Novo perfil</span></div>'
             f'<div class="card" style="padding:4px 14px">' + ''.join(f'<div class="li"><div class="ico">{ic(i,20)}</div><div style="flex:1"><strong>{t}</strong><span>{s}</span></div>{ic("chev",18)}</div>' for i, t, s in rows) + '</div>'
             f'<div class="card"><div class="row"><strong style="font:600 14.5px var(--ft)">Dados prontos para preenchimento assistido</strong></div><span class="src">Você revisa tudo antes de enviar qualquer formulário.</span></div></div>')
    return wrap(key, mode, 'm', 'profile', inner)

def s_states(key, mode):
    sk = '<div class="card"><div class="sk" style="width:35%"></div><div class="sk" style="height:18px;width:80%"></div><div class="sk" style="width:55%"></div><div class="sk" style="width:90%;height:10px"></div></div>'
    inner = (header(key, mode, 'Explorar', right=AVATAR) + f'<div class="scroll"><div class="field big">{ic("search")}<span class="ph">Carregando…</span></div>{sk}{sk}{sk}</div>')
    loading = wrap(key, mode, 'm', 'state-loading', inner, 1)
    empty = wrap(key, mode, 'm', 'state-empty', header(key, mode, 'Explorar', right=AVATAR) + f'<div class="center"><div class="state-ic">{ic("search",34)}</div><h2 style="font-size:20px">Nenhuma vaga com esses filtros</h2><p class="mu">Amplie o país ou remova um filtro. Também mostramos portais externos quando não há fonte integrada.</p><div class="btn sm" style="padding:0 24px">Limpar filtros</div></div>', 1)
    err = wrap(key, mode, 'm', 'state-error', header(key, mode, 'Explorar', right=AVATAR) + f'<div class="center"><div class="state-ic" style="color:var(--danger)">{ic("alert",34)}</div><h2 style="font-size:20px">Não foi possível carregar</h2><p class="mu">Verifique a conexão e tente novamente. Seus favoritos continuam salvos.</p><div class="btn sm" style="padding:0 24px">Tentar novamente</div></div>', 1)
    nosrc = wrap(key, mode, 'm', 'state-nosource', header(key, mode, 'Explorar', right=AVATAR) + f'<div class="center"><div class="state-ic">{ic("globe",34)}</div><h2 style="font-size:20px">Sem fonte integrada para esta busca</h2><p class="mu">Ainda não temos fonte autorizada para este país e profissão. Pesquise nos portais originais.</p><div class="btn sm sec" style="padding:0 24px">Buscar em portais externos</div></div>', 1)
    return [loading, empty, err, nosrc]

MOBILE = [('splash', s_splash), ('login', s_login), ('home', s_home), ('explore', s_explore), ('detail', s_detail), ('favorites', s_favorites), ('application', s_application), ('profile', s_profile)]

# ───────────────────────── tablet / desktop ─────────────────────────
def mark(key):
    return svg_inline(brand.icon_svg(key, 'app'), 36)

def t_home(key, mode):
    hero, search, chips, foryou, cards, apps = home_body(key, mode, wide=True)
    inner = (f'<div class="main">{header(key, mode, right=BELL + AVATAR)}<div class="scroll" style="padding:16px 28px;gap:18px">{hero}{search}{chips}{foryou}<div class="grid2">{cards[0]}{cards[1]}</div>{apps}</div></div>')
    return wrap(key, mode, 't', 'home', inner, 0, mark(key))

def t_explore(key, mode):
    inner = (f'<div class="main">{header(key, mode, "Explorar", right=AVATAR)}<div class="scroll" style="padding:16px 28px"><div class="field big">{ic("search")}<span class="ph">Qualquer profissão ou país</span></div>'
             f'<div class="chips nw"><span class="chip on">{ic("globe",16)} Todos os países</span><span class="chip">Modalidade</span><span class="chip">Salário</span><span class="chip">Idioma</span></div>'
             f'<div class="grid2">' + ''.join(job_card(j) for j in JOBS[:4]) + '</div></div></div>')
    return wrap(key, mode, 't', 'explore', inner, 1, mark(key))

def d_home(key, mode):
    hero, search, chips, foryou, cards, apps = home_body(key, mode, wide=True)
    inner = (f'<div class="main">{header(key, mode, right=BELL + AVATAR)}<div class="scroll" style="padding:16px 32px;gap:18px;flex-direction:row;flex-wrap:wrap;align-content:flex-start">'
             f'<div class="col" style="flex:1.4;gap:16px;min-width:0">{hero}{search}{chips}{foryou}<div class="grid2">{cards[0]}{cards[1]}</div></div><div class="col" style="flex:1;gap:14px;min-width:0">{apps}</div></div></div>')
    return wrap(key, mode, 'd', 'home', inner, 0, mark(key))

def d_explore(key, mode):
    left = (f'<div class="listcol"><div class="field">{ic("search")}<span class="ph">Qualquer profissão ou país</span></div>'
            f'<div class="chips"><span class="chip on sm" style="color:inherit">Todos os países</span><span class="chip sm">Modalidade</span><span class="chip sm">Salário</span></div>'
            + ''.join(job_card(j) for j in JOBS[1:4]).replace('class="card job"', 'class="card job"') + '</div>')
    right = (f'<div class="detail">{detail_content(key, mode, J["physio"])}<div class="btn" style="max-width:340px">Abrir candidatura oficial</div></div>')
    inner = f'<div class="main">{header(key, mode, "Explorar", right=AVATAR)}<div class="split">{left}{right}</div></div>'
    return wrap(key, mode, 'd', 'explore', inner, 1, mark(key))

LARGE = [('t', 'home', t_home), ('t', 'explore', t_explore), ('d', 'home', d_home), ('d', 'explore', d_explore)]
