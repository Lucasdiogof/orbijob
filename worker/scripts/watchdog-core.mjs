// Pure decision logic of the Jobicy watchdog (no network, no secrets): given what was observed, which alerts are active.
// Used by scripts/jobicy-watchdog.mjs and tested in test/watchdog.test.ts.

export const HOUR = 3600_000;
/** The app hides a job 72 h after its last verification (worker/src/freshness.ts). */
export const EXPIRE_HOURS = 72;
export const THRESHOLDS = {
  /** age of the OLDEST verification among the public jobs */
  warnAgeHours: 48,
  criticalAgeHours: 60,
  /** with a 6-hour cron: two missed runs (12 h) plus GitHub's usual delay */
  noRunHours: 14,
  noSuccessHours: 20,
  consecutiveFailures: 2,
};

/**
 * @param {object} o
 * @param {number} o.nowMs
 * @param {boolean} o.enabled           the repository variable JOBICY_REVALIDATION_ENABLED is 'true'
 * @param {{createdAt:string, conclusion:string|null, status:string, id:number, url?:string, alerts?:string[]}[]} o.runs  scheduled runs, newest first
 * @param {string|null} o.oldestCheckedAt  oldest last_checked_at among the jobs the public can see
 * @param {number} o.visibleJobs
 */
export function evaluate({ nowMs, enabled, runs, oldestCheckedAt, visibleJobs }) {
  const alerts = [];
  const add = (id, severity, message) => alerts.push({ id, severity, message });

  // 1. The catalogue itself (checked even before the automation is switched on: this is the deadline that matters).
  if (visibleJobs === 0) {
    add('catalog_empty', 'critical', 'O catalogo publico esta VAZIO (nenhuma vaga visivel). Se as vagas venceram, rode a revalidacao; se nunca foram publicadas, ignore.');
  } else if (oldestCheckedAt) {
    const t = Date.parse(oldestCheckedAt);
    if (Number.isFinite(t)) {
      const ageH = (nowMs - t) / HOUR;
      const left = Math.max(0, EXPIRE_HOURS - ageH);
      if (ageH >= THRESHOLDS.criticalAgeHours) add('validity_critical', 'critical', `A vaga verificada ha mais tempo tem ${ageH.toFixed(1)} h; sai do app em ${left.toFixed(1)} h (janela de ${EXPIRE_HOURS} h).`);
      else if (ageH >= THRESHOLDS.warnAgeHours) add('validity_warning', 'warning', `A vaga verificada ha mais tempo tem ${ageH.toFixed(1)} h; sai do app em ${left.toFixed(1)} h (janela de ${EXPIRE_HOURS} h).`);
    }
  }

  // 2. The scheduled runs (only meaningful once the automation is enabled).
  // Grace for the very first schedule: right after the switch is turned on there is no SCHEDULED run yet (manual runs do not count),
  // but the catalogue was verified recently (by the manual run that proved the set-up). Alarming then would be a false alarm; once
  // the catalogue is older than the "no run" threshold without any scheduled run, the alerts below apply in full.
  const ageH = oldestCheckedAt && Number.isFinite(Date.parse(oldestCheckedAt)) ? (nowMs - Date.parse(oldestCheckedAt)) / HOUR : null;
  const waitingForFirstRun = runs.length === 0 && ageH !== null && ageH < THRESHOLDS.noRunHours;
  if (enabled && !waitingForFirstRun) {
    const done = runs.filter((r) => r.status === 'completed');
    const newest = runs[0];
    if (!newest || (nowMs - Date.parse(newest.createdAt)) / HOUR >= THRESHOLDS.noRunHours) {
      add('schedule_missed', 'warning', `Nenhuma execucao agendada nas ultimas ${THRESHOLDS.noRunHours} h. O GitHub pode atrasar ou descartar agendamentos; em repositorio publico ele DESATIVA o agendamento apos 60 dias sem atividade no repositorio (reative em Actions).`);
    }
    const lastOk = done.find((r) => r.conclusion === 'success');
    if (!lastOk || (nowMs - Date.parse(lastOk.createdAt)) / HOUR >= THRESHOLDS.noSuccessHours) {
      add('no_recent_success', 'critical', `Nenhuma revalidacao concluida com sucesso nas ultimas ${THRESHOLDS.noSuccessHours} h.`);
    }
    const lastN = done.slice(0, THRESHOLDS.consecutiveFailures);
    if (lastN.length === THRESHOLDS.consecutiveFailures && lastN.every((r) => r.conclusion === 'failure')) {
      add('consecutive_failures', 'critical', `As ${THRESHOLDS.consecutiveFailures} ultimas execucoes agendadas falharam.`);
    }
    const tags = new Set((done[0]?.alerts) ?? []);
    if (tags.has('auth')) add('auth_failed', 'critical', 'O Supabase recusou a credencial da automacao (segredo ORBIJOB_SYNC_WORKER_KEY ausente, errado ou revogado).');
    if (tags.has('unreachable')) add('database_unreachable', 'warning', 'O banco nao respondeu na ultima execucao.');
    if (tags.has('api')) add('jobicy_api_errors', 'warning', 'A API de status do Jobicy falhou na ultima execucao (nada foi fechado por causa disso).');
  }
  return { alerts, healthy: alerts.length === 0 };
}

export const ISSUE_TITLE = 'Alerta: revalidacao automatica do Jobicy';
export const ISSUE_LABEL = 'jobicy-alert';

export function renderIssueBody({ alerts, nowIso, runUrl }) {
  const order = { critical: 0, warning: 1 };
  const lines = [...alerts].sort((a, b) => order[a.severity] - order[b.severity]).map((a) => `- **${a.severity === 'critical' ? 'CRITICO' : 'ATENCAO'}** \`${a.id}\`: ${a.message}`);
  return [
    `Verificacao de ${nowIso}.`, '', ...lines, '',
    'O que fazer: veja `docs/JOBICY_ACTIONS_AUTOMATION.md` (secao "Alertas"). A revalidacao pode ser disparada a mao em Actions → "Jobicy revalidate" → Run workflow.',
    runUrl ? `\nUltima execucao do monitor: ${runUrl}` : '',
    '\n_Esta issue e atualizada e fechada automaticamente pelo monitor quando tudo voltar ao normal._',
  ].join('\n');
}
