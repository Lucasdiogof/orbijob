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
 * Returns [{ check, status, value, note }] sorted worst first. status: ALERT | WARN | AT_CAPACITY (planned ceiling, informational) | OK.
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
    // Planned limit, not a fault (13.0): the source is healthy and full. Reported as AT_CAPACITY, never as WARN/ALERT, so it does not drown real problems;
    // a full source that stops refreshing still turns source_fresh WARN/ALERT above, and a failed pass still counts in source_runs.
    const full = input.runs24h.filter((r) => r.source_id === s.id && r.error_class === 'catalogue_full');
    if (full.length) {
      rows.push({ check: `source_ceiling:${s.id}`, status: 'AT_CAPACITY', value: `${full.length} pass(es) stopped at the planned catalogue ceiling in 24 h`, note: 'by design: nothing new enters until listings expire; raise the ceiling in worker/src/sources.ts only on purpose' });
    }
  }
  const v = input.visibleJobs;
  rows.push({
    check: 'visible_jobs', status: v < THRESHOLDS.visibleAlert ? 'ALERT' : v < THRESHOLDS.visibleWarn ? 'WARN' : 'OK',
    value: `${v} open listings verified in 72 h from published sources`, note: 'a sharp drop means sources stopped refreshing (8.0 baseline 13,491)',
  });
  const order = { ALERT: 0, WARN: 1, AT_CAPACITY: 2, OK: 3 };
  return rows.sort((a, b) => order[a.status] - order[b.status] || a.check.localeCompare(b.check));
}

/** AT_CAPACITY rows are informational: they never raise the overall status. */
export const worst = (rows) => (rows.some((r) => r.status === 'ALERT') ? 'ALERT' : rows.some((r) => r.status === 'WARN') ? 'WARN' : 'OK');
