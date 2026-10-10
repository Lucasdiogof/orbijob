#!/usr/bin/env node
// Verifica, SOMENTE LENDO, a chave exclusiva do Worker (orbijob_sync_worker) contra o Supabase hospedado. Nenhuma escrita: o código
// só envia GET. Confere que a chave (1) é uma sb_secret_ própria, nunca a legada nem a da ingestão local, (2) lê job_sources, jobs e
// sync_runs, (3) é RECUSADA nas tabelas de dados de usuário.
//
//   node scripts/worker-key-check.mjs --from-cli      lê a chave pelo NOME na CLI do Supabase já logada (só em memória)
//   ORBIJOB_WORKER_KEY=... node scripts/worker-key-check.mjs   (memória do processo chamador)
//
// A chave nunca é impressa, gravada em arquivo nem passada em argumento.
import { REF, WORKER_KEY_NAME, authChecks, localOnly, resolveWorkerKey } from './worker-key.mjs';

let base;
try { base = localOnly('ORBIJOB_REHEARSAL_BASE'); } catch (e) { console.error(`PARE: ${e.message}`); process.exit(1); }
const PROJECT_URL = base ?? `https://${REF}.supabase.co`;
const r = resolveWorkerKey({ fromCli: process.argv.includes('--from-cli') });
if (r.error) { console.error(`PARE: ${r.error}`); process.exit(1); }
const { failures, lines } = await authChecks(PROJECT_URL, r.key);
console.log(`chave "${WORKER_KEY_NAME}": ${failures.length ? 'REPROVADA' : 'APROVADA'} (somente leitura; nenhuma escrita foi feita)`);
for (const l of lines) console.log(l);
process.exit(failures.length ? 1 : 0);
