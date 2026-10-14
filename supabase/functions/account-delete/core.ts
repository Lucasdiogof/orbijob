// Pure logic of the Edge Function `account-delete` (permanent deletion of the caller's own account). No Deno- or Node-specific API, so the same
// file runs in the function and in the worker's tests.
//
// The person is identified ONLY by the verified access token (never by an id in the body), must prove they are present by typing the current
// password again, and everything private is removed in this order: resume files in Storage (objects do not cascade), then the Auth user, whose
// removal cascades through every `references auth.users(id) on delete cascade` table (profile, experiences, education, credentials, resumes,
// favourites, searches, history, applications, reminders, notifications, devices, preferences). The public catalogue is untouched.
// Idempotent: a failure after the files went leaves the user in place and the same call can be repeated.

export interface DeleteBody {
  password: string;
  confirm: true;
}

export type DeleteOutcome =
  | { status: 200; body: { status: 'deleted'; resumes_removed: number } }
  | { status: 400 | 401 | 405 | 500 | 502; body: { error: string } };

export interface StorageBucket {
  list(prefix: string, opts: { limit: number }): Promise<{ data: { name: string }[] | null; error: { message: string } | null }>;
  remove(paths: string[]): Promise<{ error: { message: string } | null }>;
}

export interface DeleteDeps {
  /** The verified user behind the access token, or null when the token is missing, forged, expired or the user no longer exists. */
  userForToken(token: string): Promise<{ id: string; email: string | null } | null>;
  /** True when this e-mail + password is a valid login of exactly this user. */
  passwordMatches(email: string, password: string, userId: string): Promise<boolean>;
  bucket: StorageBucket;
  deleteUser(userId: string): Promise<{ error: { message: string } | null }>;
}

export function bearer(header: string | null | undefined): string | null {
  const m = /^Bearer\s+([A-Za-z0-9._~+/=-]{20,4096})$/.exec((header ?? '').trim());
  return m ? m[1]! : null;
}

export function parseDeleteBody(raw: unknown): DeleteBody | null {
  if (!raw || typeof raw !== 'object') return null;
  const b = raw as Record<string, unknown>;
  if (b.confirm !== true) return null;
  if (typeof b.password !== 'string' || b.password.length < 1 || b.password.length > 256) return null;
  return { password: b.password, confirm: true };
}

/** Removes every file in the person's own folder of the private bucket; returns how many were removed. */
export async function purgeFolder(bucket: StorageBucket, userId: string): Promise<number> {
  let removed = 0;
  // Listing is paged and removal shrinks the folder, so always list page one again; the cap only protects against a stuck server.
  for (let round = 0; round < 100; round++) {
    const { data, error } = await bucket.list(userId, { limit: 100 });
    if (error) throw new Error(`list: ${error.message}`);
    const names = (data ?? []).map((o) => o.name).filter((n) => n && !n.includes('/') && n !== '.emptyFolderPlaceholder');
    if (names.length === 0) return removed;
    const { error: rmError } = await bucket.remove(names.map((n) => `${userId}/${n}`));
    if (rmError) throw new Error(`remove: ${rmError.message}`);
    removed += names.length;
  }
  throw new Error('folder did not empty');
}

export async function deleteAccount(deps: DeleteDeps, method: string, authorization: string | null, rawBody: unknown): Promise<DeleteOutcome> {
  if (method !== 'POST') return { status: 405, body: { error: 'method' } };
  const token = bearer(authorization);
  if (!token) return { status: 401, body: { error: 'unauthorised' } };
  const body = parseDeleteBody(rawBody);
  if (!body) return { status: 400, body: { error: 'bad_request' } };
  const user = await deps.userForToken(token);
  if (!user || !user.email) return { status: 401, body: { error: 'unauthorised' } };
  if (!(await deps.passwordMatches(user.email, body.password, user.id))) return { status: 401, body: { error: 'reauth_failed' } };
  let removed: number;
  try {
    removed = await purgeFolder(deps.bucket, user.id);
  } catch {
    return { status: 502, body: { error: 'storage_failed' } };
  }
  const { error } = await deps.deleteUser(user.id);
  if (error) return { status: 500, body: { error: 'delete_failed' } };
  return { status: 200, body: { status: 'deleted', resumes_removed: removed } };
}
