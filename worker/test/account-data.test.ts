import { describe, expect, it } from 'vitest';
import { bearer, deleteAccount, type DeleteDeps, parseDeleteBody, purgeFolder } from '../../supabase/functions/account-delete/core';
import { EXPORT_TABLES, exportData, type ExportDeps } from '../../supabase/functions/account-export/core';

/** Account deletion and data export (Edge Functions account-delete / account-export): pure parts with fakes. */
const TOKEN = 'eyJhbGciOiJIUzI1NiJ9.payload.signature-signature';
const AUTH = `Bearer ${TOKEN}`;
const UID = '11111111-1111-1111-1111-111111111111';

function deleteDeps(over: Partial<DeleteDeps> = {}, files: string[] = []) {
  const calls: string[] = [];
  const folder = [...files];
  const deps: DeleteDeps = {
    userForToken: async (t) => (t === TOKEN ? { id: UID, email: 'ana@example.com' } : null),
    passwordMatches: async (_e, p, id) => { calls.push('password'); return p === 'correct horse' && id === UID; },
    bucket: {
      list: async (prefix, o) => { calls.push(`list:${prefix}`); return { data: folder.slice(0, o.limit).map((name) => ({ name })), error: null }; },
      remove: async (paths) => { calls.push(`remove:${paths.join(',')}`); for (const p of paths) folder.splice(folder.indexOf(p.split('/')[1]!), 1); return { error: null }; },
    },
    deleteUser: async (id) => { calls.push(`deleteUser:${id}`); return { error: null }; },
    ...over,
  };
  return { deps, calls };
}

describe('account-delete request rules', () => {
  it('reads only a well-formed bearer token', () => {
    expect(bearer(AUTH)).toBe(TOKEN);
    for (const bad of [null, undefined, '', 'Bearer', 'Bearer short', `Basic ${TOKEN}`, `Bearer ${TOKEN} extra`]) expect(bearer(bad)).toBeNull();
  });

  it('needs the explicit confirmation and a password; an id in the body is ignored', () => {
    expect(parseDeleteBody({ password: 'x', confirm: true })).toEqual({ password: 'x', confirm: true });
    expect(parseDeleteBody({ password: 'x', confirm: true, user_id: 'someone-else' })).toEqual({ password: 'x', confirm: true });
    for (const bad of [null, 'x', {}, { password: 'x' }, { password: 'x', confirm: 'true' }, { password: '', confirm: true }, { password: 1, confirm: true }, { password: 'a'.repeat(257), confirm: true }]) {
      expect(parseDeleteBody(bad)).toBeNull();
    }
  });
});

describe('account-delete', () => {
  it('removes the resume files, then the Auth user, only after the password is proven', async () => {
    const { deps, calls } = deleteDeps({}, ['a.pdf', 'b.pdf']);
    const r = await deleteAccount(deps, 'POST', AUTH, { password: 'correct horse', confirm: true });
    expect(r).toEqual({ status: 200, body: { status: 'deleted', resumes_removed: 2 } });
    expect(calls[0]).toBe('password');
    expect(calls.at(-1)).toBe(`deleteUser:${UID}`);
    expect(calls.filter((c) => c.startsWith('remove:'))).toEqual([`remove:${UID}/a.pdf,${UID}/b.pdf`]);
    expect(calls.every((c) => !c.startsWith('list:') || c === `list:${UID}`)).toBe(true);
  });

  it('touches nothing for a wrong password, a bad token, a bad method or a bad body', async () => {
    const touched = (c: string[]) => c.filter((x) => x.startsWith('remove') || x.startsWith('deleteUser'));
    let { deps, calls } = deleteDeps({}, ['a.pdf']);
    expect(await deleteAccount(deps, 'POST', AUTH, { password: 'wrong', confirm: true })).toEqual({ status: 401, body: { error: 'reauth_failed' } });
    expect(touched(calls)).toEqual([]);
    ({ deps, calls } = deleteDeps({}, ['a.pdf']));
    expect(await deleteAccount(deps, 'POST', `Bearer ${'x'.repeat(30)}`, { password: 'correct horse', confirm: true })).toMatchObject({ status: 401 });
    expect(await deleteAccount(deps, 'POST', null, { password: 'correct horse', confirm: true })).toMatchObject({ status: 401 });
    expect(await deleteAccount(deps, 'GET', AUTH, { password: 'correct horse', confirm: true })).toMatchObject({ status: 405 });
    expect(await deleteAccount(deps, 'POST', AUTH, { password: 'correct horse' })).toMatchObject({ status: 400 });
    expect(touched(calls)).toEqual([]);
  });

  it('keeps the user when the files cannot be removed, so the same call can be repeated', async () => {
    const { deps, calls } = deleteDeps({
      bucket: { list: async () => ({ data: [{ name: 'a.pdf' }], error: null }), remove: async () => ({ error: { message: 'down' } }) },
    });
    expect(await deleteAccount(deps, 'POST', AUTH, { password: 'correct horse', confirm: true })).toEqual({ status: 502, body: { error: 'storage_failed' } });
    expect(calls.some((c) => c.startsWith('deleteUser'))).toBe(false);
  });

  it('reports a failed Auth deletion as retryable', async () => {
    const { deps } = deleteDeps({ deleteUser: async () => ({ error: { message: 'boom' } }) });
    expect(await deleteAccount(deps, 'POST', AUTH, { password: 'correct horse', confirm: true })).toEqual({ status: 500, body: { error: 'delete_failed' } });
  });

  it('is fine with an empty folder and empties a folder of more than one page', async () => {
    expect(await purgeFolder(deleteDeps().deps.bucket, UID)).toBe(0);
    const many = Array.from({ length: 250 }, (_, i) => `f${i}.pdf`);
    expect(await purgeFolder(deleteDeps({}, many).deps.bucket, UID)).toBe(250);
  });

  it('never lists or removes anything outside the person\'s own folder, even when a listing returns a nested name', async () => {
    const removed: string[] = [];
    let first = true;
    const bucket = {
      list: async () => { const r = first ? [{ name: '../other/x.pdf' }, { name: 'ok.pdf' }] : []; first = false; return { data: r, error: null }; },
      remove: async (p: string[]) => { removed.push(...p); return { error: null }; },
    };
    await purgeFolder(bucket, UID);
    expect(removed).toEqual([`${UID}/ok.pdf`]);
  });
});

