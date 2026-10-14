// Pure logic of the Edge Function `account-export` ("Export my data"). No Deno- or Node-specific API.
//
// Everything is read THROUGH THE CALLER'S OWN ACCESS TOKEN, so row-level security is the only authority: this function holds no privileged key
// and cannot return another person's row even if its code were wrong. Push tokens and other credentials are never selected (the device list
// carries platform, language and dates only). Resume files are offered as short-lived signed links, valid one hour.

export const EXPORT_TABLES: readonly { table: string; columns: string }[] = [
  { table: 'professional_profiles', columns: '*' },
  { table: 'experiences', columns: '*' },
  { table: 'education', columns: '*' },
  { table: 'credentials', columns: '*' },
  { table: 'resumes', columns: '*' },
  { table: 'user_preferences', columns: '*' },
  { table: 'saved_searches', columns: '*' },
  { table: 'saved_jobs', columns: '*' },
  { table: 'hidden_jobs', columns: '*' },
  { table: 'viewed_jobs', columns: '*' },
  { table: 'applications', columns: '*' },
  { table: 'application_events', columns: '*' },
  { table: 'reminders', columns: '*' },
  { table: 'notifications', columns: '*' },
  // never `token`: it is a credential of the device, not data about the person
  { table: 'push_devices', columns: 'id,platform,locale,created_at,last_seen_at' },
];

export const SIGNED_LINK_SECONDS = 3600;
const PAGE = 500;
const MAX_ROWS_PER_TABLE = 20000;

export interface ExportDeps {
  userForToken(token: string): Promise<{ id: string; email: string | null; created_at?: string; last_sign_in_at?: string | null } | null>;
  /** One page of one table, as the caller (RLS applies). */
  page(table: string, columns: string, from: number, to: number): Promise<{ data: Record<string, unknown>[] | null; error: { message: string } | null }>;
  signedUrl(path: string, seconds: number): Promise<string | null>;
  now(): Date;
}

export type ExportOutcome =
  | { status: 200; body: Record<string, unknown> }
  | { status: 401 | 405 | 500; body: { error: string } };

export function bearer(header: string | null | undefined): string | null {
  const m = /^Bearer\s+([A-Za-z0-9._~+/=-]{20,4096})$/.exec((header ?? '').trim());
  return m ? m[1]! : null;
}

async function readAll(deps: ExportDeps, table: string, columns: string): Promise<Record<string, unknown>[]> {
  const rows: Record<string, unknown>[] = [];
  for (let from = 0; from < MAX_ROWS_PER_TABLE; from += PAGE) {
    const { data, error } = await deps.page(table, columns, from, from + PAGE - 1);
    if (error) throw new Error(`${table}: ${error.message}`);
    const got = data ?? [];
    rows.push(...got);
    if (got.length < PAGE) break;
  }
  return rows;
}

export async function exportData(deps: ExportDeps, method: string, authorization: string | null): Promise<ExportOutcome> {
  if (method !== 'POST' && method !== 'GET') return { status: 405, body: { error: 'method' } };
  const token = bearer(authorization);
  if (!token) return { status: 401, body: { error: 'unauthorised' } };
  const user = await deps.userForToken(token);
  if (!user) return { status: 401, body: { error: 'unauthorised' } };
  try {
    const data: Record<string, Record<string, unknown>[]> = {};
    for (const t of EXPORT_TABLES) data[t.table] = await readAll(deps, t.table, t.columns);
    const resumes: Record<string, unknown>[] = [];
    for (const r of data.resumes ?? []) {
      const path = typeof r.storage_path === 'string' ? r.storage_path : '';
      // the folder must be the caller's own: refuses a tampered row before it reaches the signer
      const url = path.startsWith(`${user.id}/`) && !path.includes('..') ? await deps.signedUrl(path, SIGNED_LINK_SECONDS) : null;
      resumes.push({ id: r.id, created_at: r.created_at, file: path.split('/').pop() ?? null, download_url: url, download_url_valid_seconds: url ? SIGNED_LINK_SECONDS : null });
    }
    return {
      status: 200,
      body: {
        format: 'orbijob-data-export',
        version: 1,
        generated_at: deps.now().toISOString(),
        account: { id: user.id, email: user.email, created_at: user.created_at ?? null, last_sign_in_at: user.last_sign_in_at ?? null },
        data,
        resume_files: resumes,
        not_included: ['password and sign-in credentials', 'push tokens of your devices', 'the public job catalogue (it is not your data)'],
      },
    };
  } catch {
    return { status: 500, body: { error: 'export_failed' } };
  }
}
