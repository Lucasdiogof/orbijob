#!/usr/bin/env node
// Configura os DOIS secrets do Worker (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY) no Cloudflare, sem que a chave apareça em tela,
// argumento, arquivo ou histórico: o valor vai ao `wrangler secret put` pela ENTRADA PADRÃO (stdin).
//
//   node scripts/worker-secrets.mjs --from-cli            ENSAIO: valida a chave (somente leitura) e diz o que faria. Não envia nada.
//   node scripts/worker-secrets.mjs --from-cli --apply --yes   valida e ENVIA os dois secrets ao Worker orbijob-jobicy-sync
//
// Só é enviada uma chave que passou em worker-key-check (sb_secret_ própria, lê o catálogo, recusada nas tabelas de usuário).
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { REF, WORKER_KEY_NAME, authChecks, localOnly, resolveWorkerKey } from './worker-key.mjs';

const WORKER = 'orbijob-jobicy-sync';
const args = process.argv.slice(2);
const apply = args.includes('--apply');
let base;
try { base = localOnly('ORBIJOB_REHEARSAL_BASE'); } catch (e) { console.error(`PARE: ${e.message}`); process.exit(1); }
const PROJECT_URL = base ?? `https://${REF}.supabase.co`;
const wrangler = process.env.ORBIJOB_WRANGLER_JS ?? fileURLToPath(new URL('../node_modules/wrangler/bin/wrangler.js', import.meta.url));

const r = resolveWorkerKey({ fromCli: args.includes('--from-cli') });
if (r.error) { console.error(`PARE: ${r.error}`); process.exit(1); }
const { failures, lines } = await authChecks(PROJECT_URL, r.key);
console.log(`chave "${WORKER_KEY_NAME}": ${failures.length ? 'REPROVADA' : 'APROVADA'} (somente leitura)`);
for (const l of lines) console.log(l);
if (failures.length) { console.error('PARE: a chave nao passou nas verificacoes; nada foi enviado'); process.exit(1); }

if (!apply) {
  console.log(`ENSAIO: enviaria SUPABASE_URL (${PROJECT_URL}) e SUPABASE_SERVICE_ROLE_KEY ao Worker ${WORKER}, pela entrada padrao. Nada foi enviado.`);
  process.exit(0);
}
if (!args.includes('--yes')) { console.error('PARE: --apply exige --yes (autorizacao do proprietario)'); process.exit(1); }
if (base && !process.env.ORBIJOB_WRANGLER_JS) { console.error('PARE: um endereco de ensaio (localhost) nunca vai para um Worker real'); process.exit(1); }

/** `wrangler secret put NAME --name WORKER`, value on stdin. Wrangler's own output is dropped (it may echo prompts). */
const put = (name, value) => new Promise((resolve, reject) => {
  const p = spawn(process.execPath, [wrangler, 'secret', 'put', name, '--name', WORKER], { cwd: fileURLToPath(new URL('../', import.meta.url)), stdio: ['pipe', 'ignore', 'pipe'], env: { ...process.env, WRANGLER_SEND_METRICS: 'false', CI: '1' } });
  let err = '';
  p.stderr.on('data', (d) => { err += d; });
  p.on('error', reject);
  p.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`wrangler secret put ${name} terminou com ${code}`))));
  p.stdin.end(value + '\n');
  p.on('close', () => { err = ''; });
});
try {
  await put('SUPABASE_URL', PROJECT_URL);
  await put('SUPABASE_SERVICE_ROLE_KEY', r.key);
  console.log('OK: os dois secrets foram enviados (a chave nao foi impressa). Confira com: npx wrangler secret list --name ' + WORKER);
} catch (e) {
  console.error(`FALHA: ${e.message}`);
  process.exit(1);
}
