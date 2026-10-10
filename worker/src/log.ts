/**
 * Structured logs: one JSON object per line (Cloudflare Workers Logs indexes the fields). Only counts, classes and
 * identifiers of the run are logged: never job content, never URLs of users, never error messages from servers (they can
 * echo rows or keys). As a last line of defence every registered secret is masked wherever it appears in the line.
 */
export type Level = 'info' | 'warn' | 'error';

export interface LogSink {
  log(line: string): void;
  warn(line: string): void;
  error(line: string): void;
}

export type Logger = (level: Level, event: string, data?: Record<string, unknown>) => void;

const MIN_SECRET_LENGTH = 8;

export function createLogger(sink: LogSink, secrets: readonly string[] = [], now: () => Date = () => new Date()): Logger {
  const toMask = secrets.filter((s) => s.length >= MIN_SECRET_LENGTH);
  return (level, event, data = {}) => {
    let line = JSON.stringify({ level, event, at: now().toISOString(), ...data });
    for (const s of toMask) {
      // JSON-escaped form too (a secret containing a quote or backslash would appear escaped in the line)
      for (const variant of new Set([s, JSON.stringify(s).slice(1, -1)])) line = line.split(variant).join('[redacted]');
    }
    sink[level === 'info' ? 'log' : level](line);
  };
}

/** The console of the Workers runtime is the production sink. */
export const consoleSink: LogSink = {
  log: (l) => console.log(l),
  warn: (l) => console.warn(l),
  error: (l) => console.error(l),
};