function exportDeps(tables: Record<string, Record<string, unknown>[]>, over: Partial<ExportDeps> = {}) {
  const asked: string[] = [];
  const deps: ExportDeps = {
    userForToken: async (t) => (t === TOKEN ? { id: UID, email: 'ana@example.com', created_at: '2026-01-01T00:00:00Z', last_sign_in_at: null } : null),
    page: async (table, columns, from, to) => { asked.push(`${table}|${columns}`); return { data: (tables[table] ?? []).slice(from, to + 1), error: null }; },
    signedUrl: async (p) => `https://signed.example/${p}?t=1`,
    now: () => new Date('2026-10-14T12:00:00Z'),
    ...over,
  };
  return { deps, asked };
}

describe('account-export', () => {
  it('covers every private table of the product, without push tokens', () => {
    expect(EXPORT_TABLES.map((t) => t.table).sort()).toEqual([
      'application_events', 'applications', 'credentials', 'education', 'experiences', 'hidden_jobs', 'notifications', 'professional_profiles',
      'push_devices', 'reminders', 'resumes', 'saved_jobs', 'saved_searches', 'user_preferences', 'viewed_jobs',
    ]);
    expect(EXPORT_TABLES.find((t) => t.table === 'push_devices')!.columns).not.toMatch(/token/);
  });

  it('returns the account, every table and a short-lived link for each resume', async () => {
    const { deps } = exportDeps({
      professional_profiles: [{ id: 'p1', name: 'Ana' }],
      resumes: [{ id: 'r1', storage_path: `${UID}/cv.pdf`, created_at: 'x' }],
      saved_searches: [{ id: 's1' }],
    });
    const r = await exportData(deps, 'POST', AUTH);
    expect(r.status).toBe(200);
    const b = (r as unknown as { body: Record<string, any> }).body;
    expect(b.format).toBe('orbijob-data-export');
    expect(b.account).toEqual({ id: UID, email: 'ana@example.com', created_at: '2026-01-01T00:00:00Z', last_sign_in_at: null });
    expect(b.data.professional_profiles).toEqual([{ id: 'p1', name: 'Ana' }]);
    expect(Object.keys(b.data)).toHaveLength(EXPORT_TABLES.length);
    expect(b.resume_files).toEqual([{ id: 'r1', created_at: 'x', file: 'cv.pdf', download_url: `https://signed.example/${UID}/cv.pdf?t=1`, download_url_valid_seconds: 3600 }]);
    expect(JSON.stringify({ a: b.account, d: b.data, r: b.resume_files })).not.toMatch(/password|service_role|"token"/);
  });

  it('never signs a resume path outside the caller\'s own folder', async () => {
    const { deps } = exportDeps({ resumes: [{ id: 'r1', storage_path: 'other-user/cv.pdf' }, { id: 'r2', storage_path: `${UID}/../other/cv.pdf` }] });
    const r = await exportData(deps, 'GET', AUTH);
    expect((r as unknown as { body: { resume_files: { download_url: string | null }[] } }).body.resume_files.map((x) => x.download_url)).toEqual([null, null]);
  });

  it('reads long tables page by page', async () => {
    const rows = Array.from({ length: 1234 }, (_, i) => ({ job_id: `j${i}` }));
    const { deps } = exportDeps({ viewed_jobs: rows });
    const r = await exportData(deps, 'POST', AUTH);
    expect((r as unknown as { body: { data: { viewed_jobs: unknown[] } } }).body.data.viewed_jobs).toHaveLength(1234);
  });

  it('refuses without a valid token or method, and fails closed when a read fails', async () => {
    const { deps } = exportDeps({});
    expect(await exportData(deps, 'POST', null)).toMatchObject({ status: 401 });
    expect(await exportData(deps, 'POST', `Bearer ${'x'.repeat(30)}`)).toMatchObject({ status: 401 });
    expect(await exportData(deps, 'DELETE', AUTH)).toMatchObject({ status: 405 });
    const failing = exportDeps({}, { page: async () => ({ data: null, error: { message: 'rls' } }) }).deps;
    expect(await exportData(failing, 'POST', AUTH)).toEqual({ status: 500, body: { error: 'export_failed' } });
  });
});
