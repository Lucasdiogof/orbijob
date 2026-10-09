#!/usr/bin/env python3
"""Generates the DEFINITIVE identity-C assets for the Flutter app (single pipeline, no hand-edited copies):
  docs/design/identity/c-minimal/symbol-*.svg           isolated symbol (official)
  app/assets/brand/*.svg                                 byte-identical copies used by the app (a test enforces it)
  app/assets/fonts/*.ttf + licences                      Space Grotesk, Inter, JetBrains Mono (OFL), converted from the woff2 packages
  app/android/.../res                                    launcher (legacy + adaptive + monochrome), splash (API 21-30 and 31+)
  app/ios/Runner/Assets.xcassets                         AppIcon (opaque), LaunchImage (+dark), LaunchBackground colour
  app/web                                                favicon, icons, maskable, apple-touch-icon
Usage: python3 apply_c.py
"""
import json, math, pathlib, shutil, subprocess
from PIL import Image
from fontTools.ttLib import TTFont
import brand

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[3]                   # repo root
C = ROOT / 'docs' / 'design' / 'identity' / 'c-minimal'
APP = ROOT / 'app'
FONTS_SRC = ROOT / 'docs' / 'design' / 'fonts'
WORK = HERE / '.work' / 'apply'; WORK.mkdir(parents=True, exist_ok=True)
K = 'c-minimal'
P = brand.PALETTES[K]
INK_L, INK_D, VIO_L, VIO_D = P['light']['ink'], P['dark']['ink'], P['light']['primary'], P['dark']['primary']

def w(path, text): path.parent.mkdir(parents=True, exist_ok=True); path.write_text(text)

# ───────── geometry shared with brand.glyph_c (non-small variant) ─────────
R, SW, G, DOT = 31, 13, 9, 9
def arc_path(a, b):
    pa = (50 + R * math.cos(math.radians(a)), 50 + R * math.sin(math.radians(a)))
    pb = (50 + R * math.cos(math.radians(b)), 50 + R * math.sin(math.radians(b)))
    return f'M{pa[0]:.2f},{pa[1]:.2f}A{R},{R} 0 0 1 {pb[0]:.2f},{pb[1]:.2f}'
ARCS = [arc_path(-45 + G, 135 - G), arc_path(135 + G, 315 - G)]
DOT_PATH = f'M{50 - DOT},50a{DOT},{DOT} 0 1,0 {2 * DOT},0a{DOT},{DOT} 0 1,0 {-2 * DOT},0z'

def symbol_svg(arc, dot):
    # viewBox trimmed to the symbol (outer radius 37.5) + 4.5 units of breathing room
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="8 8 84 84" role="img" aria-label="OrbiJob">'
            + brand.glyph_svg(K, 'light').replace(INK_L, arc).replace(VIO_L, dot) + '</svg>\n')

