// Read-only audit of what the app shows (PUBLISHABLE key, same visibility as the app): every visible description is passed through the storage guard
// (src/description.ts protectPersonalData); anything it would still change is a personal phone or e-mail left in public. Prints counts only, never a number.
//   SUPABASE_PUBLISHABLE_KEY=sb_publishable_... npx vite-node scripts/public-privacy-audit.ts
import { protectPersonalData } from '../src/description';

const KEY = (process.env.SUPABASE_PUBLISHABLE_KEY ?? '').trim();
if (!KEY.startsWith('sb_publishable_')) { console.error('PARE: defina SUPABASE_PUBLISHABLE_KEY'); process.exit(1); }
const BASE = 'https://rpmlfxwebnlxnwadyvle.supabase.co/rest/v1/jobs';
const since = new Date(Date.now() - 72 * 3_600_000).toISOString();
type Row = { id: string; source_id: string; country: string | null; description: string | null };
const per = new Map<string, { visible: number; leaks: number; tel: number; email: number }>();
let after = '00000000-0000-0000-0000-000000000000';
for (;;) {
  const u = new URL(BASE);
  u.searchParams.set('select', 'id,source_id,country,description,job_sources!inner(id)');
  u.searchParams.set('status', 'eq.open');
  u.searchParams.set('job_sources.can_redistribute', 'eq.true');
  u.searchParams.set('last_checked_at', `gte.${since}`);
  u.searchParams.set('id', `gt.${after}`);
  u.searchParams.set('order', 'id');
  u.searchParams.set('limit', '1000');
  const r = await fetch(u, { headers: { apikey: KEY } });
  if (!r.ok) { console.error(`HTTP ${r.status}`); process.exit(1); }
  const rows = (await r.json()) as Row[];
  if (!rows.length) break;
  after = rows[rows.length - 1]!.id;
  for (const x of rows) {
    const s = per.get(x.source_id) ?? { visible: 0, leaks: 0, tel: 0, email: 0 };
    const d = x.description ?? '';
    s.visible++;
    if (protectPersonalData(d, x.country) !== d) s.leaks++;
    s.tel += (d.match(/\[(?:tel\.|telefon|teléfono|telèfon|téléphone)\]/g) ?? []).length;
    s.email += (d.match(/\[e-mail\]/g) ?? []).length;
    per.set(x.source_id, s);
  }
}
let leaks = 0, visible = 0;
for (const [src, s] of [...per].sort()) {
  console.log(`${src.padEnd(18)} visible=${s.visible} would_still_mask=${s.leaks} phones_masked=${s.tel} emails_masked=${s.email}`);
  leaks += s.leaks; visible += s.visible;
}
console.log(`total visible=${visible} would_still_mask=${leaks}`);
process.exit(leaks ? 1 : 0);
