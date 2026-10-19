import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { HttpError } from '../src/http';
import { normalizeSineEs, sineEsConnector, usDay } from '../src/connectors/sinees';
import { SOURCES } from '../src/sources';

// Real data of the Espírito Santo open-data catalogue (read 2026-10-17): the CKAN package trimmed to three offices and a few rows of each CSV.
const NOW = '2026-10-17T12:00:00.000Z';
const nowFn = () => new Date(NOW);
const fx = (n: string) => readFileSync(new URL(`./fixtures/${n}`, import.meta.url), 'utf8');
const pkg = fx('sinees.package.json');
const csv: Record<string, string> = { 'vagas_cariacica.csv': fx('sinees.vagas_cariacica.csv'), 'vagas_aracruz.csv': fx('sinees.vagas_aracruz.csv'), 'vagas_guarapari.csv': fx('sinees.vagas_guarapari.csv'), 'vagas_colatina.csv': fx('sinees.vagas_colatina.csv') };
const routed = ((url: string | URL | Request) => {
  const u = String(url);
  if (u.includes('package_show')) return Promise.resolve(new Response(pkg, { status: 200, headers: { 'content-type': 'application/json' } }));
  const file = Object.keys(csv).find((k) => u.endsWith(k));
  return Promise.resolve(file ? new Response(csv[file], { status: 200 }) : new Response('', { status: 404 }));
}) as typeof fetch;
const ok = (r: ReturnType<typeof normalizeSineEs>) => { if (!r.ok) throw new Error(`expected a valid job, got ${JSON.stringify(r)}`); return r.job; };
const row = (o: Record<string, string> = {}) => ({ vaga: 'Cozinheiro geral', codigo: '9100001', descricao: 'Preparam alimentos.', qualificacao: 'Experiência na função', escolaridade: 'Ensino fundamental', quantidade: '2', atualizacao: '10/15/2026', posto: 'Cariacica', ...o });