def tile(shape, scale, bg_a, bg_b, arc, dot, radius=0):
    gid = 'bg'
    fill = f'url(#{gid})' if bg_b else bg_a
    defs = f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{bg_a}"/><stop offset="1" stop-color="{bg_b}"/></linearGradient></defs>' if bg_b else ''
    off = (100 - 100 * scale) / 2
    body = brand.glyph_svg(K, 'light').replace(INK_L, arc).replace(VIO_L, dot)
    bgshape = (f'<circle cx="50" cy="50" r="50" fill="{fill}"/>' if shape == 'circle' else f'<rect width="100" height="100" rx="{radius}" fill="{fill}"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">{defs}{bgshape}<g transform="translate({off:.2f} {off:.2f}) scale({scale})">{body}</g></svg>\n'

# ───────── 1. official symbol SVGs + app copies ─────────
def brand_svgs():
    sym = {'light': (INK_L, VIO_L), 'dark': (INK_D, VIO_D), 'mono-black': ('#000000', '#000000'), 'mono-white': ('#FFFFFF', '#FFFFFF')}
    for v, (a, d) in sym.items(): w(C / f'symbol-{v}.svg', symbol_svg(a, d))
    out = APP / 'assets' / 'brand'; out.mkdir(parents=True, exist_ok=True)
    for f in [f'logo-horizontal-{v}.svg' for v in ('light', 'dark', 'mono-black', 'mono-white')] + [f'symbol-{v}.svg' for v in sym]:
        shutil.copyfile(C / f, out / f)
    print('brand svgs ok')

# ───────── 2. fonts: woff2 (OFL, latin) -> ttf for Flutter ─────────
FONT_SET = [('space-grotesk', 'SpaceGrotesk', [500, 600, 700]), ('inter', 'Inter', [400, 500, 600, 700]), ('jetbrains-mono', 'JetBrainsMono', [500])]
def fonts():
    out = APP / 'assets' / 'fonts'; out.mkdir(parents=True, exist_ok=True)
    for slug, name, weights in FONT_SET:
        for wt in weights:
            f = TTFont(FONTS_SRC / f'{slug}-latin-{wt}-normal.woff2'); f.flavor = None
            f.save(out / f'{name}-{wt}.ttf')
        shutil.copyfile(FONTS_SRC / f'LICENSE-{slug}.txt', out / f'OFL-{name}.txt')
    print('fonts ok', sum(p.stat().st_size for p in out.glob('*.ttf')) // 1024, 'KB')

# ───────── 3. platform SVG sources + native-size PNGs ─────────
jobs = []
def png(svg_text, out, size, name):
    f = WORK / f'{name}.svg'; f.write_text(svg_text)
    out.parent.mkdir(parents=True, exist_ok=True)
    jobs.append(dict(type='svg', file=str(f), out=str(out), width=size, height=size, svgWidth=size, svgHeight=size))

def platform_pngs():
    t0, t1 = P['dark']['bg'], '#17171B'
    store = tile('square', .70, '#17171B', '#0C0C0E', '#FFFFFF', '#8B6CFF')                 # iOS / marketing: full-bleed, opaque
    # Android legacy launcher (API < 26): rounded square + round
    for dens, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        res = APP / 'android/app/src/main/res' / f'mipmap-{dens}'
        png(tile('square', .70, '#17171B', '#0C0C0E', '#FFFFFF', '#8B6CFF', radius=22.5), res / 'ic_launcher.png', px, f'and-{dens}')
        png(tile('circle', .62, '#17171B', '#0C0C0E', '#FFFFFF', '#8B6CFF'), res / 'ic_launcher_round.png', px, f'and-r-{dens}')
    # iOS AppIcon
    ios = APP / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for name in [p.name for p in ios.glob('Icon-App-*.png')]:
        base = name.split('Icon-App-')[1].split('.png')[0]; size, scale = base.split('@'); px = round(float(size.split('x')[0]) * int(scale[0]))
        png(store, ios / name, px, f'ios-{base}')
    # iOS launch symbol (transparent), 96 pt: light/dark
    li = APP / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    for sc in (1, 2, 3):
        suffix = '' if sc == 1 else f'@{sc}x'
        png(symbol_svg(INK_L, VIO_L), li / f'LaunchImage{suffix}.png', 96 * sc, f'ios-li-{sc}')
        png(symbol_svg(INK_D, VIO_D), li / f'LaunchImageDark{suffix}.png', 96 * sc, f'ios-lid-{sc}')
    # Web
    web = APP / 'web'
    fav_small = brand.icon_svg(K, 'app', small=True)
    png(fav_small, web / 'favicon.png', 32, 'web-fav32')
    png(brand.icon_svg(K, 'app'), web / 'icons/Icon-192.png', 192, 'web-192')
    png(brand.icon_svg(K, 'app'), web / 'icons/Icon-512.png', 512, 'web-512')
    mask = tile('square', .62, '#17171B', '#0C0C0E', '#FFFFFF', '#8B6CFF')                # maskable: full-bleed, symbol inside the 80% safe zone
    png(mask, web / 'icons/Icon-maskable-192.png', 192, 'web-m192'); png(mask, web / 'icons/Icon-maskable-512.png', 512, 'web-m512')
    png(store, web / 'icons/apple-touch-icon.png', 180, 'web-apple')                     # opaque, iOS applies its own mask
    for s in (16, 32, 48): png(brand.icon_svg(K, 'app', small=True) if s <= 32 else brand.icon_svg(K, 'app'), WORK / f'fav-{s}.png', s, f'fav-{s}')
    w(web / 'favicon.svg', fav_small)
    (WORK / 'jobs.json').write_text(json.dumps(jobs))
    subprocess.run(['node', 'render.mjs', str(WORK / 'jobs.json')], cwd=HERE, check=True)
    # iOS icons must be opaque RGB
    for f in ios.glob('Icon-App-*.png'):
        im = Image.open(f); bg = Image.new('RGB', im.size, (12, 12, 14)); bg.paste(im, mask=im.getchannel('A') if im.mode == 'RGBA' else None); bg.save(f, optimize=True)
    # favicon.ico from native 16/32/48 renders
    import io, struct
    imgs = [Image.open(WORK / f'fav-{s}.png').convert('RGBA') for s in (16, 32, 48)]
    entries, blobs, off = b'', b'', 6 + 16 * len(imgs)
    for im in imgs:
        buf = io.BytesIO(); im.save(buf, 'PNG'); b = buf.getvalue()
        entries += struct.pack('<BBBBHHII', im.width % 256, im.height % 256, 0, 0, 1, 32, len(b), off + len(blobs)); blobs += b
    (web / 'favicon.ico').write_bytes(struct.pack('<HHH', 0, 1, len(imgs)) + entries + blobs)
    print('platform pngs ok', len(jobs))

# ───────── 4. Android XML (vector adaptive icon, monochrome, splash) ─────────
def android():
    res = APP / 'android/app/src/main/res'
    def vector(name, arc, dot, scale, dp=108, folder='drawable'):
        body = ''.join(f'<path android:pathData="{a}" android:strokeColor="{arc}" android:strokeWidth="{SW}" android:fillColor="#00000000"/>' for a in ARCS)
        body += f'<path android:pathData="{DOT_PATH}" android:fillColor="{dot}"/>'
        xml = (f'<?xml version="1.0" encoding="utf-8"?>\n<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="{dp}dp" android:height="{dp}dp" android:viewportWidth="100" android:viewportHeight="100">\n'
               f'  <group android:pivotX="50" android:pivotY="50" android:scaleX="{scale}" android:scaleY="{scale}">\n    {body.replace("<path", chr(10) + "    <path")}\n  </group>\n</vector>\n')
        w(res / folder / f'{name}.xml', xml)
    # Adaptive launcher: 108dp canvas, 66dp safe circle -> glyph radius 37.5*scale*1.08 <= 33 (scale 0.70 keeps 14% margin inside the safe circle)
    vector('ic_launcher_foreground', '#FFFFFF', '#8B6CFF', 0.70)
    vector('ic_launcher_monochrome', '#000000', '#000000', 0.70)
    w(res / 'values/ic_launcher_colors.xml', '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#111113</color>\n    <color name="splash_background">#FFFFFF</color>\n</resources>\n')
    w(res / 'values-night/ic_launcher_colors.xml', '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="splash_background">#0C0C0E</color>\n</resources>\n')
    adaptive = lambda mono: ('<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                             '    <background android:drawable="@color/ic_launcher_background"/>\n    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
                             + ('    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n' if mono else '') + '</adaptive-icon>\n')
    for n in ('ic_launcher', 'ic_launcher_round'):
        w(res / 'mipmap-anydpi-v26' / f'{n}.xml', adaptive(False)); w(res / 'mipmap-anydpi-v33' / f'{n}.xml', adaptive(True))
    # Splash: symbol only, static. 96dp symbol for API < 31; Android 12+ icon canvas is 288dp with a 192dp visible circle.
    vector('splash_symbol', '#111113', '#5B3DF5', 1.0, dp=96)
    vector('splash_symbol', '#F4F4F6', '#A593FF', 1.0, dp=96, folder='drawable-night')
    vector('splash_icon', '#111113', '#5B3DF5', 0.62, dp=288)         # 37.5*0.62*2.88 = 67dp radius -> 134dp diameter < 192dp circle
    vector('splash_icon', '#F4F4F6', '#A593FF', 0.62, dp=288, folder='drawable-night')
    layer = ('<?xml version="1.0" encoding="utf-8"?>\n<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
             '    <item android:drawable="@color/splash_background"/>\n'
             '    <item android:width="96dp" android:height="96dp" android:gravity="center" android:drawable="@drawable/splash_symbol"/>\n</layer-list>\n')
    w(res / 'drawable/launch_background.xml', layer); w(res / 'drawable-v21/launch_background.xml', layer)
    styles = lambda parent, extra='': ('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <style name="LaunchTheme" parent="{parent}">\n        <item name="android:windowBackground">@drawable/launch_background</item>\n{extra}    </style>\n'
        f'    <style name="NormalTheme" parent="{parent}">\n        <item name="android:windowBackground">@color/splash_background</item>\n    </style>\n</resources>\n')
    w(res / 'values/styles.xml', styles('@android:style/Theme.Light.NoTitleBar'))
    w(res / 'values-night/styles.xml', styles('@android:style/Theme.Black.NoTitleBar'))
    v31 = lambda parent: styles(parent, '        <item name="android:windowSplashScreenBackground">@color/splash_background</item>\n        <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>\n        <item name="android:windowSplashScreenAnimationDuration">0</item>\n')
    w(res / 'values-v31/styles.xml', v31('@android:style/Theme.Light.NoTitleBar')); w(res / 'values-night-v31/styles.xml', v31('@android:style/Theme.Black.NoTitleBar'))
    man = APP / 'android/app/src/main/AndroidManifest.xml'; t = man.read_text()
    if 'android:roundIcon' not in t: t = t.replace('android:icon="@mipmap/ic_launcher">', 'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round">'); man.write_text(t)
    print('android xml ok')

# ───────── 5. iOS metadata (LaunchImage dark variants, named colour, storyboard) ─────────
def ios():
    xc = APP / 'ios/Runner/Assets.xcassets'
    imgs = []
    for sc in (1, 2, 3):
        suffix = '' if sc == 1 else f'@{sc}x'
        imgs.append({'idiom': 'universal', 'filename': f'LaunchImage{suffix}.png', 'scale': f'{sc}x'})
    for sc in (1, 2, 3):
        suffix = '' if sc == 1 else f'@{sc}x'
        imgs.append({'idiom': 'universal', 'appearances': [{'appearance': 'luminosity', 'value': 'dark'}], 'filename': f'LaunchImageDark{suffix}.png', 'scale': f'{sc}x'})
    w(xc / 'LaunchImage.imageset/Contents.json', json.dumps({'images': imgs, 'info': {'version': 1, 'author': 'xcode'}}, indent=2) + '\n')
    comp = lambda r, g, b: {'color-space': 'srgb', 'components': {'red': f'0x{r:02X}', 'green': f'0x{g:02X}', 'blue': f'0x{b:02X}', 'alpha': '1.000'}}
    cs = {'colors': [{'idiom': 'universal', 'color': comp(255, 255, 255)},
                     {'idiom': 'universal', 'appearances': [{'appearance': 'luminosity', 'value': 'dark'}], 'color': comp(12, 12, 14)}],
          'info': {'version': 1, 'author': 'xcode'}}
    w(xc / 'LaunchBackground.colorset/Contents.json', json.dumps(cs, indent=2) + '\n')
    sb = APP / 'ios/Runner/Base.lproj/LaunchScreen.storyboard'
    sb.write_text('''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="13122.16" systemVersion="17A277" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="13104.12"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="Named colors" minToolsVersion="9.0"/>
    </dependencies>
    <scenes>
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="375" height="667"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView userInteractionEnabled="NO" contentMode="center" horizontalHuggingPriority="251" verticalHuggingPriority="251" image="LaunchImage" translatesAutoresizingMaskIntoConstraints="NO" id="YRO-k0-Ey4" accessibilityElementsHidden="YES">
                            </imageView>
                        </subviews>
                        <color key="backgroundColor" name="LaunchBackground"/>
                        <constraints>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="1a2-6s-vTC"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="4X2-HB-R7a"/>
                        </constraints>
                        <viewLayoutGuide key="safeArea" id="Bcu-3y-fUS"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="LaunchImage" width="96" height="96"/>
        <namedColor name="LaunchBackground">
            <color red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
        </namedColor>
    </resources>
</document>
''')
    print('ios metadata ok')

# ───────── 6. web manifest + index ─────────
def web():
    web = APP / 'web'
    m = {'id': '/', 'name': 'OrbiJob', 'short_name': 'OrbiJob', 'description': 'OrbiJob by Lucksrei — busca inteligente de oportunidades profissionais em qualquer lugar do mundo.',
         'lang': 'pt-BR', 'start_url': '.', 'scope': '.', 'display': 'standalone', 'orientation': 'any', 'background_color': '#FFFFFF', 'theme_color': '#111113',
         'categories': ['business', 'productivity'], 'prefer_related_applications': False,
         'icons': [{'src': 'icons/Icon-192.png?v=c1', 'sizes': '192x192', 'type': 'image/png'}, {'src': 'icons/Icon-512.png?v=c1', 'sizes': '512x512', 'type': 'image/png'},
                   {'src': 'icons/Icon-maskable-192.png?v=c1', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'maskable'},
                   {'src': 'icons/Icon-maskable-512.png?v=c1', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'maskable'}]}
    w(web / 'manifest.json', json.dumps(m, indent=2, ensure_ascii=False) + '\n')
    sym_l = symbol_svg(INK_L, VIO_L).replace('<svg ', '<svg class="s" ', 1).replace(' role="img" aria-label="OrbiJob"', ' aria-hidden="true"')
    sym_d = symbol_svg(INK_D, VIO_D).replace('<svg ', '<svg class="s d" ', 1).replace(' role="img" aria-label="OrbiJob"', ' aria-hidden="true"')
    w(web / 'index.html', f'''<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="description" content="OrbiJob by Lucksrei: busca inteligente de oportunidades profissionais em qualquer lugar do mundo.">
  <meta name="color-scheme" content="light dark">
  <meta name="theme-color" media="(prefers-color-scheme: light)" content="#FFFFFF">
  <meta name="theme-color" media="(prefers-color-scheme: dark)" content="#0C0C0E">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="default">
  <meta name="apple-mobile-web-app-title" content="OrbiJob">
  <meta name="application-name" content="OrbiJob">
  <meta name="author" content="Lucksrei">
  <!-- ?v= busts browser/favicon caches when the identity changes (Flutter 3.47's service worker does not cache assets). -->
  <link rel="icon" type="image/svg+xml" href="favicon.svg?v=c1">
  <link rel="icon" type="image/png" sizes="32x32" href="favicon.png?v=c1">
  <link rel="icon" href="favicon.ico?v=c1" sizes="any">
  <link rel="apple-touch-icon" href="icons/apple-touch-icon.png?v=c1">
  <link rel="manifest" href="manifest.json?v=c1">
  <title>OrbiJob</title>
  <style>
    html,body{{margin:0;height:100%;background:#FFFFFF}}
    #splash{{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;background:#FFFFFF}}
    #splash .s{{width:96px;height:96px}} #splash .d{{display:none}}
    @media (prefers-color-scheme: dark){{html,body,#splash{{background:#0C0C0E}} #splash .s{{display:none}} #splash .d{{display:block}}}}
  </style>
</head>
<body>
  <!-- Static splash (no animation, so nothing to reduce): removed on the first Flutter frame. -->
  <div id="splash" role="img" aria-label="OrbiJob">{sym_l}{sym_d}</div>
  <noscript>OrbiJob precisa de JavaScript habilitado. / OrbiJob needs JavaScript enabled.</noscript>
  <script>
    window.addEventListener('flutter-first-frame', function () {{
      var s = document.getElementById('splash'); if (s) s.remove();
    }});
  </script>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''')
    print('web ok')

if __name__ == '__main__':
    brand_svgs(); fonts(); platform_pngs(); android(); ios(); web()
    import dart_tokens; dart_tokens.DST.parent.mkdir(parents=True, exist_ok=True); dart_tokens.DST.write_text(dart_tokens.render()); print('dart tokens ok')
