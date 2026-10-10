// Garante, por varredura do repositório, que nenhum SQL/roteiro/doc fora do arquivo guardado liga can_redistribute
// (publicação prematura de uma fonte). Rode: node --test scripts/supabase/no_premature_publish.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '../..');
const GUARDED = 'scripts/supabase/ops/publish_jobicy.sql';
// Fixtures de teste que modelam o estado JÁ publicado de bancos descartáveis (PGlite / PostgREST de CI) ou semeiam dados locais.
const TEST_FIXTURE = /^(supabase\/tests\/|worker\/test\/|app\/test\/)/;
const TEXT = /\.(md|sql|sh|ps1|mjs|ts|json|toml|yml|yaml)$/i;

const files = execFileSync('git', ['ls-files'], { cwd: ROOT, encoding: 'utf8' }).split('\n').filter(Boolean)
  .filter((f) => TEXT.test(f) && !TEST_FIXTURE.test(f) && !f.endsWith('.golden.json') && f !== 'scripts/supabase/no_premature_publish.test.mjs');

/** Statements that WRITE the flag as true: insert into/update job_sources, or "set can_redistribute = true". */
function offenders(text) {
  const out = [];
  const flat = text.replace(/\r/g, '');
  for (const m of flat.matchAll(/(insert\s+into\s+(?:public\.)?job_sources|update\s+(?:public\.)?job_sources)[^;]*;?/gi)) {
    if (/\btrue\b/i.test(m[0])) out.push(m[0].replace(/\s+/g, ' ').slice(0, 140));
  }
  for (const m of flat.matchAll(/can_redistribute\s*(?:=|:)\s*true/gi)) {
    const ctx = flat.slice(Math.max(0, m.index - 80), m.index);
    if (/\bset\s*$|\bdo update set[^;]*$/i.test(ctx)) out.push(`set ${m[0]}`);
  }
  return out;
}

test('nenhum arquivo, exceto o guardado, liga can_redistribute', () => {
  const bad = [];
  for (const f of files) {
    if (f === GUARDED) continue;
    const o = offenders(readFileSync(resolve(ROOT, f), 'utf8'));
    if (o.length) bad.push(`${f}: ${o.join(' | ')}`);
  }
  assert.deepEqual(bad, [], 'publicacao prematura: use somente ' + GUARDED);
});

test('o arquivo de publicação mantém suas travas', () => {
  const t = readFileSync(resolve(ROOT, GUARDED), 'utf8');
  for (const needle of ["current_setting('orbijob.publish_jobicy'", 'EU-REVISEI-OS-REGISTROS-E-AUTORIZO', "status = 'ok'", 'raise exception', "status <> 'CONDITIONAL'"]) {
    assert.ok(t.includes(needle), `trava ausente: ${needle}`);
  }
  assert.equal((t.match(/set can_redistribute = true/g) ?? []).length, 1);
});

test('o detector pega os padrões perigosos (autoteste)', () => {
  assert.ok(offenders("insert into public.job_sources (id,status,can_redistribute) values ('x','READY',true);").length);
  assert.ok(offenders("update public.job_sources set can_redistribute = true where id='jobicy';").length);
  assert.ok(offenders("on conflict (id) do update set can_redistribute = true").length);
  assert.equal(offenders("insert into public.job_sources (id,status,attribution,can_redistribute) values ('jobicy','CONDITIONAL','a',false);").length, 0);
  assert.equal(offenders("update public.job_sources set can_redistribute = false where id = 'jobicy';").length, 0);
  assert.equal(offenders("`.eq('can_redistribute', true)` filtro de leitura").length, 0);
});
