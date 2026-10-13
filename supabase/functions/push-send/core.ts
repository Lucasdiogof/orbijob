// Pure logic of the push sender: Google OAuth for a service account (RS256 JWT, Web Crypto), the FCM HTTP v1 message, and the reading of FCM's
// answer. No Deno- or Node-specific API, so the same file runs in the Edge Function and in the worker's tests.

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export interface PushRow {
  notification_id: string;
  job_id: string | null;
  title: string;
  company: string | null;
  token: string;
  platform: string;
  locale: string | null;
}

export type SendOutcome = 'sent' | 'unregistered' | 'failed';

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URI = 'https://oauth2.googleapis.com/token';

export function parseServiceAccount(raw: string | undefined | null): ServiceAccount | null {
  if (!raw || !raw.trim()) return null;
  try {
    const v = JSON.parse(raw) as Partial<ServiceAccount> & { type?: string };
    if (v.type && v.type !== 'service_account') return null;
    if (!v.project_id || !v.client_email || !v.private_key?.includes('PRIVATE KEY')) return null;
    return { project_id: v.project_id, client_email: v.client_email, private_key: v.private_key, token_uri: v.token_uri };
  } catch {
    return null;
  }
}

const b64url = (bytes: Uint8Array): string => {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '');
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

/** The signed assertion Google exchanges for an access token (valid one hour). */
export async function signedAssertion(sa: ServiceAccount, nowSec: number): Promise<string> {
  const header = enc({ alg: 'RS256', typ: 'JWT' });
  const claims = enc({ iss: sa.client_email, scope: SCOPE, aud: sa.token_uri ?? TOKEN_URI, iat: nowSec, exp: nowSec + 3600 });
  const key = await crypto.subtle.importKey('pkcs8', pemToPkcs8(sa.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`)));
  return `${header}.${claims}.${b64url(sig)}`;
}

export async function accessToken(sa: ServiceAccount, fetchImpl: typeof fetch, nowSec: number): Promise<string> {
  const res = await fetchImpl(sa.token_uri ?? TOKEN_URI, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: await signedAssertion(sa, nowSec) }).toString(),
  });
  const body = (await res.json().catch(() => ({}))) as { access_token?: string };
  if (!res.ok || !body.access_token) throw new Error(`oauth: HTTP ${res.status}`);
  return body.access_token;
}

const COPY: Record<string, { head: string }> = {
  pt: { head: 'Nova vaga para você' },
  es: { head: 'Nueva vacante para ti' },
  en: { head: 'New job for you' },
};

/** The FCM v1 message: the person's language (pt / es / en), the job title and company as written by the listing, the ids the app opens. */
export function buildMessage(r: PushRow): Record<string, unknown> {
  const lang = (r.locale ?? '').toLowerCase().slice(0, 2);
  const copy = COPY[lang] ?? COPY.en!;
  const body = r.company ? `${r.title} · ${r.company}` : r.title;
  return {
    message: {
      token: r.token,
      notification: { title: copy.head, body: body.slice(0, 240) },
      data: { kind: 'new_job', notification_id: r.notification_id, ...(r.job_id ? { job_id: r.job_id } : {}) },
      android: { priority: 'normal', notification: { channel_id: 'job_alerts', tag: r.notification_id } },
      apns: { payload: { aps: { 'thread-id': 'job_alerts' } } },
    },
  };
}

/** One send. A token FCM no longer knows (404 / UNREGISTERED, or INVALID_ARGUMENT about the token) is reported so it can be forgotten. */
export async function sendOne(fetchImpl: typeof fetch, token: string, projectId: string, r: PushRow): Promise<SendOutcome> {
  const res = await fetchImpl(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(buildMessage(r)),
  });
  if (res.ok) return 'sent';
  const text = await res.text().catch(() => '');
  if (res.status === 404 || /UNREGISTERED/.test(text)) return 'unregistered';
  if (res.status === 400 && /registration token|INVALID_ARGUMENT/i.test(text) && /token/i.test(text)) return 'unregistered';
  return 'failed';
}

export interface RunSummary { claimed: number; sent: number; failed: number; forgotten: string[] }

/** Sends every claimed row (at most 8 at a time) and lists the tokens to forget. */
export async function sendAll(fetchImpl: typeof fetch, token: string, projectId: string, rows: PushRow[]): Promise<RunSummary> {
  const s: RunSummary = { claimed: rows.length, sent: 0, failed: 0, forgotten: [] };
  for (let i = 0; i < rows.length; i += 8) {
    const batch = rows.slice(i, i + 8);
    const out = await Promise.all(batch.map((r) => sendOne(fetchImpl, token, projectId, r).catch((): SendOutcome => 'failed')));
    out.forEach((o, k) => {
      if (o === 'sent') s.sent++;
      else if (o === 'unregistered') s.forgotten.push(batch[k]!.token);
      else s.failed++;
    });
  }
  s.forgotten = [...new Set(s.forgotten)];
  return s;
}

/** Constant-time comparison of the shared secret the scheduler sends. */
export function sameSecret(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}