describe('SINE-ES normalizer (real rows)', () => {
  it('maps a vacancy without inventing anything: Brazil, no employer, the state page that lists it, no date, no salary', () => {
    const j = ok(normalizeSineEs(row(), NOW));
    expect(j).toMatchObject({ source: 'sinees', country: 'BR', city: 'Cariacica, ES', company: '', language: 'pt', workMode: 'unspecified', status: 'open', lastCheckedAt: NOW, publishedAt: null, salaryMin: null, salaryCurrency: null, contractType: null, geoRestrictions: [] });
    expect(j.externalId).toBe('9100001');
    expect(j.originalUrl).toBe('https://setades.es.gov.br/vagas-de-empregos#/vaga/9100001');
    expect(j.applyUrl).toBe(j.originalUrl);
    expect(j.description).toBe(['Preparam alimentos.', '', 'Vagas: 2', 'Experiência/qualificação exigida: Experiência na função', 'Escolaridade exigida: Ensino fundamental', 'Posto de atendimento: Agência do Trabalhador de Cariacica (SINE-ES)', 'Atualizada em: 15/10/2026'].join('\n').replace('\n\n', '\n\n'));
  });

  it('an occupation code (CBO) in the code column is accepted only with its office and gets its own id; other malformed codes stay refused', () => {
    const j = ok(normalizeSineEs(row({ codigo: '5211-40', posto: 'São Mateus' }), NOW));
    expect(j.externalId).toBe('cbo-5211-40-sao-mateus');
    expect(j.description).toContain('Código da ocupação (CBO): 5211-40');
    expect(normalizeSineEs(row({ codigo: '5211-40', posto: '' }), NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeSineEs(row({ codigo: '52111-40', posto: 'Colatina' }), NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeSineEs(row({ codigo: '', posto: 'Colatina' }), NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
  });

  it('a blank quantity counts as one position (as the SETADES page says), zero or text is refused', () => {
    expect(ok(normalizeSineEs(row({ quantidade: '' }), NOW)).description).toContain('Vagas: 1');
    expect(ok(normalizeSineEs(row({ quantidade: '03' }), NOW)).description).toContain('Vagas: 3');
    expect(normalizeSineEs(row({ quantidade: '0' }), NOW)).toMatchObject({ ok: false, reason: 'no_positions' });
    expect(normalizeSineEs(row({ quantidade: 'muitas' }), NOW)).toMatchObject({ ok: false, reason: 'no_positions' });
  });

  it('refuses what cannot be shown honestly, with the reason', () => {
    expect(normalizeSineEs(null, NOW)).toMatchObject({ ok: false, reason: 'not_an_object' });
    expect(normalizeSineEs(row({ codigo: 'abc' }), NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeSineEs(row({ codigo: '12' }), NOW)).toMatchObject({ ok: false, reason: 'invalid_id' });
    expect(normalizeSineEs(row({ vaga: '  ' }), NOW)).toMatchObject({ ok: false, reason: 'missing_title', externalId: '9100001' });
    expect(normalizeSineEs(row({ atualizacao: '15/10/2026' }), NOW)).toMatchObject({ ok: false, reason: 'invalid_date' });
    expect(normalizeSineEs(row({ atualizacao: '13/45/2026' }), NOW)).toMatchObject({ ok: false, reason: 'invalid_date' });
  });

  it('a record not updated for more than 21 days is stale; one updated 20 days ago is not', () => {
    expect(normalizeSineEs(row({ atualizacao: '09/15/2026' }), NOW)).toMatchObject({ ok: false, reason: 'stale' });
    expect(normalizeSineEs(row({ atualizacao: '09/27/2026' }), NOW).ok).toBe(true);
  });

  it('filler fields ("************") are not shown, and free text keeps its line breaks and typos as the office wrote them', () => {
    const j = ok(normalizeSineEs(row({ escolaridade: '************', qualificacao: 'Sem Experiencai' }), NOW));
    expect(j.description).not.toContain('Escolaridade');
    expect(j.description).not.toContain('*');
    expect(j.description).toContain('Experiência/qualificação exigida: Sem Experiencai');
  });

  it('dates: MM/DD/YYYY only, real days only', () => {
    expect(usDay('10/15/2026')).toBe('2026-10-15');
    expect(usDay('1/5/2026')).toBe('2026-01-05');
    expect(usDay('15/10/2026')).toBe('');
    expect(usDay('02/30/2026')).toBe('');
    expect(usDay('')).toBe('');
  });
});

describe('SINE-ES connector', () => {
  it('reads the CKAN package, then every office CSV; the old record is dropped quietly, nothing is reported as a defect', async () => {
    const calls: string[] = [];
    const f = ((u: string | URL | Request) => { calls.push(String(u)); return routed(u); }) as typeof fetch;
    const c = sineEsConnector(f, nowFn);
    expect(c.presenceConfirmsOpen).toBe(true);
    const page = await c.fetchPage(null, 'discover');
    expect(calls).toHaveLength(5);
    expect(calls[0]).toBe('https://dados.es.gov.br/api/3/action/package_show?id=c43d6653-634a-4e6e-bd66-c9ca3f6ee106');
    expect(page.jobs).toHaveLength(15); // 16 rows, one older than 21 days
    expect(page.nextCursor).toBeNull();
    expect(page.rejected).toEqual([]);
    const byCode = new Map(page.jobs.map((j) => [j.externalId, j]));
    expect(byCode.get('9019403')).toMatchObject({ title: 'Açougueiro desossador', city: 'Cariacica, ES' });
    expect(byCode.get('9284915')).toMatchObject({ title: 'Acessor de Clientes', city: 'Aracruz, ES' });
    expect(byCode.has('9223447')).toBe(false); // the 09/15 record
    // Colatina writes the CBO occupation code where the others write the vacancy code: the id says so and the listing shows it as an occupation code
    const colatina = byCode.get('cbo-7170-20-colatina')!;
    expect(colatina).toMatchObject({ title: 'Ajudante de obras', city: 'Colatina, ES' });
    expect(colatina.description).toContain('Código da ocupação (CBO): 7170-20');
    expect(colatina.originalUrl).toBe('https://setades.es.gov.br/vagas-de-empregos#/vaga/cbo-7170-20-colatina');
    const multi = byCode.get('351605')!;
    expect(multi.title).toBe('TÉCNICO DE SEGURANÇA DO TRABALHO');
    expect(multi.description).toContain('Criar planos de prevenção; produz laudos técnicos;\nelabora e assina documentos');
    expect(byCode.get('9287297')!.description).not.toContain('Escolaridade');
    for (const j of page.jobs) { expect(j.company).toBe(''); expect(j.country).toBe('BR'); expect(j.originalUrl).toMatch(/^https:\/\/setades\.es\.gov\.br\/vagas-de-empregos#\/vaga\/[a-z0-9-]+$/); }
  });

  it('works against another origin (tests, mirrors): only the catalogue host is replaced', async () => {
    const seen: string[] = [];
    const f = ((u: string | URL | Request) => { seen.push(String(u)); return routed(String(u).replace('http://mirror.test', 'https://dados.es.gov.br')); }) as typeof fetch;
    const page = await sineEsConnector(f, nowFn, { origin: 'http://mirror.test/' }).fetchPage(null, 'discover');
    expect(seen.every((u) => u.startsWith('http://mirror.test/'))).toBe(true);
    expect(page.jobs).toHaveLength(15);
  });

  it('a body that is not the catalogue, an HTTP error, a broken office file and an empty catalogue are failures, never an empty list', async () => {
    const f = (b: string, status = 200) => ((async () => new Response(b, { status })) as typeof fetch);
    await expect(sineEsConnector(f('<html>challenge</html>'), nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(sineEsConnector(f('{"success":false}'), nowFn).fetchPage(null, 'discover')).rejects.toMatchObject({ status: 403 });
    await expect(sineEsConnector(f('', 503), nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
    const broken = ((u: string | URL | Request) => (String(u).includes('package_show') ? routed(u) : Promise.resolve(new Response('', { status: 500 })))) as typeof fetch;
    await expect(sineEsConnector(broken, nowFn).fetchPage(null, 'discover')).rejects.toBeInstanceOf(HttpError);
    const empty = f(JSON.stringify({ success: true, result: { resources: [] } }));
    await expect(sineEsConnector(empty, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/holds no offers/);
    await expect(sineEsConnector(routed, nowFn).fetchPage('x', 'discover')).rejects.toThrow(/invalid cursor/);
  });

  it('ignores resources that are not CSV or not on the state domain', async () => {
    const meta = JSON.stringify({ success: true, result: { resources: [
      { format: 'PDF', url: 'https://dados.es.gov.br/x/vagas_cariacica.csv' },
      { format: 'CSV', url: 'https://evil.example/vagas_cariacica.csv' },
      { format: 'CSV', url: 'http://dados.es.gov.br/x/vagas_cariacica.csv' },
    ] } });
    const calls: string[] = [];
    const f = ((u: string | URL | Request) => { calls.push(String(u)); return Promise.resolve(new Response(meta, { status: 200 })); }) as typeof fetch;
    await expect(sineEsConnector(f, nowFn).fetchPage(null, 'discover')).rejects.toThrow(/holds no offers/);
    expect(calls).toHaveLength(1);
  });
});

describe('SINE-ES source profile', () => {
  it('names the licence, the dataset and the fact that the employer is not named, and links to its own host', () => {
    const s = SOURCES.sinees!;
    expect(s.host).toBe('es.gov.br');
    expect(s.attribution).toContain('Creative Commons Attribution');
    expect(s.attribution).toContain('https://dados.es.gov.br');
    expect(s.attribution).toContain('does not name the employer');
    expect(s.maxPages).toBe(1);
  });
});
