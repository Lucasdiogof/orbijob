#!/usr/bin/env python3
"""Evidence images for the applied identity C: Android adaptive icon under different launcher masks (with the 66dp safe zone),
and the full icon set at native sizes. Output: docs/design/identity/c-minimal/applied/."""
import json, math, pathlib, subprocess
from PIL import Image
import apply_c, brand

HERE = pathlib.Path(__file__).resolve().parent
OUT = apply_c.C / 'applied'; OUT.mkdir(exist_ok=True)
W = HERE / '.work' / 'applied'; W.mkdir(parents=True, exist_ok=True)
APP = apply_c.APP

def adaptive(mask, mono=False, guides=False):
    arc, dot = ('#000000', '#000000') if mono else ('#FFFFFF', '#8B6CFF')
    bg = '#E7E7EC' if mono else '#111113'
    fg = ''.join(f'<path d="{a}" stroke="{arc}" stroke-width="13" fill="none"/>' for a in apply_c.ARCS) + f'<path d="{apply_c.DOT_PATH}" fill="{dot}"/>'
    clip = {'circle': '<circle cx="54" cy="54" r="33"/>', 'squircle': '<rect x="21" y="21" width="66" height="66" rx="24"/>', 'rounded': '<rect x="21" y="21" width="66" height="66" rx="12"/>', 'square': '<rect x="21" y="21" width="66" height="66"/>'}[mask]
    g = '<circle cx="54" cy="54" r="33" fill="none" stroke="#FF3B30" stroke-width=".6" stroke-dasharray="2 2"/>' if guides else ''
    # canvas 108dp; symbol viewport 100 -> 108 (scale 1.08) and group scale .80 around the centre, as in the vector drawable
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><defs><clipPath id="c">{clip}</clipPath></defs>'
            f'<rect width="108" height="108" fill="#d8d8de"/><g clip-path="url(#c)"><rect width="108" height="108" fill="{bg}"/>'
            f'<g transform="scale(1.08)"><g transform="translate(50 50) scale(.70) translate(-50 -50)">{fg}</g></g></g>{g}</svg>')

def main():
    jobs, files = [], []
    for i, (mask, mono) in enumerate([('circle', False), ('squircle', False), ('rounded', False), ('square', False), ('circle', True), ('squircle', True)]):
        f = W / f'm{i}.svg'; f.write_text(adaptive(mask, mono, guides=True)); files.append(W / f'm{i}.png')
        jobs.append(dict(type='svg', file=str(f), out=str(W / f'm{i}.png'), width=216, height=216, svgWidth=216, svgHeight=216))
    # Android 12+ splash (288dp canvas, 192dp visible circle)
    sp = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 288 288"><rect width="288" height="288" fill="#FFFFFF"/><circle cx="144" cy="144" r="96" fill="none" stroke="#FF3B30" stroke-width="1" stroke-dasharray="3 3"/>'
          f'<g transform="scale(2.88)"><g transform="translate(50 50) scale(.62) translate(-50 -50)">' + ''.join(f'<path d="{a}" stroke="#111113" stroke-width="13" fill="none"/>' for a in apply_c.ARCS) + f'<path d="{apply_c.DOT_PATH}" fill="#5B3DF5"/></g></g></svg>')
    (W / 'splash.svg').write_text(sp)
    jobs.append(dict(type='svg', file=str(W / 'splash.svg'), out=str(W / 'splash.png'), width=216, height=216, svgWidth=216, svgHeight=216))
    (W / 'jobs.json').write_text(json.dumps(jobs)); subprocess.run(['node', 'render.mjs', str(W / 'jobs.json')], cwd=HERE, check=True)
    ims = [Image.open(W / f'm{i}.png').convert('RGB') for i in range(6)] + [Image.open(W / 'splash.png').convert('RGB')]
    sheet = Image.new('RGB', (7 * 232 + 16, 240 + 16), (245, 245, 247))
    for i, im in enumerate(ims): sheet.paste(im, (16 + i * 232, 16))
    sheet.save(OUT / 'android-adaptive-masks.png', optimize=True)
    # native-size icon matrix (nothing is scaled up; the 1024 marketing icon is shown at 256 by downscaling)
    tiles = [('iOS 1024 (shown 256)', APP / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'), ('iOS 180', APP / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png'),
             ('Android xxxhdpi 192', APP / 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'), ('Android round 192', APP / 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png'),
             ('Web 192', APP / 'web/icons/Icon-192.png'), ('Web maskable 192', APP / 'web/icons/Icon-maskable-192.png'), ('Android hdpi 72', APP / 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png'), ('favicon 32', APP / 'web/favicon.png')]
    S = Image.new('RGB', (8 * 216 + 16, 240), (233, 233, 238)); x = 16
    for _, p in tiles:
        im = Image.open(p).convert('RGBA')
        if im.width > 256: im = im.resize((200, 200), Image.LANCZOS)     # downscale only
        bg = Image.new('RGBA', im.size, (233, 233, 238, 255)); bg.alpha_composite(im); S.paste(bg.convert('RGB'), (x, 20 + (200 - im.height) // 2)); x += 216
    S.save(OUT / 'icon-set.png', optimize=True)
    print('applied previews ok')

main()
