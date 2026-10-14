// Pure part of the remote operational health check (11.0): turns what the Worker's read-only key can read into OK / WARN / ALERT rows.
// Complements scripts/supabase/diagnostics/ops-health.sql (which also sees pg_cron and the size of the database through a database login, something
// this key cannot do). No I/O here, so it is unit-tested with plain objects.

export const HOURS = 3600_000;
export const THRESHOLDS = {
  /** newest verification (discover OR revalidate) of a published source's open listings */
  freshWarnH: 14, freshAlertH: 30,
  /** visible listings the app shows */
  visibleWarn: 9000, visibleAlert: 5000,
};

/**
 * input = {
 *   now: Date,
 *   sources: [{ id, can_redistribute }],
 *   newestChecked: { [sourceId]: ISO string | null },     // newest last_checked_at among the source's OPEN listings
 *   runs24h: [{ source_id, scope, status, error_class, started_at }],
 *   visibleJobs: number,
 * }
 * Returns [{ check, status, value, note }] sorted worst first.
 */
export function evaluateHealth(input) {
  const rows = [];
  const now = input.now.getTime();
  for (const s of input.sources) {
    if (!s.can_redistribute) continue;
    const newest = input.newestChecked[s.id] ?? null;
    const ageH = newest ? (now - Date.parse(newest)) / HOURS : Infinity;
    const status = ageH >= THRESHOLDS.freshAlertH ? 'ALERT' : ageH >= THRESHOLDS.freshWarnH ? 'WARN' : 'OK';
    rows.push({
      check: `source_fresh:${s.id}`, status,
      value: newest ? `newest verification ${newest}, ${ageH.toFixed(1)} h ago` : 'no open listing has ever been verified',
      note: `warn at ${THRESHOLDS.freshWarnH} h, alert at ${THRESHOLDS.freshAlertH} h (the app hides a listing after 72 h without verification)`,
    });
    const bad = input.runs24h.filter((r) => r.source_id === s.id && !['ok', 'running'].includes(r.status) && r.error_class !== 'catalogue_full');
    if (bad.length) {
      rows.push({
        check: `source_runs:${s.id}`, status: 'WARN',
        value: `${bad.length} pass(es) not ok in 24 h (${[...new Set(bad.map((r) => r.error_class ?? r.status))].join(', ')})`,
        note: 'a pass that stopped at the catalogue ceiling (catalogue_full) is by design and not counted',
      });
    }
    const full = input.runs24h.filter((r) => r.source_id === s.id && r.error_class === 'catalogue_full');
    if (full.length) {
      rows.push({ check: `source_ceiling:${s.id}`, status: 'WARN', value: `${full.length} pass(es) stopped at the catalogue ceiling in 24 h`, note: 'raise the ceiling in worker/src/sources.ts on purpose, or the source stops growing' });
    }
  }
  const v = input.visibleJobs;
  rows.push({
    check: 'visible_jobs', status: v < THRESHOLDS.visibleAlert ? 'ALERT' : v < THRESHOLDS.visibleWarn ? 'WARN' : 'OK',
    value: `${v} open listings verified in 72 h from published sources`, note: 'a sharp drop means sources stopped refreshing (8.0 baseline 13,491)',
  });
  const order = { ALERT: 0, WARN: 1, OK: 2 };
  return rows.sort((a, b) => order[a.status] - order[b.status] || a.check.localeCompare(b.check));
}

export const worst = (rows) => (rows.some((r) => r.status === 'ALERT') ? 'ALERT' : rows.some((r) => r.status === 'WARN') ? 'WARN' : 'OK');
