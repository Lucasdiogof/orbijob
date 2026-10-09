#!/usr/bin/env python3
"""Builds docs/design/comparison/index.html (+ quick-view PNGs in comparison/png/). Run after build.py."""
import json, pathlib, subprocess
import brand, screens

ROOT = pathlib.Path(__file__).resolve().parents[1]; OUT = ROOT.parent / 'comparison'; BUILD = pathlib.Path(__file__).resolve().parent
KEYS = list(brand.PALETTES); NAME = screens.LABEL
IMG = lambda k, mode, f: f'../identity/{k}/screens/{mode}/{f}.png'

PROS = {
 'a-orbita': dict(
   concept='Globo + órbita + ponto âmbar: a oportunidade que gira ao redor do mundo. O nome (Orbi-) e a marca dizem a mesma coisa.',
   strong=['Maior encaixe entre nome, marca e conceito ("Orbi" = órbita).', 'Ícone mais reconhecível e emocional; funciona sem texto (planeta + anel + ponto).', 'Azul profundo transmite confiança; âmbar dá calor e destaque ao ponto de oportunidade.', 'Wordmark amigável em duas cores (Orbi / Job) e boa leitura em tamanhos pequenos.', 'Interface suave (cantos 20 dp, sombras leves) que funciona para qualquer profissão.'],
   weak=['Planeta com anel é um motivo comum; pode lembrar outros produtos e a leitura "Saturno" supera "globo" em tamanhos pequenos.', 'Meridiano do ícone é detalhe fino: some abaixo de ~32 px (por isso há versão otimizada).', 'Azul é a cor mais usada em apps de carreira: menos distintiva por cor.'],
   risks=['Busca de marca/aparência: motivo planeta+órbita precisa de checagem de semelhança.', 'Âmbar sobre fundo claro só é usado em elementos gráficos (texto usa tom escurecido).']),
 'b-trajetorias': dict(
   concept='Anel aberto de nós conectados por rotas: pessoas e lugares ligados, com um nó coral = a vaga certa.',
   strong=['Identidade mais humana e acolhedora; verde-azulado + coral fogem do "azul corporativo".', 'Idéia de conexões e caminhos explica o produto (buscar, avaliar, acompanhar etapas).', 'Detalhe do "j" com ponto coral no wordmark é ownable.', 'Camada de UI própria (borda de trilha nos cartões, avatar com anel) reforça a metáfora de rota.'],
   weak=['"Rede de nós" é metáfora genérica (tecnologia/saúde/redes sociais); o ícone pode lembrar um símbolo de molécula ou de conexão.', 'No ícone de 16 px os nós viram pontos: só o nó coral e o anel sobrevivem.', 'Coral e verde-azulado juntos exigem cuidado de contraste (coral só em elementos gráficos ou tons ajustados para texto).'],
   risks=['Semelhança com marcas de rede/colaboração: checar.', 'Daltonismo: verde-azulado × coral tem luminosidade distinta (ok), mas validar com simulação.']),
 'c-minimal': dict(
   concept='"O" geométrico formado por dois arcos opostos; os vãos diagonais são espaço negativo; ponto violeta = precisão da busca.',
   strong=['Melhor em preto-e-branco, em tamanhos mínimos e como favicon: forma simples, sem detalhes finos.', 'Wordmark em caixa-alta espaçada transmite precisão e seriedade.', 'Interface mais densa e rápida de escanear (linhas finas, rótulos monoespaçados).', 'Mais fácil de reproduzir e proteger (marca abstrata).'],
   weak=['Mais fria: tende a parecer ferramenta de tecnologia/produtividade, menos acolhedora para pedreiro, enfermeira, motorista.', 'Ícone abstrato não comunica "emprego" nem "mundo" sem apoio do texto.', 'Rótulos monoespaçados e caixa-alta aumentam a carga de leitura em parágrafos e em idiomas com acentos/CJK.'],
   risks=['Violeta e "O" com ponto lembram marcas de IA/cripto/fintech; diferenciar.', 'Fonte monoespaçada em UI exige fallback para alfabetos não latinos.']),
}

