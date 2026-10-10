#!/usr/bin/env node
// Turns a vitest JSON report into GitHub annotations (`::error::`), so the exact reason a CI test failed is visible in the
// check run itself (and through the public checks API) without opening the job log. Prints nothing when everything passed.
//   npx vitest run --reporter=json --outputFile=out.json ...; node scripts/ci-annotate-vitest.mjs out.json
import { existsSync, readFileSync } from 'node:fs';

// Optional second argument: a lease-stress measurement (see test/live/lease-stress.test.ts), published as a notice.
const stress = process.argv[3];
if (stress && existsSync(stress)) {
  const m = JSON.parse(readFileSync(stress, 'utf8'));
  for (const [design, variants] of Object.entries(m)) {
    for (const [variant, r] of Object.entries(variants)) {
      console.log(`::notice title=Lease ${design} (${variant} clock)::${r.rounds} rounds x ${r.contenders} contenders; winners per round (winners:rounds) = ${JSON.stringify(r.winnersPerRound)}`);
    }
  }
}

const file = process.argv[2];
if (!file || !existsSync(file)) { console.log(`::warning title=No test report::${file ?? '(no file)'} was not produced; see the job log`); process.exit(0); }
const report = JSON.parse(readFileSync(file, 'utf8'));
const esc = (s) => s.replace(/%/g, '%25').replace(/\r/g, '').replace(/\n/g, '%0A');
const clean = (s) => s.replace(/\u001b\[[0-9;]*m/g, '').replace(/\s+/g, ' ').trim();
let shown = 0;
for (const f of report.testResults ?? []) {
  for (const t of f.assertionResults ?? []) {
    if (t.status !== 'failed' || shown >= 10) continue;
    shown++;
    const title = clean(t.fullName).replace(/[:,]/g, ' ').slice(0, 150);
    console.log(`::error title=${esc(title)}::${esc(clean((t.failureMessages ?? []).join(' ')).slice(0, 700))}`);
  }
  if (f.status === 'failed' && !(f.assertionResults ?? []).some((t) => t.status === 'failed') && f.message) {
    console.log(`::error title=${esc(clean(f.name ?? 'suite').slice(-120))}::${esc(clean(f.message).slice(0, 700))}`);
  }
}
