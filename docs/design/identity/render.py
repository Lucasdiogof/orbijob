#!/usr/bin/env python3
"""Renders preview.html and logos to PNG using headless Chromium (headless_shell, path via $CHROMIUM)."""
import os, pathlib, subprocess
HERE = pathlib.Path(__file__).parent
CH = os.environ.get('CHROMIUM', '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell')
def shot(src, out, w, h):
    subprocess.run([CH, '--no-sandbox', '--disable-gpu', '--hide-scrollbars', f'--window-size={w},{h}', f'--screenshot={out}', f'file://{src}'], check=True, capture_output=True)
for d in sorted(p for p in HERE.iterdir() if p.is_dir()):
    shot(d / 'preview.html', d / 'preview.png', 1000, 1400)
    for mode in ('light', 'dark'):
        for n in (f'logo-horizontal-{mode}', f'icon-{mode}'):
            html = d / f'_{n}.html'; bg = '#fff' if mode == 'light' else '#111'
            html.write_text(f'<body style="margin:0;background:{bg}"><img src="{n}.svg" style="height:200px;display:block;margin:20px">')
            shot(html, d / f'{n}.png', 900 if 'logo' in n else 260, 240); html.unlink()
print('rendered')
