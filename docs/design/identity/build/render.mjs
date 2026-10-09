// Usage: node render.mjs jobs.json   (jobs: [{type:'element'|'svg'|'page', ...}])
// element: {url, selector, out, scale}  -> screenshot of one element
// svg:     {file, out, width, height, bg?} -> vector rendered NATIVELY at width x height (scale 1; never upscaled)
// page:    {url, out, width, height, scale, fullPage?}
import { chromium } from 'playwright-core';
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const jobs = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const exe = process.env.CHROMIUM || '/opt/pw-browsers/chromium';
const browser = await chromium.launch({ executablePath: exe, args: ['--no-sandbox', '--disable-gpu'] });
const urlOf = (p) => (p.startsWith('http') ? p : pathToFileURL(resolve(p)).href);
let n = 0;
for (const j of jobs) {
  if (j.type === 'element') {
    const ctx = await browser.newContext({ deviceScaleFactor: j.scale || 1, viewport: { width: 1400, height: 1000 } });
    const page = await ctx.newPage();
    await page.goto(urlOf(j.url)); await page.evaluate(() => document.fonts.ready);
    if (j.css) await page.addStyleTag({ content: j.css });
    await page.locator(j.selector).first().screenshot({ path: j.out, animations: 'disabled' });
    await ctx.close();
  } else if (j.type === 'svg') {
    const ctx = await browser.newContext({ deviceScaleFactor: 1, viewport: { width: j.width, height: j.height } });
    const page = await ctx.newPage();
    const svg = readFileSync(j.file, 'utf8');
    await page.setContent(`<html><body style="margin:0;background:${j.bg || 'transparent'}"><div style="width:${j.width}px;height:${j.height}px;display:flex;align-items:center;justify-content:center">${svg.replace('<svg ', `<svg width="${j.svgWidth || j.width}" height="${j.svgHeight || j.height}" `)}</div></body></html>`);
    await page.screenshot({ path: j.out, omitBackground: !j.bg });
    await ctx.close();
  } else {
    const ctx = await browser.newContext({ deviceScaleFactor: j.scale || 1, viewport: { width: j.width, height: j.height } });
    const page = await ctx.newPage();
    await page.goto(urlOf(j.url)); await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: j.out, fullPage: !!j.fullPage });
    await ctx.close();
  }
  n++;
}
await browser.close();
console.log('rendered', n);
