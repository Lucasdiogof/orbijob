// Builds _aplicar/<dir>: the ordered SQL files the OWNER runs to publish reviewed sources and to extend the daily expiry to them.
// Each publish file = a review note + the one `set` line the guard demands + the guarded script itself (scripts/supabase/ops/publish_source.sql).
// Nothing here is run by the build: the owner reads the note and runs the files in order.
//   node scripts/make-owner-pack.mjs ../_aplicar/2026-10-13_6_0_fontes
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const out = process.argv[2];
if (!out) { console.error('uso: node scripts/make-owner-pack.mjs <pasta>'); process.exit(2); }
mkdirSync(out, { recursive: true });
const guarded = readFileSync(new URL('../../scripts/supabase/ops/publish_source.sql', import.meta.url), 'utf8').replace(/^﻿/, '');

const sources = [
  {
    id: 'teachingvacancies',
    note: [
      'Teaching Vacancies (Inglaterra, Department for Education): licenca OGL v3.0 declarada nos termos da propria API ("You are free to reuse job listing data',
      'under the terms of the Open Government Licence"; unica excecao: nao cobrar de quem responde ao anuncio). Atribuicao gravada em job_sources.attribution.',
      'Revisado em 13/10/2026: titulos, escolas (empresa), cidade, pais GB declarado pela fonte, link para a pagina do proprio anuncio, descricao em texto limpo,',
      'salario so quando o texto traz 1 ou 2 valores simples com o periodo. Detalhes: docs/SOURCES_6_0.md.',
    ],
  },
  {
    id: 'nycjobs',
    note: [
      'NYC Jobs (NYC Open Data, dataset kpav-sd4t, Department of Citywide Administrative Services): dados abertos da Cidade de Nova York (Open Data Law, Local Law 11/2012:',
      'sem registro, licenca ou restricao de uso). Apenas postagens External (as Internal nunca sao lidas). Link: https://cityjobs.nyc.gov/job/{job_id}.',
      'Revisado em 13/10/2026: titulos, agencia como empresa, pais US, salario com periodo, descricao em texto limpo. Detalhes: docs/SOURCES_6_0.md.',
    ],
  },
  {
    id: 'getonboard',
    note: [
      'Get on Board (tecnologia na America Latina): API PUBLICA documentada ("Public API: open to anyone ... no authentication required", /api-doc.html), robots.txt sem restricoes.',
      'ATENCAO (decisao sua): os Termos de Servico lidos (13/10/2026) restringem copia e download automatico apenas no contrato de CLIENTES; nada na referencia da API publica nem',
      'na politica de privacidade concede ou nega armazenar/redistribuir. Recomendado: publicar e, em paralelo, escrever para team@getonbrd.com pedindo confirmacao (rascunho em',
      'docs/SOURCES_6_0.md). Reversao imediata: update public.job_sources set can_redistribute = false where id = \'getonboard\';',
    ],
  },
];
let n = 1;
for (const s of sources) {
  const body = [
    ...s.note.map((l) => `-- ${l}`),
    `-- Reverter: update public.job_sources set can_redistribute = false where id = '${s.id}';`,
    `set orbijob.publish_source = '${s.id}:EU-REVISEI-OS-REGISTROS-E-AUTORIZO';`,
    guarded,
  ].join('\n');
  writeFileSync(join(out, `${String(n++).padStart(2, '0')}_publicar_${s.id}.sql`), body);
}

const expiry = [
  '-- Estende a expiracao diaria (so gera `unknown`, nunca `closed`) as tres fontes novas: uma vaga que o feed deixa de listar ha mais de 7 dias sai do app e fica',
  '-- recuperavel por 30 dias. Agenda propria (04:27 UTC, entre a das outras fontes 04:22 e a retencao 04:37), sem tocar nos agendamentos existentes.',
  '-- Pre-requisitos: pg_cron e a migration 20261017000000 (ja aplicadas). Desligar: select cron.unschedule(\'sources6-expire-unseen\');',
  "set orbijob.enable_new_sources_expiry = 'EU-AUTORIZO-A-EXPIRACAO-AUTOMATICA';",
  'do $enable$',
  'begin',
  "  if coalesce(current_setting('orbijob.enable_new_sources_expiry', true), '') <> 'EU-AUTORIZO-A-EXPIRACAO-AUTOMATICA' then",
  "    raise exception 'ativacao bloqueada: falta a autorizacao explicita do proprietario (ver o cabecalho deste arquivo)';",
  '  end if;',
  "  if to_regnamespace('cron') is null then raise exception 'ativacao bloqueada: a extensao pg_cron nao esta instalada'; end if;",
  "  if to_regprocedure('ops.expire_unseen_jobs(text, interval, text[], integer)') is null then",
  "    raise exception 'ativacao bloqueada: a migration 20261017000000 nao foi aplicada';",
  '  end if;',
  "  perform cron.schedule('sources6-expire-unseen', '27 4 * * *', $cmd$select ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO', interval '7 days', array['getonboard', 'teachingvacancies', 'nycjobs'])$cmd$);",
  'end',
  '$enable$;',
].join('\n');
writeFileSync(join(out, `${String(n++).padStart(2, '0')}_ligar_expiracao_fontes_novas.sql`), expiry);

writeFileSync(join(out, 'LEIA-ME.md'), [
  '# Pacote do dono: fontes novas do OrbiJob 6.0 (13/10/2026)',
  '',
  'As tres fontes abaixo ja estao no banco **sem aparecer no app** (`can_redistribute = false`): o conector foi testado, a simulacao e a importacao rodaram e as',
  'amostras foram revisadas (docs/SOURCES_6_0.md). Publicar e uma decisao sua: cada arquivo se recusa a rodar sem a frase de autorizacao, que ja vem na primeira linha.',
  '',
  'Ordem (SQL Editor do projeto `rpmlfxwebnlxnwadyvle`, um arquivo por vez):',
  '1. `01_publicar_teachingvacancies.sql`  (licenca OGL explicita; seguro)',
  '2. `02_publicar_nycjobs.sql`            (dados abertos da cidade; seguro)',
  '3. `03_publicar_getonboard.sql`         (leia a observacao do cabecalho antes)',
  '4. `04_ligar_expiracao_fontes_novas.sql` (expiracao diaria; opcional, so organiza o banco)',
  '',
  'Conferir depois: `select id, can_redistribute from public.job_sources order by id;` e abrir o app (as vagas aparecem em ate uma passada de descoberta).',
].join('\n'));
console.log('ok', out);
