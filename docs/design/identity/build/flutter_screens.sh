#!/usr/bin/env bash
# Builds the real Flutter web app (production + preview entrypoints) and captures real screenshots with headless Chromium.
# Needs: flutter on PATH, node deps installed here (npm i), CHROMIUM (default /opt/pw-browsers/chromium), python3 + pillow.
set -euo pipefail
cd "$(dirname "$0")"
APP=../../../../app
OUT=../../flutter-screenshots
( cd "$APP" && flutter build web --release --no-web-resources-cdn && flutter build web --release --no-web-resources-cdn -t lib/main_preview.dart --output build/web_preview )
rm -rf "$OUT"; node flutter_screenshots.mjs "$OUT"
python3 - "$OUT" <<'PY'
import sys, pathlib
from PIL import Image
before = after = 0
for f in sorted(pathlib.Path(sys.argv[1]).glob('*.png')):
    before += f.stat().st_size
    Image.open(f).convert('RGB').quantize(colors=256, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).save(f, optimize=True)
    after += f.stat().st_size
print(f'screenshots: {before/1e6:.1f} MB -> {after/1e6:.1f} MB')
PY
