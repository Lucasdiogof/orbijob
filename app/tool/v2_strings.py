#!/usr/bin/env python3
"""Adds OrbiJob 2.0 strings to the three ARB files (en, pt, es) without touching existing keys.

Usage: python tool/v2_strings.py tool/v2_strings_<batch>.json   (a JSON map: key -> {"en": ..., "pt": ..., "es": ...}).
Keys that already exist are skipped, so the script is safe to run again. Run `flutter gen-l10n` afterwards.
"""
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent / 'lib' / 'l10n'
batch = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))

for lang in ('en', 'pt', 'es'):
    p = root / f'app_{lang}.arb'
    data = json.loads(p.read_text(encoding='utf-8'))
    added = 0
    for key, texts in batch.items():
        if key in data:
            continue
        meta = texts.get('_meta')
        data[key] = texts[lang]
        if meta:
            data['@' + key] = meta
        added += 1
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(lang, 'added', added)
