// Real screenshots of the Flutter web builds (not mockups): serves build/web (production, no fixtures) and
// build/web_preview (illustrative fixtures, banner pinned) and drives them with headless Chromium.
// Usage: node flutter_screenshots.mjs <outDir>
import { chromium } from 'playwright-core';
import { createServer } from 'node:http';
import { readFileSync, existsSync, statSync, mkdirSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';

const out = resolve(process.argv[2] || '../../flutter-screenshots');
mkdirSync(out, { recursive: true });
const APP = resolve('../../../../app/build');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.otf': 'font/otf', '.ttf': 'font/ttf', '.bin': 'application/octet-stream', '.txt': 'text/plain', '.symbols': 'text/plain' };
const serve = (dir) => new Promise((ok) => {
  const s = createServer((req, res) => {
    let p = join(dir, decodeURIComponent(req.url.split('?')[0]));
    if (!existsSync(p) || statSync(p).isDirectory()) p = join(dir, 'index.html');
    res.writeHead(200, { 'Content-Type': mime[extname(p)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(readFileSync(p));
  }).listen(0, () => ok({ s, port: s.address().port }));
});
const prod = await serve(join(APP, 'web')), prev = await serve(join(APP, 'web_preview'));
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || '/opt/pw-browsers/chromium', args: ['--no-sandbox', '--disable-gpu', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });

async function open({ port, w, h, scheme, dpr = 2, locale = 'en-US', query = '' }) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr, colorScheme: scheme, locale });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto(`http://localhost:${port}/${query}`);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
  await page.waitForSelector('#splash', { state: 'detached', timeout: 60000 }); // static splash is removed on the first Flutter frame
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1200);
  return { ctx, page, errors };
}
const shot = async (page, name) => { await page.waitForTimeout(500); await page.screenshot({ path: join(out, `${name}.png`) }); console.log('shot', name); };
const btn = (page, name) => page.getByRole('button', { name }).first();
async function search(page, q) {
  const box = page.getByRole('textbox').last();
  await box.click(); await page.keyboard.type(q); await page.keyboard.press('Enter');
  await page.waitForTimeout(1200);
}

for (const scheme of ['light', 'dark']) {
  const M = { w: 390, h: 844 };
  // 01 static web splash (main.dart.js blocked on purpose so the splash stays visible)
  {
    const ctx = await browser.newContext({ viewport: { width: M.w, height: M.h }, deviceScaleFactor: 2, colorScheme: scheme });
    const page = await ctx.newPage();
    await page.route('**/main.dart.js', (r) => r.abort());
    await page.goto(`http://localhost:${prod.port}/`); await page.waitForSelector('#splash'); await shot(page, `web-splash-${scheme}`); await ctx.close();
  }
  // production build (real flow: no fixtures)
  {
    const { ctx, page, errors } = await open({ port: prod.port, ...M, scheme });
    await shot(page, `prod-01-home-${scheme}`);
    await btn(page, 'Explore').click(); await page.waitForTimeout(600);
    await shot(page, `prod-02-explore-${scheme}`);
    await search(page, 'Pedreiro'); await shot(page, `prod-03-no-source-${scheme}`);
    await btn(page, 'Favorites').click(); await page.waitForTimeout(600); await shot(page, `prod-04-favorites-${scheme}`);
    await btn(page, 'Applications').click(); await page.waitForTimeout(600); await shot(page, `prod-05-applications-${scheme}`);
    await btn(page, 'Profile').click(); await page.waitForTimeout(800); await shot(page, `prod-06-profile-${scheme}`);
    if (errors.length) console.log('PAGE ERRORS (prod mobile)', errors);
    await ctx.close();
  }
  // preview build (illustrative fixtures)
  {
    const { ctx, page, errors } = await open({ port: prev.port, ...M, scheme });
    await shot(page, `preview-01-home-${scheme}`);
    await btn(page, 'Explore').click(); await page.waitForTimeout(600);
    await search(page, 'Health'); await shot(page, `preview-02-results-${scheme}`);
    await page.locator('[aria-label="Save job"]').first().click(); await page.waitForTimeout(400);
    await shot(page, `preview-03-results-favorited-${scheme}`);
    await page.locator('[aria-label*="Fisioterapeuta"]').first().click(); await page.waitForTimeout(900);
    await shot(page, `preview-04-detail-${scheme}`);
    await page.goBack().catch(() => {}); await page.keyboard.press('Escape'); await page.waitForTimeout(600);
    await btn(page, 'Favorites').click().catch(() => {}); await page.waitForTimeout(700);
    await shot(page, `preview-05-favorites-${scheme}`);
    if (errors.length) console.log('PAGE ERRORS (preview mobile)', errors);
    await ctx.close();
  }
  // states in preview: loading (delayed source) and empty (source answers, nothing matches)
  {
    const { ctx, page } = await open({ port: prev.port, ...M, scheme, query: '?delay=60000' });
    await btn(page, 'Explore').click(); await page.waitForTimeout(500); await search(page, 'Health'); await page.waitForTimeout(500);
    await shot(page, `preview-06-loading-${scheme}`); await ctx.close();
  }
  {
    const { ctx, page } = await open({ port: prev.port, ...M, scheme });
    await btn(page, 'Explore').click(); await page.waitForTimeout(500); await search(page, 'zzzz'); await shot(page, `preview-07-empty-${scheme}`); await ctx.close();
  }
  // tablet and desktop (rail / extended rail / master-detail)
  for (const [name, w, h] of [['tablet', 834, 1112], ['desktop', 1280, 800]]) {
    const { ctx, page, errors } = await open({ port: prev.port, w, h, scheme, dpr: 1 });
    await shot(page, `preview-${name}-home-${scheme}`);
    await btn(page, 'Explore').click(); await page.waitForTimeout(600);
    await search(page, 'Health');
    if (name === 'desktop') await page.locator('[aria-label*="Fisioterapeuta"]').first().click().catch(() => {});
    await shot(page, `preview-${name}-explore-${scheme}`);
    if (errors.length) console.log(`PAGE ERRORS (${name})`, errors);
    await ctx.close();
  }
}
// large text and Portuguese, narrow phone
{
  const { ctx, page } = await open({ port: prev.port, w: 360, h: 740, scheme: 'light', locale: 'pt-BR' });
  await btn(page, 'Explorar').click(); await page.waitForTimeout(500); await search(page, 'Saúde'); await shot(page, 'preview-pt-results-light'); await ctx.close();
}
await browser.close(); prod.s.close(); prev.s.close();
console.log('done');
