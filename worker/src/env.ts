/**
 * Environment of the Cloudflare Worker, typed and validated. Minimal structural types are declared here instead of
 * pulling @cloudflare/workers-types, which would clash with the Node types the tests use.
 *
 * Secrets are set with `wrangler secret put` (never in wrangler.toml, never in Git). Error messages built from this file
 * name the variable and the problem, never the value.
 */
export interface Env {
  /** https://<project-ref>.supabase.co */
  SUPABASE_URL?: string;
  /** SECRET. A `sb_secret_...` key or a legacy `service_role` JWT. Never the publishable/anon key. */
  SUPABASE_SERVICE_ROLE_KEY?: string;
  /** Optional, tests only: origin of a stand-in Jobicy API (`https://jobicy.com` or a localhost URL). Unset in production. */
  JOBICY_API_URL?: string;
  /** Optional: cap on feed pages per pass (1-100, default 40). */
  SYNC_MAX_PAGES?: string;
}

export interface ScheduledController {
  readonly cron: string;
  readonly scheduledTime: number;
}

export interface ExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
}

export type KeyKind = 'secret' | 'service_role_jwt' | 'anon_jwt' | 'publishable' | 'unknown';

/** Classifies a Supabase key by shape only (the JWT signature is not checked: the server does that). */
export function classifyKey(key: string): KeyKind {
  if (key.startsWith('sb_secret_')) return 'secret';
  if (key.startsWith('sb_publishable_')) return 'publishable';
  const m = /^eyJ[\w-]+\.([\w-]+)\.[\w-]+$/.exec(key);
  if (m) {
    try {
      const role = (JSON.parse(atob(m[1]!.replace(/-/g, '+').replace(/_/g, '/'))) as { role?: unknown }).role;
      if (role === 'service_role') return 'service_role_jwt';
      if (role === 'anon') return 'anon_jwt';
    } catch { /* not a JSON payload: unknown */ }
  }
  return 'unknown';
}

export class ConfigError extends Error {
  constructor(readonly problems: string[]) {
    super(`invalid configuration: ${problems.join('; ')}`);
    this.name = 'ConfigError';
  }
}

export interface Config {
  supabaseUrl: string;
  serviceKey: string;
  keyKind: 'secret' | 'service_role_jwt';
  /** Origin override for the Jobicy API; undefined in production. */
  jobicyOrigin?: string;
  maxPages: number;
}

const LOCAL_HOSTS = ['localhost', '127.0.0.1', '[::1]'];

/** @throws ConfigError listing every problem found (variable names and reasons only, never values). */
export function loadConfig(env: Env): Config {
  const problems: string[] = [];
  const url = (env.SUPABASE_URL ?? '').trim();
  const key = (env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();

  let supabaseUrl = '';
  if (!url) problems.push('SUPABASE_URL is not set');
  else {
    try {
      const u = new URL(url);
      const local = LOCAL_HOSTS.includes(u.hostname);
      if (!(u.protocol === 'https:' || (u.protocol === 'http:' && local)) || u.username || u.password) {
        problems.push('SUPABASE_URL must be https without credentials');
      } else supabaseUrl = u.origin;
    } catch {
      problems.push('SUPABASE_URL is not a valid URL');
    }
  }

  let keyKind: Config['keyKind'] = 'secret';
  if (!key) problems.push('SUPABASE_SERVICE_ROLE_KEY is not set');
  else {
    const kind = classifyKey(key);
    if (kind === 'secret' || kind === 'service_role_jwt') keyKind = kind;
    else if (kind === 'publishable' || kind === 'anon_jwt') {
      problems.push('SUPABASE_SERVICE_ROLE_KEY holds a publishable/anon key, which cannot write the catalogue');
    } else problems.push('SUPABASE_SERVICE_ROLE_KEY is not a recognised secret key (sb_secret_... or a service_role JWT)');
  }

  let jobicyOrigin: string | undefined;
  if (env.JOBICY_API_URL !== undefined && env.JOBICY_API_URL.trim() !== '') {
    try {
      const u = new URL(env.JOBICY_API_URL.trim());
      const ok = (u.protocol === 'https:' && u.hostname === 'jobicy.com') || (u.protocol === 'http:' && LOCAL_HOSTS.includes(u.hostname));
      if (ok && !u.username && !u.password) jobicyOrigin = u.origin;
      else problems.push('JOBICY_API_URL must be https://jobicy.com or a localhost URL');
    } catch {
      problems.push('JOBICY_API_URL is not a valid URL');
    }
  }

  let maxPages = 40;
  if (env.SYNC_MAX_PAGES !== undefined && env.SYNC_MAX_PAGES.trim() !== '') {
    const n = Number(env.SYNC_MAX_PAGES);
    if (Number.isInteger(n) && n >= 1 && n <= 100) maxPages = n;
    else problems.push('SYNC_MAX_PAGES must be an integer from 1 to 100');
  }

  if (problems.length) throw new ConfigError(problems);
  return { supabaseUrl, serviceKey: key, keyKind, jobicyOrigin, maxPages };
}