def sw(c): return ''.join(f'<span class="sw" style="background:{v}" title="{n} {v}"><b style="color:{"#000" if brand._lum(v) > .4 else "#fff"}">{n}<br>{v}</b></span>' for n, v in c.items() if n in ('bg', 'surface', 'ink', 'muted', 'primary', 'primaryContainer', 'accent', 'danger'))

def build():
    logos = ''.join(f'<div class="cell"><h4>{NAME[k]}</h4><div class="lg light">{screens.svg_inline(brand.logo_svg(k, "light"), 70)}</div><div class="lg dark" style="background:{brand.PALETTES[k]["dark"]["bg"]}">{screens.svg_inline(brand.logo_svg(k, "dark"), 70)}</div>'
                    f'<div class="lg light">{screens.svg_inline(brand.logo_svg(k, "mono-black"), 44)}</div><div class="lg dark" style="background:#111">{screens.svg_inline(brand.logo_svg(k, "mono-white"), 44)}</div></div>' for k in KEYS)
    icons = ''.join(f'<div class="cell"><h4>{NAME[k]}</h4><div class="icons">' + ''.join(f'<div style="background:{bg};padding:10px;border-radius:12px">{screens.svg_inline(brand.icon_svg(k, kind), 92)}</div>' for kind, bg in (('app', '#e9ebf0'), ('light', '#fff'), ('dark', '#111'), ('mono-black', '#fff'), ('mono-white', '#111'))) + f'</div><img class="native" src="../identity/{k}/icon-sizes-light.png" alt="Ícone em 16, 32, 48, 64, 128 e 512 px, tamanhos reais"></div>' for k in KEYS)
    pal = ''.join(f'<div class="cell"><h4>{NAME[k]}</h4><p class="lbl">claro</p><div class="sws">{sw(brand.PALETTES[k]["light"])}</div><p class="lbl">escuro</p><div class="sws">{sw(brand.PALETTES[k]["dark"])}</div><p class="note">Tipografia: {brand.TYPE[k]["note"]}</p></div>' for k in KEYS)
    def trio(f, mode, cap=''):
        return '<div class="trio">' + ''.join(f'<figure><figcaption>{NAME[k]}</figcaption><img src="{IMG(k, mode, f)}" alt="{NAME[k]} {f} {mode}"></figure>' for k in KEYS) + '</div>'
    home = f'<h3>Claro</h3>{trio("03-home", "light")}<h3>Escuro</h3>{trio("03-home", "dark")}'
    explore = f'<h3>Claro</h3>{trio("04-explore", "light")}<h3>Escuro</h3>{trio("04-explore", "dark")}'
    allscr = ''.join(f'<div class="cell wide"><h4>{NAME[k]} — telas (claro e escuro) · <a href="../identity/{k}/screens.html">abrir telas ao vivo</a></h4><img src="../identity/{k}/sheet-mobile-light.png" alt="{NAME[k]} claro"><img src="../identity/{k}/sheet-mobile-dark.png" alt="{NAME[k]} escuro"></div>' for k in KEYS)
    resp = ''.join(f'<div class="cell wide"><h4>{NAME[k]}</h4><div class="resp"><img class="tab" src="../identity/{k}/screens/light/tablet-home.png" alt="tablet"><img class="desk" src="../identity/{k}/screens/dark/desktop-explore.png" alt="desktop"></div></div>' for k in KEYS)
    states = ''.join(f'<div class="cell wide"><h4>{NAME[k]}</h4><div class="states">' + ''.join(f'<img src="{IMG(k, "light", "09-state-" + s)}" alt="{s}">' for s in ('loading', 'empty', 'error', 'nosource')) + '</div></div>' for k in KEYS)
    sw_tbl = '<table><tr><th></th>' + ''.join(f'<th>{NAME[k]}</th>' for k in KEYS) + '</tr>'
    for title, key in (('Conceito', 'concept'), ('Pontos fortes', 'strong'), ('Pontos fracos', 'weak'), ('Riscos visuais', 'risks')):
        sw_tbl += f'<tr><th>{title}</th>' + ''.join('<td>' + (PROS[k][key] if isinstance(PROS[k][key], str) else '<ul>' + ''.join(f'<li>{x}</li>' for x in PROS[k][key]) + '</ul>') + '</td>' for k in KEYS) + '</tr>'
    sw_tbl += '</table>'
    rec = open(BUILD / 'recommendation.html').read()
    css = ('*{box-sizing:border-box}body{margin:0;font:16px/1.55 Inter,system-ui,sans-serif;background:#f4f5f8;color:#14161c}'
           'header{background:#0e1220;color:#fff;padding:28px 24px}header h1{margin:0 0 6px;font-size:28px}header p{margin:4px 0;color:#c9d0e6;max-width:900px}'
           'nav{position:sticky;top:0;z-index:5;background:#fff;border-bottom:1px solid #dde0e8;display:flex;gap:4px;flex-wrap:wrap;padding:8px 16px}nav a{padding:8px 12px;border-radius:8px;color:#14161c;text-decoration:none;font-weight:600;font-size:14px}nav a:hover{background:#eceef4}'
           'main{max-width:1500px;margin:0 auto;padding:8px 24px 64px}section{padding-top:28px}h2{font-size:24px;margin:0 0 6px}h3{margin:18px 0 8px}h4{margin:0 0 8px}.lead{color:#444;max-width:820px;margin:0 0 14px}'
           '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}.cell{background:#fff;border:1px solid #dde0e8;border-radius:14px;padding:16px}.cell.wide{grid-column:1/-1}'
           '.lg{padding:14px;border-radius:10px;margin-bottom:8px;display:flex;align-items:center;border:1px solid #e6e8ee}.lg.light{background:#fff}.lg svg{max-width:100%}'
           '.icons{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:10px}.native{max-width:100%;height:auto;border:1px solid #e6e8ee;border-radius:8px}'
           '.sws{display:flex;flex-wrap:wrap;gap:4px}.sw{width:76px;height:64px;border-radius:8px;border:1px solid #0002;display:flex;align-items:flex-end;padding:4px;font-size:9.5px;line-height:1.15}.lbl{font-size:12px;color:#555;margin:8px 0 4px;text-transform:uppercase;letter-spacing:.06em}.note{font-size:13px;color:#555}'
           '.trio{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:20px}.trio img{width:100%;height:auto;border-radius:18px;border:1px solid #cfd3dd;display:block}figure{margin:0}figcaption{font-weight:700;margin:0 0 6px}'
           '.cell img{max-width:100%;height:auto;border-radius:8px;display:block;margin:8px 0}.resp{display:flex;gap:16px;flex-wrap:wrap;align-items:flex-start}.resp .tab{width:min(46%,420px)}.resp .desk{width:min(52%,640px)}'
           '.states{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}table{border-collapse:collapse;width:100%;background:#fff;border-radius:14px;overflow:hidden;border:1px solid #dde0e8}th,td{padding:12px 14px;border-bottom:1px solid #eceef4;vertical-align:top;text-align:left;font-size:14.5px}th{background:#f1f2f7;width:130px}ul{margin:0;padding-left:18px}'
           '.rec{background:#fff;border:2px solid #14161c;border-radius:14px;padding:20px}.warn{background:#fff7e0;border:1px solid #f0d28a;border-radius:10px;padding:12px 14px;margin:12px 0}.badge{display:inline-block;background:#14161c;color:#fff;border-radius:99px;padding:2px 10px;font-size:12px;font-weight:700}')
    nav = ''.join(f'<a href="#{i}">{t}</a>' for i, t in (('logos', 'Logotipos'), ('icons', 'Ícones'), ('palettes', 'Paletas'), ('home', 'Home'), ('explore', 'Explorar'), ('screens', 'Todas as telas'), ('responsive', 'Tablet/Desktop'), ('states', 'Estados'), ('compare', 'Prós e contras'), ('recommendation', 'Recomendação'), ('checks', 'Verificações')))
    html = (f'<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OrbiJob — comparação das identidades (propostas)</title><style>{screens.css("../fonts")}{css}</style>'
            f'<header><h1>OrbiJob — comparação de identidades</h1><p>Três propostas, o mesmo conteúdo ilustrativo. <b>Nenhuma foi escolhida nem aplicada ao aplicativo</b>; a decisão é do proprietário.</p><p>Todo conteúdo de tela (vagas, empresas, notas, salários, compatibilidades) é <b>fictício</b> e está identificado em cada tela.</p></header><nav>{nav}</nav><main>'
            f'<section id="logos"><h2>Logotipos horizontais</h2><p class="lead">Cada coluna: versão clara, escura, monocromática preta e monocromática branca. Wordmarks são curvas vetoriais de fontes OFL.</p><div class="grid">{logos}</div></section>'
            f'<section id="icons"><h2>Ícones do aplicativo</h2><p class="lead">Tile de marca, claro, escuro e monocromáticos. A faixa de baixo mostra 16, 32, 48, 64, 128 e 512 px <b>nos tamanhos reais</b>, cada um renderizado do vetor (nunca ampliado); até 32 px usa-se a versão óptica simplificada.</p><div class="grid">{icons}</div></section>'
            f'<section id="palettes"><h2>Paletas e tipografia</h2><p class="lead">Todos os pares de texto atingem WCAG AA (≥ 4,5:1) e componentes ≥ 3:1 — calculado, não estimado (ver verificações).</p><div class="grid">{pal}</div></section>'
            f'<section id="home"><h2>Home</h2>{home}</section><section id="explore"><h2>Explorar (busca)</h2>{explore}</section>'
            f'<section id="screens"><h2>Todas as telas</h2><p class="lead">Splash, login, home, explorar, detalhes, favoritos, acompanhamento de candidatura e perfil profissional.</p><div class="grid">{allscr}</div></section>'
            f'<section id="responsive"><h2>Tablet e desktop/Web</h2><p class="lead">Navigation rail a partir de 600 dp; no desktop, lista + painel de detalhe. Mobile usa bottom navigation.</p><div class="grid">{resp}</div></section>'
            f'<section id="states"><h2>Estados: carregando, vazio, erro e sem fonte integrada</h2><div class="grid">{states}</div></section>'
            f'<section id="compare"><h2>Pontos fortes, fracos e riscos</h2>{sw_tbl}</section>'
            f'<section id="recommendation"><h2>Recomendação</h2><div class="rec">{rec}</div></section>'
            f'<section id="checks"><h2>Verificações automáticas</h2><p class="lead">Resultado completo em <a href="verification.md">verification.md</a>. Ao regerar os materiais, rode <code>python3 docs/design/identity/build/verify.py</code>.</p></section></main></html>')
    (OUT).mkdir(parents=True, exist_ok=True); (OUT / 'index.html').write_text(html)
    (OUT / 'png').mkdir(exist_ok=True)
    jobs = [dict(type='element', url=str(OUT / 'index.html'), selector=f'#{s}', out=str(OUT / 'png' / f'{n}.png'), scale=1, css='nav{display:none!important}') for s, n in (('logos', '01-logotipos'), ('icons', '02-icones'), ('palettes', '03-paletas'), ('home', '04-home-claro-escuro'), ('explore', '05-explorar-claro-escuro'), ('responsive', '06-tablet-desktop'), ('states', '07-estados'), ('compare', '08-pros-e-contras'), ('recommendation', '09-recomendacao'))]
    jf = BUILD / '.work' / 'cmp.json'; jf.write_text(json.dumps(jobs)); subprocess.run(['node', 'render.mjs', str(jf)], cwd=BUILD, check=True)

if __name__ == '__main__': build(); print('comparison ok')
