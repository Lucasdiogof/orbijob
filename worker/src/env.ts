/**
 * Environment of the Cloudflare Worker, typed and validated. Minimal structural types are declared here instead of
 * pulling @cloudflare/workers-types, which would clash with the Node types the tests use.
 *
 * Secrets are set with `wrangler secret put` (never in wrangler.toml, never in Git). Error messages built from this file
 * name the variable and the problem, never the value.
 */
import { SOURCES } from './sources';

export interface Env {
  /** https://<project-ref>.supabase.co */
  SUPABASE_URL?: string;
  /** SECRET. A `sb_secret_...` key or a legacy `service_role` JWT. Never the publishable/anon key. */
  SUPABASE_SERVICE_ROLE_KEY?: string;
  /** Optional, tests only: origin of a stand-in Jobicy API (`https://jobicy.com` or a localhost URL). Unset in production. */
  JOBICY_API_URL?: string;
  /** Which source this pass reads: `jobicy` (default), `arbeitnow`, `remoteok` or `remotive` (src/sources.ts). */
  SYNC_SOURCE?: string;
  /** Optional, tests only: origin of a stand-in API of the chosen source (a localhost URL). Unset in production. */
  SOURCE_API_URL?: string;
  /** Optional: cap on feed pages per pass (1-100, default 40). */
  SYNC_MAX_PAGES?: string;
  /**
   * `full` (default): read the feed, store new and changed jobs, then revalidate stored jobs that left the feed.
   * `revalidate`: touch NO feed and import NOTHING; only ask the source about the jobs already stored (closes the confirmed closed,
   * stamps the confirmed open). The deployed wrangler.toml pins `revalidate`, so widening the catalogue is always an explicit edit.
   * `discover`: read the feed and INSERT only listings that are not stored yet (and that the status endpoint confirms active). Never
   * updates, closes or re-opens a stored job (docs/JOBICY_DISCOVERY.md).
   */
  SYNC_MODE?: string;
  /** Optional, `discover` mode: no new listing is added once this many jobs of the source are stored (1-100000; default 4000). */
  SYNC_MAX_CATALOGUE?: string;
  /** Optional, `full` and `discover` modes: at most this many jobs NOT already stored are added per pass (0-10000; unset = no cap in `full`, 200 in `discover`). */
  SYNC_MAX_NEW_JOBS?: string;
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
  /** `job_sources.id` of the source this pass reads. */
  source: string;
  /** Origin override for the chosen source (tests only; undefined in production). */
  sourceOrigin?: string;
  maxPages: number;
  mode: 'full' | 'revalidate' | 'discover';
  /** Cap on jobs added per pass in `full` and `discover` modes; undefined = uncapped (`discover` defaults to DISCOVER_DEFAULT_CAP). */
  maxNewJobs?: number;
  /** `discover` only: ceiling on the stored jobs of the source (default {@link DISCOVER_DEFAULT_CATALOGUE}). */
  maxCatalogue?: number;
}

/** New listings a `discover` pass may add when SYNC_MAX_NEW_JOBS is unset: a full week of the feed is ~300, so this bounds a surprise. */
export const DISCOVER_DEFAULT_CAP = 200;
/** ~38 KB per stored job (measured in production: rows + full-text and trigram indexes): 4000 jobs ~ 150 MB of the 500 MB free database. */
export const DISCOVER_DEFAULT_CATALOGUE = 4000;

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

  let source = 'jobicy';
  if (env.SYNC_SOURCE !== undefined && env.SYNC_SOURCE.trim() !== '') {
    const v = env.SYNC_SOURCE.trim();
    if (SOURCES[v]) source = v;
    else problems.push(`SYNC_SOURCE must be one of: ${Object.keys(SOURCES).join(', ')}`);
  }
  const profile = SOURCES[source]!;
  let sourceOrigin: string | undefined = jobicyOrigin;
  if (env.SOURCE_API_URL !== undefined && env.SOURCE_API_URL.trim() !== '') {
    try {
      const u = new URL(env.SOURCE_API_URL.trim());
      if (u.protocol === 'http:' && LOCAL_HOSTS.includes(u.hostname) && !u.username && !u.password) sourceOrigin = u.origin;
      else problems.push('SOURCE_API_URL must be a localhost URL (it exists for tests only)');
    } catch {
      problems.push('SOURCE_API_URL is not a valid URL');
    }
  }

  let maxPages = profile.maxPages;
  if (env.SYNC_MAX_PAGES !== undefined && env.SYNC_MAX_PAGES.trim() !== '') {
    const n = Number(env.SYNC_MAX_PAGES);
    if (Number.isInteger(n) && n >= 1 && n <= 100) maxPages = n;
    else problems.push('SYNC_MAX_PAGES must be an integer from 1 to 100');
  }

  let mode: Config['mode'] = 'full';
  if (env.SYNC_MODE !== undefined && env.SYNC_MODE.trim() !== '') {
    const m = env.SYNC_MODE.trim();
    if (m === 'full' || m === 'revalidate' || m === 'discover') mode = m;
    else problems.push('SYNC_MODE must be "full", "revalidate" or "discover"');
  }

  let maxNewJobs: number | undefined;
  if (env.SYNC_MAX_NEW_JOBS !== undefined && env.SYNC_MAX_NEW_JOBS.trim() !== '') {
    const n = Number(env.SYNC_MAX_NEW_JOBS);
    if (Number.isInteger(n) && n >= 0 && n <= 10_000) maxNewJobs = n;
    else problems.push('SYNC_MAX_NEW_JOBS must be an integer from 0 to 10000');
  }

  if (maxNewJobs === undefined && mode === 'discover') maxNewJobs = profile.newCap;

  let maxCatalogue: number | undefined = mode === 'discover' ? profile.catalogue : undefined;
  if (env.SYNC_MAX_CATALOGUE !== undefined && env.SYNC_MAX_CATALOGUE.trim() !== '') {
    const n = Number(env.SYNC_MAX_CATALOGUE);
    if (Number.isInteger(n) && n >= 1 && n <= 100_000) maxCatalogue = n;
    else problems.push('SYNC_MAX_CATALOGUE must be an integer from 1 to 100000');
  }
  if (problems.length) throw new ConfigError(problems);
  return { supabaseUrl, serviceKey: key, keyKind, jobicyOrigin, source, sourceOrigin, maxPages, mode, maxNewJobs, maxCatalogue };
}
