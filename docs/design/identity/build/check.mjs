// Layout checks on the rendered preview pages: horizontal overflow and touch-target sizes.
// Usage: node check.mjs out.json page1.html page2.html ...
import { chromium } from 'playwright-core';
import { writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
const [out, ...pages] = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || '/opt/pw-browsers/chromium', args: ['--no-sandbox'] });
const report = [];
for (const f of pages) {
  const page = await (await browser.newContext({ viewport: { width: 1400, height: 1000 } })).newPage();
  await page.goto(pathToFileURL(resolve(f)).href); await page.evaluate(() => document.fonts.ready);
  const r = await page.evaluate(() => {
    const res = { frames: 0, overflow: [], smallTargets: [], missingFonts: [] };
    for (const fr of document.querySelectorAll('.frame')) {
      res.frames++;
      const b = fr.getBoundingClientRect();
      for (const el of fr.querySelectorAll('*')) {
        if (el.closest('.nw') || el.closest('.deco') || el.closest('.hero')) continue;      // intentionally clipped rows / decorative art
        const e = el.getBoundingClientRect(); if (!e.width) continue;
        if (e.right > b.right + 1 || e.left < b.left - 1) res.overflow.push(`${fr.id}: <${el.tagName.toLowerCase()} class="${el.className && el.className.baseVal === undefined ? el.className : ''}">`);
      }
      for (const el of fr.querySelectorAll('.btn,.iconbtn,.nav a,.rail a,.field,.chip:not(.sm)')) {
        const e = el.getBoundingClientRect();
        if (e.height < 44 - 0.5 || e.width < 44 - 0.5) res.smallTargets.push(`${fr.id}: ${el.className} ${Math.round(e.width)}x${Math.round(e.height)}`);
      }
    }
    for (const fam of ['Sora', 'Manrope', 'Space Grotesk', 'Inter', 'JetBrains Mono']) if (![...document.fonts].some(ff => ff.family.replace(/['"]/g, '') === fam && ff.status === 'loaded')) res.missingFonts.push(fam);
    return res;
  });
  report.push({ page: f, ...r });
}
await browser.close();
writeFileSync(out, JSON.stringify(report, null, 2));
for (const r of report) console.log(r.page.split('/').slice(-2)[0], 'frames', r.frames, 'overflow', r.overflow.length, 'smallTargets', r.smallTargets.length, 'fontsNotLoadedHere', r.missingFonts.join(',') || '-');
