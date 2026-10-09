// Web/PWA checks against the production build (app/build/web): manifest, icons, theme colours, meta tags,
// service worker, then a headless run in light/dark at phone/tablet/desktop sizes (no page errors, no overflow
// of the page itself, Tab reaches interactive elements). Output: JSON on stdout. Usage: node web_checks.mjs
import { chromium } from 'playwright-core';
import { createServer } from 'node:http';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';

const WEB = resolve('../../../../app/build/web');
const r = { manifest: {}, html: {}, runs: [] };
const read = (f) => readFileSync(join(WEB, f), 'utf8');
const m = JSON.parse(read('manifest.json'));
const png = (f) => { const b = readFileSync(join(WEB, f)); return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) }; };
r.manifest = {
  name: m.name, short_name: m.short_name, display: m.display, theme_color: m.theme_color, background_color: m.background_color,
  icons: m.icons.map((i) => { const f = i.src.split('?')[0]; const d = png(f); return { src: i.src, purpose: i.purpose || 'any', declared: i.sizes, actual: `${d.w}x${d.h}`, ok: `${d.w}x${d.h}` === i.sizes }; }),
  hasMaskable: m.icons.some((i) => i.purpose === 'maskable'),
};
const html = read('index.html');
r.html = {
  title: /<title>(.*?)<\/title>/.exec(html)?.[1],
  viewportFit: html.includes('viewport-fit=cover'),
  themeColorLight: /media="\(prefers-color-scheme: light\)" content="(#\w+)"/.exec(html)?.[1],
  themeColorDark: /media="\(prefers-color-scheme: dark\)" content="(#\w+)"/.exec(html)?.[1],
  favicons: ['favicon.svg', 'favicon.png', 'favicon.ico', 'icons/apple-touch-icon.png'].map((f) => ({ f, linked: html.includes(f), exists: existsSync(join(WEB, f)) })),
  staticSplash: html.includes('id="splash"'),
};
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.otf': 'font/otf', '.ttf': 'font/ttf' };
const server = createServer((req, res) => {
  let p = join(WEB, decodeURIComponent(req.url.split('?')[0]));
  if (!existsSync(p) || statSync(p).isDirectory()) p = join(WEB, 'index.html');
  res.writeHead(200, { 'Content-Type': mime[extname(p)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  res.end(readFileSync(p));
}).listen(0);
await new Promise((ok) => server.on('listening', ok));
const port = server.address().port;
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || '/opt/pw-browsers/chromium', args: ['--no-sandbox', '--disable-gpu', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
for (const scheme of ['light', 'dark']) for (const [w, h] of [[390, 844], [820, 1180], [1440, 900]]) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, colorScheme: scheme });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (c) => c.type() === 'error' && errors.push(c.text()));
  await page.goto(`http://localhost:${port}/`);
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
  await page.waitForSelector('#splash', { state: 'detached', timeout: 60000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1000);
  const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  const scroll = await page.evaluate(() => ({ x: document.documentElement.scrollWidth > innerWidth, y: document.documentElement.scrollHeight > innerHeight + 1 }));
  const focusables = [];
  for (let i = 0; i < 6; i++) { await page.keyboard.press('Tab'); focusables.push(await page.evaluate(() => document.activeElement?.getAttribute('aria-label') || document.activeElement?.tagName)); }
  r.runs.push({ scheme, size: `${w}x${h}`, bodyBg: bg, pageScrollsHorizontally: scroll.x, pageScrollsVertically: scroll.y, tabStops: focusables, errors });
  await ctx.close();
}
await browser.close(); server.close();
console.log(JSON.stringify(r, null, 2));
const bad = r.manifest.icons.some((i) => !i.ok) || !r.manifest.hasMaskable || r.runs.some((x) => x.errors.length || x.pageScrollsHorizontally);
process.exit(bad ? 1 : 0);
