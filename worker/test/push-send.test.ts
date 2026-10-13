import { createVerify, generateKeyPairSync } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  accessToken, buildMessage, parseServiceAccount, type PushRow, sameSecret, sendAll, sendOne, signedAssertion,
} from '../../supabase/functions/push-send/core';

/** The sender of the Edge Function push-send (supabase/functions/push-send): pure parts, with Google and FCM replaced by fakes. */
const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const PEM = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
const SA = { type: 'service_account', project_id: 'orbijob', client_email: 'push@orbijob.iam.gserviceaccount.com', private_key: PEM };
const row = (o: Partial<PushRow> = {}): PushRow => ({
  notification_id: 'n1', job_id: 'j1', title: 'Fisioterapeuta Pélvica', company: 'Clínica Ágil', token: 'tok-1', platform: 'android', locale: 'pt-BR', ...o,
});
const res = (status: number, body: unknown) => new Response(typeof body === 'string' ? body : JSON.stringify(body), { status });

describe('service account', () => {
  it('accepts a Firebase service-account JSON and refuses anything else', () => {
    expect(parseServiceAccount(JSON.stringify(SA))).toMatchObject({ project_id: 'orbijob' });
    for (const bad of [undefined, '', '{', JSON.stringify({ ...SA, type: 'authorized_user' }), JSON.stringify({ ...SA, private_key: 'x' }), JSON.stringify({ project_id: 'p' })]) {
      expect(parseServiceAccount(bad)).toBeNull();
    }
  });

  it('signs a valid RS256 assertion for the FCM scope, valid one hour', async () => {
    const jwt = await signedAssertion(parseServiceAccount(JSON.stringify(SA))!, 1_800_000_000);
    const [h, c, s] = jwt.split('.');
    const v = createVerify('RSA-SHA256');
    v.update(`${h}.${c}`);
    expect(v.verify(publicKey, Buffer.from(s!, 'base64url'))).toBe(true);
    const claims = JSON.parse(Buffer.from(c!, 'base64url').toString());
    expect(claims).toEqual({
      iss: SA.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: 'https://oauth2.googleapis.com/token', iat: 1_800_000_000, exp: 1_800_003_600,
    });
  });

  it('exchanges the assertion for an access token and fails loudly when Google refuses', async () => {
    const sa = parseServiceAccount(JSON.stringify(SA))!;
    const calls: RequestInit[] = [];
    const ok = (async (_u: unknown, init?: RequestInit) => { calls.push(init!); return res(200, { access_token: 'ya29.x' }); }) as typeof fetch;
    expect(await accessToken(sa, ok, 1_800_000_000)).toBe('ya29.x');
    expect(String(calls[0]!.body)).toContain('grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer');
    await expect(accessToken(sa, (async () => res(400, { error: 'invalid_grant' })) as typeof fetch, 1)).rejects.toThrow(/oauth: HTTP 400/);
  });
});

describe('message', () => {
  it('speaks the person\'s language, keeps the listing\'s own title and company, and carries the ids the app opens', () => {
    const m = buildMessage(row()) as { message: { token: string; notification: { title: string; body: string }; data: Record<string, string> } };
    expect(m.message.token).toBe('tok-1');
    expect(m.message.notification).toEqual({ title: 'Nova vaga para você', body: 'Fisioterapeuta Pélvica · Clínica Ágil' });
    expect(m.message.data).toEqual({ kind: 'new_job', notification_id: 'n1', job_id: 'j1' });
    expect((buildMessage(row({ locale: 'es' })) as { message: { notification: { title: string } } }).message.notification.title).toBe('Nueva vacante para ti');
    expect((buildMessage(row({ locale: null, company: null, job_id: null })) as { message: { notification: { title: string; body: string }; data: Record<string, string> } }).message)
      .toMatchObject({ notification: { title: 'New job for you', body: 'Fisioterapeuta Pélvica' }, data: { kind: 'new_job', notification_id: 'n1' } });
  });
});

describe('sending', () => {
  it('classifies FCM answers: sent, a token it no longer knows, and other failures', async () => {
    const f = (status: number, body: unknown) => (async () => res(status, body)) as typeof fetch;
    expect(await sendOne(f(200, { name: 'm' }), 't', 'orbijob', row())).toBe('sent');
    expect(await sendOne(f(404, { error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }), 't', 'orbijob', row())).toBe('unregistered');
    expect(await sendOne(f(400, { error: { status: 'INVALID_ARGUMENT', message: 'The registration token is not a valid FCM registration token' } }), 't', 'orbijob', row())).toBe('unregistered');
    expect(await sendOne(f(400, { error: { status: 'INVALID_ARGUMENT', message: 'Invalid JSON payload' } }), 't', 'orbijob', row())).toBe('failed');
    expect(await sendOne(f(503, 'unavailable'), 't', 'orbijob', row())).toBe('failed');
  });

  it('sends every row with the bearer token to the project endpoint and lists each dead token once', async () => {
    const seen: string[] = [];
    const fake = (async (url: unknown, init?: RequestInit) => {
      expect(String(url)).toBe('https://fcm.googleapis.com/v1/projects/orbijob/messages:send');
      expect((init!.headers as Record<string, string>).authorization).toBe('Bearer ya29.x');
      const tok = JSON.parse(String(init!.body)).message.token as string;
      seen.push(tok);
      if (tok.startsWith('dead')) return res(404, 'UNREGISTERED');
      if (tok === 'boom') throw new Error('network');
      return res(200, {});
    }) as typeof fetch;
    const rows = [...Array.from({ length: 10 }, (_, i) => row({ token: `ok-${i}` })), row({ token: 'dead-1' }), row({ token: 'dead-1', notification_id: 'n2' }), row({ token: 'boom' })];
    const s = await sendAll(fake, 'ya29.x', 'orbijob', rows);
    expect(s).toEqual({ claimed: 13, sent: 10, failed: 1, forgotten: ['dead-1'] });
    expect(seen).toHaveLength(13);
  });

  it('the scheduler secret is compared exactly', () => {
    expect(sameSecret('abc123', 'abc123')).toBe(true);
    for (const [a, b] of [['abc123', 'abc124'], ['abc', 'abc123'], ['', ''], [null, 'x'], ['x', undefined]] as const) expect(sameSecret(a, b)).toBe(false);
  });
});

describe('reminders', () => {
  it('interview and follow-up reminders get their own title in each language and carry the application id', () => {
    const m = (o: Partial<PushRow>) => (buildMessage(row(o)) as { message: { notification: { title: string }; data: Record<string, string> } }).message;
    expect(m({ kind: 'interview', job_id: null, application_id: 'a1' })).toMatchObject({
      notification: { title: 'Entrevista nas próximas 24 h' }, data: { kind: 'interview', notification_id: 'n1', application_id: 'a1' },
    });
    expect(m({ kind: 'follow_up', locale: 'es' }).notification.title).toBe('Día de dar seguimiento a la candidatura');
    expect(m({ kind: 'interview', locale: 'en-GB' }).notification.title).toBe('Interview in the next 24 h');
    expect(m({ kind: null }).data.kind).toBe('new_job');
  });
});
